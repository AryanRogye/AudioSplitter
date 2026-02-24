//
//  EditorViewModel+Staging.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/13/26.
//

import Foundation

// MARK: - Staging Creation/Deletion
extension EditorViewModel {
    /// We can add multiple of the same tracks so this is ok
    public func addToStaged(_ item: EditorFile) {
        self.stagedTracks.append(item)
    }
    /// Removing Items from staging
    public func removeFromStaged(_ item: EditorFile) {
        self.stagedTracks.removeAll(where: { $0.id == item.id })
    }
}
