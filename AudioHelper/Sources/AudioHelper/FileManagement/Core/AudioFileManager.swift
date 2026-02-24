import Foundation

/// Central file manager for page-scoped sandbox directories.
public final class AudioFileManager: AudioFileManaging {
    public let configuration: AudioFileManagerConfiguration

    private let fileManager: FileManager
    // Path helpers are reused inside other locked operations (copy/move destination resolution),
    // so this lock must support same-thread reentrancy to avoid deadlocks.
    private let lock = NSRecursiveLock()

    public init(
        configuration: AudioFileManagerConfiguration = .init(),
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
    }

    /// Convenience accessor for the default location.
    public subscript(namespace: AudioFileNamespace) -> any AudioPageFileStoring {
        page(namespace, location: nil)
    }

    /// Returns a file store tied to a page namespace.
    public func page(
        _ namespace: AudioFileNamespace,
        location: AudioFileLocation? = nil
    ) -> any AudioPageFileStoring {
        AudioPageFileStore(
            manager: self,
            namespace: namespace,
            location: location ?? configuration.defaultLocation
        )
    }

    /// Creates page directories up-front.
    public func preparePages(
        _ namespaces: [AudioFileNamespace],
        location: AudioFileLocation? = nil
    ) throws {
        let selectedLocation = location ?? configuration.defaultLocation
        for namespace in namespaces {
            _ = try directoryURL(for: namespace, location: selectedLocation)
        }
    }

