//
//  TimelineTopPlaybackControls.swift
//  ComfyAudio
//

import SwiftUI

struct TimelineTopPlaybackControls: View {
    
    @Environment(EditorTheme.self) var theme
    @Binding var beatsPerBar: Int
    let isPlaying: Bool
    let onToggle: () -> Void
    let playbackToStart: () -> Void
    let cameraToStart: () -> Void
    let toPlayhead: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(theme.accent)
                    .imageScale(.medium)
                    .padding(8)
                    .background(
                        Circle().stroke(theme.accent.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
            
            Spacer()
            
            Menu {
                Button("Jump to Start") { cameraToStart() }
                Button("To Playhead") { toPlayhead() }
                Button("Restart Playback") { playbackToStart() }
                Stepper(value: $beatsPerBar, in: 1...12) {
                    Text("Beats per Bar: \(beatsPerBar)")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(theme.accent)
                    .imageScale(.medium)
                    .padding(8)
                    .background(
                        Circle().stroke(theme.accent.opacity(0.35), lineWidth: 1)
                    )
            }
        }
    }
}
