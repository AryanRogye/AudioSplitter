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
class TimelineClip: Identifiable, Equatable {
    static func == (lhs: TimelineClip, rhs: TimelineClip) -> Bool {
        return lhs.id == rhs.id
    }
    
    let id = UUID()
    var asset: EditorFile
    var startTime: TimeInterval = 0.0
    var audio = AVAudioPreviewPlayback()
    
    var sourceStart: TimeInterval = 0
    /// now means CLIP duration
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
    
    /// Scheduled is id -> (start Task and end Task)
    private var scheduled: [UUID: (start: Task<Void, Never>, stop: Task<Void, Never>)] = [:]
    
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
    
    public func assign(_ item: TimelineClip) {
        clips.append(item)
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
                let timelineOffset = accumulatedTime - clip.startTime
                let clipEndInSource = clip.sourceStart + max(0, clip.duration)
                
                if timelineOffset <= 0 {
                    clip.audio.seek(to: clip.sourceStart)
                    continue
                }
                
                let fileTime = clip.sourceStart + timelineOffset
                clip.audio.seek(to: min(fileTime, clipEndInSource))
            }
        }
    }
    
    public func getClip(byID id: UUID) -> TimelineClip? {
        return clips.first(where: { $0.id == id })
    }
    
    public func remove(_ clip: TimelineClip) {
        cancelScheduled(for: clip.id)
        clip.audio.pause()
        clips.removeAll { $0.id == clip.id }
    }
    
    private func cancelScheduled(for id: UUID) {
        if let pair = scheduled[id] {
            pair.start.cancel()
            pair.stop.cancel()
            scheduled[id] = nil
        }
    }

    public func replaceAsset(_ updated: EditorFile) {
        for clip in clips where clip.asset.id == updated.id {
            clip.asset = updated
        }
    }
    
    public func play() throws {
        
        /// checks
        if transportState == .playing { return }
        transportState = .playing
        if startTime == nil { startTime = Date() }
        
        for clip in clips {
            /// cancel any scheduled audio both start and stop
            cancelScheduled(for: clip.id)
            
            /// Basic Calculations
            let sessionTime = accumulatedTime
            let clipEndTime = clip.startTime + max(0, clip.duration)
            
            /// (Start) Task
            let startTask = Task { [weak self] in
                guard let self else { return }
                
                /// Do not start playback if this clip is already fully in the past.
                if sessionTime >= clipEndTime {
                    return
                }
                
                /// If the playhead (sessionTime) is before the clip starts
                if sessionTime < clip.startTime {
                    /// calculates the exact time difference
                    let delay = clip.startTime - sessionTime
                    
                    /// tells the task to wait (sleep) for that exact delay
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    if Task.isCancelled { return }
                    
                    /// fires the audio from the clip's beginning (sourceStart)
                    try? self.playAudio(previewAudio: clip.audio, url: clip.asset.url, time: clip.sourceStart)
                }
                /// we're in the range to play something
                else {
                    /// calculates exactly how far in we are (timelineOffset),
                    let timelineOffset = sessionTime - clip.startTime
                    let fileTime = clip.sourceStart + timelineOffset
                    /// Plays
                    try? self.playAudio(previewAudio: clip.audio, url: clip.asset.url, time: fileTime)
                }
            }
            
            
            /// calculating the exact "expiration timer" for the clip
            
            /// The waiting time before the clip even starts. If the playhead is already inside the clip, this is 0
            let leadIn = max(0, clip.startTime - sessionTime)
            /// How deep into the clip the playhead currently is. If the playhead is before the clip starts, this is 0
            let offsetIntoClip = max(0, sessionTime - clip.startTime)
            let remaining = max(0, clip.duration - offsetIntoClip)
            /// get the exact number of seconds from right now until the clip needs to shut off
            let totalStopDelay = leadIn + remaining
            
            /**
             The Task then just looks at totalStopDelay. If it's 0 or less,
             the playhead is already past the end of the clip,
             so it forces a pause just in case
             */
            let stopTask = Task {
                // If clip already ended relative to current playhead, stop immediately.
                if totalStopDelay <= 0 {
                    clip.audio.pause()
                    return
                }
                /// calculates the time to pause
                try? await Task.sleep(nanoseconds: UInt64(totalStopDelay * 1_000_000_000))
                if Task.isCancelled { return }
                clip.audio.pause()
            }
            
            scheduled[clip.id] = (start: startTask, stop: stopTask)
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
        
        for (_, pair) in scheduled {
            pair.start.cancel()
            pair.stop.cancel()
        }
        scheduled.removeAll()
    }
    
    private func playAudio(previewAudio: AVAudioPreviewPlayback, url: URL, time: TimeInterval) throws {
        try previewAudio.togglePreview(fileURL: url, startTime: time)
    }
    
    public func stop() {
        for (_, pair) in scheduled {
            pair.start.cancel()
            pair.stop.cancel()
        }
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
