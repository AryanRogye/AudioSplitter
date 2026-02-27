//
//  TimelineContent.swift
//  ComfyAudio
//

import SwiftUI

struct TimelineContent: View {
    @Bindable var editorVM: EditorViewModel
    let pixelsPerSecond: CGFloat
    let timelineLeftInset: CGFloat
    let headerWidth: CGFloat

    private let totalSeconds: Double = 180
    private let gridHeight: CGFloat = 60
    private let laneHeight: CGFloat = 60
    
    var body: some View {
        let scale = BeatScale(bpm: 120, beatsPerBar: 4, pixelsPerSecond: pixelsPerSecond)
        let totalWidth = CGFloat(totalSeconds) * pixelsPerSecond

        return ZStack(alignment: .topLeading) {
            ScrollView([.vertical], showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    TimeRulerView(
                        totalSeconds: totalSeconds,
                        pixelsPerSecond: pixelsPerSecond,
                        headerWidth: headerWidth
                    )
                    ForEach(editorVM.timelineSong.clips) { clip in
                        Button(action: {
                            withAnimation(.spring) {
                                if editorVM.selectedClip == clip.id {
                                    editorVM.selectedClip = nil
                                } else {
                                    editorVM.selectedClip = clip.id
                                }
                            }
                        }) {
                            ZStack {
                                BeatGridView(scale: scale, totalSeconds: totalSeconds, laneHeight: gridHeight)
                                    .padding(.leading, timelineLeftInset)
                                    .frame(width: totalWidth + timelineLeftInset)
                                
                                TimelineTrackLane(clip: clip, headerWidth: headerWidth, pixelsPerSecond: pixelsPerSecond, selected: Binding(
                                    get: { editorVM.selectedClip == clip.id },
                                    set: { _ in }
                                ))
                                .frame(height: laneHeight)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                editorVM.removeURLFromSong(clip)
                            } label: {
                                Label("Remove Stem", systemImage: "trash")
                            }
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .clipped()
    }
}

struct TimeRulerView: View {
    
    @Environment(EditorTheme.self) var theme
    let totalSeconds: Double
    let pixelsPerSecond: CGFloat
    let headerWidth: CGFloat
    
    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: headerWidth)
                .padding(.horizontal, 8)
            
            ZStack(alignment: .bottomLeading) {
                let steps = Int(totalSeconds / 5)
                
                ForEach(0...steps, id: \.self) { i in
                    let time = Double(i) * 5
                    
                    bar(time)
                        .offset(x: time * pixelsPerSecond)
                }
                ForEach(0...steps, id: \.self) { i in
                    let time = Double(i) * 1
                    
                    if i % 5 != 0 {
                        regularBar(time)
                            .offset(x: time * pixelsPerSecond)
                    }
                }
            }
        }
        .frame(height: 30) // Gives the ruler some breathing room
    }
    
    private func regularBar(_ time: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(theme.accent.opacity(0.5))
                .frame(width: 1)
                .frame(maxHeight: 8)
        }
    }
    private func bar(_ time: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatTime(time))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.accent.opacity(0.5))
            
            Rectangle()
                .fill(theme.accent.opacity(0.5))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
