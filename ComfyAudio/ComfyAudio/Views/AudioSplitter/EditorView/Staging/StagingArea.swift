//
//  StagingArea.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/9/26.
//

import SwiftUI

/// StagingArea is the top 30% of the screen in the Editor View
/// Allows us to choose songs to add from your library, drag and drop them into
/// the timeline view, etc
struct StagingArea: View {
    
    @Bindable var editorVM: EditorViewModel
    var areaHeight: CGFloat
    
    init(editorVM: EditorViewModel, areaHeight: CGFloat) {
        self.editorVM = editorVM
        self.areaHeight = areaHeight
    }
    
    let shape = UnevenRoundedRectangle(
        topLeadingRadius: 32,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: 32,
        style: .continuous
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            
            /// Real Content
            CurrentStagingContent(
                editorVM: editorVM
            )
            
            /// Draggable Configuration
            DraggableBottomSheet(
                isOpen: $editorVM.isRecentsOpen,
                areaHeight: areaHeight - 5,
                title: "Your Library \(editorVM.allSongs.count)"
            ) {
                /// Draggable Content
                StagingModalContent(
                    editorVM: editorVM
                )
            }
        }
        .clipped()
    }
}
