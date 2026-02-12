//
//  EditorView.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/8/26.
//

import SwiftUI

struct EditorView: View {
    
    @ObservedObject var viewModel: AudioLibraryViewModel
    @State private var editorVM = EditorViewModel()
    
    var body: some View {
        GeometryReader { geo in
            
            let libraryHeight = geo.size.height * 0.30
            let timelineHeight = geo.size.height * 0.70;
            
            VStack(spacing: 6) {
                StagingArea(
                    viewModel: viewModel,
                    editorVM: editorVM,
                    areaHeight: libraryHeight
                )
                .frame(height: libraryHeight)
                .padding(.horizontal, 6)
                
                TimelineEditorView()
                    .frame(height: timelineHeight)
                    .padding(.horizontal, 6)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

#Preview {
    
    let sampleHistory: [ProcessedTrackHistoryItem] = [
        ProcessedTrackHistoryItem(
            id: UUID(),
            sourceFileName: "Track 1.mp3",
            sourceFileURL: URL(fileURLWithPath: "/tmp/track1.mp3"),
            createdAt: .now,
            sourceFingerprint: [0.1, 0.3, 0.9],
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
            customName: "My Remix Track"
        ),
        ProcessedTrackHistoryItem(
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
    ]

    
    EditorView(
        viewModel: AudioLibraryViewModel(
            previewHistory: sampleHistory
        )
    )
}
