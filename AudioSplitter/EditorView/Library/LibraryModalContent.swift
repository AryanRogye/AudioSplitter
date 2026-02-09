//
//  LibraryModalContent.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/9/26.
//

import SwiftUI

struct LibraryModalContent: View {
    
    @ObservedObject var viewModel: AudioLibraryViewModel
    @State private var selectedItem: ProcessedTrackHistoryItem? = nil
    
    var body: some View {
        if viewModel.history.isEmpty {
            Text("No recents yet.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 6)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.history.indices, id: \.self) { index in
                        let item = viewModel.history[index]
                        let isSelected = item == selectedItem
                        LibraryModalRow(
                            isSelected: isSelected,
                            item: item,
                            onClick: {
                                withAnimation(.snappy) {
                                    selectItemInModal(item: item)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    private func selectItemInModal(item: ProcessedTrackHistoryItem) {
        if selectedItem == item {
            /// if equal we set back to nil
            selectedItem = nil
        } else {
            selectedItem = item
        }
    }
}

struct LibraryModalRow: View {
    
    var isSelected: Bool
    var item: ProcessedTrackHistoryItem
    var onClick: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onClick) {
                HStack {
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
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .rotationEffect(.degrees(isSelected ? 90 : 0)) // Rotate when open
                        .padding(8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isSelected {
                HStack(spacing: 0) {
                    LibraryRowButton(text: "Add"   , systemName: "plus"  , color: Color(.systemGreen), isLeft: true, isRight: false) { }
                    LibraryRowButton(text: "Rename", systemName: "pencil", color: .blue, isLeft: false, isRight: false) { }
                    LibraryRowButton(text: "Delete", systemName: "trash",  color: .red, isLeft: false, isRight: true) { }
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
    }
}

struct LibraryRowButton: View {
    
    var text: String
    var systemName: String
    var color: Color
    var isLeft: Bool
    var isRight: Bool
    var action: () -> Void
    
    private var buttonShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: isLeft ? 6 : 0,
            bottomLeadingRadius: isLeft ? 12 : 0,
            bottomTrailingRadius: isRight ? 12 : 0,
            topTrailingRadius: isRight ? 6 : 0,
            style: .continuous
        )
    }
    
    var body: some View {
        Button(action: action) {
            Label(text, systemImage: systemName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(color.gradient, in: buttonShape)
                .contentShape(buttonShape)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
// Simple bounce effect on tap
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
