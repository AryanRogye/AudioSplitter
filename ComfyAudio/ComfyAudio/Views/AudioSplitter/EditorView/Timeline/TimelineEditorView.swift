//
//  TimelineEditorView.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/12/26.
//

import SwiftUI

struct TimelineEditorView: View {

    @Bindable var editorVM: EditorViewModel

    let pixelsPerSecond: CGFloat = 20

    /// left section
    private let headerWidth: CGFloat = 90
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
                        timelineLeftInset: timelineLeftInset,
                        headerWidth: headerWidth
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
        /// TODO: SHOW SOMETHING HERE ON SELECTED ID
        .overlay(alignment: .bottom) {
            if let id = editorVM.selectedClip {
                GlassEffectContainer {
                    VStack {
                        Text("Selected: \(id)")
                        Button {
                            Task {
                                try? await editorVM.splitAtCurrentSelection()
                            }
                        } label: {
                            Text("Split At Current?")
                        }
                        .buttonStyle(GlassProminentButtonStyle())
                    }
                    .padding(4)
                }
            }
        }
    }
}
