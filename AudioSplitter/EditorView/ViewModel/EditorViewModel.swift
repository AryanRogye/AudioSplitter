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
    var historyStore: AudioHistoryStoring
    
    var allSongs: [EditorFile]
    var stagedTracks: [EditorFile] = []
    
    var timelineSong = TimelineSong()
    var playbackError: String?
    var shouldShowError = false
    
    /// Initializer
    init(allSongs: [EditorFile], history: any AudioHistoryStoring) {
        self.allSongs = allSongs
        self.historyStore = history
    }
}
