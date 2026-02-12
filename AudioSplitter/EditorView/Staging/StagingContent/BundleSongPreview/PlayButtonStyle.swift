//
//  PlayButtonStyle.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/12/26.
//

import SwiftUI

/// This style is used for the play button, it looks really nice behind it
struct PlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        configuration.isPressed
                        ? Color(.systemGray5).opacity(0.5)
                        : Color(.systemGray).opacity(0.2)
                    )
            }
            .scaleEffect(configuration.isPressed ? 1.05 : 1.0)
            .animation(
                .spring,
                value: configuration.isPressed
            )
    }
}
