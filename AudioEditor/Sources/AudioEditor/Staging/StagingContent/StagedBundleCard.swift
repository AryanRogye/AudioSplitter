//
//  StagedBundleCard.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/10/26.
//

import SwiftUI

/// Represents each staged card in the CurrentStagingContent
struct StagedBundleCard: View {
    
    @Environment(EditorTheme.self) var theme
    let item: EditorFile
    var onRemove: () -> Void
    var onAddToTimeline: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            /// Header
            HStack(alignment: .top) {
                /// Name + Date Created
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.accent)
                        .lineLimit(1)
                    
                    Text(item.createdAt.formatted(.dateTime.month().day().year()))
                        .font(.caption2)
                        .foregroundStyle(theme.accent.opacity(0.7))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                BundleSongPreview(
                    url: item.url,
                    onRemove: onRemove,
                    onAddToTimeline: onAddToTimeline
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.accent.opacity(0.4), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}


#if DEBUG
#Preview {
    StagedBundleCard(item: .previewSong, onRemove: {}, onAddToTimeline: {})
    StagedBundleCard(item: .previewSong, onRemove: {}, onAddToTimeline: {})
    StagedBundleCard(item: .previewSong, onRemove: {}, onAddToTimeline: {})
    StagedBundleCard(item: .previewSong, onRemove: {}, onAddToTimeline: {})
}
#endif
