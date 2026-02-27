//
//  TimelineEditorView.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/12/26.
//

import SwiftUI

struct TimelineEditorView: View {

    @Environment(EditorTheme.self) var theme
    @Bindable var editorVM: EditorViewModel

    let pixelsPerSecond: CGFloat = 20

    /// left section
    private let headerWidth: CGFloat = 90
    private let headerSpacing: CGFloat = 9
    private let laneHPadding: CGFloat = 8
    private let minimumTimelineSeconds: Int = 180

    private var timelineLeftInset: CGFloat {
        headerWidth + headerSpacing + laneHPadding
    }
    
    private var markerSeconds: Int {
        let dynamicMax = Int(ceil(max(editorVM.timelineSong.currentTime, editorVM.timelineSong.duration)))
        return max(minimumTimelineSeconds, dynamicMax)
    }

    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var initialPlayheadTime: TimeInterval? = nil

    var body: some View {
        VStack(spacing: 0) {
            TimelinePlaybackControls(isPlaying: editorVM.isPlaying) {
                editorVM.toggleAudio()
            } playbackToStart: {
                editorVM.timelineSong.stop()
                editorVM.timelineSong.seek(to: 0)
                scrollProxy?.scrollTo("start", anchor: .leading)
            } cameraToStart: {
                scrollProxy?.scrollTo("start", anchor: .leading)
            } toPlayhead: {
                let t = editorVM.timelineSong.currentTime
                let s = max(0, min(Int(t.rounded(.down)), markerSeconds))
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy?.scrollTo("sec-\(s)", anchor: .center)
                }
            }
            
            Rectangle()
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .foregroundStyle(theme.accent.opacity(0.5))
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        
                        Color.clear.id("start")
                        
                        HStack(spacing: 0) {
                            ForEach(0...markerSeconds, id: \.self) { second in
                                Color.clear
                                    .frame(width: pixelsPerSecond, height: 1)   // 👈 key
                                    .id("sec-\(second)")
                            }
                        }
                        .frame(height: 1) // optional but helps
                        
                        TimelineContent(
                            editorVM: editorVM,
                            pixelsPerSecond: pixelsPerSecond,
                            timelineLeftInset: timelineLeftInset,
                            headerWidth: headerWidth
                        )

                        
                        TimelinePlayhead(
                            editorVM: editorVM,
                            pixelsPerSecond: pixelsPerSecond,
                            timelineLeftInset: timelineLeftInset,
                            initialPlayheadTime: $initialPlayheadTime
                        )
                        .id("playhead")
                    }
                }
                .task {
                    if scrollProxy == nil {
                        scrollProxy = proxy
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundPrimary)
        .dropDestination(for: EditorFile.self) { items, _ in
            withAnimation(.spring()) {
                editorVM.addDroppedItems(items)
            }
            return true
        }
        .overlay(alignment: .bottom) {
            if let id = editorVM.selectedClip {
                TimelineSelectionOverlay(
                    editorVM: editorVM,
                    id: id
                )
            }
        }
    }
}
