//
//  TimelinePlayhead.swift
//  ComfyAudio
//

import SwiftUI

struct TimelinePlayhead: View {
    
    @Environment(EditorTheme.self) var theme
    @Bindable var editorVM: EditorViewModel
    let pixelsPerSecond: CGFloat
    let timelineLeftInset: CGFloat

    @Binding var initialPlayheadTime: TimeInterval?

    var body: some View {
        TimelineView(.animation) { _ in
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(theme.accent)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)

                Image(systemName: "arrowtriangle.down.fill")
                    .foregroundColor(theme.accent)
                    .offset(y: -2)
            }
            .frame(width: 30)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .offset(
                x: timelineLeftInset + (editorVM.timelineSong.currentTime * pixelsPerSecond) - 15,
                y: 20
            )
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        if initialPlayheadTime == nil {
                            initialPlayheadTime = editorVM.timelineSong.currentTime
                        }
                        guard let start = initialPlayheadTime else { return }

                        let timeDelta = value.translation.width / pixelsPerSecond
                        let newTime = max(0, start + timeDelta)

                        editorVM.timelineSong.stop()
                        editorVM.timelineSong.seek(to: newTime)
                    }
                    .onEnded { _ in
                        initialPlayheadTime = nil
                    }
            )
        }
    }
}
