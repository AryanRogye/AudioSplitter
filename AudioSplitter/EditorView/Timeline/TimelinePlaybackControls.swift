//
//  TimelinePlaybackControls.swift
//  AudioSplitter
//

import SwiftUI

struct TimelinePlaybackControls: View {
    let isPlaying: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onToggle) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
            }
            Spacer()
        }
        .buttonStyle(PlayButtonStyle())
        .padding(.vertical, 6)
    }
}
