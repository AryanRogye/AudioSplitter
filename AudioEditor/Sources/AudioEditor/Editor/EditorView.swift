//
//  EditorView.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/8/26.
//

import SwiftUI

public struct EditorView: View {
    
    @State private var editorVM : EditorViewModel
    
    public init(allSongs: [EditorFile]) {
        self.editorVM = EditorViewModel(allSongs: allSongs, /*history: historyStore*/)
        /// DEBUG: REMOVE THIS IN PRODUCTION
        editorVM.addDroppedItems(allSongs)
    }
    
    public var body: some View {
        GeometryReader { geo in
            
            let libraryHeight = geo.size.height * 0.30
            let timelineHeight = geo.size.height * 0.70;
            
            VStack(spacing: 6) {
                StagingArea(
                    editorVM: editorVM,
                    areaHeight: libraryHeight
                )
                .frame(height: libraryHeight)
                .padding(.horizontal, 6)
                
                TimelineEditorView(
                    editorVM: editorVM
                )
                .frame(height: timelineHeight)
                .padding(.horizontal, 6)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}


#if DEBUG
#Preview {
    return EditorView(allSongs: [.previewSong])
        .task {
            
        }
}
#endif

#if DEBUG
extension EditorFile {
    static var previewSong: EditorFile {
        let bundle = Bundle.module
        
        let url = bundle.url(forResource: "Belong to the City", withExtension: "mp3")
        return EditorFile(
            url ?? URL(fileURLWithPath: "/dev/null"),
            id: UUID(),
            name: "Belong to the City",
            created: .now,
            type: .all
        )
    }
}
#endif
