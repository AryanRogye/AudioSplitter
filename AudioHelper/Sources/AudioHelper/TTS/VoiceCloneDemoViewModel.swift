//
//  VoiceCloneDemoViewModel.swift
//  AudioHelper
//
//  Created by Aryan Rogye on 2/23/26.
//

import SwiftUI
@preconcurrency import AVFoundation
import PhotosUI
import UniformTypeIdentifiers
import Combine
import UIKit
import FluidAudio

#if os(iOS)

@MainActor
public final class VoiceCloneDemoViewModel: NSObject, ObservableObject {
    private struct ControlSnapshot: Codable {
        var studioQualityMode: Bool
        var strictLiteralMode: Bool
        var synthesisTemperature: Float
        var maxReferenceDurationSeconds: Double
        var preferredReferenceDurationSeconds: Double
        var minReferenceDurationSeconds: Double
        var voiceCloneSampleRate: Double
        var referenceHighPassHz: Float
        var referenceTargetPeak: Float
        var referenceMaxGain: Float
        var referenceFadeSeconds: Double
        var speechEnergyFloor: Float
        var speechThresholdMultiplier: Float
        var speechThresholdBlend: Float
        var segmentCharLimit: Int
        var mergeCrossfadeSeconds: Double
        var pauseSecondsLiteral: Double
        var pauseSecondsNormal: Double
        var outputTargetPeak: Float
        var outputMaxGain: Float
        var outputFadeSeconds: Double
        var outputTrimThreshold: Float
        var outputTrimMaxSeconds: Double
        
        static let defaults = ControlSnapshot(
            studioQualityMode: true,
            strictLiteralMode: true,
            synthesisTemperature: 0.10,
            maxReferenceDurationSeconds: 20.0,
            preferredReferenceDurationSeconds: 14.0,
            minReferenceDurationSeconds: 4.0,
            voiceCloneSampleRate: 24_000,
            referenceHighPassHz: 70,
            referenceTargetPeak: 0.92,
            referenceMaxGain: 3.0,
            referenceFadeSeconds: 0.018,
            speechEnergyFloor: 0.0035,
            speechThresholdMultiplier: 1.8,
            speechThresholdBlend: 0.22,
            segmentCharLimit: 140,
            mergeCrossfadeSeconds: 0.022,
            pauseSecondsLiteral: 0.045,
            pauseSecondsNormal: 0.020,
            outputTargetPeak: 0.94,
            outputMaxGain: 1.6,
            outputFadeSeconds: 0.010,
            outputTrimThreshold: 0.0018,
            outputTrimMaxSeconds: 0.35
        )
    }
    
    struct SavedAudioItem: Identifiable, Hashable {
        let url: URL
        let name: String
        let createdAt: Date
        let sizeBytes: Int64
        
        var id: String { url.path }
        var baseName: String { (name as NSString).deletingPathExtension }
        var fileExtension: String { (name as NSString).pathExtension }
    }
    
    @Published var text: String = "This is my cloned voice speaking on device."
    @Published var status: String = "Pick a clip, clone voice, then speak. Studio mode improves reference quality."
    
    @Published var selectedMediaName: String = "None"
    @Published var hasSelectedMedia: Bool = false
    @Published var hasClonedVoice: Bool = false
    @Published var clonedVoiceName: String = "None"
    
    @Published var isInitializing: Bool = false
    @Published var isCloning: Bool = false
    @Published var isSynthesizing: Bool = false
    @Published var isPlaying: Bool = false
    @Published var synthesisTemperature: Float = 0.10
    @Published var strictLiteralMode: Bool = true
    @Published var studioQualityMode: Bool = true
    @Published var maxReferenceDurationSeconds: Double = 20.0
    @Published var preferredReferenceDurationSeconds: Double = 14.0
    @Published var minReferenceDurationSeconds: Double = 4.0
    @Published var voiceCloneSampleRate: Double = 24_000
    @Published var referenceHighPassHz: Float = 70
    @Published var referenceTargetPeak: Float = 0.92
    @Published var referenceMaxGain: Float = 3.0
    @Published var referenceFadeSeconds: Double = 0.018
    @Published var speechEnergyFloor: Float = 0.0035
    @Published var speechThresholdMultiplier: Float = 1.8
    @Published var speechThresholdBlend: Float = 0.22
    @Published var segmentCharLimit: Int = 140
    @Published var mergeCrossfadeSeconds: Double = 0.022
    @Published var pauseSecondsLiteral: Double = 0.045
    @Published var pauseSecondsNormal: Double = 0.020
    @Published var outputTargetPeak: Float = 0.94
    @Published var outputMaxGain: Float = 1.6
    @Published var outputFadeSeconds: Double = 0.010
    @Published var outputTrimThreshold: Float = 0.0018
    @Published var outputTrimMaxSeconds: Double = 0.35
    @Published var controlProfileText: String = ""
    @Published var audioSaveName: String = ""
    @Published var savedAudioItems: [SavedAudioItem] = []
    
    private var synthManager = PocketTtsManager()
    
    private var clonedVoice: PocketTtsVoiceData?
    private var selectedMediaURL: URL?
    private var extractedAudioURL: URL?
    private var synthesizedAudioURL: URL?
    private var audioPlayer: AVAudioPlayer?
    private var didInitialize = false
    private var selectionVersion = 0
    private let controlSnapshotDefaultsKey = "ComfyTTS.ControlSnapshot.v2"
    private let savedAudioFolderName = "ComfyTTS-Saved-Audio"
    
    override init() {
        super.init()
        loadControlsFromDevice()
        refreshControlProfileText()
        refreshSavedAudioItems()
    }
    
    func initializeManually() async {
        guard !isInitializing else { return }
        do {
            try await ensureInitialized(forceStatusUpdate: true)
            status = "PocketTTS initialized. Pick a clip to clone."
        } catch {
            status = "Initialization failed: \(error.localizedDescription)"
        }
    }
    
