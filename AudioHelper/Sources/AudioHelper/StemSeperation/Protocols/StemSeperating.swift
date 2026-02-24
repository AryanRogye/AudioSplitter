//
//  StemSeperating.swift
//  AudioHelper
//
//  Created by Aryan Rogye on 2/23/26.
//

import Foundation

/**
 * Public Facing API so we can easily split audio
 */
public protocol StemSeparating: Sendable {
    nonisolated func separate(fileURL: URL) throws -> [StemFile]
}
