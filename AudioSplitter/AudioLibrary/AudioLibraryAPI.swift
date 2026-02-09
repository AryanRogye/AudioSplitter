import Foundation

extension StemKind: Codable {}

struct StoredStemAsset: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: StemKind
    var fileURL: URL
    let sourceTrackName: String
    let createdAt: Date
    var customName: String?
}

struct ProcessedTrackHistoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let sourceFileName: String
    var sourceFileURL: URL
    let createdAt: Date
    let sourceFingerprint: [Float]
    var stems: [StoredStemAsset]
    var customName: String?
}

struct SavedLayeredMix: Identifiable, Codable, Hashable {
    let id: UUID
    var fileURL: URL
    let createdAt: Date
    let vocalName: String
    let instrumentalName: String
    let delaySeconds: Double
}

extension StoredStemAsset {
    var displayName: String {
        if let customName, !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customName
        }
        return sourceTrackName
    }
}

extension ProcessedTrackHistoryItem {
    var displayName: String {
        if let customName, !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customName
        }
        return sourceFileName
    }
}

extension SavedLayeredMix {
    var displayName: String {
        "\(vocalName) + \(instrumentalName)"
    }
}

struct DuplicateAudioMatch: Identifiable, Hashable {
    let entry: ProcessedTrackHistoryItem
    let similarity: Double

    var id: UUID {
        entry.id
    }
}

protocol AudioHistoryStoring {
    func loadHistory() throws -> [ProcessedTrackHistoryItem]
    func loadSavedLayeredMixes() throws -> [SavedLayeredMix]
    func saveProcessedTrack(
        sourceURL: URL,
        stems: [StemFile],
        sourceFingerprint: [Float]
    ) throws -> ProcessedTrackHistoryItem
    func saveLayeredMix(
        from exportedFileURL: URL,
        vocalName: String,
        instrumentalName: String,
        delaySeconds: Double
    ) throws -> SavedLayeredMix
    func renameHistoryItem(id: UUID, newName: String?) throws
    func renameStemAsset(id: UUID, newName: String?) throws
    func deleteHistoryItem(id: UUID) throws
    func deleteSavedLayeredMix(id: UUID) throws
}

protocol AudioFingerprinting: Sendable {
    func fingerprint(for fileURL: URL) throws -> [Float]
    func similarity(between lhs: [Float], and rhs: [Float]) -> Double
}

protocol StagePlaybackControlling: AnyObject {
    var isPlaying: Bool { get }
    var onPlaybackStateChanged: ((Bool) -> Void)? { get set }
    var currentPlaybackTime: TimeInterval { get }
    var currentDuration: TimeInterval { get }

    func configure(
        vocalURL: URL?,
        vocalStartTime: TimeInterval,
        instrumentalURL: URL?,
        instrumentalStartTime: TimeInterval,
        stageDelay: TimeInterval
    )
    func seek(to time: TimeInterval)
    func togglePlayback() throws
    func stopPlayback()
}

enum StageTrackRole: String {
    case vocal
    case instrumental
}

protocol StagePreviewPlaybackControlling: AnyObject {
    var currentlyPreviewingRole: StageTrackRole? { get }
    var onPreviewStateChanged: ((StageTrackRole?) -> Void)? { get set }
    var currentPlaybackTime: TimeInterval { get }
    var currentDuration: TimeInterval { get }

    func togglePreview(role: StageTrackRole, fileURL: URL?, startTime: TimeInterval) throws
    func seek(to time: TimeInterval)
    func stopPreview()
}

protocol StageMixExporting {
    func exportLayeredMix(
        vocalURL: URL,
        vocalStartTime: TimeInterval,
        instrumentalURL: URL,
        instrumentalStartTime: TimeInterval,
        stageDelay: TimeInterval
    ) async throws -> URL
}
