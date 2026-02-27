//
//  TimelineSelectionOverlay.swift
//  AudioEditor
//
//  Created by Aryan Rogye on 2/26/26.
//

import SwiftUI

struct TimelineSelectionOverlay: View {
    
    @Environment(EditorTheme.self) var theme
    @Bindable var editorVM: EditorViewModel
    @State var clickedVolume: Bool = false
    let id: UUID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            /// Header
            header
            
            if clickedVolume {
                if let clip = editorVM.selectedClipFile() {
                    TimelineClipVolumeEditor(
                        clip: clip
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Primary action row
            timelineActions
        }
        .clipped()
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.clear.interactive().tint(.black.opacity(0.6)), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Header
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(theme.accent)
            Text("Selected: \(id)")
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .font(.footnote)
                .foregroundStyle(theme.accent.opacity(0.7))
            Spacer()
        }
    }
    
    private var timelineActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Split button
                Button {
                    Task { try? await editorVM.splitAtCurrentSelection() }
                } label: {
                    Image(systemName: "scissors")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 36, height: 36)
                        .background(
                            Capsule().fill(theme.accent.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())

                // Mute/solo button (placeholder action)
                Button {
                    withAnimation(.spring()) {
                        clickedVolume.toggle()
                    }
                } label: {
                    Image(systemName: "speaker.2")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 36, height: 36)
                        .background(
                            Capsule().fill(theme.accent.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                
                Button {
                    withAnimation {
                        
                    }
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 36, height: 36)
                        .background(
                            Capsule().fill(theme.accent.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                
            }
            .foregroundStyle(theme.accent)
        }
    }
}


private struct TimelineClipVolumeEditor: View {
    @Environment(EditorTheme.self) var theme
    @Bindable var clip: TimelineClip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                Text("\(Int(clip.volume * 100))%")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.accent)
                    .contentTransition(.numericText(value: Double(clip.volume)))
                    .animation(.smooth(duration: 0.15), value: clip.volume)
            
            HStack(spacing: 10) {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accent.opacity(0.6))
                
                Slider(value: $clip.volume, in: 0...1)
                    .tint(theme.accent)
                    .scaleEffect(y: 1.25)
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accent.opacity(0.9))
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.clear)
                .stroke(theme.accent.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}
