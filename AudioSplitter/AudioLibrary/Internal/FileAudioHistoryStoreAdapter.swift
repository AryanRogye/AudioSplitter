import Foundation

final class FileAudioHistoryStoreAdapter: AudioHistoryStoring {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadHistory() throws -> [ProcessedTrackHistoryItem] {
        try ensureBaseDirectories()

        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return []
        }

        let data = try Data(contentsOf: manifestURL)
        let decoded = try decoder.decode([ProcessedTrackHistoryItem].self, from: data)
        let repaired = repairHistoryPathsIfPossible(decoded)

        if repaired != decoded {
            try writeHistory(repaired)
        }

        return repaired.sorted { $0.createdAt > $1.createdAt }
    }

    func loadSavedLayeredMixes() throws -> [SavedLayeredMix] {
        try ensureBaseDirectories()

        guard fileManager.fileExists(atPath: mixesManifestURL.path) else {
            return []
        }

        let data = try Data(contentsOf: mixesManifestURL)
        let decoded = try decoder.decode([SavedLayeredMix].self, from: data)
        let repaired = decoded.filter { fileManager.fileExists(atPath: $0.fileURL.path) }

        if repaired != decoded {
            try writeSavedMixes(repaired)
        }

        return repaired.sorted { $0.createdAt > $1.createdAt }
    }

    func saveProcessedTrack(
        sourceURL: URL,
        stems: [StemFile],
        sourceFingerprint: [Float]
    ) throws -> ProcessedTrackHistoryItem {
        try ensureBaseDirectories()

        var history = try loadHistory()
        let entryID = UUID()
        let entryDirectory = entriesDirectory.appendingPathComponent(entryID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: entryDirectory, withIntermediateDirectories: true)

        let copiedSourceURL = try copy(
            itemAt: sourceURL,
            toDirectory: entryDirectory,
            preferredName: "source-\(sanitized(sourceURL.lastPathComponent))"
        )

        let copiedStems = try stems.map { stem in
            let stemURL = try copy(
                itemAt: stem.fileURL,
                toDirectory: entryDirectory,
                preferredName: "\(stem.kind.rawValue).\(stem.fileURL.pathExtension.isEmpty ? "wav" : stem.fileURL.pathExtension)"
            )

            return StoredStemAsset(
                id: UUID(),
                kind: stem.kind,
                fileURL: stemURL,
                sourceTrackName: sourceURL.lastPathComponent,
                createdAt: Date(),
                customName: nil
            )
        }

        let entry = ProcessedTrackHistoryItem(
            id: entryID,
            sourceFileName: sourceURL.lastPathComponent,
            sourceFileURL: copiedSourceURL,
            createdAt: Date(),
            sourceFingerprint: sourceFingerprint,
            stems: copiedStems,
            customName: nil
        )

        history.insert(entry, at: 0)
        try writeHistory(history)
        return entry
    }

    func saveLayeredMix(
        from exportedFileURL: URL,
        vocalName: String,
        instrumentalName: String,
        delaySeconds: Double
    ) throws -> SavedLayeredMix {
        try ensureBaseDirectories()

        var mixes = try loadSavedLayeredMixes()
        let mixID = UUID()

        let fileExtension = exportedFileURL.pathExtension.isEmpty ? "m4a" : exportedFileURL.pathExtension
        let destinationURL = mixesDirectory
            .appendingPathComponent("mix-\(mixID.uuidString)")
            .appendingPathExtension(fileExtension)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: exportedFileURL, to: destinationURL)

        let mix = SavedLayeredMix(
            id: mixID,
            fileURL: destinationURL,
            createdAt: Date(),
            vocalName: vocalName,
            instrumentalName: instrumentalName,
            delaySeconds: delaySeconds
        )

        mixes.insert(mix, at: 0)
        try writeSavedMixes(mixes)
        return mix
    }

    func renameHistoryItem(id: UUID, newName: String?) throws {
        var history = try loadHistory()
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }

        history[index].customName = normalizedName(newName)
        try writeHistory(history)
    }

    func renameStemAsset(id: UUID, newName: String?) throws {
        var history = try loadHistory()

        for entryIndex in history.indices {
            guard let stemIndex = history[entryIndex].stems.firstIndex(where: { $0.id == id }) else {
                continue
            }

            history[entryIndex].stems[stemIndex].customName = normalizedName(newName)
            try writeHistory(history)
            return
        }
    }

    func deleteHistoryItem(id: UUID) throws {
        var history = try loadHistory()
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }

        history.remove(at: index)
        try writeHistory(history)

        let entryDirectory = entriesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: entryDirectory.path) {
            try fileManager.removeItem(at: entryDirectory)
        }
    }

    func deleteSavedLayeredMix(id: UUID) throws {
        var mixes = try loadSavedLayeredMixes()
        guard let index = mixes.firstIndex(where: { $0.id == id }) else { return }

        let mix = mixes.remove(at: index)
        try writeSavedMixes(mixes)

        if fileManager.fileExists(atPath: mix.fileURL.path) {
            try fileManager.removeItem(at: mix.fileURL)
        }
    }

    private func writeHistory(_ entries: [ProcessedTrackHistoryItem]) throws {
        let data = try encoder.encode(entries)
        try data.write(to: manifestURL, options: .atomic)
    }

    private func writeSavedMixes(_ mixes: [SavedLayeredMix]) throws {
        let data = try encoder.encode(mixes)
        try data.write(to: mixesManifestURL, options: .atomic)
    }

    private func ensureBaseDirectories() throws {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: entriesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: mixesDirectory, withIntermediateDirectories: true)
    }

    private func copy(itemAt sourceURL: URL, toDirectory directory: URL, preferredName: String) throws -> URL {
        let targetURL = directory.appendingPathComponent(preferredName)

        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }

        try fileManager.copyItem(at: sourceURL, to: targetURL)
        return targetURL
    }

    private func sanitized(_ fileName: String) -> String {
        let forbidden = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return fileName
            .components(separatedBy: forbidden)
            .joined(separator: "-")
    }

    private func normalizedName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func repairHistoryPathsIfPossible(_ items: [ProcessedTrackHistoryItem]) -> [ProcessedTrackHistoryItem] {
        items.map { item in
            var repaired = item
            let entryDirectory = entriesDirectory.appendingPathComponent(item.id.uuidString, isDirectory: true)

            if !fileManager.fileExists(atPath: repaired.sourceFileURL.path),
               let sourceURL = resolveSourceURL(for: repaired, entryDirectory: entryDirectory) {
                repaired.sourceFileURL = sourceURL
            }

            repaired.stems = repaired.stems.map { stem in
                var repairedStem = stem

                if !fileManager.fileExists(atPath: repairedStem.fileURL.path),
                   let stemURL = resolveStemURL(for: repairedStem, entryDirectory: entryDirectory) {
                    repairedStem.fileURL = stemURL
                }

                return repairedStem
            }

            return repaired
        }
    }

    private func resolveSourceURL(
        for entry: ProcessedTrackHistoryItem,
        entryDirectory: URL
    ) -> URL? {
        let expected = entryDirectory.appendingPathComponent("source-\(sanitized(entry.sourceFileName))")
        if fileManager.fileExists(atPath: expected.path) {
            return expected
        }

        if let fallback = firstFile(
            in: entryDirectory,
            where: { $0.lastPathComponent.hasPrefix("source-") }
        ) {
            return fallback
        }

        return nil
    }

    private func resolveStemURL(
        for stem: StoredStemAsset,
        entryDirectory: URL
    ) -> URL? {
        let preferredExtension = stem.fileURL.pathExtension.isEmpty ? "wav" : stem.fileURL.pathExtension
        let expected = entryDirectory.appendingPathComponent("\(stem.kind.rawValue).\(preferredExtension)")
        if fileManager.fileExists(atPath: expected.path) {
            return expected
        }

        if let entryDirectoryMatch = firstFile(
            in: entryDirectory,
            where: { file in
                file.deletingPathExtension().lastPathComponent == stem.kind.rawValue
            }
        ) {
            return entryDirectoryMatch
        }

        let separatedStemsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SeparatedStems", isDirectory: true)

        if let legacyMatch = firstFile(
            in: separatedStemsDirectory,
            where: { file in
                file.lastPathComponent == stem.fileURL.lastPathComponent
            }
        ) {
            return legacyMatch
        }

        return nil
    }

    private func firstFile(in directory: URL, where predicate: (URL) -> Bool) -> URL? {
        guard fileManager.fileExists(atPath: directory.path) else { return nil }

        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let next = enumerator?.nextObject() as? URL {
            guard let isRegularFile = try? next.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                  isRegularFile == true else {
                continue
            }

            if predicate(next) {
                return next
            }
        }

        return nil
    }

    private var baseDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioLibrary", isDirectory: true)
    }

    private var entriesDirectory: URL {
        baseDirectory.appendingPathComponent("Entries", isDirectory: true)
    }

    private var mixesDirectory: URL {
        baseDirectory.appendingPathComponent("Mixes", isDirectory: true)
    }

    private var manifestURL: URL {
        baseDirectory.appendingPathComponent("history.json")
    }

    private var mixesManifestURL: URL {
        baseDirectory.appendingPathComponent("mixes.json")
    }
}
