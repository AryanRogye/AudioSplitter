import Combine
import Foundation

@MainActor
final class StemSeparationViewModel: ObservableObject, StemSeparationScreenAPI {
    @Published var selectedFileURL: URL?
    @Published var outputStems: [StemFile] = []
    @Published private(set) var latestSeparatedStems: [StemFile] = []
    @Published private(set) var latestSeparatedSourceURL: URL?
    @Published var statusText = "Select an MP3 and split it."
    @Published var isProcessing = false
    @Published var errorText: String?
    @Published var currentlyPlayingURL: URL?

    private let separator: StemSeparating
    private let playbackController: AudioPlaybackControlling

    private var allOutputStems: [StemFile] = []
    private var preferredStemKinds: Set<StemKind> = Set(StemKind.allCases)

    convenience init() {
        self.init(
            separator: CoreMLMDXStemSeparatorAdapter(),
            playbackController: AVAudioPlaybackAdapter()
        )
    }

    init(
        separator: StemSeparating,
        playbackController: AudioPlaybackControlling
    ) {
        self.separator = separator
        self.playbackController = playbackController
        self.currentlyPlayingURL = playbackController.currentlyPlayingURL

        self.playbackController.onPlaybackStateChanged = { [weak self] url in
            Task { @MainActor in
                self?.currentlyPlayingURL = url
            }
        }
    }

    func importPickedFile(from sourceURL: URL) {
        do {
            playbackController.stopPlayback()
            selectedFileURL = try copyToSandbox(from: sourceURL)
            outputStems = []
            allOutputStems = []
            latestSeparatedStems = []
            latestSeparatedSourceURL = nil
            errorText = nil
            statusText = "Loaded: \(selectedFileURL?.lastPathComponent ?? "")"
        } catch {
            errorText = error.localizedDescription
            statusText = "Import failed"
        }
    }

    func setPreferredStemKinds(_ kinds: Set<StemKind>) {
        let normalizedKinds = kinds.isEmpty ? Set(StemKind.allCases) : kinds
        preferredStemKinds = normalizedKinds
        outputStems = filteredAndSortedStems(from: allOutputStems)
    }

    func splitSelectedFile(autoPlayFirstStem: Bool = false) {
        guard let selectedFileURL else {
            errorText = "Please choose an MP3 first."
            return
        }

        isProcessing = true
        errorText = nil
        outputStems = []
        allOutputStems = []
        latestSeparatedStems = []
        latestSeparatedSourceURL = nil
        playbackController.stopPlayback()
        statusText = "Splitting track..."

        let processingURL = selectedFileURL
        let separator = self.separator

        Task {
            do {
                let stems = try await Task.detached(priority: .userInitiated) {
                    try separator.separate(fileURL: processingURL)
                }.value

                allOutputStems = stems
                outputStems = filteredAndSortedStems(from: stems)
                latestSeparatedStems = stems
                latestSeparatedSourceURL = processingURL
                statusText = "Created \(stems.count) stems."

                if autoPlayFirstStem, let firstStem = outputStems.first {
                    togglePlayback(for: firstStem.fileURL)
                }
            } catch {
                errorText = error.localizedDescription
                statusText = "Separation failed"
                latestSeparatedSourceURL = nil
            }

            isProcessing = false
        }
    }

    func isPlaying(_ url: URL?) -> Bool {
        playbackController.isPlaying(url)
    }

    func togglePlayback(for url: URL?) {
        do {
            try playbackController.togglePlayback(for: url)
            currentlyPlayingURL = playbackController.currentlyPlayingURL
        } catch {
            errorText = "Playback failed: \(error.localizedDescription)"
            playbackController.stopPlayback()
            currentlyPlayingURL = playbackController.currentlyPlayingURL
        }
    }

    private func filteredAndSortedStems(from stems: [StemFile]) -> [StemFile] {
        let visibleKinds = preferredStemKinds
        let filtered = stems.filter { visibleKinds.contains($0.kind) }

        return StemKind.allCases.compactMap { kind in
            filtered.first(where: { $0.kind == kind })
        }
    }

    private func copyToSandbox(from sourceURL: URL) throws -> URL {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let importsDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Imports", isDirectory: true)

        try fileManager.createDirectory(at: importsDirectory, withIntermediateDirectories: true)

        let destination = importsDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(sourceURL.lastPathComponent)")

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }
}
