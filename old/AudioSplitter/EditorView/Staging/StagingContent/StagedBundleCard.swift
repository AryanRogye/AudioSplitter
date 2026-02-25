//
//  StagedBundleCard.swift
//  AudioSplitter
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
                        .font(.system(.headline, design: .rounded))
                        .lineLimit(1)
                    
                    Text(item.createdAt.formatted(.dateTime.month().day().year()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                /// The "Unstage" Button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary.opacity(0.5))
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                // Stem Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Select Track Role")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                // Preview Control
                BundleSongPreview(
                    url: item.url
                )
                .padding(.bottom, 4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}
