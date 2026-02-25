import AVFoundation
import Foundation

struct AVAudioFingerprintAdapter: AudioFingerprinting {
    private let binCount: Int
    private let maxDurationSeconds: Double

    init(binCount: Int = 256, maxDurationSeconds: Double = 180) {
        self.binCount = binCount
        self.maxDurationSeconds = maxDurationSeconds
    }

    func fingerprint(for fileURL: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: fileURL, commonFormat: .pcmFormatFloat32, interleaved: false)
        let sampleRate = file.processingFormat.sampleRate

        let maxFrames = AVAudioFramePosition(sampleRate * maxDurationSeconds)
        let totalFramesToRead = Int(max(1, min(file.length, maxFrames)))

        let readChunk = min(totalFramesToRead, 16_384)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(readChunk)
        ) else {
            throw FingerprintError.bufferAllocationFailed
        }

        var absoluteSums = [Float](repeating: 0, count: binCount)
        var absoluteCounts = [Int](repeating: 0, count: binCount)
        var consumedFrames = 0

        while consumedFrames < totalFramesToRead {
            let remaining = totalFramesToRead - consumedFrames
            let framesRequested = AVAudioFrameCount(min(readChunk, remaining))

            try file.read(into: buffer, frameCount: framesRequested)
            let readFrames = Int(buffer.frameLength)

            if readFrames == 0 {
                break
            }

            guard let channels = buffer.floatChannelData else {
                throw FingerprintError.missingChannelData
            }

            let channelCount = Int(buffer.format.channelCount)

            for frame in 0..<readFrames {
                var monoSample: Float = 0
                for channel in 0..<channelCount {
                    monoSample += channels[channel][frame]
                }
                monoSample /= Float(channelCount)

                let position = consumedFrames + frame
                let normalized = Double(position) / Double(max(1, totalFramesToRead - 1))
                let binIndex = min(binCount - 1, Int(normalized * Double(binCount)))

                absoluteSums[binIndex] += abs(monoSample)
                absoluteCounts[binIndex] += 1
            }

            consumedFrames += readFrames
        }

        var fingerprint = [Float](repeating: 0, count: binCount)
        for index in 0..<binCount {
            if absoluteCounts[index] > 0 {
                fingerprint[index] = absoluteSums[index] / Float(absoluteCounts[index])
            }
        }

        return normalized(fingerprint)
    }

    func similarity(between lhs: [Float], and rhs: [Float]) -> Double {
        let count = min(lhs.count, rhs.count)
        guard count > 0 else { return 0 }

        let left = normalized(Array(lhs.prefix(count)))
        let right = normalized(Array(rhs.prefix(count)))

        var dot: Double = 0
        for index in 0..<count {
            dot += Double(left[index] * right[index])
        }

        return max(-1, min(1, dot))
    }

    private func normalized(_ vector: [Float]) -> [Float] {
        guard !vector.isEmpty else { return [] }

        let mean = vector.reduce(0, +) / Float(vector.count)
        var centered = vector.map { $0 - mean }

        let norm = sqrt(centered.reduce(0) { $0 + ($1 * $1) })
        guard norm > 1e-6 else {
            return centered.map { _ in 0 }
        }

        for index in centered.indices {
            centered[index] /= norm
        }

        return centered
    }
}

enum FingerprintError: LocalizedError {
    case bufferAllocationFailed
    case missingChannelData

    var errorDescription: String? {
        switch self {
        case .bufferAllocationFailed:
            return "Unable to allocate audio buffer for fingerprinting."
        case .missingChannelData:
            return "Audio fingerprinting failed because channel data is unavailable."
        }
    }
}
