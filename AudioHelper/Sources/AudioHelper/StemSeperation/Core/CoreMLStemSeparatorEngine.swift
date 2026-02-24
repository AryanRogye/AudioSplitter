//
//  CoreMLStemSeparatorEngine.swift
//  AudioHelper
//
//  Created by Aryan Rogye on 2/23/26.
//

import Accelerate
import AVFoundation
import CoreML
import Foundation

nonisolated enum CoreMLStemSeparatorEngine {
    private static let expectedModelNames = ["UVRMDXNet", "StemSeparator", "AudioSeparator", "DemucsSeparator"]
    
    private enum ModelLocation {
        case compiled(URL)
        case source(URL)
    }
    
    // MDX model contract for UVR-MDX-NET-Inst_HQ_5.
    private static let modelSampleRate: Double = 44_100
    private static let nFFT = 5_120
    private static let hopLength = 1_024
    private static let dimF = 2_560
    private static let segmentFrames = 256
    private static let trim = nFFT / 2
    private static let chunkSize = hopLength * (segmentFrames - 1)
    private static let genSize = chunkSize - 2 * trim
    private static let overlap = 0.25
    private static let compensate: Float = 1.01
    
    private struct StereoPCM {
        let left: [Float]
        let right: [Float]
        let sampleRate: Double
    }
    
    private struct StereoChunk {
        var left: [Float]
        var right: [Float]
    }
    
    private struct Spectrogram4 {
        // Channel order matches UVR STFT: [L.real, L.imag, R.real, R.imag]
        var channels: [[Float]]
        let frames: Int
    }
    
    private struct ModelContract {
        let model: MLModel
        let inputName: String
        let outputName: String
    }
    
    private struct MultiArrayReader {
        private enum Storage {
            case float32(UnsafePointer<Float32>, Int)
            case float64(UnsafePointer<Double>, Int)
            case float16(UnsafePointer<UInt16>, Int)
        }
        
        private let storage: Storage
        
        init(array: MLMultiArray, requiredCapacity: Int) throws {
            let capacity = max(requiredCapacity, array.count)
            
            switch array.dataType {
            case .float32:
                let pointer = array.dataPointer.bindMemory(to: Float32.self, capacity: capacity)
                storage = .float32(UnsafePointer(pointer), capacity)
            case .double:
                let pointer = array.dataPointer.bindMemory(to: Double.self, capacity: capacity)
                storage = .float64(UnsafePointer(pointer), capacity)
            case .float16:
                let pointer = array.dataPointer.bindMemory(to: UInt16.self, capacity: capacity)
                storage = .float16(UnsafePointer(pointer), capacity)
            default:
                throw StemSeparationError.unsupportedModelOutput(
                    details: "Unsupported MLMultiArray dtype: \(array.dataType.rawValue)"
                )
            }
        }
        
        var capacity: Int {
            switch storage {
            case .float32(_, let capacity), .float64(_, let capacity), .float16(_, let capacity):
                return capacity
            }
        }
        
        func value(at index: Int) -> Float {
            switch storage {
            case .float32(let pointer, _):
                return pointer[index]
            case .float64(let pointer, _):
                return Float(pointer[index])
            case .float16(let pointer, _):
                return Self.float16ToFloat(pointer[index])
            }
        }
        
        private static func float16ToFloat(_ bits: UInt16) -> Float {
            let sign = UInt32(bits & 0x8000) << 16
            let exponent = Int((bits & 0x7C00) >> 10)
            let fraction = UInt32(bits & 0x03FF)
            
            let valueBits: UInt32
            if exponent == 0 {
                if fraction == 0 {
                    valueBits = sign
                } else {
                    // Subnormal half -> normalized single.
                    var normalizedFraction = fraction
                    var exp = -14
                    while (normalizedFraction & 0x0400) == 0 {
                        normalizedFraction <<= 1
                        exp -= 1
                    }
                    normalizedFraction &= 0x03FF
                    let singleExponent = UInt32(exp + 127) << 23
                    let singleFraction = normalizedFraction << 13
                    valueBits = sign | singleExponent | singleFraction
                }
            } else if exponent == 0x1F {
                // Inf/NaN
                valueBits = sign | 0x7F80_0000 | (fraction << 13)
            } else {
                let singleExponent = UInt32(exponent - 15 + 127) << 23
                let singleFraction = fraction << 13
                valueBits = sign | singleExponent | singleFraction
            }
            
            return Float(bitPattern: valueBits)
        }
    }
    
    private final class STFTProcessor {
        private let nFFT: Int
        private let hopLength: Int
        private let dimF: Int
        private let trim: Int
        private let window: [Float]
        private let forwardDFT: vDSP.DFT<Float>
        private let inverseDFT: vDSP.DFT<Float>
        
        init(nFFT: Int, hopLength: Int, dimF: Int) throws {
            guard let forwardDFT = vDSP.DFT(
                count: nFFT,
                direction: .forward,
                transformType: .complexComplex,
                ofType: Float.self
            ), let inverseDFT = vDSP.DFT(
                count: nFFT,
                direction: .inverse,
                transformType: .complexComplex,
                ofType: Float.self
            ) else {
                throw StemSeparationError.predictionFailed(details: "Failed to initialize FFT transforms")
            }
            
            self.nFFT = nFFT
            self.hopLength = hopLength
            self.dimF = dimF
            self.trim = nFFT / 2
            self.window = Self.hannPeriodic(size: nFFT)
            self.forwardDFT = forwardDFT
            self.inverseDFT = inverseDFT
        }
        
        func forwardStereo(left: [Float], right: [Float], zeroLowBins: Int) throws -> Spectrogram4 {
            let leftSpec = try forwardChannel(left)
            let rightSpec = try forwardChannel(right)
            
            var channels = [leftSpec.real, leftSpec.imag, rightSpec.real, rightSpec.imag]
            let frameCount = leftSpec.frames
            
            if zeroLowBins > 0 {
                let binsToMute = min(zeroLowBins, dimF)
                for channelIndex in channels.indices {
                    for bin in 0..<binsToMute {
                        let start = bin * frameCount
                        let end = start + frameCount
                        for index in start..<end {
                            channels[channelIndex][index] = 0
                        }
                    }
                }
            }
            
            return Spectrogram4(channels: channels, frames: frameCount)
        }
        
        func inverseStereo(_ spectrogram: Spectrogram4, expectedLength: Int) throws -> StereoChunk {
            guard spectrogram.channels.count == 4 else {
                throw StemSeparationError.unsupportedModelOutput(details: "Expected 4 spectrogram channels, got \(spectrogram.channels.count)")
            }
            
            let left = try inverseChannel(
                real: spectrogram.channels[0],
                imag: spectrogram.channels[1],
                frames: spectrogram.frames,
                expectedLength: expectedLength
            )
            let right = try inverseChannel(
                real: spectrogram.channels[2],
                imag: spectrogram.channels[3],
                frames: spectrogram.frames,
                expectedLength: expectedLength
            )
            
            return StereoChunk(left: left, right: right)
        }
        
        private func forwardChannel(_ signal: [Float]) throws -> (real: [Float], imag: [Float], frames: Int) {
            let padded = reflectPad(signal, amount: trim)
            guard padded.count >= nFFT else {
                throw StemSeparationError.predictionFailed(details: "Chunk too short for STFT")
            }
            
            let frames = ((padded.count - nFFT) / hopLength) + 1
            var real = [Float](repeating: 0, count: dimF * frames)
            var imag = [Float](repeating: 0, count: dimF * frames)
            var inputReal = [Float](repeating: 0, count: nFFT)
            let inputImag = [Float](repeating: 0, count: nFFT)
            var outputReal = [Float](repeating: 0, count: nFFT)
            var outputImag = [Float](repeating: 0, count: nFFT)
            
            for frame in 0..<frames {
                let start = frame * hopLength
                for index in 0..<nFFT {
                    inputReal[index] = padded[start + index] * window[index]
                }
                
                forwardDFT.transform(
                    inputReal: inputReal,
                    inputImaginary: inputImag,
                    outputReal: &outputReal,
                    outputImaginary: &outputImag
                )
                
                for frequency in 0..<dimF {
                    let slot = frequency * frames + frame
                    real[slot] = outputReal[frequency]
                    imag[slot] = outputImag[frequency]
                }
            }
            
            return (real: real, imag: imag, frames: frames)
        }
        
        private func inverseChannel(
            real: [Float],
            imag: [Float],
            frames: Int,
            expectedLength: Int
        ) throws -> [Float] {
            guard real.count == dimF * frames, imag.count == dimF * frames else {
                throw StemSeparationError.unsupportedModelOutput(details: "Unexpected spectrogram shape during ISTFT")
            }
            
            let paddedLength = nFFT + hopLength * (frames - 1)
            let nyquist = nFFT / 2
            let inverseScale = 1.0 / Float(nFFT)
            
            var output = [Float](repeating: 0, count: paddedLength)
            var windowSquares = [Float](repeating: 0, count: paddedLength)
            var spectrumReal = [Float](repeating: 0, count: nFFT)
            var spectrumImag = [Float](repeating: 0, count: nFFT)
            var timeReal = [Float](repeating: 0, count: nFFT)
            var timeImag = [Float](repeating: 0, count: nFFT)
            
            for frame in 0..<frames {
                for index in 0..<nFFT {
                    spectrumReal[index] = 0
                    spectrumImag[index] = 0
                }
                
                for frequency in 0..<dimF {
                    let slot = frequency * frames + frame
                    spectrumReal[frequency] = real[slot]
                    spectrumImag[frequency] = imag[slot]
                }
                
                spectrumReal[nyquist] = 0
                spectrumImag[nyquist] = 0
                
                if nyquist > 1 {
                    for frequency in 1..<nyquist {
                        let mirror = nFFT - frequency
                        spectrumReal[mirror] = spectrumReal[frequency]
                        spectrumImag[mirror] = -spectrumImag[frequency]
                    }
                }
                
                inverseDFT.transform(
                    inputReal: spectrumReal,
                    inputImaginary: spectrumImag,
                    outputReal: &timeReal,
                    outputImaginary: &timeImag
                )
                
                let start = frame * hopLength
                for index in 0..<nFFT {
                    let sample = timeReal[index] * inverseScale * window[index]
                    output[start + index] += sample
                    windowSquares[start + index] += window[index] * window[index]
                }
            }
            
            for index in output.indices where windowSquares[index] > 1e-8 {
                output[index] /= windowSquares[index]
            }
            
            if output.count <= (2 * trim) {
                return [Float](repeating: 0, count: expectedLength)
            }
            
            let centered = Array(output[trim..<(output.count - trim)])
            
            if centered.count >= expectedLength {
                return Array(centered.prefix(expectedLength))
            }
            
            var padded = centered
            padded.append(contentsOf: repeatElement(0, count: expectedLength - centered.count))
            return padded
        }
        
        private static func hannPeriodic(size: Int) -> [Float] {
            guard size > 0 else { return [] }
            let denominator = Float(size)
            return (0..<size).map { index in
                0.5 - 0.5 * cosf(2 * .pi * Float(index) / denominator)
            }
        }
        
        private func reflectPad(_ input: [Float], amount: Int) -> [Float] {
            guard amount > 0 else { return input }
            guard input.count > 1 else { return [Float](repeating: input.first ?? 0, count: input.count + amount * 2) }
            
            let clampedAmount = min(amount, input.count - 1)
            var padded = [Float](repeating: 0, count: input.count + clampedAmount * 2)
            
            for index in 0..<clampedAmount {
                padded[index] = input[clampedAmount - index]
            }
            
            for index in input.indices {
                padded[clampedAmount + index] = input[index]
            }
            
            for index in 0..<clampedAmount {
                padded[clampedAmount + input.count + index] = input[input.count - 2 - index]
            }
            
            return padded
        }
    }
    
    static func separate(fileURL: URL) throws -> [StemFile] {
        try Task.checkCancellation()
        let contract = try loadContract()
        let source = try readStereoPCM(from: fileURL)
        try Task.checkCancellation()
        
        let modelRateInput: StereoPCM
        if abs(source.sampleRate - modelSampleRate) > 0.5 {
            let left = resample(source.left, from: source.sampleRate, to: modelSampleRate)
            let right = resample(source.right, from: source.sampleRate, to: modelSampleRate)
            modelRateInput = StereoPCM(left: left, right: right, sampleRate: modelSampleRate)
        } else {
            modelRateInput = source
        }
        
        var stems = try runMDXInference(source: modelRateInput, contract: contract)
        try Task.checkCancellation()
        
        if abs(source.sampleRate - modelRateInput.sampleRate) > 0.5 {
            stems = stems.mapValues { chunk in
                StereoChunk(
                    left: resample(chunk.left, from: modelRateInput.sampleRate, to: source.sampleRate),
                    right: resample(chunk.right, from: modelRateInput.sampleRate, to: source.sampleRate)
                )
            }
        }

        try Task.checkCancellation()
        return try write(
            stems: stems,
            sampleRate: source.sampleRate,
            sourceName: fileURL.deletingPathExtension().lastPathComponent
        )
    }
    
    private static func loadContract() throws -> ModelContract {
        guard let modelLocation = resolveModelLocation() else {
            throw StemSeparationError.modelNotFound(expectedNames: expectedModelNames)
        }
        
        let modelURL: URL
        switch modelLocation {
        case .compiled(let url):
            modelURL = url
        case .source(let url):
            modelURL = try MLModel.compileModel(at: url)
        }
        
        let model = try MLModel(contentsOf: modelURL)
        
        guard let input = model.modelDescription.inputDescriptionsByName.first(where: { $0.value.type == .multiArray }) else {
            throw StemSeparationError.unsupportedModelInput(details: "No multi-array input found")
        }
        
        guard let inputConstraint = input.value.multiArrayConstraint else {
            throw StemSeparationError.unsupportedModelInput(details: "Input '\(input.key)' is missing a shape constraint")
        }
        
        let inputShape = inputConstraint.shape.map(\.intValue)
        let expectedInput = [1, 4, dimF, segmentFrames]
        guard inputShape == expectedInput else {
            throw StemSeparationError.unsupportedModelInput(
                details: "Expected \(expectedInput), got \(inputShape)"
            )
        }
        
        guard let output = model.modelDescription.outputDescriptionsByName.first(where: { $0.value.type == .multiArray }) else {
            throw StemSeparationError.unsupportedModelOutput(details: "No multi-array output found")
        }
        
        if let outputConstraint = output.value.multiArrayConstraint {
            let outputShape = outputConstraint.shape.map(\.intValue)
            let expectedOutput = [1, 4, dimF, segmentFrames]
            guard outputShape == expectedOutput else {
                throw StemSeparationError.unsupportedModelOutput(
                    details: "Expected \(expectedOutput), got \(outputShape)"
                )
            }
        }
        
        return ModelContract(
            model: model,
            inputName: input.key,
            outputName: output.key
        )
    }
    
    private static func resolveModelLocation() -> ModelLocation? {
        let bundles = modelSearchBundles()
        
        for bundle in bundles {
            for modelName in expectedModelNames {
                if let compiled = bundle.url(forResource: modelName, withExtension: "mlmodelc") {
                    return .compiled(compiled)
                }
            }
        }
        
        for bundle in bundles {
            for modelName in expectedModelNames {
                if let sourcePackage = bundle.url(forResource: modelName, withExtension: "mlpackage") {
                    return .source(sourcePackage)
                }
                if let sourceModel = bundle.url(forResource: modelName, withExtension: "mlmodel") {
                    return .source(sourceModel)
                }
            }
        }
        
        for bundle in bundles {
            if let anyCompiled = bundle.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil)?.first {
                return .compiled(anyCompiled)
            }
            if let anyPackage = bundle.urls(forResourcesWithExtension: "mlpackage", subdirectory: nil)?.first {
                return .source(anyPackage)
            }
            if let anySourceModel = bundle.urls(forResourcesWithExtension: "mlmodel", subdirectory: nil)?.first {
                return .source(anySourceModel)
            }
        }
        
        return nil
    }
    
    private static func modelSearchBundles() -> [Bundle] {
        var bundles: [Bundle] = []
        
        #if SWIFT_PACKAGE
        bundles.append(.module)
        #endif
        
        bundles.append(.main)
        return bundles
    }
    
    private static func runMDXInference(
        source: StereoPCM,
        contract: ModelContract
    ) throws -> [StemKind: StereoChunk] {
        try Task.checkCancellation()
        let primary = try demixPrimarySource(source: source, contract: contract)
        try Task.checkCancellation()
        
        let sampleCount = min(source.left.count, primary.left.count)
        var vocalsLeft = [Float](repeating: 0, count: sampleCount)
        var vocalsRight = [Float](repeating: 0, count: sampleCount)
        var instrumentalLeft = [Float](repeating: 0, count: sampleCount)
        var instrumentalRight = [Float](repeating: 0, count: sampleCount)
        
        for index in 0..<sampleCount {
            instrumentalLeft[index] = primary.left[index]
            instrumentalRight[index] = primary.right[index]
            vocalsLeft[index] = source.left[index] - primary.left[index] * compensate
            vocalsRight[index] = source.right[index] - primary.right[index] * compensate
        }
        
        return [
            .instrumental: StereoChunk(left: instrumentalLeft, right: instrumentalRight),
            .vocals: StereoChunk(left: vocalsLeft, right: vocalsRight)
        ]
    }
    
    private static func demixPrimarySource(
        source: StereoPCM,
        contract: ModelContract
    ) throws -> StereoChunk {
        try Task.checkCancellation()
        let sampleCount = source.left.count
        let remainder = sampleCount % genSize
        let pad = genSize + trim - remainder
        
        var mixtureLeft = [Float](repeating: 0, count: trim)
        mixtureLeft.append(contentsOf: source.left)
        mixtureLeft.append(contentsOf: repeatElement(0, count: pad))
        
        var mixtureRight = [Float](repeating: 0, count: trim)
        mixtureRight.append(contentsOf: source.right)
        mixtureRight.append(contentsOf: repeatElement(0, count: pad))
        
        let mixtureLength = mixtureLeft.count
        let step = max(Int((1.0 - overlap) * Double(chunkSize)), 1)
        
        var resultLeft = [Float](repeating: 0, count: mixtureLength)
        var resultRight = [Float](repeating: 0, count: mixtureLength)
        var dividerLeft = [Float](repeating: 0, count: mixtureLength)
        var dividerRight = [Float](repeating: 0, count: mixtureLength)
        var windowCache: [Int: [Float]] = [:]
        
        let stft = try STFTProcessor(nFFT: nFFT, hopLength: hopLength, dimF: dimF)
        
        for start in stride(from: 0, to: mixtureLength, by: step) {
            try Task.checkCancellation()
            let end = min(start + chunkSize, mixtureLength)
            let actualCount = end - start
            
            var chunkLeft = Array(mixtureLeft[start..<end])
            var chunkRight = Array(mixtureRight[start..<end])
            
            if actualCount < chunkSize {
                chunkLeft.append(contentsOf: repeatElement(0, count: chunkSize - actualCount))
                chunkRight.append(contentsOf: repeatElement(0, count: chunkSize - actualCount))
            }
            
            let spectrumInput = try stft.forwardStereo(left: chunkLeft, right: chunkRight, zeroLowBins: 3)
            let inputArray = try makeModelInput(from: spectrumInput)
            let provider = try MLDictionaryFeatureProvider(dictionary: [contract.inputName: inputArray])
            
            let prediction: MLFeatureProvider
            do {
                prediction = try contract.model.prediction(from: provider)
            } catch {
                throw StemSeparationError.predictionFailed(details: error.localizedDescription)
            }
            try Task.checkCancellation()
            
            guard let outputArray = prediction.featureValue(for: contract.outputName)?.multiArrayValue else {
                throw StemSeparationError.unsupportedModelOutput(details: "Missing output '\(contract.outputName)'")
            }
            
            let predictedSpectrum = try decodeModelOutput(outputArray, expectedFrames: segmentFrames)
            let predictedWave = try stft.inverseStereo(predictedSpectrum, expectedLength: chunkSize)
            
            let window: [Float]
            if let cached = windowCache[actualCount] {
                window = cached
            } else {
                let generated = hannSymmetric(size: actualCount)
                windowCache[actualCount] = generated
                window = generated
            }
            
            for offset in 0..<actualCount {
                let destination = start + offset
                let weight = window[offset]
                
                resultLeft[destination] += predictedWave.left[offset] * weight
                resultRight[destination] += predictedWave.right[offset] * weight
                dividerLeft[destination] += weight
                dividerRight[destination] += weight
            }
        }
        
        for index in 0..<mixtureLength {
            if dividerLeft[index] > 1e-8 {
                resultLeft[index] /= dividerLeft[index]
            }
            if dividerRight[index] > 1e-8 {
                resultRight[index] /= dividerRight[index]
            }
        }
        
        guard mixtureLength > 2 * trim else {
            throw StemSeparationError.predictionFailed(details: "Mixture was too short after padding")
        }
        
        let centeredLeft = Array(resultLeft[trim..<(mixtureLength - trim)])
        let centeredRight = Array(resultRight[trim..<(mixtureLength - trim)])
        
        return StereoChunk(
            left: Array(centeredLeft.prefix(sampleCount)),
            right: Array(centeredRight.prefix(sampleCount))
        )
    }
    
    private static func makeModelInput(from spectrum: Spectrogram4) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [1, 4, NSNumber(value: dimF), NSNumber(value: spectrum.frames)], dataType: .float32)
        let pointer = array.dataPointer.bindMemory(to: Float32.self, capacity: array.count)
        
        let strideBatch = array.strides[0].intValue
        let strideChannel = array.strides[1].intValue
        let strideFrequency = array.strides[2].intValue
        let strideFrame = array.strides[3].intValue
        
        for channel in 0..<4 {
            let source = spectrum.channels[channel]
            for frequency in 0..<dimF {
                for frame in 0..<spectrum.frames {
                    let sourceIndex = frequency * spectrum.frames + frame
                    let destination = 0 * strideBatch
                    + channel * strideChannel
                    + frequency * strideFrequency
                    + frame * strideFrame
                    pointer[destination] = source[sourceIndex]
                }
            }
        }
        
        return array
    }
    
    private static func decodeModelOutput(_ array: MLMultiArray, expectedFrames: Int) throws -> Spectrogram4 {
        guard array.shape.count == 4 else {
            throw StemSeparationError.unsupportedModelOutput(details: "Expected rank-4 output, got rank-\(array.shape.count)")
        }
        
        let shape = array.shape.map(\.intValue)
        let expected = [1, 4, dimF, expectedFrames]
        guard shape == expected else {
            throw StemSeparationError.unsupportedModelOutput(details: "Expected \(expected), got \(shape)")
        }
        
        let strideBatch = array.strides[0].intValue
        let strideChannel = array.strides[1].intValue
        let strideFrequency = array.strides[2].intValue
        let strideFrame = array.strides[3].intValue
        let maxSourceIndex =
        (shape[0] - 1) * strideBatch
        + (shape[1] - 1) * strideChannel
        + (shape[2] - 1) * strideFrequency
        + (shape[3] - 1) * strideFrame
        guard maxSourceIndex >= 0 else {
            throw StemSeparationError.unsupportedModelOutput(details: "Output strides produced negative indexing")
        }
        let reader = try MultiArrayReader(array: array, requiredCapacity: maxSourceIndex + 1)
        
        var channels = Array(
            repeating: [Float](repeating: 0, count: dimF * expectedFrames),
            count: 4
        )
        
        for channel in 0..<4 {
            for frequency in 0..<dimF {
                for frame in 0..<expectedFrames {
                    let source = 0 * strideBatch
                    + channel * strideChannel
                    + frequency * strideFrequency
                    + frame * strideFrame
                    guard source >= 0, source < reader.capacity else {
                        throw StemSeparationError.unsupportedModelOutput(
                            details: "Output index \(source) is out of bounds for capacity \(reader.capacity)"
                        )
                    }
                    channels[channel][frequency * expectedFrames + frame] = reader.value(at: source)
                }
            }
        }
        
        return Spectrogram4(channels: channels, frames: expectedFrames)
    }
    
    private static func readStereoPCM(from fileURL: URL) throws -> StereoPCM {
        let file = try AVAudioFile(forReading: fileURL)
        guard file.length > 0 else { throw StemSeparationError.unreadableAudio }
        
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw StemSeparationError.unreadableAudio
        }
        
        try file.read(into: buffer)
        
        guard let channels = buffer.floatChannelData else {
            throw StemSeparationError.unreadableAudio
        }
        
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { throw StemSeparationError.unreadableAudio }
        
        let left = Array(UnsafeBufferPointer(start: channels[0], count: frameCount))
        let right: [Float]
        
        if Int(format.channelCount) > 1 {
            right = Array(UnsafeBufferPointer(start: channels[1], count: frameCount))
        } else {
            right = left
        }
        
        return StereoPCM(left: left, right: right, sampleRate: format.sampleRate)
    }
    
    private static func hannSymmetric(size: Int) -> [Float] {
        guard size > 1 else { return [1] }
        let denominator = Float(size - 1)
        return (0..<size).map { index in
            0.5 - 0.5 * cosf(2 * .pi * Float(index) / denominator)
        }
    }
    
    private static func resample(_ input: [Float], from sourceRate: Double, to targetRate: Double) -> [Float] {
        if abs(sourceRate - targetRate) < 0.5 {
            return input
        }
        
        let ratio = targetRate / sourceRate
        let outputCount = max(1, Int(Double(input.count) * ratio))
        var output = [Float](repeating: 0, count: outputCount)
        
        for outputIndex in 0..<outputCount {
            let sourcePosition = Double(outputIndex) / ratio
            let lower = min(Int(sourcePosition), input.count - 1)
            let upper = min(lower + 1, input.count - 1)
            let fraction = Float(sourcePosition - Double(lower))
            output[outputIndex] = (1 - fraction) * input[lower] + fraction * input[upper]
        }
        
        return output
    }
    
    private static func write(
        stems: [StemKind: StereoChunk],
        sampleRate: Double,
        sourceName: String
    ) throws -> [StemFile] {
        let fileManager = FileManager.default
        // Stage outputs in caches so callers can decide if/where to persist.
        let baseDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioHelper", isDirectory: true)
            .appendingPathComponent("StagedStems", isDirectory: true)
        let outputDirectory = baseDirectory.appendingPathComponent(
            "\(sourceName)-\(Int(Date().timeIntervalSince1970))",
            isDirectory: true
        )
        
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        var written: [StemFile] = []
        
        for kind in StemKind.allCases {
            guard let stem = stems[kind] else { continue }
            
            let url = outputDirectory.appendingPathComponent("\(kind.rawValue).wav")
            let file = try AVAudioFile(forWriting: url, settings: outputFormat.settings)
            
            let frameCount = stem.left.count
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: AVAudioFrameCount(frameCount)
            ) else {
                throw StemSeparationError.unreadableAudio
            }
            
            buffer.frameLength = AVAudioFrameCount(frameCount)
            guard let channels = buffer.floatChannelData else {
                throw StemSeparationError.unreadableAudio
            }
            
            for index in 0..<frameCount {
                channels[0][index] = stem.left[index]
                channels[1][index] = stem.right[index]
            }
            
            try file.write(from: buffer)
            written.append(StemFile(kind: kind, fileURL: url))
        }
        
        return written
    }
}
