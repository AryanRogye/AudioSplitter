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
    
    init(
        viewModel: AudioLibraryViewModel,
        editorVM: EditorViewModel,
        areaHeight: CGFloat
    ) {
        self.viewModel = viewModel
        self.editorVM = editorVM
        self.areaHeight = areaHeight
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // 1. Base Content
            VStack(alignment: .leading, spacing: 10) {
                Text("Library").font(.headline)
                Text("Main content area...").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6))
            
            // 2. Reusable Sheet
            DraggableBottomSheet(
                isOpen: $editorVM.isRecentsOpen,
                areaHeight: areaHeight - 5,
                title: "Recents"
            ) {
                // The specific content for this instance
                Group {
                    if viewModel.history.isEmpty {
                        Text("No recents yet.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(viewModel.history) { item in
                                    Text(item.displayName)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .clipped()
    }
    
    let shape = UnevenRoundedRectangle(
        topLeadingRadius: 32,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: 32,
        style: .continuous
    )
}
