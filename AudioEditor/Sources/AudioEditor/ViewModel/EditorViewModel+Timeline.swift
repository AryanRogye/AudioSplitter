//
//  EditorViewModel+Timeline.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/13/26.
//

import Foundation
import AudioPlayback

// MARK: - Timeline
extension EditorViewModel {
    
    var isPlaying : Bool {
        timelineSong.isRunning
    }
    public func toggleAudio() {
        do {
            if isPlaying {
                try timelineSong.pause()
            } else {
                try timelineSong.play()
            }
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
    /**
     * when we drop in a file into the timeline view from the staging area, this adds the songs as a song
     */
    public func addDroppedItems(_ items: [EditorFile]) {
        timelineSong.assign(items)
    }
    
    /**
     * Removes the song from the timeline view
     */
    public func removeURLFromSong(_ clip: TimelineClip) {
        if selectedClip == clip.id {
            selectedClip = nil
        }
        timelineSong.remove(clip)
    }
}
