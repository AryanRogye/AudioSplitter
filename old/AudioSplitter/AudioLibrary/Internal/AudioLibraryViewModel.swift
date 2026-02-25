import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioLibraryViewModel: ObservableObject {
    @Published private(set) var history: [ProcessedTrackHistoryItem] = []
    @Published private(set) var savedLayeredMixes: [SavedLayeredMix] = []
    @Published private(set) var selectionDuplicateMatch: DuplicateAudioMatch?
    @Published private(set) var isCheckingSimilarity = false
    @Published private(set) var isStagePlaying = false
    @Published private(set) var isSavingLayeredMix = false
    @Published private(set) var currentlyPreviewingRole: StageTrackRole?
    @Published private(set) var previewPlaybackTime: Double = 0
    @Published private(set) var previewPlaybackDuration: Double = 0
    @Published private(set) var stagePlaybackTime: Double = 0
    @Published private(set) var stagePlaybackDuration: Double = 0
    @Published var stageErrorText: String?

    @Published var selectedVocalID: StoredStemAsset.ID?
    @Published var selectedInstrumentalID: StoredStemAsset.ID?
    
    @Published var vocalStartTime: Double = 0
    @Published var instrumentalStartTime: Double = 0
    @Published var stageDelay: Double = 0
    @Published private(set) var selectedVocalDuration: Double = 0
    @Published private(set) var selectedInstrumentalDuration: Double = 0

    let historyStore: AudioHistoryStoring
    private let fingerprinting: AudioFingerprinting
    private let stagePlayback: StagePlaybackControlling
    private let previewPlayback: StagePreviewPlaybackControlling
    private let stageMixExporter: StageMixExporting

    private var sourceFingerprintCache: [String: [Float]] = [:]
    private var durationCache: [String: Double] = [:]
    private var lastPersistedSignature: String?
    private var latestDuplicateCheckPath: String?
    private let duplicateThreshold = 0.94
    private var previewTimelineTimer: Timer?
    private var stageTimelineTimer: Timer?

    convenience init(previewHistory: [ProcessedTrackHistoryItem]) {
        self.init(
            historyStore: FileAudioHistoryStoreAdapter(),
            fingerprinting: AVAudioFingerprintAdapter(),
            stagePlayback: AVAudioStagePlaybackAdapter(),
            previewPlayback: AVAudioStagePreviewPlaybackAdapter(),
            stageMixExporter: AVAudioStageMixExporterAdapter()
        )
        self.history = previewHistory
    }
    
    convenience init() {
        self.init(
            historyStore: FileAudioHistoryStoreAdapter(),
            fingerprinting: AVAudioFingerprintAdapter(),
            stagePlayback: AVAudioStagePlaybackAdapter(),
            previewPlayback: AVAudioStagePreviewPlaybackAdapter(),
            stageMixExporter: AVAudioStageMixExporterAdapter()
        )
    }

    init(
        historyStore: AudioHistoryStoring,
        fingerprinting: AudioFingerprinting,
        stagePlayback: StagePlaybackControlling,
        previewPlayback: StagePreviewPlaybackControlling,
        stageMixExporter: StageMixExporting
    ) {
        self.historyStore = historyStore
        self.fingerprinting = fingerprinting
        self.stagePlayback = stagePlayback
        self.previewPlayback = previewPlayback
        self.stageMixExporter = stageMixExporter
        self.isStagePlaying = stagePlayback.isPlaying
        self.currentlyPreviewingRole = previewPlayback.currentlyPreviewingRole

        self.stagePlayback.onPlaybackStateChanged = { [weak self] isPlaying in
            Task { @MainActor in
                self?.isStagePlaying = isPlaying
                self?.handleStagePlaybackStateChanged(isPlaying)
            }
        }

        self.previewPlayback.onPreviewStateChanged = { [weak self] role in
            Task { @MainActor in
                self?.currentlyPreviewingRole = role
                self?.handlePreviewStateChanged(role)
            }
        }

        reloadHistory()
    }

    var maxVocalStartTime: Double {
        max(0, selectedVocalDuration - 0.05)
    }

    var maxInstrumentalStartTime: Double {
        max(0, selectedInstrumentalDuration - 0.05)
    }

    var stageDelayRangeMagnitude: Double {
        // Keep at least 30s and expand with selected track lengths.
        max(30, ceil(max(selectedVocalDuration, selectedInstrumentalDuration)))
    }

    var minStageDelay: Double {
        -stageDelayRangeMagnitude
    }

    var maxStageDelay: Double {
        stageDelayRangeMagnitude
    }

    var availableVocalAssets: [StoredStemAsset] {
        history
            .flatMap(\.stems)
            .filter { $0.kind == .vocals && FileManager.default.fileExists(atPath: $0.fileURL.path) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var availableInstrumentalAssets: [StoredStemAsset] {
        history
            .flatMap(\.stems)
            .filter { $0.kind == .instrumental && FileManager.default.fileExists(atPath: $0.fileURL.path) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var selectedVocalAsset: StoredStemAsset? {
        availableVocalAssets.first(where: { $0.id == selectedVocalID })
    }

    var selectedInstrumentalAsset: StoredStemAsset? {
        availableInstrumentalAssets.first(where: { $0.id == selectedInstrumentalID })
    }
    
    func fileUrls() -> [EditorFile] {
        var files: [EditorFile] = []
        
        for hist in history {
            
            let editorFile = EditorFile(
                hist.sourceFileURL,
                id: hist.id,
                name: hist.displayName,
                created: hist.createdAt,
                type: .all
            )
            files.append(editorFile)
            
            for stem in hist.stems {
                let kind: SongType = stem.kind == .vocals ? .vocal : .instrumental
                
                let stemFile = EditorFile(
                    stem.fileURL,
                    id: stem.id,
                    name: stem.displayName,
                    created: stem.createdAt,
                    type: kind
                )
                files.append(stemFile)
            }
        }
        
        return files
    }

    func reloadHistory() {
        do {
            history = try historyStore.loadHistory()
            savedLayeredMixes = try historyStore.loadSavedLayeredMixes()
            resetStageSelectionIfNeeded()
            handleSelectionChanged()
        } catch {
            stageErrorText = "Failed to load history: \(error.localizedDescription)"
        }
    }

    func persistProcessedTrack(sourceURL: URL, stems: [StemFile]) {
        guard !stems.isEmpty else { return }

        let signature = ([sourceURL.path] + stems.map(\.fileURL.path).sorted()).joined(separator: "|")
        guard signature != lastPersistedSignature else { return }

        Task {
            do {
                let sourceFingerprint = try await fingerprintForFile(at: sourceURL)
                let saved = try historyStore.saveProcessedTrack(
                    sourceURL: sourceURL,
                    stems: stems,
                    sourceFingerprint: sourceFingerprint
                )

                history.insert(saved, at: 0)
                lastPersistedSignature = signature
                resetStageSelectionIfNeeded()
                handleSelectionChanged()
            } catch {
                stageErrorText = "Could not save split history: \(error.localizedDescription)"
            }
        }
    }

    func evaluateSelectionForDuplicate(_ sourceURL: URL?) {
        selectionDuplicateMatch = nil
        isCheckingSimilarity = false
        guard let sourceURL else { return }

        isCheckingSimilarity = true
        latestDuplicateCheckPath = sourceURL.path

        Task {
            let match = await findDuplicateCandidate(for: sourceURL)
            if latestDuplicateCheckPath == sourceURL.path {
                selectionDuplicateMatch = match
                isCheckingSimilarity = false
            }
        }
    }

    func findDuplicateCandidate(for sourceURL: URL) async -> DuplicateAudioMatch? {
        guard !history.isEmpty else { return nil }

        do {
            let fingerprint = try await fingerprintForFile(at: sourceURL)

            let best = history
                .map { entry in
                    DuplicateAudioMatch(
                        entry: entry,
                        similarity: fingerprinting.similarity(between: fingerprint, and: entry.sourceFingerprint)
                    )
                }
                .max(by: { $0.similarity < $1.similarity })

            guard let best, best.similarity >= duplicateThreshold else {
                return nil
            }

            return best
        } catch {
            stageErrorText = "Similarity check failed: \(error.localizedDescription)"
            return nil
        }
    }

    func toggleStagePlayback() {
        stageErrorText = nil

        previewPlayback.stopPreview()
        currentlyPreviewingRole = previewPlayback.currentlyPreviewingRole

        stagePlayback.configure(
            vocalURL: selectedVocalAsset?.fileURL,
            vocalStartTime: vocalStartTime,
            instrumentalURL: selectedInstrumentalAsset?.fileURL,
            instrumentalStartTime: instrumentalStartTime,
            stageDelay: stageDelay
        )

        do {
            try stagePlayback.togglePlayback()
            isStagePlaying = stagePlayback.isPlaying
            refreshStageTimeline()
        } catch {
            stageErrorText = error.localizedDescription
            stagePlayback.stopPlayback()
            isStagePlaying = stagePlayback.isPlaying
            refreshStageTimeline()
        }
    }

    func stopStagePlayback() {
        stagePlayback.stopPlayback()
        isStagePlaying = stagePlayback.isPlaying
        refreshStageTimeline()
    }

    func scrubStagePlayback(to time: Double) {
        stagePlayback.seek(to: time)
        refreshStageTimeline()
    }

    func stopPreview() {
        previewPlayback.stopPreview()
        currentlyPreviewingRole = previewPlayback.currentlyPreviewingRole
    }

    func toggleVocalPreview() {
        togglePreview(
            role: .vocal,
            url: selectedVocalAsset?.fileURL,
            startTime: vocalStartTime
        )
    }

    func toggleInstrumentalPreview() {
        togglePreview(
            role: .instrumental,
            url: selectedInstrumentalAsset?.fileURL,
            startTime: instrumentalStartTime
        )
    }

    func saveCurrentLayeredMix() {
        guard let selectedVocal = selectedVocalAsset,
              let selectedInstrumental = selectedInstrumentalAsset else {
            stageErrorText = "Select both a vocal and an instrumental before saving a layered mix."
            return
        }

        let vocalURL = selectedVocal.fileURL
        let instrumentalURL = selectedInstrumental.fileURL
        let vocalStartOffset = self.vocalStartTime
        let instrumentalStartOffset = self.instrumentalStartTime
        let stageDelayOffset = self.stageDelay
        let vocalName = selectedVocal.displayName
        let instrumentalName = selectedInstrumental.displayName

        stageErrorText = nil
        isSavingLayeredMix = true

        Task {
            do {
                let exportedURL = try await stageMixExporter.exportLayeredMix(
                    vocalURL: vocalURL,
                    vocalStartTime: vocalStartOffset,
                    instrumentalURL: instrumentalURL,
                    instrumentalStartTime: instrumentalStartOffset,
                    stageDelay: stageDelayOffset
                )
                defer {
                    try? FileManager.default.removeItem(at: exportedURL)
                }

                let savedMix = try historyStore.saveLayeredMix(
                    from: exportedURL,
                    vocalName: vocalName,
                    instrumentalName: instrumentalName,
                    delaySeconds: stageDelayOffset
                )

                savedLayeredMixes.insert(savedMix, at: 0)
            } catch {
                stageErrorText = "Could not save layered mix: \(error.localizedDescription)"
            }

            isSavingLayeredMix = false
        }
    }

    func deleteSavedLayeredMix(id: UUID) {
        do {
            try historyStore.deleteSavedLayeredMix(id: id)
            savedLayeredMixes.removeAll { $0.id == id }
        } catch {
            stageErrorText = "Could not delete layered mix: \(error.localizedDescription)"
        }
    }

    func handleSelectionChanged() {
        stopStagePlayback()
        stopPreview()

        Task {
            await refreshSelectedDurations()
        }
    }

    func setVocalStartTime(_ value: Double) {
        let clamped = clampStartTime(value, maxDuration: selectedVocalDuration)
        vocalStartTime = clamped
        if currentlyPreviewingRole == .vocal {
            previewPlayback.seek(to: clamped)
            refreshPreviewTimeline()
        }
    }

    func setInstrumentalStartTime(_ value: Double) {
        let clamped = clampStartTime(value, maxDuration: selectedInstrumentalDuration)
        instrumentalStartTime = clamped
        if currentlyPreviewingRole == .instrumental {
            previewPlayback.seek(to: clamped)
            refreshPreviewTimeline()
        }
    }

    func nudgeVocalStartTime(by delta: Double) {
        setVocalStartTime(vocalStartTime + delta)
    }

    func nudgeInstrumentalStartTime(by delta: Double) {
        setInstrumentalStartTime(instrumentalStartTime + delta)
    }

    func scrubActivePreview(to time: Double) {
        switch currentlyPreviewingRole {
        case .vocal:
            setVocalStartTime(time)
        case .instrumental:
            setInstrumentalStartTime(time)
        case .none:
            break
        }
    }

    func setStageDelay(_ value: Double) {
        stageDelay = clampedStageDelay(value)
        if isStagePlaying {
            stopStagePlayback()
        }
    }

    func nudgeStageDelay(by delta: Double) {
        setStageDelay(stageDelay + delta)
    }

    func formattedTime(_ value: Double) -> String {
        let totalSeconds = Int(max(0, value.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func formattedPreciseTime(_ value: Double) -> String {
        let clamped = max(0, value)
        let minutes = Int(clamped) / 60
        let seconds = clamped.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%06.3f", minutes, seconds)
    }

    func formattedSignedSeconds(_ value: Double) -> String {
        let sign = value < 0 ? "-" : "+"
        let absolute = abs(value)
        let minutes = Int(absolute) / 60
        let seconds = absolute.truncatingRemainder(dividingBy: 60)
        return String(format: "%@%d:%04.1f", sign, minutes, seconds)
    }

    func formattedPreciseSignedSeconds(_ value: Double) -> String {
        let sign = value < 0 ? "-" : "+"
        return "\(sign)\(formattedPreciseTime(abs(value)))"
    }

    func renameHistoryItem(id: UUID, newName: String?) {
        do {
            try historyStore.renameHistoryItem(id: id, newName: newName)
            reloadHistory()
        } catch {
            stageErrorText = "Could not rename item: \(error.localizedDescription)"
        }
    }

    func renameStemAsset(id: UUID, newName: String?) {
        do {
            try historyStore.renameStemAsset(id: id, newName: newName)
            reloadHistory()
        } catch {
            stageErrorText = "Could not rename stem: \(error.localizedDescription)"
        }
    }

    func deleteHistoryItem(id: UUID) {
        do {
            try historyStore.deleteHistoryItem(id: id)
            reloadHistory()
        } catch {
            stageErrorText = "Could not delete item: \(error.localizedDescription)"
        }
    }

    private func resetStageSelectionIfNeeded() {
//        if selectedVocalAsset == nil {
//            selectedVocalID = availableVocalAssets.first?.id
//        }
//
//        if selectedInstrumentalAsset == nil {
//            selectedInstrumentalID = availableInstrumentalAssets.first?.id
//        }
    }

    private func togglePreview(role: StageTrackRole, url: URL?, startTime: Double) {
        stageErrorText = nil
        stopStagePlayback()

        do {
            try previewPlayback.togglePreview(
                role: role,
                fileURL: url,
                startTime: startTime
            )
            currentlyPreviewingRole = previewPlayback.currentlyPreviewingRole
        } catch {
            stageErrorText = error.localizedDescription
            previewPlayback.stopPreview()
            currentlyPreviewingRole = previewPlayback.currentlyPreviewingRole
        }
    }

    private func clampStartTime(_ value: Double, maxDuration: Double) -> Double {
        min(max(0, value), max(0, maxDuration - 0.05))
    }

    private func clampedStageDelay(_ value: Double) -> Double {
        min(max(value, minStageDelay), maxStageDelay)
    }

    private func refreshSelectedDurations() async {
        let selectedVocal = selectedVocalAsset
        let selectedInstrumental = selectedInstrumentalAsset

        let vocalDuration = await duration(for: selectedVocal?.fileURL) ?? 0
        let instrumentalDuration = await duration(for: selectedInstrumental?.fileURL) ?? 0

        if selectedVocal?.id == selectedVocalAsset?.id {
            selectedVocalDuration = vocalDuration
            vocalStartTime = clampStartTime(vocalStartTime, maxDuration: vocalDuration)
        }

        if selectedInstrumental?.id == selectedInstrumentalAsset?.id {
            selectedInstrumentalDuration = instrumentalDuration
            instrumentalStartTime = clampStartTime(instrumentalStartTime, maxDuration: instrumentalDuration)
        }

        stageDelay = clampedStageDelay(stageDelay)
    }

    private func handlePreviewStateChanged(_ role: StageTrackRole?) {
        if role == nil {
            stopPreviewTimelineUpdates()
            previewPlaybackTime = 0
            previewPlaybackDuration = 0
            return
        }

        startPreviewTimelineUpdates()
        refreshPreviewTimeline()
    }

    private func startPreviewTimelineUpdates() {
        previewTimelineTimer?.invalidate()
        previewTimelineTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPreviewTimeline()
            }
        }
    }

    private func stopPreviewTimelineUpdates() {
        previewTimelineTimer?.invalidate()
        previewTimelineTimer = nil
    }

    private func refreshPreviewTimeline() {
        previewPlaybackTime = max(0, previewPlayback.currentPlaybackTime)
        previewPlaybackDuration = max(0, previewPlayback.currentDuration)
    }

    private func handleStagePlaybackStateChanged(_ isPlaying: Bool) {
        if isPlaying {
            startStageTimelineUpdates()
            refreshStageTimeline()
        } else {
            stopStageTimelineUpdates()
            refreshStageTimeline()
        }
    }

    private func startStageTimelineUpdates() {
        stageTimelineTimer?.invalidate()
        stageTimelineTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStageTimeline()
            }
        }
    }

    private func stopStageTimelineUpdates() {
        stageTimelineTimer?.invalidate()
        stageTimelineTimer = nil
    }

    private func refreshStageTimeline() {
        stagePlaybackTime = max(0, stagePlayback.currentPlaybackTime)
        stagePlaybackDuration = max(0, stagePlayback.currentDuration)
    }

    private func duration(for fileURL: URL?) async -> Double? {
        guard let fileURL else { return nil }
        let cacheKey = fileURL.path

        if let cached = durationCache[cacheKey] {
            return cached
        }

        let seconds = await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: fileURL)
            let raw = CMTimeGetSeconds(asset.duration)
            guard raw.isFinite, raw > 0 else { return 0.0 }
            return raw
        }.value

        durationCache[cacheKey] = seconds
        return seconds
    }

    private func fingerprintForFile(at url: URL) async throws -> [Float] {
        let cacheKey = url.path

        if let cached = sourceFingerprintCache[cacheKey] {
            return cached
        }

        let fingerprint = try await Task.detached(priority: .userInitiated) { [fingerprinting] in
            try fingerprinting.fingerprint(for: url)
        }.value

        sourceFingerprintCache[cacheKey] = fingerprint
        return fingerprint
    }
}
