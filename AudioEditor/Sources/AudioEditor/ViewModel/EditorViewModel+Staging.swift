//
//  EditorViewModel+Staging.swift
//  ComfyAudio
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
        /// this way we only remove 1 item
        for i in 0..<self.stagedTracks.count {
            if self.stagedTracks[i].id == item.id {
                self.stagedTracks.remove(at: i)
                return
            }
        }
    }
}
