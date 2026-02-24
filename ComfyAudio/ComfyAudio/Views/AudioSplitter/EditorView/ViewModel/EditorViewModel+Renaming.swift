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
        renameItem(id: item.id, newName: newName)
    }

    internal func renameItem(id: UUID, newName: String?) {
        guard let item = allSongs.first(where: { $0.id == id }) else { return }
        guard let targetName = resolvedFilename(from: newName, currentURL: item.url) else { return }

        let sourceURL = item.url
        let directory = sourceURL.deletingLastPathComponent()

        do {
            let destinationURL = uniqueDestinationURL(
                in: directory,
                sourceURL: sourceURL,
                desiredFileName: targetName
            )

            if destinationURL.path != sourceURL.path {
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            }

            let renamed = EditorFile(
                destinationURL,
                id: item.id,
                name: destinationURL.lastPathComponent,
                created: item.createdAt,
                type: item.type
            )

            allSongs = allSongs.map { $0.id == id ? renamed : $0 }
            syncStagedTrackNames()
            timelineSong.replaceAsset(renamed)
        } catch {
            print("Rename failed for \(sourceURL.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func resolvedFilename(from newName: String?, currentURL: URL) -> String? {
        guard let newName else { return nil }

        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let sanitized = trimmed
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return nil }

        let baseName = (sanitized as NSString)
            .deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseName.isEmpty else { return nil }

        let currentExtension = currentURL.pathExtension
        if currentExtension.isEmpty {
            return baseName
        }

        return "\(baseName).\(currentExtension)"
    }

    private func uniqueDestinationURL(
        in directory: URL,
        sourceURL: URL,
        desiredFileName: String
    ) -> URL {
        let fileManager = FileManager.default
        let requested = directory.appendingPathComponent(desiredFileName, isDirectory: false)

        if requested.path == sourceURL.path || !fileManager.fileExists(atPath: requested.path) {
            return requested
        }

        let baseName = requested.deletingPathExtension().lastPathComponent
        let ext = requested.pathExtension

        var index = 1
        while true {
            let candidateName: String
            if ext.isEmpty {
                candidateName = "\(baseName)-\(index)"
            } else {
                candidateName = "\(baseName)-\(index).\(ext)"
            }

            let candidate = directory.appendingPathComponent(candidateName, isDirectory: false)
            if candidate.path == sourceURL.path || !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
    
    /**
     * Keeps staged entries in sync with renamed file metadata from allSongs.
     */
    internal func syncStagedTrackNames() {
        let latestByID = Dictionary(uniqueKeysWithValues: allSongs.map { ($0.id, $0) })
        stagedTracks = stagedTracks.map { latestByID[$0.id] ?? $0 }
    }
}
