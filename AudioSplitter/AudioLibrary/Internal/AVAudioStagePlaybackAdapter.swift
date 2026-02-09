import AVFoundation
import Foundation

final class AVAudioStagePlaybackAdapter: NSObject, StagePlaybackControlling, AVAudioPlayerDelegate {
    var onPlaybackStateChanged: ((Bool) -> Void)?
    var currentPlaybackTime: TimeInterval {
        if isPlaying, let stageStartDeviceTime {
            let now = max(vocalPlayer?.deviceCurrentTime ?? 0, instrumentalPlayer?.deviceCurrentTime ?? 0)
            return clampTimeline(now - stageStartDeviceTime)
        }
        return clampTimeline(queuedTimelineTime)
    }
    var currentDuration: TimeInterval {
        stageDuration
    }

    private(set) var isPlaying: Bool = false {
        didSet {
            if oldValue != isPlaying {
                onPlaybackStateChanged?(isPlaying)
            }
        }
    }

    private var vocalURL: URL?
    private var instrumentalURL: URL?
    private var vocalStartTime: TimeInterval = 0
    private var instrumentalStartTime: TimeInterval = 0
    private var stageDelay: TimeInterval = 0
    private var stageStartDeviceTime: TimeInterval?
    private var stageDuration: TimeInterval = 0
    private var queuedTimelineTime: TimeInterval = 0

    private var vocalPlayer: AVAudioPlayer?
    private var instrumentalPlayer: AVAudioPlayer?
    private var pendingCompletionCount = 0

    func configure(
        vocalURL: URL?,
        vocalStartTime: TimeInterval,
        instrumentalURL: URL?,
        instrumentalStartTime: TimeInterval,
        stageDelay: TimeInterval
    ) {
        if self.vocalURL != vocalURL ||
            self.instrumentalURL != instrumentalURL ||
            self.vocalStartTime != vocalStartTime ||
            self.instrumentalStartTime != instrumentalStartTime ||
            self.stageDelay != stageDelay {
            stopPlayback()
        }

        self.vocalURL = vocalURL
        self.instrumentalURL = instrumentalURL
        self.vocalStartTime = max(0, vocalStartTime)
        self.instrumentalStartTime = max(0, instrumentalStartTime)
        self.stageDelay = stageDelay
        self.queuedTimelineTime = 0
    }

    func togglePlayback() throws {
        if isPlaying {
            stopPlayback()
            return
        }

        try startPlayback(fromTimelineTime: queuedTimelineTime)
    }

    func seek(to time: TimeInterval) {
        let clamped = clampTimeline(time)
        queuedTimelineTime = clamped

        guard isPlaying else { return }

        do {
            try startPlayback(fromTimelineTime: clamped)
        } catch {
            stopPlayback()
        }
    }

