import Foundation

// API surface intended for app-level use.
// Everything else is placed in StemSeparation/Internal.

struct StemFile: Identifiable, Hashable {
    let id = UUID()
    let kind: StemKind
    let fileURL: URL

    var displayName: String {
        kind.rawValue.capitalized
    }
}

enum StemKind: String, CaseIterable, Hashable {
    case vocals
    case drums
    case bass
    case other
    case instrumental
}

enum StemSeparationError: LocalizedError {
    case modelNotFound(expectedNames: [String])
    case unsupportedModelInput(details: String)
    case unsupportedModelOutput(details: String)
    case unreadableAudio
    case predictionFailed(details: String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let expectedNames):
            return "No bundled Core ML model was found. Add a .mlmodel to the app target (for example: \(expectedNames.joined(separator: ", ")))."
        case .unsupportedModelInput(let details):
            return "Unsupported model input: \(details)"
        case .unsupportedModelOutput(let details):
            return "Unsupported model output: \(details)"
        case .unreadableAudio:
            return "Could not decode the selected audio file."
        case .predictionFailed(let details):
            return "Model inference failed: \(details)"
        }
    }
}

protocol StemSeparating: Sendable {
    nonisolated func separate(fileURL: URL) throws -> [StemFile]
}

protocol AudioPlaybackControlling: AnyObject {
    var currentlyPlayingURL: URL? { get }
    var onPlaybackStateChanged: ((URL?) -> Void)? { get set }

    func isPlaying(_ url: URL?) -> Bool
    func togglePlayback(for url: URL?) throws
    func stopPlayback()
}

// This is the exact API surface that ContentView calls.
@MainActor
protocol StemSeparationScreenAPI: AnyObject {
    var selectedFileURL: URL? { get set }
    var outputStems: [StemFile] { get set }
    var statusText: String { get set }
    var isProcessing: Bool { get set }
    var errorText: String? { get set }
    var currentlyPlayingURL: URL? { get set }

    func importPickedFile(from sourceURL: URL)
    func setPreferredStemKinds(_ kinds: Set<StemKind>)
    func splitSelectedFile(autoPlayFirstStem: Bool)
    func isPlaying(_ url: URL?) -> Bool
    func togglePlayback(for url: URL?)
}
