//
//  TimelineModels.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/13/26.
//

import Foundation
import AVFoundation
import AudioHelper

enum TransportState {
    case stopped
    case playing
    case paused
}

@Observable
@MainActor
class TimelineClip: Identifiable {
    let id = UUID()
    var asset: EditorFile
    var startTime: TimeInterval = 0.0
    var audio = AVAudioPreviewPlayback()
    var duration: TimeInterval = 0
    
    init(asset: EditorFile) async {
        self.asset = asset
        await calcDuration()
    }
    
    private func calcDuration() async {
        let ass = AVURLAsset(url: asset.url)
        if let dur = try? await ass.load(.duration) {
            self.duration = dur.seconds
        }
    }
}

@Observable
@MainActor
class TimelineSong {
    /// NO map because we may want multiple of the same URLs
    var clips: [TimelineClip] = []
    
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private var transportState: TransportState = .stopped
    private var scheduled: [UUID: Task<Void, Never>] = [:]
    
    var duration: TimeInterval = 0

    var isRunning: Bool {
        transportState == .playing
    }
    
    var currentTime: TimeInterval {
        switch transportState {
        case .playing:
            guard let startTime else { return accumulatedTime }
            return accumulatedTime + Date().timeIntervalSince(startTime)
        case .paused, .stopped:
            return accumulatedTime
        }
    }
    
    public func assign(_ items: [EditorFile]) {
        Task(priority: .userInitiated) {
            var clips: [TimelineClip] = []
            
            /// Each stem has a file url which gets added into `addedURLs`
            /// when we call play this will bundle up all and toggle play on them
            for file in items {
                let clip = await TimelineClip(asset: file)
                clips.append(clip)
            }
            
            await MainActor.run { [clips] in
                self.clips.append(contentsOf: clips)
            }
        }
    }
    
    public func seek(to time: TimeInterval) {
        let wasPlaying = isRunning
        
        // Pause everything to clear existing scheduled tasks
        if wasPlaying {
            try? pause()
        }
        
        // Set the new time
        accumulatedTime = max(0, time)
        
        // Resume if it was already playing, otherwise update the paused audio engines
        if wasPlaying {
            try? play()
        } else {
            for clip in clips {
                let seekTime = accumulatedTime - clip.startTime
                if seekTime >= 0 {
                    clip.audio.seek(to: seekTime)
                } else {
                    clip.audio.seek(to: 0)
                }
            }
        }
    }
    
    public func remove(_ clip: TimelineClip) {
        scheduled[clip.id]?.cancel()
        scheduled[clip.id] = nil
        clip.audio.pause()
        clips.removeAll { $0.id == clip.id }
    }

    public func replaceAsset(_ updated: EditorFile) {
        for clip in clips where clip.asset.id == updated.id {
            clip.asset = updated
        }
    }
    
    public func play() throws {
        
        if transportState == .playing { return }
        transportState = .playing
        if startTime == nil { startTime = Date() }
        
        for clip in clips {
            scheduled[clip.id]?.cancel()
            scheduled[clip.id] = Task {
                let sessionTime = accumulatedTime
                if sessionTime < clip.startTime {
                    let delay = clip.startTime - sessionTime
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    if Task.isCancelled { return }
                    try? self.playAudio(previewAudio: clip.audio, url: clip.asset.url, time: 0)
                } else {
                    let seek = sessionTime - clip.startTime
                    try? self.playAudio(previewAudio: clip.audio, url: clip.asset.url, time: seek)
                }
            }
        }
    }
    
    public func pause() throws {
        transportState = .paused
        for clip in clips {
            Task { clip.audio.pause() }
        }
        
        if let startTime = startTime {
            // Calculate the duration since the timer started and add it to accumulated time
            accumulatedTime += Date().timeIntervalSince(startTime)
            self.startTime = nil
        }
        
        for (_, t) in scheduled { t.cancel() }
        scheduled.removeAll()
    }
    
    private func playAudio(previewAudio: AVAudioPreviewPlayback, url: URL, time: TimeInterval) throws {
        try previewAudio.togglePreview(fileURL: url, startTime: time)
    }
    
    public func stop() {
        for (_, t) in scheduled { t.cancel() }
        scheduled.removeAll()

        transportState = .stopped
        startTime = nil
        accumulatedTime = 0
        
        for clip in clips {
            clip.audio.pause()
            clip.audio.seek(to: 0)
        }
    }
}
