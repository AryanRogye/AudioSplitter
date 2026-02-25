//
//  TimelineEditorView.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/12/26.
//

import SwiftUI

struct TimelineEditorView: View {

    @Bindable var editorVM: EditorViewModel

    let pixelsPerSecond: CGFloat = 20

    private let headerWidth: CGFloat = 80
    private let headerSpacing: CGFloat = 10
    private let laneHPadding: CGFloat = 8

    private var timelineLeftInset: CGFloat {
        headerWidth + headerSpacing + laneHPadding
    }

    @State private var initialPlayheadTime: TimeInterval? = nil

    var body: some View {
        VStack(spacing: 0) {
            TimelinePlaybackControls(isPlaying: editorVM.isPlaying) {
                editorVM.toggleAudio()
            }

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    TimelineContent(
                        editorVM: editorVM,
                        pixelsPerSecond: pixelsPerSecond,
                        timelineLeftInset: timelineLeftInset
                    )

                    TimelinePlayhead(
                        editorVM: editorVM,
                        pixelsPerSecond: pixelsPerSecond,
                        timelineLeftInset: timelineLeftInset,
                        initialPlayheadTime: $initialPlayheadTime
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
        .dropDestination(for: EditorFile.self) { items, _ in
            withAnimation(.spring()) {
                editorVM.addDroppedItems(items)
            }
            return true
        }
    }
}
