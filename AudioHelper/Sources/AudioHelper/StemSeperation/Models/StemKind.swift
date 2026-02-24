//
//  StemKind.swift
//  AudioHelper
//
//  Created by Aryan Rogye on 2/23/26.
//

import SwiftUI

/**
 * Represents the Kind of Stem provided
 */
public enum StemKind: String, Sendable, CaseIterable, Hashable {
    case vocals = "Vocals"
    case instrumental = "Instrumentals"
    
    public var tint: Color {
        switch self {
        case .vocals: .yellow
        case .instrumental: .blue
        }
    }
}
