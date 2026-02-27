//
//  BundleSongPreviewViewModel.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/12/26.
//

import Foundation
import AudioPlayback

/// ViewModel for BundleSongPreview, this drives the entire row's audio
extension BundleSongPreview {
    @Observable
    @MainActor
    internal final class BundleSongPreviewViewModel {
        
        var preview = AVAudioPreviewPlayback()
        var playbackError: String?
        var shouldShowError = false
        
        init() {
            print("Initialized")
        }
        
        public func playAudio(
            _ url: URL
        ) {
            if preview.isPlaying {
                preview.stopPreview()
                return
            }
            do {
                try preview.togglePreview(
                    fileURL: url,
                    startTime: 0,
                    volume: 1.0
                )
            } catch let error as StagePreviewPlaybackError {
                switch error {
                case .fileMissing(let path):
                    playbackError = "File Missing: \(path)"
                case .failedToStart:
                    playbackError = "Failed To Start"
                case .playbackFailed(let details):
                    playbackError = "Playback Failed: \(details)"
                }
                shouldShowError = true
            } catch {
                playbackError = error.localizedDescription
                shouldShowError = true
            }
        }
    }
}
