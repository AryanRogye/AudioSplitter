//
//  EditorViewModel.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/11/26.
//

import Foundation

@Observable
@MainActor
final class EditorViewModel {
    var isRecentsOpen = false
    var stagedTracks: [ProcessedTrackHistoryItem] = []
    
    /// We can add multiple of the same tracks so this is ok
    public func addToStaged(_ item: ProcessedTrackHistoryItem) {
        self.stagedTracks.append(item)
    }
    /// Removing Items from staging
    public func removeFromStaged(_ item: ProcessedTrackHistoryItem) {
        self.stagedTracks.removeAll(where: { $0.id == item.id })
    }
}
