//
//  EditorViewModel.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/11/26.
//

import Foundation
import AVFoundation
import Accelerate

@Observable
@MainActor
final class EditorViewModel {
    var isRecentsOpen = false
    var allSongs: [EditorFile]
    var stagedTracks: [EditorFile] = []
    
    var timelineSong = TimelineSong()
    var playbackError: String?
    var shouldShowError = false
    
    var selectedClip: TimelineClip.ID?
    
    /// Initializer
    init(allSongs: [EditorFile]) {
        self.allSongs = allSongs
    }
    
    public func splitAtCurrentSelection() async throws {
        guard let selectedClip else { return }
        try timelineSong.pause()
        guard let clip = timelineSong.getClip(byID: selectedClip) else {
            try timelineSong.play()
            return
        }
        
        let t = timelineSong.currentTime
        let old_start = clip.startTime
        let oldSourceStart = clip.sourceStart
        let old_duration = clip.duration
        
        let leftDuration = t - old_start
        guard leftDuration > 0, leftDuration < clip.duration else {
            try timelineSong.play()
            return
        }
        /// left peice is set
        clip.duration = leftDuration
        
        /// creating right peice
        let right = await TimelineClip(asset: clip.asset)
        right.startTime = t
        right.sourceStart = oldSourceStart + leftDuration
        right.duration = old_duration - leftDuration
        
        timelineSong.assign(right)
        
        print("Stopped At: \(timelineSong.currentTime)")
        print("End: \(clip.duration)")
    }
}

extension EditorViewModel {
    private static func resample(_ values: [Float], to targetCount: Int) -> [Float] {
        guard targetCount > 0 else { return [] }
        guard !values.isEmpty else { return [] }
        guard values.count != targetCount else { return values }
        guard values.count > 1 else { return Array(repeating: values[0], count: targetCount) }
        
        let maxSourceIndex = values.count - 1
        let maxTargetIndex = max(targetCount - 1, 1)
        var output: [Float] = []
        output.reserveCapacity(targetCount)
        
        for targetIndex in 0..<targetCount {
            let position = Double(targetIndex) * Double(maxSourceIndex) / Double(maxTargetIndex)
            let lower = Int(position.rounded(.down))
            let upper = min(lower + 1, maxSourceIndex)
            let fraction = Float(position - Double(lower))
            let interpolated = values[lower] + (values[upper] - values[lower]) * fraction
            output.append(interpolated)
        }
        
        return output
    }

    static func generateWaveform(
        from url: URL,
        startTime: TimeInterval = 0,
        endTime: TimeInterval? = nil,
        sampleCount: Int = 500
    ) async -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return [] }
        guard sampleCount > 0 else { return [] }
        
        let totalFrames = AVAudioFramePosition(audioFile.length)
        let sampleRate = audioFile.processingFormat.sampleRate
        
        let requestedStartFrame = AVAudioFramePosition(max(0, startTime) * sampleRate)
        let requestedEndFrame: AVAudioFramePosition = {
            if let endTime {
                return AVAudioFramePosition(max(0, endTime) * sampleRate)
            }
            return totalFrames
        }()
        
        let startFrame = min(max(0, requestedStartFrame), totalFrames)
        let endFrame = min(max(startFrame, requestedEndFrame), totalFrames)
        guard endFrame > startFrame else { return [] }
        
        audioFile.framePosition = startFrame
        
        let targetFrameCount = endFrame - startFrame
        let rawFramesPerBuffer = max(1, targetFrameCount / Int64(sampleCount))
        let framesPerBuffer = AVAudioFrameCount(min(rawFramesPerBuffer, Int64(UInt32.max)))
        
        // 1. Create a buffer sized perfectly for one "chunk" (bin) of our waveform
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: framesPerBuffer) else { return [] }
        
        var waveform: [Float] = []
        waveform.reserveCapacity(sampleCount)
        let channelCount = Int(audioFile.processingFormat.channelCount)
        
        do {
            // 2. Read the audio file sequentially chunk-by-chunk
            while audioFile.framePosition < endFrame {
                let framesLeft = endFrame - audioFile.framePosition
                let clampedFramesLeft = min(framesLeft, AVAudioFramePosition(UInt32.max))
                let framesToRead = min(AVAudioFrameCount(clampedFramesLeft), framesPerBuffer)
                
                try audioFile.read(into: buffer, frameCount: framesToRead)
                guard let floatChannelData = buffer.floatChannelData, buffer.frameLength > 0 else { break }
                
                var binMax: Float = 0.0
                
                // 3. Scan all channels (Left/Right) to find the absolute loudest peak in this chunk
                for channel in 0..<channelCount {
                    let channelData = floatChannelData[channel]
                    var channelPeak: Float = 0.0
                    
                    // vDSP_maxmgv instantly calculates the max magnitude (absolute value) in the array
                    vDSP_maxmgv(channelData, 1, &channelPeak, vDSP_Length(buffer.frameLength))
                    binMax = max(binMax, channelPeak)
                }
                
                waveform.append(binMax)
                
                // Stop reading if we hit our exact requested sample count
                if waveform.count >= sampleCount { break }
            }
        } catch {
            print("Error reading audio file: \(error)")
        }
        
        // 4. Normalize the data so the absolute loudest peak in the whole file equals 1.0
        if let maxVal = waveform.max(), maxVal > 0 {
            let normalized = waveform.map { $0 / maxVal }
            return resample(normalized, to: sampleCount)
        }
        
        return resample(waveform, to: sampleCount)
    }
}