    private func startPlayback(fromTimelineTime timelineTime: TimeInterval) throws {
        stopPlayersOnly()

        guard let vocalURL, let instrumentalURL else {
            throw StagePlaybackError.missingTracks
        }
        guard FileManager.default.fileExists(atPath: vocalURL.path) else {
            throw StagePlaybackError.fileMissing(path: vocalURL.path)
        }
        guard FileManager.default.fileExists(atPath: instrumentalURL.path) else {
            throw StagePlaybackError.fileMissing(path: instrumentalURL.path)
        }

        var sessionSetupError: Error?
        do {
            do {
                try prepareAudioSessionIfAvailable()
            } catch {
                sessionSetupError = error
            }

            let vocalPlayer = try AVAudioPlayer(contentsOf: vocalURL)
            let instrumentalPlayer = try AVAudioPlayer(contentsOf: instrumentalURL)

            vocalPlayer.delegate = self
            instrumentalPlayer.delegate = self

            stageDuration = computeStageDuration(vocalPlayer: vocalPlayer, instrumentalPlayer: instrumentalPlayer)
            let timeline = clampTimeline(timelineTime)
            queuedTimelineTime = timeline

            let vocalOffset = max(0, -stageDelay)
            let instrumentalOffset = max(0, stageDelay)
            let vocalSourceTime = vocalStartTime + max(0, timeline - vocalOffset)
            let instrumentalSourceTime = instrumentalStartTime + max(0, timeline - instrumentalOffset)

            vocalPlayer.currentTime = clamp(vocalSourceTime, for: vocalPlayer)
            instrumentalPlayer.currentTime = clamp(instrumentalSourceTime, for: instrumentalPlayer)

            vocalPlayer.prepareToPlay()
            instrumentalPlayer.prepareToPlay()

            let startAt = max(vocalPlayer.deviceCurrentTime, instrumentalPlayer.deviceCurrentTime) + 0.05
            let vocalLead = max(0, vocalOffset - timeline)
            let instrumentalLead = max(0, instrumentalOffset - timeline)
            let vocalAtTime = startAt + vocalLead
            let instrumentalAtTime = startAt + instrumentalLead

            let vocalHasRemaining = timeline < vocalOffset + max(0, vocalPlayer.duration - vocalStartTime)
            let instrumentalHasRemaining = timeline < instrumentalOffset + max(0, instrumentalPlayer.duration - instrumentalStartTime)

            var vocalStarted = false
            var instrumentalStarted = false

            if vocalHasRemaining {
                vocalStarted = vocalPlayer.play(atTime: vocalAtTime)
                if !vocalStarted {
                    vocalStarted = vocalPlayer.play()
                }
            }

            if instrumentalHasRemaining {
                instrumentalStarted = instrumentalPlayer.play(atTime: instrumentalAtTime)
                if !instrumentalStarted {
                    instrumentalStarted = instrumentalPlayer.play()
                }
            }

            guard vocalStarted || instrumentalStarted else {
                throw StagePlaybackError.failedToStart
            }

            self.vocalPlayer = vocalPlayer
            self.instrumentalPlayer = instrumentalPlayer
            pendingCompletionCount = (vocalStarted ? 1 : 0) + (instrumentalStarted ? 1 : 0)
            stageStartDeviceTime = startAt - timeline
            isPlaying = true
        } catch {
            stopPlayback()
            let sessionDetails: String
            if let sessionSetupError {
                sessionDetails = " | session: \(detailedError(sessionSetupError))"
            } else {
                sessionDetails = ""
            }

            let fileContext = "vocal=\(vocalURL.lastPathComponent), instrumental=\(instrumentalURL.lastPathComponent), delay=\(stageDelay)s"
            throw StagePlaybackError.playbackFailed(
                details: "\(detailedError(error))\(sessionDetails) | \(fileContext)"
            )
        }
    }

    func stopPlayback() {
        queuedTimelineTime = 0
        stageDuration = 0
        stageStartDeviceTime = nil
        stopPlayersOnly()
        isPlaying = false
    }

    private func stopPlayersOnly() {
        vocalPlayer?.stop()
        instrumentalPlayer?.stop()
        vocalPlayer = nil
        instrumentalPlayer = nil
        pendingCompletionCount = 0
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        pendingCompletionCount -= 1
        if pendingCompletionCount <= 0 {
            stopPlayback()
        }
    }

    private func clamp(_ requested: TimeInterval, for player: AVAudioPlayer) -> TimeInterval {
        max(0, min(requested, max(0, player.duration - 0.05)))
    }

    private func computeStageDuration(vocalPlayer: AVAudioPlayer, instrumentalPlayer: AVAudioPlayer) -> TimeInterval {
        let vocalOffset = max(0, -stageDelay)
        let instrumentalOffset = max(0, stageDelay)
        let vocalAvailable = max(0, vocalPlayer.duration - vocalStartTime)
        let instrumentalAvailable = max(0, instrumentalPlayer.duration - instrumentalStartTime)
        return max(vocalOffset + vocalAvailable, instrumentalOffset + instrumentalAvailable)
    }

    private func clampTimeline(_ requested: TimeInterval) -> TimeInterval {
        guard stageDuration > 0 else { return max(0, requested) }
        return max(0, min(requested, stageDuration))
    }

    private func prepareAudioSessionIfAvailable() throws {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
#endif
    }

    private func detailedError(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)"
    }
}

enum StagePlaybackError: LocalizedError {
    case missingTracks
    case fileMissing(path: String)
    case failedToStart
    case playbackFailed(details: String)

    var errorDescription: String? {
        switch self {
        case .missingTracks:
            return "Choose both a vocal and an instrumental before playback."
        case .fileMissing(let path):
            return "Layered playback file is missing at path: \(path)"
        case .failedToStart:
            return "Could not start synchronized playback."
        case .playbackFailed(let details):
            return "Layered playback failed: \(details)"
        }
    }
}