    func importFromFiles(_ url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let copiedURL = try Self.copyToTemporaryFile(from: url)
            setSelectedMedia(url: copiedURL)
        } catch {
            status = "Import failed: \(error.localizedDescription)"
        }
    }
    
    func importFromPhotoPicker(_ temporaryVideoURL: URL) {
        setSelectedMedia(url: temporaryVideoURL)
    }
    
    func clearSelection() {
        stopPlayback()
        selectedMediaURL = nil
        selectedMediaName = "None"
        hasSelectedMedia = false
        selectionVersion += 1
        clearClonedVoiceState(updateStatus: false)
        
        if let extractedAudioURL {
            try? FileManager.default.removeItem(at: extractedAudioURL)
            self.extractedAudioURL = nil
        }
        
        status = "Selection cleared. Pick a new clip."
    }
    
    func clearClonedVoice() {
        clearClonedVoiceState(updateStatus: true)
    }
    
    func hardResetSession() {
        stopPlayback()
        selectionVersion += 1
        selectedMediaURL = nil
        selectedMediaName = "None"
        hasSelectedMedia = false
        clearClonedVoiceState(updateStatus: false)
        synthManager = PocketTtsManager()
        didInitialize = false
        
        if let extractedAudioURL {
            try? FileManager.default.removeItem(at: extractedAudioURL)
            self.extractedAudioURL = nil
        }
        if let synthesizedAudioURL {
            try? FileManager.default.removeItem(at: synthesizedAudioURL)
            self.synthesizedAudioURL = nil
        }
        
        status = "Session reset: model, voice clone, and temporary audio cleared."
    }
    
    func saveControlsToDevice() {
        do {
            let data = try JSONEncoder().encode(sanitizedSnapshot(currentControlSnapshot()))
            UserDefaults.standard.set(data, forKey: controlSnapshotDefaultsKey)
            status = "Controls saved on device."
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }
    
    func loadControlsFromDevice() {
        guard let data = UserDefaults.standard.data(forKey: controlSnapshotDefaultsKey) else {
            applyControlSnapshot(.defaults)
            return
        }
        
        do {
            let snapshot = try JSONDecoder().decode(ControlSnapshot.self, from: data)
            applyControlSnapshot(snapshot)
        } catch {
            applyControlSnapshot(.defaults)
        }
    }
    
    func resetControlsToDefaults() {
        applyControlSnapshot(.defaults)
        refreshControlProfileText()
        status = "Controls reset to defaults."
    }
    
    func refreshControlProfileText() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sanitizedSnapshot(currentControlSnapshot()))
            controlProfileText = String(decoding: data, as: UTF8.self)
            status = "Control profile exported to text."
        } catch {
            status = "Export profile failed: \(error.localizedDescription)"
        }
    }
    
    func loadControlProfileFromText() {
        let text = controlProfileText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            status = "Paste a control profile JSON first."
            return
        }
        
        do {
            let data = Data(text.utf8)
            let snapshot = try JSONDecoder().decode(ControlSnapshot.self, from: data)
            applyControlSnapshot(snapshot)
            saveControlsToDevice()
            status = "Control profile loaded from text."
        } catch {
            status = "Profile JSON invalid: \(error.localizedDescription)"
        }
    }
    
    func copyControlProfileTextToClipboard() {
        refreshControlProfileText()
#if canImport(UIKit)
        UIPasteboard.general.string = controlProfileText
        status = "Control profile copied to clipboard."
#else
        status = "Clipboard not available on this platform."
#endif
    }
    
    func pasteControlProfileTextFromClipboard() {
#if canImport(UIKit)
        guard let value = UIPasteboard.general.string, !value.isEmpty else {
            status = "Clipboard is empty."
            return
        }
        controlProfileText = value
        status = "Pasted control profile JSON from clipboard."
#else
        status = "Clipboard not available on this platform."
#endif
    }
    
    func saveLatestAudioToLibrary() {
        guard let synthesizedAudioURL else {
            status = "Synthesize audio first, then save it."
            return
        }
        
        do {
            let directory = try savedAudioLibraryDirectory()
            let sourceExtension = synthesizedAudioURL.pathExtension.isEmpty ? "wav" : synthesizedAudioURL.pathExtension
            let requestedName = audioSaveName.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseName: String
            if requestedName.isEmpty {
                baseName = Self.defaultSaveName(from: text)
                audioSaveName = baseName
            } else {
                baseName = requestedName
            }
            
            let sanitized = Self.sanitizedFileBaseName(baseName)
            let destinationURL = Self.uniqueDestinationURL(
                in: directory,
                baseName: sanitized,
                fileExtension: sourceExtension
            )
            
            try FileManager.default.copyItem(at: synthesizedAudioURL, to: destinationURL)
            refreshSavedAudioItems()
            status = "Saved audio: \(destinationURL.lastPathComponent)"
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }
    
    func playSavedAudio(_ item: SavedAudioItem) {
        do {
            stopPlayback()
            try playAudio(from: item.url)
            status = "Playing saved audio: \(item.name)"
        } catch {
            status = "Playback failed: \(error.localizedDescription)"
        }
    }
    
    func renameSavedAudio(_ item: SavedAudioItem, to newName: String) {
        let requested = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty else {
            status = "Rename failed: name is empty."
            return
        }
        
        do {
            let directory = try savedAudioLibraryDirectory()
            let fileExtension = item.fileExtension.isEmpty ? "wav" : item.fileExtension
            let sanitized = Self.sanitizedFileBaseName(requested)
            let destinationURL = Self.uniqueDestinationURL(
                in: directory,
                baseName: sanitized,
                fileExtension: fileExtension,
                excluding: item.url
            )
            
            if destinationURL.standardizedFileURL == item.url.standardizedFileURL {
                status = "Name unchanged."
                return
            }
            
            try FileManager.default.moveItem(at: item.url, to: destinationURL)
            refreshSavedAudioItems()
            status = "Renamed to \(destinationURL.lastPathComponent)"
        } catch {
            status = "Rename failed: \(error.localizedDescription)"
        }
    }
    
    func deleteSavedAudio(_ item: SavedAudioItem) {
        do {
            if let currentURL = synthesizedAudioURL,
               currentURL.standardizedFileURL == item.url.standardizedFileURL {
                synthesizedAudioURL = nil
            }
            try FileManager.default.removeItem(at: item.url)
            refreshSavedAudioItems()
            status = "Deleted \(item.name)"
        } catch {
            status = "Delete failed: \(error.localizedDescription)"
        }
    }
    
    func refreshSavedAudioItems() {
        do {
            let directory = try savedAudioLibraryDirectory()
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            
            let allowedExtensions = Set(["wav", "m4a", "mp3", "caf", "aiff", "aif"])
            let items: [SavedAudioItem] = urls.compactMap { url in
                let fileExtension = url.pathExtension.lowercased()
                guard allowedExtensions.contains(fileExtension) else { return nil }
                
                let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
                guard values?.isRegularFile == true else { return nil }
                
                let createdAt = values?.creationDate ?? values?.contentModificationDate ?? .distantPast
                let sizeBytes = Int64(values?.fileSize ?? 0)
                return SavedAudioItem(
                    url: url,
                    name: url.lastPathComponent,
                    createdAt: createdAt,
                    sizeBytes: sizeBytes
                )
            }
            
            savedAudioItems = items.sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.createdAt > rhs.createdAt
            }
        } catch {
            savedAudioItems = []
            status = "Audio library load failed: \(error.localizedDescription)"
        }
    }
    
    func cloneVoiceFromSelection() async {
        guard !isCloning else { return }
        guard hasSelectedMedia else {
            status = "Pick a clip first."
            return
        }
        
        isCloning = true
        defer { isCloning = false }
        
        do {
            clearClonedVoiceState(updateStatus: false)
            let requestedVersion = selectionVersion
            let sourceName = selectedMediaName
            
            status = "Preparing reference audio..."
            let audioURL = try await preparedAudioURLForSelection()
            
            if didInitialize {
                // Drop synthesis models before cloning to reduce peak memory.
                synthManager = PocketTtsManager()
                didInitialize = false
            }
            
            status = "Cloning voice..."
            let cloneManager = PocketTtsManager()
            let voice: PocketTtsVoiceData
            if studioQualityMode {
                status = "Analyzing reference speech..."
                let rawSamples = try Self.load24kMonoFloatSamples(from: audioURL, targetSampleRate: voiceCloneSampleRate)
                let selectedSamples = Self.extractBestSpeechWindow(
                    from: rawSamples,
                    sampleRate: voiceCloneSampleRate,
                    targetSeconds: preferredReferenceDurationSeconds,
                    minSeconds: minReferenceDurationSeconds,
                    energyFloor: speechEnergyFloor,
                    noiseMultiplier: speechThresholdMultiplier,
                    thresholdBlend: speechThresholdBlend
                )
                let conditionedSamples = Self.conditionReferenceSamples(
                    selectedSamples,
                    sampleRate: voiceCloneSampleRate,
                    highPassHz: referenceHighPassHz,
                    targetPeak: referenceTargetPeak,
                    maxGain: referenceMaxGain,
                    fadeSeconds: referenceFadeSeconds
                )
                let refSeconds = Double(conditionedSamples.count) / voiceCloneSampleRate
                status = String(format: "Cloning from %.1fs clean reference...", refSeconds)
                voice = try await cloneManager.cloneVoice(from: conditionedSamples)
            } else {
                voice = try await cloneManager.cloneVoice(from: audioURL)
            }
            
            guard requestedVersion == selectionVersion else {
                status = "Selection changed while cloning. Clone discarded."
                return
            }
            
            clonedVoice = voice
            hasClonedVoice = true
            clonedVoiceName = sourceName
            status = "Voice cloned. Enter text and tap Speak."
        } catch {
            clearClonedVoiceState(updateStatus: false)
            status = "Voice clone failed: \(error.localizedDescription)"
        }
    }
    
    func synthesizeWithClonedVoice() async {
        guard !isSynthesizing else { return }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            status = "Enter text first."
            return
        }
        
        guard let clonedVoice else {
            status = "Clone a voice first."
            return
        }
        
        let preparedText = Self.normalizedSynthesisText(from: trimmed)
        let segments = strictLiteralMode
        ? Self.sentenceSegments(from: preparedText, maxCharsPerSegment: segmentCharLimit)
        : [preparedText]
        
        if preparedText.count > 220 {
            status = "For best accuracy, keep each sentence short."
        }
        
        isSynthesizing = true
        defer { isSynthesizing = false }
        
        do {
            try await ensureInitialized(forceStatusUpdate: false)
            stopPlayback()
            
            let outputURL = try await synthesizeSegmentsToWave(
                segments: segments,
                voiceData: clonedVoice,
                temperature: synthesisTemperature,
                deEss: studioQualityMode,
                enhanceOutput: studioQualityMode
            )
            
            if let synthesizedAudioURL {
                try? FileManager.default.removeItem(at: synthesizedAudioURL)
            }
            synthesizedAudioURL = outputURL
            audioSaveName = Self.defaultSaveName(from: preparedText)
            
            try playAudio(from: outputURL)
            status = "Playing synthesized audio."
        } catch {
            status = "Synthesis failed: \(error.localizedDescription)"
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
    
    private func setSelectedMedia(url: URL) {
        stopPlayback()
        selectionVersion += 1
        
        selectedMediaURL = url
        selectedMediaName = url.lastPathComponent
        hasSelectedMedia = true
        
        clearClonedVoiceState(updateStatus: false)
        
        if let extractedAudioURL {
            try? FileManager.default.removeItem(at: extractedAudioURL)
            self.extractedAudioURL = nil
        }
        
        status = "Selected \(selectedMediaName). Tap Clone Voice."
    }
    
    private func ensureInitialized(forceStatusUpdate: Bool) async throws {
        guard !didInitialize else { return }
        guard !isInitializing else { return }
        
        isInitializing = true
        defer { isInitializing = false }
        
        if forceStatusUpdate {
            status = "Initializing PocketTTS (first run downloads models)..."
        }
        
        try await synthManager.initialize()
        didInitialize = true
    }
    
    private func preparedAudioURLForSelection() async throws -> URL {
        guard let selectedMediaURL else {
            throw VoiceCloneDemoError.noMediaSelected
        }
        
        status = Self.isVideoURL(selectedMediaURL)
        ? "Extracting audio from video..."
        : "Preparing audio clip..."
        
        let outputURL = try await exportReferenceAudioClip(
            from: selectedMediaURL,
            maxDurationSeconds: maxReferenceDurationSeconds
        )
        
        if let extractedAudioURL {
            try? FileManager.default.removeItem(at: extractedAudioURL)
        }
        extractedAudioURL = outputURL
        return outputURL
    }
    
    private func exportReferenceAudioClip(
        from mediaURL: URL,
        maxDurationSeconds: Double
    ) async throws -> URL {
        let asset = AVURLAsset(url: mediaURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw VoiceCloneDemoError.videoHasNoAudioTrack
        }
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw VoiceCloneDemoError.audioExtractionSetupFailed
        }
        
        let outputURL = Self.temporaryURL(withExtension: "m4a")
        try? FileManager.default.removeItem(at: outputURL)
        
        let mediaDuration = try await asset.load(.duration)
        let mediaDurationSeconds = CMTimeGetSeconds(mediaDuration)
        guard mediaDurationSeconds.isFinite, mediaDurationSeconds > 0 else {
            throw VoiceCloneDemoError.invalidMediaDuration
        }
        
        let clippedDurationSeconds = min(maxDurationSeconds, mediaDurationSeconds)
        exportSession.timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: clippedDurationSeconds, preferredTimescale: 600)
        )
        
        do {
            try await exportSession.export(to: outputURL, as: .m4a)
            return outputURL
        } catch {
            throw VoiceCloneDemoError.audioExtractionFailed(error.localizedDescription)
        }
    }
    
    private func playAudio(from url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        player.play()
        
        audioPlayer = player
        isPlaying = true
    }
    
    private static func copyToTemporaryFile(from sourceURL: URL) throws -> URL {
        let ext = sourceURL.pathExtension.isEmpty ? "tmp" : sourceURL.pathExtension
        let destinationURL = temporaryURL(withExtension: ext)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
    
    private static func temporaryURL(withExtension ext: String) -> URL {
        URL.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }
    
    private func savedAudioLibraryDirectory() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? URL.temporaryDirectory
        let directory = documents.appendingPathComponent(savedAudioFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
    
    private static func sanitizedFileBaseName(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let filteredScalars = trimmed.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        var collapsed = String(filteredScalars)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "_{2,}", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ._-"))
        
        if collapsed.isEmpty {
            collapsed = "audio"
        }
        return collapsed
    }
    
    private static func defaultSaveName(from text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let snippet = normalized.split(separator: " ").prefix(6).joined(separator: " ")
        let prefix = snippet.isEmpty ? "audio" : snippet
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        return sanitizedFileBaseName("\(prefix)-\(stamp)")
    }
    
    private static func uniqueDestinationURL(
        in directory: URL,
        baseName: String,
        fileExtension: String,
        excluding existingURL: URL? = nil
    ) -> URL {
        let ext = fileExtension.lowercased()
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(ext)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            if let existingURL,
               candidate.standardizedFileURL == existingURL.standardizedFileURL {
                return candidate
            }
            candidate = directory.appendingPathComponent("\(baseName)-\(index)").appendingPathExtension(ext)
            index += 1
        }
        return candidate
    }
    
    private static func isVideoURL(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else {
            return false
        }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }
    
    private func clearClonedVoiceState(updateStatus: Bool) {
        clonedVoice = nil
        hasClonedVoice = false
        clonedVoiceName = "None"
        
        if updateStatus {
            status = "Cloned voice cleared."
        }
    }
    
    private func currentControlSnapshot() -> ControlSnapshot {
        ControlSnapshot(
            studioQualityMode: studioQualityMode,
            strictLiteralMode: strictLiteralMode,
            synthesisTemperature: synthesisTemperature,
            maxReferenceDurationSeconds: maxReferenceDurationSeconds,
            preferredReferenceDurationSeconds: preferredReferenceDurationSeconds,
            minReferenceDurationSeconds: minReferenceDurationSeconds,
            voiceCloneSampleRate: voiceCloneSampleRate,
            referenceHighPassHz: referenceHighPassHz,
            referenceTargetPeak: referenceTargetPeak,
            referenceMaxGain: referenceMaxGain,
            referenceFadeSeconds: referenceFadeSeconds,
            speechEnergyFloor: speechEnergyFloor,
            speechThresholdMultiplier: speechThresholdMultiplier,
            speechThresholdBlend: speechThresholdBlend,
            segmentCharLimit: segmentCharLimit,
            mergeCrossfadeSeconds: mergeCrossfadeSeconds,
            pauseSecondsLiteral: pauseSecondsLiteral,
            pauseSecondsNormal: pauseSecondsNormal,
            outputTargetPeak: outputTargetPeak,
            outputMaxGain: outputMaxGain,
            outputFadeSeconds: outputFadeSeconds,
            outputTrimThreshold: outputTrimThreshold,
            outputTrimMaxSeconds: outputTrimMaxSeconds
        )
    }
    
    private func applyControlSnapshot(_ snapshot: ControlSnapshot) {
        let s = sanitizedSnapshot(snapshot)
        studioQualityMode = s.studioQualityMode
        strictLiteralMode = s.strictLiteralMode
        synthesisTemperature = s.synthesisTemperature
        maxReferenceDurationSeconds = s.maxReferenceDurationSeconds
        preferredReferenceDurationSeconds = s.preferredReferenceDurationSeconds
        minReferenceDurationSeconds = s.minReferenceDurationSeconds
        voiceCloneSampleRate = s.voiceCloneSampleRate
        referenceHighPassHz = s.referenceHighPassHz
        referenceTargetPeak = s.referenceTargetPeak
        referenceMaxGain = s.referenceMaxGain
        referenceFadeSeconds = s.referenceFadeSeconds
        speechEnergyFloor = s.speechEnergyFloor
        speechThresholdMultiplier = s.speechThresholdMultiplier
        speechThresholdBlend = s.speechThresholdBlend
        segmentCharLimit = s.segmentCharLimit
        mergeCrossfadeSeconds = s.mergeCrossfadeSeconds
        pauseSecondsLiteral = s.pauseSecondsLiteral
        pauseSecondsNormal = s.pauseSecondsNormal
        outputTargetPeak = s.outputTargetPeak
        outputMaxGain = s.outputMaxGain
        outputFadeSeconds = s.outputFadeSeconds
        outputTrimThreshold = s.outputTrimThreshold
        outputTrimMaxSeconds = s.outputTrimMaxSeconds
    }
    
    private func sanitizedSnapshot(_ snapshot: ControlSnapshot) -> ControlSnapshot {
        var s = snapshot
        s.synthesisTemperature = Self.clampFloat(s.synthesisTemperature, min: 0.0, max: 0.7)
        s.maxReferenceDurationSeconds = Self.clampDouble(s.maxReferenceDurationSeconds, min: 6.0, max: 30.0)
        s.preferredReferenceDurationSeconds = Self.clampDouble(s.preferredReferenceDurationSeconds, min: 3.0, max: 24.0)
        s.minReferenceDurationSeconds = Self.clampDouble(s.minReferenceDurationSeconds, min: 1.0, max: 12.0)
        s.preferredReferenceDurationSeconds = min(s.preferredReferenceDurationSeconds, s.maxReferenceDurationSeconds)
        s.minReferenceDurationSeconds = min(s.minReferenceDurationSeconds, s.preferredReferenceDurationSeconds)
        s.voiceCloneSampleRate = Self.clampDouble(s.voiceCloneSampleRate, min: 16_000, max: 24_000)
        s.referenceHighPassHz = Self.clampFloat(s.referenceHighPassHz, min: 20, max: 180)
        s.referenceTargetPeak = Self.clampFloat(s.referenceTargetPeak, min: 0.6, max: 0.98)
        s.referenceMaxGain = Self.clampFloat(s.referenceMaxGain, min: 1.0, max: 5.0)
        s.referenceFadeSeconds = Self.clampDouble(s.referenceFadeSeconds, min: 0.0, max: 0.08)
        s.speechEnergyFloor = Self.clampFloat(s.speechEnergyFloor, min: 0.0005, max: 0.02)
        s.speechThresholdMultiplier = Self.clampFloat(s.speechThresholdMultiplier, min: 1.0, max: 4.0)
        s.speechThresholdBlend = Self.clampFloat(s.speechThresholdBlend, min: 0.0, max: 1.0)
        s.segmentCharLimit = max(50, min(260, s.segmentCharLimit))
        s.mergeCrossfadeSeconds = Self.clampDouble(s.mergeCrossfadeSeconds, min: 0.0, max: 0.12)
        s.pauseSecondsLiteral = Self.clampDouble(s.pauseSecondsLiteral, min: 0.0, max: 0.25)
        s.pauseSecondsNormal = Self.clampDouble(s.pauseSecondsNormal, min: 0.0, max: 0.15)
        s.outputTargetPeak = Self.clampFloat(s.outputTargetPeak, min: 0.6, max: 0.98)
        s.outputMaxGain = Self.clampFloat(s.outputMaxGain, min: 1.0, max: 4.0)
        s.outputFadeSeconds = Self.clampDouble(s.outputFadeSeconds, min: 0.0, max: 0.08)
        s.outputTrimThreshold = Self.clampFloat(s.outputTrimThreshold, min: 0.0001, max: 0.02)
        s.outputTrimMaxSeconds = Self.clampDouble(s.outputTrimMaxSeconds, min: 0.0, max: 1.5)
        return s
    }
    
    private static func clampDouble(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }
    
    private static func clampFloat(_ value: Float, min: Float, max: Float) -> Float {
        Swift.max(min, Swift.min(max, value))
    }
    
    private func synthesizeSegmentsToWave(
        segments: [String],
        voiceData: PocketTtsVoiceData,
        temperature: Float,
        deEss: Bool,
        enhanceOutput: Bool
    ) async throws -> URL {
        var chunkURLs: [URL] = []
        
        do {
            for (index, segment) in segments.enumerated() {
                if segments.count == 1 {
                    status = "Synthesizing speech..."
                } else {
                    status = "Synthesizing segment \(index + 1)/\(segments.count)..."
                }
                
                let wavData = try await synthManager.synthesize(
                    text: segment,
                    voiceData: voiceData,
                    temperature: temperature,
                    deEss: deEss
                )
                let chunkURL = Self.temporaryURL(withExtension: "wav")
                try wavData.write(to: chunkURL, options: .atomic)
                chunkURLs.append(chunkURL)
            }
            
            if chunkURLs.count == 1 {
                if enhanceOutput {
                    let enhancedURL = try Self.enhanceWaveFile(
                        chunkURLs[0],
                        sampleRate: voiceCloneSampleRate,
                        trimThreshold: outputTrimThreshold,
                        trimMaxSeconds: outputTrimMaxSeconds,
                        targetPeak: outputTargetPeak,
                        maxGain: outputMaxGain,
                        fadeSeconds: outputFadeSeconds
                    )
                    try? FileManager.default.removeItem(at: chunkURLs[0])
                    return enhancedURL
                }
                return chunkURLs[0]
            }
            
            let mergedURL = try Self.mergeWaveFiles(
                chunkURLs,
                sampleRate: voiceCloneSampleRate,
                crossfadeSeconds: mergeCrossfadeSeconds,
                pauseSeconds: strictLiteralMode ? pauseSecondsLiteral : pauseSecondsNormal,
                trimThreshold: outputTrimThreshold,
                trimMaxSeconds: outputTrimMaxSeconds,
                targetPeak: outputTargetPeak,
                maxGain: outputMaxGain,
                fadeSeconds: outputFadeSeconds
            )
            let finalURL: URL
            if enhanceOutput {
                finalURL = try Self.enhanceWaveFile(
                    mergedURL,
                    sampleRate: voiceCloneSampleRate,
                    trimThreshold: outputTrimThreshold,
                    trimMaxSeconds: outputTrimMaxSeconds,
                    targetPeak: outputTargetPeak,
                    maxGain: outputMaxGain,
                    fadeSeconds: outputFadeSeconds
                )
                try? FileManager.default.removeItem(at: mergedURL)
            } else {
                finalURL = mergedURL
            }
            for url in chunkURLs {
                try? FileManager.default.removeItem(at: url)
            }
            return finalURL
        } catch {
            for url in chunkURLs {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }
    }
    
    private static func load24kMonoFloatSamples(
        from url: URL,
        targetSampleRate: Double
    ) throws -> [Float] {
        let inputFile = try AVAudioFile(forReading: url)
        let inputFormat = inputFile.processingFormat
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: false
            )
        else {
            throw VoiceCloneDemoError.audioPreparationFailed("Failed to create target audio format.")
        }
        
        let inputFrameCapacity = AVAudioFrameCount(max(1, inputFile.length))
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: inputFrameCapacity) else {
            throw VoiceCloneDemoError.audioPreparationFailed("Failed to allocate input buffer.")
        }
        try inputFile.read(into: inputBuffer)
        guard inputBuffer.frameLength > 0 else {
            throw VoiceCloneDemoError.audioPreparationFailed("Reference audio is empty.")
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw VoiceCloneDemoError.audioPreparationFailed("Failed to initialize audio converter.")
        }
        
        let ratio = targetSampleRate / inputFormat.sampleRate
        let estimatedOutputFrames = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 2048
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: estimatedOutputFrames) else {
            throw VoiceCloneDemoError.audioPreparationFailed("Failed to allocate output buffer.")
        }
        
        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .endOfStream
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        if let conversionError {
            throw VoiceCloneDemoError.audioPreparationFailed(conversionError.localizedDescription)
        }
        guard status == .haveData || status == .endOfStream else {
            throw VoiceCloneDemoError.audioPreparationFailed("Audio conversion failed with status \(status.rawValue).")
        }
        
        guard let channel = outputBuffer.floatChannelData?.pointee else {
            throw VoiceCloneDemoError.audioPreparationFailed("Converted audio has no channel data.")
        }
        return Array(UnsafeBufferPointer(start: channel, count: Int(outputBuffer.frameLength)))
    }
    
    private static func extractBestSpeechWindow(
        from samples: [Float],
        sampleRate: Double,
        targetSeconds: Double,
        minSeconds: Double,
        energyFloor: Float,
        noiseMultiplier: Float,
        thresholdBlend: Float
    ) -> [Float] {
        let targetSamples = max(1, Int(targetSeconds * sampleRate))
        let minSamples = max(1, Int(minSeconds * sampleRate))
        guard samples.count > targetSamples else {
            return samples
        }
        
        let frameSize = max(240, Int(sampleRate * 0.02))
        let frameCount = samples.count / frameSize
        guard frameCount > 0 else {
            return Array(samples.prefix(targetSamples))
        }
        
        var rms: [Float] = []
        rms.reserveCapacity(frameCount)
        for frame in 0..<frameCount {
            let start = frame * frameSize
            let end = min(samples.count, start + frameSize)
            var sumSquares: Float = 0
            for value in samples[start..<end] {
                sumSquares += value * value
            }
            let count = max(1, end - start)
            rms.append((sumSquares / Float(count)).squareRoot())
        }
        
        let sortedRms = rms.sorted()
        let noiseFloor = percentile(sortedRms, fraction: 0.20)
        let loudLevel = percentile(sortedRms, fraction: 0.92)
        let threshold = max(energyFloor, noiseFloor * noiseMultiplier, noiseFloor + (loudLevel - noiseFloor) * thresholdBlend)
        
        let minFrames = max(1, minSamples / frameSize)
        let targetFrames = max(minFrames, targetSamples / frameSize)
        let bridgeGapFrames = 8
        
        var ranges: [(start: Int, end: Int)] = []
        var activeStart: Int?
        var gapFrames = 0
        
        for frame in 0..<frameCount {
            if rms[frame] >= threshold {
                if activeStart == nil {
                    activeStart = frame
                }
                gapFrames = 0
            } else if activeStart != nil {
                gapFrames += 1
                if gapFrames > bridgeGapFrames {
                    let end = frame - gapFrames
                    if let start = activeStart, end >= start {
                        ranges.append((start, end))
                    }
                    activeStart = nil
                    gapFrames = 0
                }
            }
        }
        
        if let start = activeStart {
            let end = frameCount - 1 - gapFrames
            if end >= start {
                ranges.append((start, end))
            }
        }
        
        let chosenRange: (start: Int, end: Int)
        if let best = ranges.max(by: { lhs, rhs in
            score(range: lhs, rms: rms, minFrames: minFrames) < score(range: rhs, rms: rms, minFrames: minFrames)
        }) {
            chosenRange = best
        } else {
            let centerStart = max(0, (frameCount - targetFrames) / 2)
            let centerEnd = min(frameCount - 1, centerStart + targetFrames - 1)
            chosenRange = (centerStart, centerEnd)
        }
        
        let padFrames = max(1, Int(0.25 * sampleRate / Double(frameSize)))
        var startFrame = max(0, chosenRange.start - padFrames)
        var endFrame = min(frameCount - 1, chosenRange.end + padFrames)
        
        let selectedFrames = endFrame - startFrame + 1
        if selectedFrames > targetFrames {
            var peakFrame = startFrame
            var peakValue: Float = -1
            for frame in startFrame...endFrame where rms[frame] > peakValue {
                peakFrame = frame
                peakValue = rms[frame]
            }
            startFrame = max(0, min(peakFrame - (targetFrames / 2), frameCount - targetFrames))
            endFrame = min(frameCount - 1, startFrame + targetFrames - 1)
        } else if selectedFrames < minFrames {
            let center = (startFrame + endFrame) / 2
            startFrame = max(0, center - (minFrames / 2))
            endFrame = min(frameCount - 1, startFrame + minFrames - 1)
            if endFrame - startFrame + 1 < minFrames {
                startFrame = max(0, endFrame - minFrames + 1)
            }
        }
        
        let sampleStart = startFrame * frameSize
        let sampleEnd = min(samples.count, (endFrame + 1) * frameSize)
        guard sampleEnd > sampleStart else {
            return Array(samples.prefix(targetSamples))
        }
        return Array(samples[sampleStart..<sampleEnd])
    }
    
    private static func score(
        range: (start: Int, end: Int),
        rms: [Float],
        minFrames: Int
    ) -> Float {
        let duration = max(1, range.end - range.start + 1)
        var energy: Float = 0
        for frame in range.start...range.end {
            energy += rms[frame]
        }
        let mean = energy / Float(duration)
        let lengthWeight = Float(duration)
        let penalty: Float = duration < minFrames ? 0.65 : 1.0
        return mean * lengthWeight * penalty
    }
    
    private static func percentile(_ sortedValues: [Float], fraction: Float) -> Float {
        guard !sortedValues.isEmpty else { return 0 }
        let clamped = max(0, min(1, fraction))
        let index = Int((Float(sortedValues.count - 1) * clamped).rounded())
        return sortedValues[index]
    }
    
    private static func conditionReferenceSamples(
        _ samples: [Float],
        sampleRate: Double,
        highPassHz: Float,
        targetPeak: Float,
        maxGain: Float,
        fadeSeconds: Double
    ) -> [Float] {
        guard !samples.isEmpty else { return samples }
        var conditioned = samples
        
        // Remove low-frequency rumble before embedding extraction.
        let dt: Float = 1 / Float(sampleRate)
        let rc: Float = 1 / (2 * .pi * highPassHz)
        let alpha: Float = rc / (rc + dt)
        var previousX: Float = conditioned[0]
        var previousY: Float = conditioned[0]
        conditioned[0] = 0
        if conditioned.count > 1 {
            for idx in 1..<conditioned.count {
                let x = conditioned[idx]
                let y = alpha * (previousY + x - previousX)
                conditioned[idx] = y
                previousX = x
                previousY = y
            }
        }
        
        let mean = conditioned.reduce(0, +) / Float(conditioned.count)
        for idx in conditioned.indices {
            conditioned[idx] -= mean
        }
        
        conditioned = peakNormalize(conditioned, targetPeak: targetPeak, maxGain: maxGain)
        applyFadeInOut(&conditioned, sampleRate: sampleRate, fadeSeconds: fadeSeconds)
        return conditioned
    }
    
    private static func mergeWaveFiles(
        _ fileURLs: [URL],
        sampleRate: Double,
        crossfadeSeconds: Double,
        pauseSeconds: Double,
        trimThreshold: Float,
        trimMaxSeconds: Double,
        targetPeak: Float,
        maxGain: Float,
        fadeSeconds: Double
    ) throws -> URL {
        guard let firstURL = fileURLs.first else {
            throw VoiceCloneDemoError.audioMergeFailed("No synthesized segments.")
        }
        var merged = try load24kMonoFloatSamples(from: firstURL, targetSampleRate: sampleRate)
        merged = trimSilence(merged, threshold: trimThreshold, maxTrimSeconds: trimMaxSeconds, sampleRate: sampleRate)
        
        let crossfadeSamples = max(0, Int(sampleRate * crossfadeSeconds))
        let pauseSamples = max(0, Int(sampleRate * pauseSeconds))
        
        for fileURL in fileURLs.dropFirst() {
            var next = try load24kMonoFloatSamples(from: fileURL, targetSampleRate: sampleRate)
            next = trimSilence(next, threshold: trimThreshold, maxTrimSeconds: trimMaxSeconds, sampleRate: sampleRate)
            guard !next.isEmpty else { continue }
            
            if merged.isEmpty {
                merged = next
                continue
            }
            
            let fadeCount = min(crossfadeSamples, merged.count, next.count)
            if fadeCount > 0 {
                let denom = Float(max(1, fadeCount - 1))
                for idx in 0..<fadeCount {
                    let t = Float(idx) / denom
                    let mergedIndex = merged.count - fadeCount + idx
                    merged[mergedIndex] = (merged[mergedIndex] * (1 - t)) + (next[idx] * t)
                }
                if pauseSamples > 0 {
                    merged.append(contentsOf: repeatElement(Float.zero, count: pauseSamples))
                }
                merged.append(contentsOf: next.dropFirst(fadeCount))
            } else {
                if pauseSamples > 0 {
                    merged.append(contentsOf: repeatElement(Float.zero, count: pauseSamples))
                }
                merged.append(contentsOf: next)
            }
        }
        
        merged = peakNormalize(merged, targetPeak: targetPeak, maxGain: maxGain)
        applyFadeInOut(&merged, sampleRate: sampleRate, fadeSeconds: fadeSeconds)
        return try writeWaveSamples(merged, sampleRate: sampleRate)
    }
    
    private static func enhanceWaveFile(
        _ url: URL,
        sampleRate: Double,
        trimThreshold: Float,
        trimMaxSeconds: Double,
        targetPeak: Float,
        maxGain: Float,
        fadeSeconds: Double
    ) throws -> URL {
        var samples = try load24kMonoFloatSamples(from: url, targetSampleRate: sampleRate)
        samples = trimSilence(samples, threshold: trimThreshold, maxTrimSeconds: trimMaxSeconds, sampleRate: sampleRate)
        samples = peakNormalize(samples, targetPeak: targetPeak, maxGain: maxGain)
        applyFadeInOut(&samples, sampleRate: sampleRate, fadeSeconds: fadeSeconds)
        return try writeWaveSamples(samples, sampleRate: sampleRate)
    }
    
    private static func trimSilence(
        _ samples: [Float],
        threshold: Float,
        maxTrimSeconds: Double,
        sampleRate: Double
    ) -> [Float] {
        guard !samples.isEmpty else { return samples }
        guard let first = samples.firstIndex(where: { abs($0) > threshold }),
              let last = samples.lastIndex(where: { abs($0) > threshold }),
              last >= first else {
            return samples
        }
        
        let maxTrimSamples = Int(maxTrimSeconds * sampleRate)
        let start = min(first, maxTrimSamples)
        let trailing = samples.count - 1 - last
        let endTrim = min(trailing, maxTrimSamples)
        let endExclusive = max(start + 1, samples.count - endTrim)
        return Array(samples[start..<endExclusive])
    }
    
    private static func peakNormalize(
        _ samples: [Float],
        targetPeak: Float,
        maxGain: Float
    ) -> [Float] {
        guard !samples.isEmpty else { return samples }
        let peak = samples.reduce(0 as Float) { max($0, abs($1)) }
        guard peak > 0.00001 else { return samples }
        let gain = min(maxGain, targetPeak / peak)
        return samples.map { max(-0.98, min(0.98, $0 * gain)) }
    }
    
    private static func applyFadeInOut(
        _ samples: inout [Float],
        sampleRate: Double,
        fadeSeconds: Double
    ) {
        guard !samples.isEmpty else { return }
        let fadeSamples = min(Int(sampleRate * fadeSeconds), samples.count / 2)
        guard fadeSamples > 1 else { return }
        let denom = Float(fadeSamples - 1)
        for idx in 0..<fadeSamples {
            let gain = Float(idx) / denom
            samples[idx] *= gain
            let tailIndex = samples.count - 1 - idx
            samples[tailIndex] *= gain
        }
    }
    
    private static func writeWaveSamples(_ samples: [Float], sampleRate: Double) throws -> URL {
        guard
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            )
        else {
            throw VoiceCloneDemoError.audioMergeFailed("Failed to create output format.")
        }
        
        let outputURL = temporaryURL(withExtension: "wav")
        try? FileManager.default.removeItem(at: outputURL)
        
        let file = try AVAudioFile(
            forWriting: outputURL,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        
        let chunkSize = 4096
        var offset = 0
        while offset < samples.count {
            let count = min(chunkSize, samples.count - offset)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
                  let channel = buffer.floatChannelData?.pointee else {
                throw VoiceCloneDemoError.audioMergeFailed("Failed to allocate output buffer.")
            }
            buffer.frameLength = AVAudioFrameCount(count)
            samples[offset..<(offset + count)].withUnsafeBufferPointer { src in
                guard let base = src.baseAddress else { return }
                channel.update(from: base, count: count)
            }
            try file.write(from: buffer)
            offset += count
        }
        
        return outputURL
    }
    
    private static func normalizedSynthesisText(from text: String) -> String {
        var normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalized.isEmpty else { return normalized }
        
        if let last = normalized.last, !".!?".contains(last) {
            normalized.append(".")
        }
        
        return normalized
    }
    
    private static func sentenceSegments(from text: String, maxCharsPerSegment: Int) -> [String] {
        let nsText = text as NSString
        guard nsText.length > 0 else { return [] }
        
        let pattern = "(?<=[.!?])\\s+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [text]
        }
        
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: fullRange)
        
        var segments: [String] = []
        var cursor = 0
        
        for match in matches {
            let length = match.range.location - cursor
            if length > 0 {
                let part = nsText.substring(with: NSRange(location: cursor, length: length))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !part.isEmpty {
                    segments.append(part)
                }
            }
            cursor = match.range.location + match.range.length
        }
        
        let tailLength = nsText.length - cursor
        if tailLength > 0 {
            let tail = nsText.substring(with: NSRange(location: cursor, length: tailLength))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty {
                segments.append(tail)
            }
        }
        
        if segments.isEmpty {
            segments = [text]
        }
        
        // Keep each synthesis call short for better literal adherence.
        return segments.flatMap { segment in
            guard segment.count > maxCharsPerSegment else { return [segment] }
            let pieces = segment.split(separator: ",").map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            if pieces.isEmpty {
                return [segment]
            }
            return pieces.map { piece in
                if let last = piece.last, ".!?".contains(last) {
                    return piece
                }
                return piece + "."
            }
        }
    }
}

