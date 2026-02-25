//
//  TimelineContent.swift
//  ComfyAudio
//

import SwiftUI

struct TimelineContent: View {
    @Bindable var editorVM: EditorViewModel
    let pixelsPerSecond: CGFloat
    let timelineLeftInset: CGFloat

    private let totalSeconds: Double = 180
    private let gridHeight: CGFloat = 60
    private let laneHeight: CGFloat = 60

    var body: some View {
        let scale = BeatScale(bpm: 120, beatsPerBar: 4, pixelsPerSecond: pixelsPerSecond)
        let totalWidth = CGFloat(totalSeconds) * pixelsPerSecond

        return ZStack(alignment: .topLeading) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(editorVM.timelineSong.clips) { clip in
                        ZStack {
                            BeatGridView(scale: scale, totalSeconds: totalSeconds, laneHeight: gridHeight)
                                .padding(.leading, timelineLeftInset)
                                .frame(width: totalWidth + timelineLeftInset)
                                .background(Color(.tertiarySystemBackground))

                            TimelineTrackLane(clip: clip, pixelsPerSecond: pixelsPerSecond)
                                .frame(height: laneHeight)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                editorVM.removeURLFromSong(clip)
                            } label: {
                                Label("Remove Stem", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .clipped()
    }
}
