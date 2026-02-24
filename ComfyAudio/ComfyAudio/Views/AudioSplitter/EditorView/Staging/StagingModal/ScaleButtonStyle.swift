//
//  ScaleButtonStyle.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/10/26.
//

import SwiftUI

// Simple bounce effect on tap
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
