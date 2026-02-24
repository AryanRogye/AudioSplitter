//
//  StemFile.swift
//  AudioHelper
//
//  Created by Aryan Rogye on 2/23/26.
//

import Foundation

/**
 * Represents a Stem File
 */
public struct StemFile: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public let kind: StemKind
    public let fileURL: URL
    
    public var displayName: String {
        kind.rawValue.capitalized
    }
}