extension VoiceCloneDemoViewModel: AVAudioPlayerDelegate {
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.isPlaying = false
            if flag {
                self?.status = "Playback finished."
            } else {
                self?.status = "Playback ended early."
            }
        }
    }
}

private enum VoiceCloneDemoError: LocalizedError {
    case noMediaSelected
    case videoHasNoAudioTrack
    case invalidMediaDuration
    case audioPreparationFailed(String)
    case audioExtractionSetupFailed
    case audioExtractionFailed(String)
    case audioMergeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noMediaSelected:
            return "No media clip selected."
        case .videoHasNoAudioTrack:
            return "The selected video has no audio track."
        case .invalidMediaDuration:
            return "Could not read media duration."
        case .audioPreparationFailed(let message):
            return "Audio preparation failed: \(message)."
        case .audioExtractionSetupFailed:
            return "Failed to create audio extraction session for this video."
        case .audioExtractionFailed(let message):
            return "Audio extraction failed: \(message)."
        case .audioMergeFailed(let message):
            return "Audio merge failed: \(message)."
        }
    }
}

public struct TTSView: View {
    @StateObject private var vm = VoiceCloneDemoViewModel()
    @State private var showVideoPicker = false
    @State private var showFileImporter = false
    @State private var showRules = true
    @State private var showControlDeck = true
    @State private var showProfileEditor = false
    @State private var showDeepTuning = false
    @State private var renameTarget: VoiceCloneDemoViewModel.SavedAudioItem?
    @State private var renameDraft: String = ""
    @State private var pendingDeleteTarget: VoiceCloneDemoViewModel.SavedAudioItem?
    @FocusState private var isTextEditorFocused: Bool
    
