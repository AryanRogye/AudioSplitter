import AVFoundation
import SwiftUI
import Foundation
import Observation
import Combine

// TODO: Clean This File Up

@Observable
@MainActor
final class AVAudioPreviewPlayback: NSObject, AVAudioPlayerDelegate {
    
    var currentPlaybackTime: TimeInterval {
        audioPlayer?.currentTime ?? 0
    }
    var currentDuration: TimeInterval {
        audioPlayer?.duration ?? 0
    }
    
    var isPlaying : Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    private var audioPlayer: AVAudioPlayer?
    
    @MainActor
    deinit {
        audioPlayer?.stop()
        audioPlayer?.delegate = nil
        audioPlayer = nil
    }
    
    func togglePreview(role: StageTrackRole, fileURL: URL, startTime: TimeInterval) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw StagePreviewPlaybackError.fileMissing(path: fileURL.path)
        }
        
        var sessionSetupError: Error?
        do {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true)
            } catch {
                sessionSetupError = error
            }
            
            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.delegate = self
            let clampedStart = max(0, min(startTime, max(0, player.duration - 0.05)))
            player.currentTime = clampedStart
            player.prepareToPlay()
            let didPlay = player.play()
            if !didPlay {
                throw StagePreviewPlaybackError.failedToStart
            }
            
            audioPlayer = player
        } catch {
            stopPreview()
            let nsError = error as NSError
            let sessionDetails: String
            if let sessionSetupError {
                let sessionNSError = sessionSetupError as NSError
                sessionDetails = " | session: \(sessionNSError.domain) (\(sessionNSError.code)): \(sessionNSError.localizedDescription)"
            } else {
                sessionDetails = ""
            }
            throw StagePreviewPlaybackError.playbackFailed(
                details: "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)\(sessionDetails)"
            )
        }
    }
    
    func stopPreview() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    func seek(to time: TimeInterval) {
        guard let audioPlayer else { return }
        
        let dur = audioPlayer.duration
        guard dur.isFinite, dur > 0 else { return }
        
        let wasPlaying = audioPlayer.isPlaying
        let clamped = max(0, min(time, dur - 0.05))
        
        if wasPlaying { audioPlayer.pause() }
        audioPlayer.currentTime = clamped
        if wasPlaying { audioPlayer.play() }
    }

    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPreview()
    }
}

final class AVAudioStagePreviewPlaybackAdapter: NSObject, StagePreviewPlaybackControlling, AVAudioPlayerDelegate {
    var onPreviewStateChanged: ((StageTrackRole?) -> Void)?
    var currentPlaybackTime: TimeInterval {
        audioPlayer?.currentTime ?? 0
    }
    var currentDuration: TimeInterval {
        audioPlayer?.duration ?? 0
    }
    
    var isPlayingAudio: Bool {
        return audioPlayer?.isPlaying ?? false
    }


    private(set) var currentlyPreviewingRole: StageTrackRole? {
        didSet {
            if oldValue != currentlyPreviewingRole {
                onPreviewStateChanged?(currentlyPreviewingRole)
            }
        }
    }

    private var audioPlayer: AVAudioPlayer?

    func togglePreview(role: StageTrackRole, fileURL: URL?, startTime: TimeInterval) throws {
        if currentlyPreviewingRole == role {
            stopPreview()
            return
        }

        guard let fileURL else {
            throw StagePreviewPlaybackError.missingTrack(role: role)
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw StagePreviewPlaybackError.fileMissing(path: fileURL.path)
        }

        var sessionSetupError: Error?
        do {
            do {
                try prepareAudioSessionIfAvailable()
            } catch {
                sessionSetupError = error
            }

            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.delegate = self
            let clampedStart = max(0, min(startTime, max(0, player.duration - 0.05)))
            player.currentTime = clampedStart
            player.prepareToPlay()
            let didPlay = player.play()
            if !didPlay {
                throw StagePreviewPlaybackError.failedToStart
            }

            audioPlayer = player
            currentlyPreviewingRole = role
        } catch {
            stopPreview()
            let nsError = error as NSError
            let sessionDetails: String
            if let sessionSetupError {
                let sessionNSError = sessionSetupError as NSError
                sessionDetails = " | session: \(sessionNSError.domain) (\(sessionNSError.code)): \(sessionNSError.localizedDescription)"
            } else {
                sessionDetails = ""
            }
            throw StagePreviewPlaybackError.playbackFailed(
                details: "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)\(sessionDetails)"
            )
        }
    }

    func stopPreview() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentlyPreviewingRole = nil
    }

    func seek(to time: TimeInterval) {
        guard let audioPlayer else { return }
        let clamped = max(0, min(time, max(0, audioPlayer.duration - 0.05)))
        audioPlayer.currentTime = clamped
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPreview()
    }

    private func prepareAudioSessionIfAvailable() throws {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
#endif
    }
}

enum StagePreviewPlaybackError: LocalizedError {
    case missingTrack(role: StageTrackRole)
    case fileMissing(path: String)
    case failedToStart
    case playbackFailed(details: String)

    var errorDescription: String? {
        switch self {
        case .missingTrack(let role):
            switch role {
            case .vocal:
                return "Select a vocal track to preview."
            case .instrumental:
                return "Select an instrumental track to preview."
            }
        case .fileMissing(let path):
            return "Preview file is missing at path: \(path)"
        case .failedToStart:
            return "Preview audio failed to start."
        case .playbackFailed(let details):
            return "Preview failed: \(details)"
        }
    }
}
