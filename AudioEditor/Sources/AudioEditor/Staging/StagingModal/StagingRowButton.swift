//
//  StagingRowButton.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/10/26.
//

import SwiftUI

/// Selection Button inside of the view
struct StagingRowButton: View {
    
    var text: String
    var systemName: String
    var color: Color
    var isLeft: Bool
    var isRight: Bool
    var action: () -> Void
    
    private var buttonShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: isLeft ? 6 : 0,
            bottomLeadingRadius: isLeft ? 12 : 0,
            bottomTrailingRadius: isRight ? 12 : 0,
            topTrailingRadius: isRight ? 6 : 0,
            style: .continuous
        )
    }
    
    var body: some View {
        Button(action: action) {
            Label(text, systemImage: systemName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(color.gradient, in: buttonShape)
                .contentShape(buttonShape)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