    func directoryURL(
        for namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws -> URL {
        try withLock {
            let safeContainer = try sanitizePathComponent(
                configuration.containerFolderName,
                label: "container folder name"
            )
            let safeNamespace = try sanitizePathComponent(namespace.rawValue, label: "namespace")

            let root = try rootDirectory(for: location)
            let container = root.appendingPathComponent(safeContainer, isDirectory: true)
            try createDirectoryIfNeeded(at: container)

            let pageDirectory = container.appendingPathComponent(safeNamespace, isDirectory: true)
            try createDirectoryIfNeeded(at: pageDirectory)
            return pageDirectory
        }
    }

    func fileURL(
        named fileName: String,
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws -> URL {
        let safeFileName = try sanitizePathComponent(fileName, label: "file name")
        let directory = try directoryURL(for: namespace, location: location)
        return directory.appendingPathComponent(safeFileName, isDirectory: false)
    }

    func listFiles(
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws -> [URL] {
        let directory = try directoryURL(for: namespace, location: location)
        return try withLock {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            // Keep results deterministic for UI/state updates.
            return contents.sorted { lhs, rhs in
                lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
            }
        }
    }

    func containsFile(
        named fileName: String,
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws -> Bool {
        let target = try fileURL(named: fileName, namespace: namespace, location: location)
        return withLock {
            fileManager.fileExists(atPath: target.path)
        }
    }

    func existingFileURL(
        named fileName: String,
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws -> URL? {
        let target = try fileURL(named: fileName, namespace: namespace, location: location)
        return withLock {
            fileManager.fileExists(atPath: target.path) ? target : nil
        }
    }

    func copyItemIn(
        from sourceURL: URL,
        preferredName: String?,
        duplicatePolicy: AudioFileDuplicatePolicy,
        namespace: AudioFileNamespace,
        location: AudioFileLocation,
        securityScoped: Bool
    ) throws -> URL {
        try withSecurityScopeIfNeeded(for: sourceURL, required: securityScoped) {
            try withLock {
                guard fileManager.fileExists(atPath: sourceURL.path) else {
                    throw AudioFileManagerError.sourceFileMissing(sourceURL)
                }

                let name = preferredName ?? sourceURL.lastPathComponent
                let destination = try resolvedDestination(
                    for: name,
                    duplicatePolicy: duplicatePolicy,
                    namespace: namespace,
                    location: location
                )
                try fileManager.copyItem(at: sourceURL, to: destination)
                return destination
            }
        }
    }

    func moveItemIn(
        from sourceURL: URL,
        preferredName: String?,
        duplicatePolicy: AudioFileDuplicatePolicy,
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws -> URL {
        try withLock {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw AudioFileManagerError.sourceFileMissing(sourceURL)
            }

            let name = preferredName ?? sourceURL.lastPathComponent
            let destination = try resolvedDestination(
                for: name,
                duplicatePolicy: duplicatePolicy,
                namespace: namespace,
                location: location
            )

            do {
                try fileManager.moveItem(at: sourceURL, to: destination)
            } catch {
                // Fallback for cross-volume moves.
                try fileManager.copyItem(at: sourceURL, to: destination)
                try fileManager.removeItem(at: sourceURL)
            }
            return destination
        }
    }

    func removeFile(
        named fileName: String,
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws {
        let target = try fileURL(named: fileName, namespace: namespace, location: location)
        try withLock {
            guard fileManager.fileExists(atPath: target.path) else { return }
            try fileManager.removeItem(at: target)
        }
    }

    func removeFile(
        at fileURL: URL,
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws {
        let directoryComponents = try directoryURL(for: namespace, location: location)
            .resolvingSymlinksInPath()
            .standardized
            .pathComponents
        let targetComponents = fileURL
            .resolvingSymlinksInPath()
            .standardized
            .pathComponents

        guard targetComponents.starts(with: directoryComponents) else {
            throw AudioFileManagerError.invalidPathComponent(
                value: fileURL.path,
                label: "file URL outside namespace"
            )
        }

        try withLock {
            guard fileManager.fileExists(atPath: fileURL.path) else { return }
            try fileManager.removeItem(at: fileURL)
        }
    }

    func clearDirectory(
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws {
        let directory = try directoryURL(for: namespace, location: location)
        try withLock {
            let urls = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for url in urls {
                try fileManager.removeItem(at: url)
            }
        }
    }

    func subdirectoryURL(
        named name: String,
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws -> URL {
        let safeName = try sanitizePathComponent(name, label: "subdirectory name")
        let directory = try directoryURL(for: namespace, location: location)
        let subdirectory = directory.appendingPathComponent(safeName, isDirectory: true)
        try withLock {
            try createDirectoryIfNeeded(at: subdirectory)
        }
        return subdirectory
    }

    func uniqueFileURL(
        for fileName: String,
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws -> URL {
        let safeName = try sanitizePathComponent(fileName, label: "file name")
        let directory = try directoryURL(for: namespace, location: location)
        return withLock {
            uniquifiedURL(
                in: directory,
                fileName: safeName
            )
        }
    }

    private func resolvedDestination(
        for fileName: String,
        duplicatePolicy: AudioFileDuplicatePolicy,
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) throws -> URL {
        let safeName = try sanitizePathComponent(fileName, label: "file name")
        let baseDestination = try fileURL(
            named: safeName,
            namespace: namespace,
            location: location
        )

        let exists = fileManager.fileExists(atPath: baseDestination.path)
        guard exists else { return baseDestination }

        switch duplicatePolicy {
        case .fail:
            throw AudioFileManagerError.destinationFileExists(baseDestination)
        case .replace:
            try fileManager.removeItem(at: baseDestination)
            return baseDestination
        case .uniquify:
            return uniquifiedURL(
                in: baseDestination.deletingLastPathComponent(),
                fileName: safeName
            )
        }
    }

    private func uniquifiedURL(in directory: URL, fileName: String) -> URL {
        let originalURL = directory.appendingPathComponent(fileName, isDirectory: false)
        guard fileManager.fileExists(atPath: originalURL.path) else {
            return originalURL
        }

        let originalExtension = originalURL.pathExtension
        let originalBaseName = originalURL.deletingPathExtension().lastPathComponent

        var index = 1
        while true {
            let candidateName: String
            if originalExtension.isEmpty {
                candidateName = "\(originalBaseName)-\(index)"
            } else {
                candidateName = "\(originalBaseName)-\(index).\(originalExtension)"
            }

            let candidate = directory.appendingPathComponent(candidateName, isDirectory: false)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private func createDirectoryIfNeeded(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    private func rootDirectory(for location: AudioFileLocation) throws -> URL {
        switch location {
        case .applicationSupport:
            return try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        case .caches:
            return try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        case .documents:
            return try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        case .temporary:
            return fileManager.temporaryDirectory
        }
    }

    private func sanitizePathComponent(_ value: String, label: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AudioFileManagerError.invalidPathComponent(value: value, label: label)
        }
        guard trimmed != "." && trimmed != ".." else {
            throw AudioFileManagerError.invalidPathComponent(value: value, label: label)
        }
        guard !trimmed.contains("/") else {
            throw AudioFileManagerError.invalidPathComponent(value: value, label: label)
        }
        return trimmed
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func withSecurityScopeIfNeeded<T>(
        for url: URL,
        required: Bool,
        _ body: () throws -> T
    ) throws -> T {
        guard required else { return try body() }

        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try body()
    }
}
