//
//  LibraryPicker.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/9/26.
//

import SwiftUI

struct LibraryPicker: View {
    
    @ObservedObject var viewModel: AudioLibraryViewModel
    @Bindable var editorVM: EditorViewModel
    var areaHeight: CGFloat
    
    init(viewModel: AudioLibraryViewModel,editorVM: EditorViewModel,areaHeight: CGFloat) {
        self.viewModel = viewModel
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
            currentLibraryContent
            
            /// Draggable Configuration
            DraggableBottomSheet(
                isOpen: $editorVM.isRecentsOpen,
                areaHeight: areaHeight - 5,
                title: "Your Library \(viewModel.history.count)"
            ) {
                /// Draggable Content
                LibraryModalContent(viewModel: viewModel)
            }
        }
        .clipped()
    }
    
    var currentLibraryContent: some View {
        // 1. Base Content
        VStack(alignment: .leading, spacing: 10) {
            Text("Library").font(.headline)
            Text("Main content area...").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
}
