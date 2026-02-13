//
//  TimelineModels.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/13/26.
//

import Foundation

enum TransportState {
    case stopped
    case playing
    case paused
}

@Observable
@MainActor
class TimelineClip: Identifiable {
    let id = UUID()
    let asset: EditorFile
    var startTime: TimeInterval = 0.0 // This is the delay in seconds
    
    nonisolated init(asset: EditorFile) {
        self.asset = asset
    }
}

@Observable
@MainActor
class TimelineSong {
    /// NO map because we may want multiple of the same URLs
    var clips: [TimelineClip] = []
    var audios: [AVAudioPreviewPlayback] = []
    
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var transportState: TransportState = .stopped
    
    public func assign(_ items: [EditorFile]) {
        Task.detached(priority: .userInitiated) {
            var clips: [TimelineClip] = []
            
            /// Each stem has a file url which gets added into `addedURLs`
            /// when we call play this will bundle up all and toggle play on them
            for file in items {
                let clip = TimelineClip(asset: file)
                clips.append(clip)
            }
            
            await MainActor.run { [clips] in
                self.clips.append(contentsOf: clips)
                self.seedAudio()
            }
        }
    }
    
    public func remove(_ clip: TimelineClip) {
        clips.removeAll { $0.id == clip.id }
        seedAudio()
    }

    var isRunning: Bool {
        transportState == .playing
    }
    
    public func play() throws {
        
        if transportState == .playing { return }
        transportState = .playing
        if startTime == nil { startTime = Date() }
        let count = min(audios.count, clips.count)
        
        for i in 0..<count {
            let audio = audios[i]
            let clip  = clips[i]
            
            Task {
                let sessionTime = accumulatedTime
                
                if sessionTime < clip.startTime {
                    let delay = clip.startTime - sessionTime
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    try self.playAudio(previewAudio: audio, url: clip.asset.url, time: 0)
                } else {
                    let seek = sessionTime - clip.startTime
                    try self.playAudio(previewAudio: audio, url: clip.asset.url, time: seek)
                }
            }
        }
    }
    
    public func pause() throws {
        transportState = .paused
        for audio in audios {
            Task {
                audio.pause()
            }
        }
        
        if let startTime = startTime {
            // Calculate the duration since the timer started and add it to accumulated time
            accumulatedTime += Date().timeIntervalSince(startTime)
            self.startTime = nil
        }
    }
    
    private func playAudio(previewAudio: AVAudioPreviewPlayback, url: URL, time: TimeInterval) throws {
        try previewAudio.togglePreview(fileURL: url, startTime: time)
    }
    
    /// Function Seeds after audio is changed based on addedURLs
    private func seedAudio() {
        transportState = .stopped
        audios.removeAll()
        startTime = nil
        accumulatedTime = .zero
        for _ in clips {
            let previewAudio = AVAudioPreviewPlayback()
            audios.append(previewAudio)
        }
    }
}
