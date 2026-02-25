import AVFoundation
import Foundation

final class AVAudioStageMixExporterAdapter: StageMixExporting {
    func exportLayeredMix(
        vocalURL: URL,
        vocalStartTime: TimeInterval,
        instrumentalURL: URL,
        instrumentalStartTime: TimeInterval,
        stageDelay: TimeInterval
    ) async throws -> URL {
        let request = ExportRequest(
            vocalURL: vocalURL,
            vocalStartTime: max(0, vocalStartTime),
            instrumentalURL: instrumentalURL,
            instrumentalStartTime: max(0, instrumentalStartTime),
            stageDelay: stageDelay
        )

        return try await Task.detached(priority: .userInitiated) {
            try Self.renderMix(request)
        }.value
    }

    private struct ExportRequest: Sendable {
        let vocalURL: URL
        let vocalStartTime: TimeInterval
        let instrumentalURL: URL
        let instrumentalStartTime: TimeInterval
        let stageDelay: TimeInterval
    }

    private static func renderMix(_ request: ExportRequest) throws -> URL {
        guard FileManager.default.fileExists(atPath: request.vocalURL.path) else {
            throw StageMixExportError.fileMissing(path: request.vocalURL.path)
        }
        guard FileManager.default.fileExists(atPath: request.instrumentalURL.path) else {
            throw StageMixExportError.fileMissing(path: request.instrumentalURL.path)
        }

        let vocalAsset = AVURLAsset(url: request.vocalURL)
        let instrumentalAsset = AVURLAsset(url: request.instrumentalURL)

        guard let vocalSourceTrack = vocalAsset.tracks(withMediaType: .audio).first else {
            throw StageMixExportError.missingTrack(role: .vocal)
        }
        guard let instrumentalSourceTrack = instrumentalAsset.tracks(withMediaType: .audio).first else {
            throw StageMixExportError.missingTrack(role: .instrumental)
        }

        let composition = AVMutableComposition()
        guard let vocalMixTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let instrumentalMixTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw StageMixExportError.couldNotCreateComposition
        }

        let timescale: CMTimeScale = 600

        let vocalRangeStart = CMTime(seconds: request.vocalStartTime, preferredTimescale: timescale)
        let vocalRangeDuration = CMTimeSubtract(vocalAsset.duration, vocalRangeStart)
        if vocalRangeDuration.isValid, vocalRangeDuration.seconds > 0 {
            try vocalMixTrack.insertTimeRange(
                CMTimeRange(start: vocalRangeStart, duration: vocalRangeDuration),
                of: vocalSourceTrack,
                at: CMTime(seconds: max(0, -request.stageDelay), preferredTimescale: timescale)
            )
        }

        let instrumentalRangeStart = CMTime(seconds: request.instrumentalStartTime, preferredTimescale: timescale)
        let instrumentalRangeDuration = CMTimeSubtract(instrumentalAsset.duration, instrumentalRangeStart)
        if instrumentalRangeDuration.isValid, instrumentalRangeDuration.seconds > 0 {
            try instrumentalMixTrack.insertTimeRange(
                CMTimeRange(start: instrumentalRangeStart, duration: instrumentalRangeDuration),
                of: instrumentalSourceTrack,
                at: CMTime(seconds: max(0, request.stageDelay), preferredTimescale: timescale)
            )
        }

        let hasAnyAudio = vocalMixTrack.timeRange.duration.seconds > 0 || instrumentalMixTrack.timeRange.duration.seconds > 0
        guard hasAnyAudio else {
            throw StageMixExportError.emptyMix
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("stage-mix-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw StageMixExportError.couldNotCreateExportSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = true

        let semaphore = DispatchSemaphore(value: 0)
        exportSession.exportAsynchronously {
            semaphore.signal()
        }
        semaphore.wait()

        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw StageMixExportError.exportFailed(details: exportSession.error?.localizedDescription ?? "Unknown export error.")
        case .cancelled:
            throw StageMixExportError.exportCancelled
        default:
            throw StageMixExportError.exportFailed(details: "Unexpected export status: \(exportSession.status.rawValue)")
        }
    }
}

enum StageMixExportError: LocalizedError {
    case fileMissing(path: String)
    case missingTrack(role: StageTrackRole)
    case emptyMix
    case couldNotCreateComposition
    case couldNotCreateExportSession
    case exportFailed(details: String)
    case exportCancelled

    var errorDescription: String? {
        switch self {
        case .fileMissing(let path):
            return "Mix export file is missing at path: \(path)"
        case .missingTrack(let role):
            switch role {
            case .vocal:
                return "Could not read the selected vocal audio track."
            case .instrumental:
                return "Could not read the selected instrumental audio track."
            }
        case .emptyMix:
            return "Nothing to export: both tracks start beyond their available durations."
        case .couldNotCreateComposition:
            return "Could not prepare layered audio composition."
        case .couldNotCreateExportSession:
            return "Could not initialize audio exporter."
        case .exportFailed(let details):
            return "Mix export failed: \(details)"
        case .exportCancelled:
            return "Mix export was cancelled."
        }
    }
}
