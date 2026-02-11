//
//  CurrentStagingContent.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/10/26.
//

import SwiftUI

struct CurrentStagingContent: View {
    @ObservedObject var viewModel: AudioLibraryViewModel
    @Bindable var editorVM: EditorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            /// Header with count
            HStack {
                Text("Staged Tracks")
                    .font(.system(.headline, design: .rounded))
                
                Text("\(editorVM.stagedTracks.count)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2), in: Capsule())
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            if editorVM.stagedTracks.isEmpty {
                ContentUnavailableView("No tracks added",
                                       systemImage: "music.note.list",
                                       description: Text("Select tracks from your library to start editing."))
                .symbolVariant(.slash)
            } else {
                /// List of all staged songs
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(editorVM.stagedTracks), id: \.self) { track in
                            StagedBundleCard(item: track)
                                .environmentObject(viewModel)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
}
