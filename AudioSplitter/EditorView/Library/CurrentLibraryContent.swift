//
//  CurrentLibraryContent.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/10/26.
//

import SwiftUI

struct CurrentLibraryContent: View {
    @ObservedObject var viewModel: AudioLibraryViewModel
    @Bindable var editorVM: EditorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with count
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
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(editorVM.stagedTracks), id: \.self) { track in
                            StagedBundleCard(item: track)
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


struct StagedBundleCard: View {
    let item: ProcessedTrackHistoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                // Show the date it was processed
                Text(item.createdAt.formatted(.dateTime.month().day()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            // Show the "Children" (the stems)
            HStack(spacing: 6) {
                ForEach(item.stems) { stem in
                    Text(stem.kind.rawValue.prefix(1).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background {
                            Circle()
                                .fill(.blue.opacity(0.2))
                        }
                }
                
                if item.stems.isEmpty {
                    Text("No stems found")
                        .font(.caption2)
                        .italic()
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}
