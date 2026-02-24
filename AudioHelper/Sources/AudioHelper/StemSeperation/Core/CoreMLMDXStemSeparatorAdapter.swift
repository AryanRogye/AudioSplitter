//
//  CoreMLMDXStemSeparatorAdapter.swift
//  AudioHelper
//
//  Created by Aryan Rogye on 2/23/26.
//

import Accelerate
import AVFoundation
import CoreML
import Foundation

public struct CoreMLMDXStemSeparatorAdapter: StemSeparating {
    
    public init() {
        
    }
    
    public nonisolated func separate(fileURL: URL) throws -> [StemFile] {
        try CoreMLStemSeparatorEngine.separate(fileURL: fileURL)
    }
}
