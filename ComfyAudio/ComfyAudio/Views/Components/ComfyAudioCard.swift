//
//  ComfyAudioCard.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/23/26.
//

import SwiftUI

struct ComfyAudioCard<Content: View>: View {
    
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack {
            content
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.clear)
                .stroke(Theme.goldAccent ?? .white, style: .init(lineWidth: 1.5))
        }
    }
}

