//
//  StagedBundleCard.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/10/26.
//

import SwiftUI

/// Represents each staged card in the CurrentStagingContent
struct StagedBundleCard: View {
    
    let item: ProcessedTrackHistoryItem
    @EnvironmentObject var viewModel: AudioLibraryViewModel
    
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
                VStack {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(item.stems) { stem in
                                let selected = viewModel.selectedVocalID == stem.id || viewModel.selectedInstrumentalID == stem.id
                                Button(action: {
                                    if stem.kind == .vocals {
                                        viewModel.selectedInstrumentalID = nil
                                        viewModel.selectedVocalID = stem.id
                                    } else if stem.kind == .instrumental {
                                        viewModel.selectedVocalID = nil
                                        viewModel.selectedInstrumentalID = stem.id
                                    }
                                }) {
                                    Text(stem.kind.rawValue.prefix(1).uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(8)
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                        .background {
                                            Circle()
                                                .fill(selected ? Color(.systemPink).opacity(0.2) : .blue.opacity(0.2))
                                        }
                                        .onAppear {
                                            print("CARD \(item.displayName)")
                                            print("stem \(stem.kind) id=\(stem.id)")
                                            print("selectedVocalID=\(String(describing: viewModel.selectedVocalID))")
                                            print("selectedInstID=\(String(describing: viewModel.selectedInstrumentalID))")
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if viewModel.selectedVocalAsset == nil {
                        Text("Select One")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if item.stems.isEmpty {
                    Text("No stems found")
                        .font(.caption2)
                        .italic()
                } else {
                    SongPreview()
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

struct SongPreview: View {
    
    @EnvironmentObject var viewModel: AudioLibraryViewModel
    
    var isPlaying: Bool {
        viewModel.currentlyPreviewingRole == .vocal || viewModel.currentlyPreviewingRole == .instrumental
    }
    
    var body: some View {
        VStack {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5).opacity(0.5))
                        .frame(height: 4)
                    
                }
            }
            HStack {
                Button {
                    if viewModel.selectedVocalID != nil {
                        viewModel.toggleVocalPreview()
                    } else if viewModel.selectedInstrumentalID != nil {
                        viewModel.toggleInstrumentalPreview()
                    }
                } label: {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }
}


#Preview {
    StagedBundleCard(item: ProcessedTrackHistoryItem(
        id: UUID(),
        sourceFileName: "Track 2.wav",
        sourceFileURL: URL(fileURLWithPath: "/tmp/track2.wav"),
        createdAt: .now.addingTimeInterval(-3600),
        sourceFingerprint: [0.2, 0.4, 0.7],
        stems: [
            StoredStemAsset(
                id: UUID(),
                kind: .vocals,
                fileURL: URL(fileURLWithPath: "/tmp/track1_vocals.mp3"),
                sourceTrackName: "Opposite",
                createdAt: .now,
                customName: "Don Toliver"
            ),
            StoredStemAsset(
                id: UUID(),
                kind: .instrumental,
                fileURL: URL(fileURLWithPath: "/tmp/track1_instrumental.mp3"),
                sourceTrackName: "Mo City Flexologist",
                createdAt: .now,
                customName: "Travis Scott"
            )
        ],
        customName: nil
    )
    )
    .environmentObject(AudioLibraryViewModel())
}
