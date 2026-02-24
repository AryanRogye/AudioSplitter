//
//  StagingModalContent.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/9/26.
//

import SwiftUI

/// This exists in the StagingArea modal, this allows us to pick
/// library items to add to our staging area
struct StagingModalContent: View {
    
    @Bindable var editorVM : EditorViewModel
    @State private var selectedItem: EditorFile? = nil
    
    var body: some View {
        if editorVM.allSongs.isEmpty {
            Text("No recents yet.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 6)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(editorVM.allSongs.indices, id: \.self) { index in
                        
                        let item = editorVM.allSongs[index]
                        let isSelected = item == selectedItem
                        /// in the staging area
                        let isStaged = editorVM.stagedTracks.contains(item)
                        
                        StagingModalRow(
                            isSelected: isSelected,
                            item: item,
                            isStaged: isStaged,
                            onClick: {
                                withAnimation(.snappy) {
                                    selectItemInModal(item: item)
                                }
                            },
                            onAdd: {
                                editorVM.addToStaged(item)
                            },
                            onRename: { newValue in
                                editorVM.renameEditorClip(item: item, newName: newValue)
                            },
                            onErase: {
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    private func selectItemInModal(item: EditorFile) {
        if selectedItem == item {
            /// if equal we set back to nil
            selectedItem = nil
        } else {
            selectedItem = item
        }
    }
}
