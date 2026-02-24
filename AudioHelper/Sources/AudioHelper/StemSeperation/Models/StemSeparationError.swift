//
//  StemSeparationError.swift
//  AudioHelper
//
//  Created by Aryan Rogye on 2/23/26.
//

import Foundation

/**
 * Error for whatever may happen while we're splitting stems
 */
enum StemSeparationError: LocalizedError {
    case modelNotFound(expectedNames: [String])
    case unsupportedModelInput(details: String)
    case unsupportedModelOutput(details: String)
    case unreadableAudio
    case predictionFailed(details: String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let expectedNames):
            return "No bundled Core ML model was found. Add a model resource (.mlpackage, .mlmodel, or .mlmodelc) to the AudioHelper package resources (for example: \(expectedNames.joined(separator: ", ")))."
        case .unsupportedModelInput(let details):
            return "Unsupported model input: \(details)"
        case .unsupportedModelOutput(let details):
            return "Unsupported model output: \(details)"
        case .unreadableAudio:
            return "Could not decode the selected audio file."
        case .predictionFailed(let details):
            return "Model inference failed: \(details)"
        }
    }
}
