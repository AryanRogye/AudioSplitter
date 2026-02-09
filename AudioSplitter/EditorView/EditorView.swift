//
//  EditorView.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/8/26.
//

import SwiftUI

@Observable
@MainActor
final class EditorViewModel {
    var isRecentsOpen = false
}

struct EditorView: View {
    
    @ObservedObject var viewModel: AudioLibraryViewModel
    @State private var editorVM = EditorViewModel()
    
    var body: some View {
        GeometryReader { geo in
            
            let libraryHeight = geo.size.height * 0.30
            let timelineHeight = geo.size.height * 0.70;
            
            VStack(spacing: 6) {
                LibraryPicker(
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

struct TimelineEditorView: View {
    
    let shape = UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: 32,
        bottomTrailingRadius: 32,
        topTrailingRadius: 0,
        style: .continuous
    )

    var body: some View {
        VStack {
            VStack {
                Text("Hellok")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background (shape.fill(Color(.systemGray6)))
    }
}


#Preview {
    
    @Previewable @StateObject var viewModel = AudioLibraryViewModel()
    
    EditorView(viewModel: viewModel)
}
