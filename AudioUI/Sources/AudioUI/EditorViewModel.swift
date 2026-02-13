//
//  EditorViewModel.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/11/26.
//

import Foundation
import AudioUI

@Observable
@MainActor
final class EditorViewModel {
    var isRecentsOpen = false
    var historyStore: AudioHistoryStoring
    
    var allSongs: [EditorFile]
    var stagedTracks: [EditorFile] = []
    
    init(allSongs: [EditorFile], history: any AudioHistoryStoring) {
        self.allSongs = allSongs
        self.historyStore = history
    }
    
    func renameHistoryItem(id: UUID, newName: String?) {
        func fileUrls(history: [ProcessedTrackHistoryItem]) -> [EditorFile] {
            var files: [EditorFile] = []
            
            for hist in history {
                
                let editorFile = EditorFile(
                    hist.sourceFileURL,
                    name: hist.displayName,
                    created: hist.createdAt,
                    type: .all
                )
                files.append(editorFile)
                
                for stem in hist.stems {
                    var kind: SongType = stem.kind == .vocals ? .vocal : .instrumental
                    
                    let stemFile = EditorFile(
                        stem.fileURL,
                        name: stem.displayName,
                        created: stem.createdAt,
                        type: kind
                    )
                    files.append(stemFile)
                }
            }
            
            return files
        }
        
        do {
            try historyStore.renameHistoryItem(id: id, newName: newName)
            
            let history = try historyStore.loadHistory()
            allSongs = fileUrls(history: history)
            
        } catch {
            print("There was a error: \(error.localizedDescription)")
        }
    }
    
    
    
    /// We can add multiple of the same tracks so this is ok
    public func addToStaged(_ item: EditorFile) {
        self.stagedTracks.append(item)
    }
    /// Removing Items from staging
    public func removeFromStaged(_ item: EditorFile) {
        self.stagedTracks.removeAll(where: { $0.id == item.id })
    }
}
