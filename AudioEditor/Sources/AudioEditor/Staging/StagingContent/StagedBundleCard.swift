//
//  StagedBundleCard.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/10/26.
//

import SwiftUI

/// Represents each staged card in the CurrentStagingContent
struct StagedBundleCard: View {
    
    let item: EditorFile
    var onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            /// Header
            HStack(alignment: .top) {
                /// Name + Date Created
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    
                    Text(item.createdAt.formatted(.dateTime.month().day().year()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                BundleSongPreview(
                    url: item.url,
                    onRemove: onRemove
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}


#Preview {
    StagedBundleCard(item: .previewSong, onRemove: {})
    StagedBundleCard(item: .previewSong, onRemove: {})
    StagedBundleCard(item: .previewSong, onRemove: {})
    StagedBundleCard(item: .previewSong, onRemove: {})
}

