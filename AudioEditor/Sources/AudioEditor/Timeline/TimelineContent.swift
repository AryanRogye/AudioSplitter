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
                    ForEach(editorVM.timelineSong.clips) { clip in
                        Button(action: {
                            if editorVM.selectedClip == clip.id {
                                editorVM.selectedClip = nil
                            } else {
                                editorVM.selectedClip = clip.id
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
