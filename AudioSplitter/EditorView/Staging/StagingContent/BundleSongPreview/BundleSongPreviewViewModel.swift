//
//  BundleSongPreviewViewModel.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/12/26.
//

import Foundation

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
            for selected: SelectedStageListen,
            _ vocalURL: URL,
            _ instrumentalURL: URL
        ) {
            if preview.isPlaying {
                preview.stopPreview()
                return
            }
            if let role = selected.stageTrackRole {
                do {
                    if role == .vocal {
                        try preview.togglePreview(
                            role: role,
                            fileURL: vocalURL,
                            startTime: 0
                        )
                    } else if role == .instrumental {
                        try preview.togglePreview(
                            role: role,
                            fileURL: instrumentalURL,
                            startTime: 0
                        )
                    }
                } catch let error as StagePreviewPlaybackError {
                    switch error {
                    case .missingTrack(let role):
                        playbackError = "Missing Track: \(role)"
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
}