    public init() {
        
    }
    
    private var isRenameAlertPresented: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { newValue in
                if !newValue {
                    renameTarget = nil
                    renameDraft = ""
                }
            }
        )
    }
    
    private var isDeleteDialogPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteTarget != nil },
            set: { newValue in
                if !newValue {
                    pendingDeleteTarget = nil
                }
            }
        )
    }
    
    private static let savedAudioDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private static let savedAudioSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()
    
    public var body: some View {
        NavigationStack {
            ZStack {
                TTSPalette.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                    Text("ComfyTTS Voice Clone")
                        .font(.title2.bold())
                    
                    Text("On-device flow: pick reference clip -> clone voice -> synthesize speech")
                        .font(.footnote)
                        .foregroundStyle(TTSPalette.textSecondary)
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Quality Rules")
                                    .font(.headline)
                                Spacer()
                                Button(showRules ? "Hide" : "Show") {
                                    showRules.toggle()
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if showRules {
                                Text("1. Keep Studio quality audio ON for best voice quality.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("2. Use a clean single-speaker reference clip (8-20s, no music/noise).")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("3. After selecting a new clip, tap Clone Voice again before Speak.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("4. For exact wording: Strict literal mode ON, temperature 0.00-0.10.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text("5. For naturalness: Strict literal mode OFF, temperature 0.10-0.18.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Control Deck")
                                    .font(.headline)
                                Spacer()
                                Button(showControlDeck ? "Hide" : "Show") {
                                    showControlDeck.toggle()
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if showControlDeck {
                                HStack(spacing: 8) {
                                    Button("Save Controls") {
                                        vm.saveControlsToDevice()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Button("Reset Controls") {
                                        vm.resetControlsToDefaults()
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button("Hard Reset Session") {
                                        vm.hardResetSession()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Toggle("Studio quality audio", isOn: $vm.studioQualityMode)
                                    Toggle("Strict literal mode (sentence-by-sentence)", isOn: $vm.strictLiteralMode)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Temperature")
                                        Spacer()
                                        Text(String(format: "%.2f", vm.synthesisTemperature))
                                            .font(.footnote.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $vm.synthesisTemperature, in: 0.00...0.40, step: 0.01)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Segment Char Limit")
                                        Spacer()
                                        Text("\(vm.segmentCharLimit)")
                                            .font(.footnote.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { Double(vm.segmentCharLimit) },
                                            set: { vm.segmentCharLimit = Int($0.rounded()) }
                                        ),
                                        in: 60...240,
                                        step: 5
                                    )
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Reference Max Seconds")
                                        Spacer()
                                        Text(String(format: "%.1f", vm.maxReferenceDurationSeconds))
                                            .font(.footnote.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $vm.maxReferenceDurationSeconds, in: 6...30, step: 1)
                                    
                                    HStack {
                                        Text("Reference Preferred Seconds")
                                        Spacer()
                                        Text(String(format: "%.1f", vm.preferredReferenceDurationSeconds))
                                            .font(.footnote.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $vm.preferredReferenceDurationSeconds, in: 3...24, step: 1)
                                    
                                    HStack {
                                        Text("Reference Minimum Seconds")
                                        Spacer()
                                        Text(String(format: "%.1f", vm.minReferenceDurationSeconds))
                                            .font(.footnote.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $vm.minReferenceDurationSeconds, in: 1...12, step: 0.5)
                                }
                                
                                HStack(spacing: 8) {
                                    Button(showDeepTuning ? "Hide Deep Tuning" : "Show Deep Tuning") {
                                        showDeepTuning.toggle()
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button(showProfileEditor ? "Hide JSON" : "Show JSON") {
                                        showProfileEditor.toggle()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                if showDeepTuning {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("Reference High-Pass (Hz)")
                                            Spacer()
                                            Text(String(format: "%.0f", vm.referenceHighPassHz))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.referenceHighPassHz, in: 20...180, step: 1)
                                        
                                        HStack {
                                            Text("Reference Target Peak")
                                            Spacer()
                                            Text(String(format: "%.2f", vm.referenceTargetPeak))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.referenceTargetPeak, in: 0.60...0.98, step: 0.01)
                                        
                                        HStack {
                                            Text("Reference Max Gain")
                                            Spacer()
                                            Text(String(format: "%.2f", vm.referenceMaxGain))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.referenceMaxGain, in: 1.0...5.0, step: 0.1)
                                        
                                        HStack {
                                            Text("Reference Fade (ms)")
                                            Spacer()
                                            Text(String(format: "%.0f", vm.referenceFadeSeconds * 1000))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.referenceFadeSeconds, in: 0.0...0.08, step: 0.002)
                                        
                                        HStack {
                                            Text("Speech Energy Floor")
                                            Spacer()
                                            Text(String(format: "%.4f", vm.speechEnergyFloor))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.speechEnergyFloor, in: 0.0005...0.02, step: 0.0005)
                                        
                                        HStack {
                                            Text("Speech Threshold Multiplier")
                                            Spacer()
                                            Text(String(format: "%.2f", vm.speechThresholdMultiplier))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.speechThresholdMultiplier, in: 1.0...4.0, step: 0.05)
                                        
                                        HStack {
                                            Text("Speech Threshold Blend")
                                            Spacer()
                                            Text(String(format: "%.2f", vm.speechThresholdBlend))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.speechThresholdBlend, in: 0.0...1.0, step: 0.02)
                                        
                                        HStack {
                                            Text("Crossfade (ms)")
                                            Spacer()
                                            Text(String(format: "%.0f", vm.mergeCrossfadeSeconds * 1000))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.mergeCrossfadeSeconds, in: 0.0...0.12, step: 0.002)
                                        
                                        HStack {
                                            Text("Pause Literal (ms)")
                                            Spacer()
                                            Text(String(format: "%.0f", vm.pauseSecondsLiteral * 1000))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.pauseSecondsLiteral, in: 0.0...0.25, step: 0.005)
                                        
                                        HStack {
                                            Text("Pause Natural (ms)")
                                            Spacer()
                                            Text(String(format: "%.0f", vm.pauseSecondsNormal * 1000))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.pauseSecondsNormal, in: 0.0...0.15, step: 0.005)
                                        
                                        HStack {
                                            Text("Output Target Peak")
                                            Spacer()
                                            Text(String(format: "%.2f", vm.outputTargetPeak))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.outputTargetPeak, in: 0.60...0.98, step: 0.01)
                                        
                                        HStack {
                                            Text("Output Max Gain")
                                            Spacer()
                                            Text(String(format: "%.2f", vm.outputMaxGain))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.outputMaxGain, in: 1.0...4.0, step: 0.1)
                                        
                                        HStack {
                                            Text("Output Fade (ms)")
                                            Spacer()
                                            Text(String(format: "%.0f", vm.outputFadeSeconds * 1000))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.outputFadeSeconds, in: 0.0...0.08, step: 0.002)
                                        
                                        HStack {
                                            Text("Output Trim Threshold")
                                            Spacer()
                                            Text(String(format: "%.4f", vm.outputTrimThreshold))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.outputTrimThreshold, in: 0.0001...0.02, step: 0.0005)
                                        
                                        HStack {
                                            Text("Output Trim Max (s)")
                                            Spacer()
                                            Text(String(format: "%.2f", vm.outputTrimMaxSeconds))
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Slider(value: $vm.outputTrimMaxSeconds, in: 0.0...1.5, step: 0.05)
                                    }
                                }
                                
                                if showProfileEditor {
                                    TextEditor(text: $vm.controlProfileText)
                                        .frame(minHeight: 160)
                                        .padding(8)
                                        .background(TTSPalette.backgroundSecondary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(TTSPalette.goldAccent.opacity(0.55), lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    
                                    HStack(spacing: 8) {
                                        Button("Export JSON") {
                                            vm.refreshControlProfileText()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        
                                        Button("Copy") {
                                            vm.copyControlProfileTextToClipboard()
                                        }
                                        .buttonStyle(.bordered)
                                        
                                        Button("Paste") {
                                            vm.pasteControlProfileTextFromClipboard()
                                        }
                                        .buttonStyle(.bordered)
                                        
                                        Button("Load JSON") {
                                            vm.loadControlProfileFromText()
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                    }
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Model")
                                .font(.headline)
                            
                            Text("First run downloads PocketTTS models, then everything runs locally.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 10) {
                                Button(vm.isInitializing ? "Initializing..." : "Initialize Model") {
                                    Task { await vm.initializeManually() }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(vm.isInitializing || vm.isCloning || vm.isSynthesizing)
                                
                                if vm.isInitializing {
                                    ProgressView()
                                }
                            }
                        }
                    }
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Reference Clip")
                                .font(.headline)
                            
                            Text("Use a clean 1-30 second sample of one speaker.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            
                            Text("To avoid memory spikes, the app uses up to the first 20 seconds.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            
                            Text("Selected: \(vm.selectedMediaName)")
                                .font(.footnote)
                            
                            HStack(spacing: 10) {
                                Button("Pick Video (Photos)") {
                                    showVideoPicker = true
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(vm.isInitializing || vm.isCloning || vm.isSynthesizing)
                                
                                Button("Pick File") {
                                    showFileImporter = true
                                }
                                .buttonStyle(.bordered)
                                .disabled(vm.isInitializing || vm.isCloning || vm.isSynthesizing)
                                
                                Button("Clear") {
                                    vm.clearSelection()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!vm.hasSelectedMedia || vm.isCloning || vm.isSynthesizing)
                            }
                        }
                    }
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Voice Clone")
                                .font(.headline)
                            
                            Text(vm.hasClonedVoice ? "Voice clone ready." : "No cloned voice yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            
                            Text("Current voice: \(vm.clonedVoiceName)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 10) {
                                Button(vm.isCloning ? "Cloning..." : "Clone Voice") {
                                    Task { await vm.cloneVoiceFromSelection() }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!vm.hasSelectedMedia || vm.isInitializing || vm.isCloning || vm.isSynthesizing)
                                
                                Button("Clear Cloned Voice") {
                                    vm.clearClonedVoice()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!vm.hasClonedVoice || vm.isCloning || vm.isSynthesizing)
                            }
                        }
                    }
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Synthesis")
                                .font(.headline)
                            
                            TextEditor(text: $vm.text)
                                .focused($isTextEditorFocused)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(TTSPalette.backgroundSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(TTSPalette.goldAccent.opacity(0.55), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Studio quality audio", isOn: $vm.studioQualityMode)
                                Toggle("Strict literal mode (sentence-by-sentence)", isOn: $vm.strictLiteralMode)
                                
                                HStack {
                                    Text("Accuracy vs variation")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(String(format: "temperature %.2f", vm.synthesisTemperature))
                                        .font(.footnote.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                
                                Slider(value: $vm.synthesisTemperature, in: 0.00...0.30, step: 0.05)
                                
                                Text("Lower is more literal. Start around 0.05-0.15.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 10) {
                                Button(vm.isSynthesizing ? "Synthesizing..." : "Speak") {
                                    Task { await vm.synthesizeWithClonedVoice() }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!vm.hasClonedVoice || vm.isInitializing || vm.isCloning || vm.isSynthesizing)
                                
                                Button(vm.isPlaying ? "Stop Playback" : "Stop") {
                                    vm.stopPlayback()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!vm.isPlaying)
                                
                                Button("Hide Keyboard") {
                                    isTextEditorFocused = false
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Save Current Audio")
                                    .font(.subheadline.weight(.semibold))
                                
                                TextField("Saved file name", text: $vm.audioSaveName)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(TTSPalette.backgroundSecondary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(TTSPalette.goldAccent.opacity(0.55), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                
                                HStack(spacing: 10) {
                                    Button("Save Audio") {
                                        vm.saveLatestAudioToLibrary()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(vm.isInitializing || vm.isCloning || vm.isSynthesizing)
                                    
                                    Button("Refresh Library") {
                                        vm.refreshSavedAudioItems()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Saved Audio Library")
                                .font(.headline)
                            
                            Text("Stored on device in Documents/ComfyTTS-Saved-Audio.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            
                            if vm.savedAudioItems.isEmpty {
                                Text("No saved files yet.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(vm.savedAudioItems) { item in
                                        HStack(alignment: .center, spacing: 8) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .lineLimit(1)
                                                
                                                Text("\(Self.savedAudioDateFormatter.string(from: item.createdAt)) • \(Self.savedAudioSizeFormatter.string(fromByteCount: item.sizeBytes))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            Spacer(minLength: 8)
                                            
                                            Button("Play") {
                                                vm.playSavedAudio(item)
                                            }
                                            .buttonStyle(.bordered)
                                            
                                            Menu("Manage") {
                                                Button("Rename") {
                                                    renameTarget = item
                                                    renameDraft = item.baseName
                                                }
                                                
                                                Button("Delete", role: .destructive) {
                                                    pendingDeleteTarget = item
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(TTSPalette.backgroundSecondary.opacity(0.75))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(TTSPalette.goldAccent.opacity(0.45), lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                    }
                    
                    Text(vm.status)
                        .font(.footnote)
                        .foregroundStyle(TTSPalette.textSecondary)
                        .padding(.top, 4)
                }
                .padding()
                .foregroundStyle(TTSPalette.textPrimary)
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextEditorFocused = false
                }
            }
            }
            .navigationTitle("ComfyTTS")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isTextEditorFocused = false
                    }
                }
            }
            .toolbarBackground(TTSPalette.backgroundSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .groupBoxStyle(TTSDarkGoldGroupBoxStyle())
        .tint(TTSPalette.goldAccent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showVideoPicker) {
            VideoPickerSheet { result in
                switch result {
                case .success(let url):
                    vm.importFromPhotoPicker(url)
                case .failure(let error):
                    vm.status = "Video picker failed: \(error.localizedDescription)"
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    vm.status = "No file selected."
                    return
                }
                vm.importFromFiles(url)
            case .failure(let error):
                vm.status = "File picker failed: \(error.localizedDescription)"
            }
        }
        .alert("Rename Saved Audio", isPresented: isRenameAlertPresented) {
            TextField("New name", text: $renameDraft)
            
            Button("Cancel", role: .cancel) {
                renameTarget = nil
                renameDraft = ""
            }
            
            Button("Save") {
                if let item = renameTarget {
                    vm.renameSavedAudio(item, to: renameDraft)
                }
                renameTarget = nil
                renameDraft = ""
            }
        } message: {
            Text("Pick a new file name.")
        }
        .confirmationDialog(
            "Delete saved audio?",
            isPresented: isDeleteDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let item = pendingDeleteTarget {
                    vm.deleteSavedAudio(item)
                }
                pendingDeleteTarget = nil
            }
            
            Button("Cancel", role: .cancel) {
                pendingDeleteTarget = nil
            }
        } message: {
            if let item = pendingDeleteTarget {
                Text("This permanently deletes \(item.name).")
            } else {
                Text("This permanently deletes the selected file.")
            }
        }
    }
}

private enum TTSPalette {
    static let backgroundPrimary = Color(.sRGB, red: 10.0 / 255.0, green: 10.0 / 255.0, blue: 10.0 / 255.0, opacity: 1)
    static let backgroundSecondary = Color(.sRGB, red: 18.0 / 255.0, green: 18.0 / 255.0, blue: 18.0 / 255.0, opacity: 1)
    static let surface = Color(.sRGB, red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 26.0 / 255.0, opacity: 1)
    static let goldAccent = Color(.sRGB, red: 242.0 / 255.0, green: 214.0 / 255.0, blue: 117.0 / 255.0, opacity: 1)
    static let textPrimary = Color(.sRGB, red: 245.0 / 255.0, green: 245.0 / 255.0, blue: 245.0 / 255.0, opacity: 1)
    static let textSecondary = Color(.sRGB, red: 184.0 / 255.0, green: 184.0 / 255.0, blue: 184.0 / 255.0, opacity: 1)
}

private struct TTSDarkGoldGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.label
            configuration.content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TTSPalette.surface.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TTSPalette.goldAccent.opacity(0.7), lineWidth: 1.2)
        )
    }
}

private struct VideoPickerSheet: UIViewControllerRepresentable {
    let onResult: (Result<URL, Error>) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }
    
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onResult: (Result<URL, Error>) -> Void
        
        init(onResult: @escaping (Result<URL, Error>) -> Void) {
            self.onResult = onResult
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else {
                return
            }
            
            let provider = result.itemProvider
            let typeIdentifier = preferredTypeIdentifier(for: provider)
            
            guard let typeIdentifier else {
                DispatchQueue.main.async {
                    self.onResult(.failure(VideoPickerError.unsupportedVideoType))
                }
                return
            }
            
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    DispatchQueue.main.async {
                        self.onResult(.failure(error))
                    }
                    return
                }
                
                guard let url else {
                    DispatchQueue.main.async {
                        self.onResult(.failure(VideoPickerError.noFileReturned))
                    }
                    return
                }
                
                do {
                    let copied = try Self.copyToTemporaryFile(from: url, typeIdentifier: typeIdentifier)
                    DispatchQueue.main.async {
                        self.onResult(.success(copied))
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.onResult(.failure(error))
                    }
                }
            }
        }
        
        private func preferredTypeIdentifier(for provider: NSItemProvider) -> String? {
            let candidates = [
                UTType.mpeg4Movie.identifier,
                UTType.quickTimeMovie.identifier,
                UTType.movie.identifier
            ]
            
            for identifier in candidates where provider.hasItemConformingToTypeIdentifier(identifier) {
                return identifier
            }
            
            return provider.registeredTypeIdentifiers.first
        }
        
        private static func copyToTemporaryFile(from sourceURL: URL, typeIdentifier: String) throws -> URL {
            let type = UTType(typeIdentifier)
            let ext = type?.preferredFilenameExtension ?? (sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)
            
            let destinationURL = URL.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        }
    }
}

private enum VideoPickerError: LocalizedError {
    case unsupportedVideoType
    case noFileReturned
    
    var errorDescription: String? {
        switch self {
        case .unsupportedVideoType:
            return "Unsupported video type selected."
        case .noFileReturned:
            return "The picker did not return a video file."
        }
    }
}


#endif
