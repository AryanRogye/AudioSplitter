//
//  StagingModalRow.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/10/26.
//

import SwiftUI

/// Each item in the StagingModalContent will be this😂
struct StagingModalRow: View {
    
    var isSelected: Bool
    var item: EditorFile
    var isStaged: Bool
    var onClick: () -> Void
    var onAdd: () -> Void
    var onRename: (String) -> Void
    var onErase: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onClick) {
                HStack {
                    /// If we have this item staged, we can add it again, but we should show a indicator that
                    /// something is already staged inside
                    if isStaged {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                            .transition(.scale.combined(with: .opacity)) // Nice pop-in effect
                            .padding(.leading, 8)
                    }
                    /// name to display
                    /// making sure that it can only be 2 lines
                    Text(item.displayName)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    
                    Spacer()
                    
                    /// On Click Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isSelected ? 90 : 0)) // Rotate when open
                        .padding(8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            /// when we select the item row, a dropdown or "section" opens up underneath revealing these items
            if isSelected {
                HStack(spacing: 0) {
                    StagingRowButton(text: "Add"   , systemName: "plus"  , color: Color(.systemGreen), isLeft: true, isRight: false) { onAdd() }
                    StagingRowButton(text: "Rename", systemName: "pencil", color: .blue, isLeft: false, isRight: false) { rename() }
//                    StagingRowButton(text: "Delete", systemName: "trash",  color: .red, isLeft: false, isRight: true) { onErase() }
                }
                .transition(
                    .asymmetric(
                        // IN: Slide from right + Fade in
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        // OUT: Slide back to right + Fade out
                        removal: .move(edge: .trailing).combined(with: .opacity)                    )
                )
            }
        }
        .clipped()
        .background(
            isSelected ? .regularMaterial : .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 12)
        )
        /// Rename alert
        .alert("Rename \"\(item.displayName)\"", isPresented: $showRenameAlert) {
            TextField(text: $renameText) { }
            Button("Cancel", role: .cancel) { }
            Button("OK") {
                if renameText.isEmpty { return }
                onRename(renameText)
            }
        } message: {
            Text("Enter the new name")
        }
    }
    
    /// Rename related
    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    private func rename() {
        renameText = item.displayName
        showRenameAlert = true
    }
}
