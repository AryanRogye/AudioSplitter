//
//  EditorView.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/8/26.
//

import SwiftUI

struct EditorView: View {
    
    @State private var editorVM : EditorViewModel
    
    init(allSongs: [EditorFile], historyStore: AudioHistoryStoring) {
        self.editorVM = EditorViewModel(allSongs: allSongs, history: historyStore)
    }
    
    var body: some View {
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
                
                TimelineEditorView()
                    .frame(height: timelineHeight)
                    .padding(.horizontal, 6)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
