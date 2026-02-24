//
//  EditorViewModel.swift
//  AudioSplitter
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
//    var historyStore: AudioHistoryStoring
    
    var allSongs: [EditorFile]
    var stagedTracks: [EditorFile] = []
    
    var timelineSong = TimelineSong()
    var playbackError: String?
    var shouldShowError = false
    
    /// Initializer
    init(allSongs: [EditorFile]/*, history: any AudioHistoryStoring*/) {
        self.allSongs = allSongs
//        self.historyStore = history
    }
}

extension EditorViewModel {
    static func generateWaveform(from url: URL, sampleCount: Int = 500) async -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return [] }
        
        let frameCount = AVAudioFramePosition(audioFile.length)
        let framesPerBuffer = AVAudioFrameCount(max(1, frameCount / Int64(sampleCount)))
        
        // 1. Create a buffer sized perfectly for one "chunk" (bin) of our waveform
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: framesPerBuffer) else { return [] }
        
        var waveform: [Float] = []
        waveform.reserveCapacity(sampleCount)
        let channelCount = Int(audioFile.processingFormat.channelCount)
        
        do {
            // 2. Read the audio file sequentially chunk-by-chunk
            while audioFile.framePosition < frameCount {
                let framesLeft = frameCount - audioFile.framePosition
                let framesToRead = min(AVAudioFrameCount(framesLeft), framesPerBuffer)
                
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
            return waveform.map { $0 / maxVal }
        }
        
        return waveform
    }
}
