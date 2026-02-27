//
//  CurrentStagingContent.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/10/26.
//

import SwiftUI

/// Currently Staged Content, this is the top 30% of the screen in the EditorView
struct CurrentStagingContent: View {
    @Bindable var editorVM: EditorViewModel
    @Environment(EditorTheme.self) var theme: EditorTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            /// Header with count
            HStack {
                Text("Staged Tracks")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                
                Text("\(editorVM.stagedTracks.count)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(theme.accent)
                    .background(theme.textSecondary.opacity(0.2), in: Capsule())
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            if editorVM.stagedTracks.isEmpty {
                ContentUnavailableView("No tracks added",
                                       systemImage: "music.note.list",
                                       description: Text("Select tracks from your library to start editing."))
                .symbolVariant(.slash)
                .foregroundStyle(theme.accent.opacity(0.5))
            } else {
                /// List of all staged songs
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(editorVM.stagedTracks.indices, id: \.self) { index in
                            if index < editorVM.stagedTracks.count {
                                let track = editorVM.stagedTracks[index]
                                StagedBundleCard(item: track) {
                                    editorVM.removeFromStaged(track)
                                } onAddToTimeline: {
                                    editorVM.addDroppedItems([track])
                                }
                                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12))
                                .draggable(track) {
                                    VStack {
                                        Text(track.displayName)
                                    }
                                    .padding(6)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundSecondary)
    }
}
