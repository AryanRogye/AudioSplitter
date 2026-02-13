//
//  AVAudioPreviewPlayback.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/12/26.
//

import AVFoundation

@Observable
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
    private var url: URL?
    
    @MainActor
    deinit {
        audioPlayer?.stop()
        audioPlayer?.delegate = nil
        audioPlayer = nil
    }
    
    func togglePreview(fileURL: URL, startTime: TimeInterval) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw StagePreviewPlaybackError.fileMissing(path: fileURL.path)
        }
        
        self.url = fileURL
        
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
    
    func play() {
        audioPlayer?.play()
    }
    func pause() {
        audioPlayer?.pause()
    }
    
    func stopPreview() {
        audioPlayer?.stop()
        audioPlayer = nil
        url = nil
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


enum StagePreviewPlaybackError: LocalizedError {
    case fileMissing(path: String)
    case failedToStart
    case playbackFailed(details: String)
    
    var errorDescription: String? {
        switch self {
        case .fileMissing(let path):
            return "Preview file is missing at path: \(path)"
        case .failedToStart:
            return "Preview audio failed to start."
        case .playbackFailed(let details):
            return "Preview failed: \(details)"
        }
    }
}
