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
    let totalSeconds: Double
    let bpm: Double
    let beatsPerBar: Int

    private let gridHeight: CGFloat = 60
    private let laneHeight: CGFloat = 60

    private var scale: BeatScale {
        BeatScale(
            bpm: bpm,
            beatsPerBar: beatsPerBar,
            pixelsPerSecond: pixelsPerSecond
        )
    }

    private var totalWidth: CGFloat {
        CGFloat(totalSeconds) * pixelsPerSecond
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimeRulerView(
                totalSeconds: totalSeconds,
                scale: scale,
                headerWidth: headerWidth
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            ScrollView([.vertical], showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ClipsView(
                        editorVM: editorVM,
                        scale: scale,
                        totalWidth: totalWidth,
                        totalSeconds: totalSeconds,
                        laneHeight: laneHeight,
                        timelineLeftInset: timelineLeftInset,
                        gridHeight: gridHeight,
                        headerWidth: headerWidth,
                        pixelsPerSecond: pixelsPerSecond
                    )
                    .padding(.top)
                }
                .scrollTargetLayout()
                .padding(.vertical, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .clipped()
        }
    }
}

struct ClipsView: View {

    @Environment(EditorTheme.self) var theme
    @Bindable var editorVM: EditorViewModel
    let scale: BeatScale
    let totalWidth: CGFloat
    let totalSeconds: Double
    let laneHeight: CGFloat
    let timelineLeftInset: CGFloat
    let gridHeight: CGFloat
    let headerWidth: CGFloat
    let pixelsPerSecond: CGFloat

    var body: some View {
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

                    TimelineTrackLane(
                        clip: clip,
                        headerWidth: headerWidth,
                        pixelsPerSecond: pixelsPerSecond,
                        scale: scale,
                        selected: Binding(
                            get: { editorVM.selectedClip == clip.id },
                            set: { _ in }
                        )
                    )
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
            } preview: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(clip.asset.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(theme.accent.opacity(0.9))

                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9, weight: .semibold))
                        Text(formatBarBeat(clip.startTime))
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(theme.accent.opacity(0.8))
                    .padding(.horizontal, 6)

                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(scale.beat(at: clip.duration), specifier: "%.2f") beats")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(theme.accent.opacity(0.8))
                    .padding(.horizontal, 6)
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: headerWidth, alignment: .leading)
                .padding()
                .glassEffect(.regular.tint(.black).interactive(), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func formatBarBeat(_ seconds: Double) -> String {
        let safeBeatsPerBar = max(scale.beatsPerBar, 1)
        let beat = scale.beat(at: seconds)
        let barIndex = Int(beat / Double(safeBeatsPerBar))
        let beatInBar = beat - (Double(barIndex) * Double(safeBeatsPerBar)) + 1
        return String(format: "B%d:%0.2f", barIndex + 1, beatInBar)
    }
}
