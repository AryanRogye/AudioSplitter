//
//  TimelineEditorView.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/12/26.
//

import SwiftUI

extension TimelineEditorView {
    @Observable
    @MainActor
    internal final class TimelineViewModel {
        var droppedItems: [ProcessedTrackHistoryItem] = []
        
        public func addDroppedItems(_ items: [ProcessedTrackHistoryItem]) {
            droppedItems.append(contentsOf: items)
        }
    }
}

struct TimelineEditorView: View {
    
    @State private var vm = TimelineViewModel()
    
    let shape = UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: 32,
        bottomTrailingRadius: 32,
        topTrailingRadius: 0,
        style: .continuous
    )
    
    /**
     
     */
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(vm.droppedItems.indices, id: \.self)  { index in
                    let track = vm.droppedItems[index]
                    VStack {
                        Text(track.displayName)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background (shape.fill(Color(.systemGray6)))
        .dropDestination(for: ProcessedTrackHistoryItem.self) { items, location in
            withAnimation(.spring()) {
                vm.addDroppedItems(items)
            }
            /// Confirms the drop was successful
            return true
        }
    }
}
