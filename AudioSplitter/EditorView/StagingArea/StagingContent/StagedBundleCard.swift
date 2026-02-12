//
//  StagedBundleCard.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/10/26.
//

import SwiftUI

enum SelectedStageListen {
    case none
    case vocal
    case instrumental
    
    var stageTrackRole: StageTrackRole? {
        switch self {
        case .none: return nil
        case .vocal: return .vocal
        case .instrumental: return .instrumental
        }
    }
    var kind: StemKind? {
        switch self {
        case .none: return nil
        case .vocal: return .vocals
        case .instrumental: return .instrumental
        }
    }
}

/// Represents each staged card in the CurrentStagingContent
struct StagedBundleCard: View {
    
    @State private var selected: SelectedStageListen = .none
    let item: ProcessedTrackHistoryItem
    var onRemove: () -> Void
    
    var vocalURL: URL? {
        let vocals = item.stems.first(where: { $0.kind == .vocals })
        return vocals?.fileURL
    }
    var instrumentalURL: URL? {
        let instruments = item.stems.first(where: { $0.kind == .instrumental })
        return instruments?.fileURL
    }
    
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
                    
                    HStack(spacing: 8) {
                        ForEach(item.stems.indices, id: \.self) { index in
                            let stem = item.stems[index]
                            StemBundleCardToggleButton(stem: stem, selected: $selected)
                        }
                    }
                }
                
                Spacer()
                
                // Preview Control
                BundleSongPreview(
                    selected: $selected,
                    vocalURL: vocalURL,
                    instrumentalURL: instrumentalURL
                )
                .padding(.bottom, 4)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

#Preview {
    StagedBundleCard(
        item: ProcessedTrackHistoryItem(
                id: UUID(),
                sourceFileName: "Blow 2.wav",
                sourceFileURL: URL(fileURLWithPath: "/System/Library/Sounds/Blow.aiff"),
                createdAt: .now.addingTimeInterval(-3600),
                sourceFingerprint: [0.2, 0.4, 0.7],
                stems: [
                    StoredStemAsset(
                        id: UUID(),
                        kind: .vocals,
                        fileURL: URL(fileURLWithPath: "/System/Library/Sounds/Blow.aiff"),
                        sourceTrackName: "Opposite",
                        createdAt: .now,
                        customName: "Don Toliver"
                    ),
                    StoredStemAsset(
                        id: UUID(),
                        kind: .instrumental,
                        fileURL: URL(fileURLWithPath: "/System/Library/Sounds/Blow.aiff"),
                        sourceTrackName: "Mo City Flexologist",
                        createdAt: .now,
                        customName: "Travis Scott"
                    )
                ],
                customName: nil
            )
    ) {
        
    }
}
