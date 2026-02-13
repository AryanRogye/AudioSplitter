//
//  EditorViewModel+Renaming.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/13/26.
//

import Foundation

/// Handles renaming items in the view
// MARK: - Renaming
extension EditorViewModel {
    
    /// Public API to rename a EditorClip
    public func renameEditorClip(item: EditorFile, newName: String?) {
        if item.type == .all {
            renameItem(id: item.id, newName: newName, isStem: false)
        } else {
            renameItem(id: item.id, newName: newName, isStem: true)
        }
    }

    internal func renameItem(id: UUID, newName: String?, isStem: Bool) {
        do {
            if isStem {
                try historyStore.renameStemAsset(id: id, newName: newName)
            } else {
                try historyStore.renameHistoryItem(id: id, newName: newName)
            }
            
            let history = try historyStore.loadHistory()
            allSongs = fileUrls(history: history)
            syncStagedTrackNames()
        } catch {
            print("There was a error: \(error.localizedDescription)")
        }
    }
    
    private func fileUrls(history: [ProcessedTrackHistoryItem]) -> [EditorFile] {
        var files: [EditorFile] = []
        
        for hist in history {
            
            let editorFile = EditorFile(
                hist.sourceFileURL,
                id: hist.id,
                name: hist.displayName,
                created: hist.createdAt,
                type: .all
            )
            files.append(editorFile)
            
            for stem in hist.stems {
                let kind: SongType = stem.kind == .vocals ? .vocal : .instrumental
                
                let stemFile = EditorFile(
                    stem.fileURL,
                    id: stem.id,
                    name: stem.displayName,
                    created: stem.createdAt,
                    type: kind
                )
                files.append(stemFile)
            }
        }
        
        return files
    }
    
    /**
     * After operations like renaming (see renameItem), allSongs is refreshed from the history store. Calling
     * syncStagedTrackNames ensures that any staged items reflect the latest data (names and any other updated
     * properties), without changing the staged selection itself
     */
    internal func syncStagedTrackNames() {
        let latestByID = Dictionary(uniqueKeysWithValues: allSongs.map { ($0.id, $0) })
        stagedTracks = stagedTracks.map { latestByID[$0.id] ?? $0 }
    }
}
