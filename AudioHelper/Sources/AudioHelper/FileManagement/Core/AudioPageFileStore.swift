import Foundation

/// File operations scoped to a single page namespace.
public struct AudioPageFileStore: AudioPageFileStoring {
    public let namespace: AudioFileNamespace
    public let location: AudioFileLocation

    private let manager: AudioFileManager

    init(
        manager: AudioFileManager,
        namespace: AudioFileNamespace,
        location: AudioFileLocation
    ) {
        self.manager = manager
        self.namespace = namespace
        self.location = location
    }

    /// URL of the page directory. The directory is created if needed.
    public func directoryURL() throws -> URL {
        try manager.directoryURL(for: namespace, location: location)
    }

    /// Returns a file URL inside the page directory.
    public func fileURL(named fileName: String) throws -> URL {
        try manager.fileURL(named: fileName, namespace: namespace, location: location)
    }

    /// Returns a unique URL inside the page directory based on the provided name.
    public func uniqueFileURL(for fileName: String) throws -> URL {
        try manager.uniqueFileURL(for: fileName, namespace: namespace, location: location)
    }

    /// Creates a subdirectory under the page directory and returns its URL.
    public func makeSubdirectory(named name: String) throws -> URL {
        try manager.subdirectoryURL(named: name, namespace: namespace, location: location)
    }

    /// Lists files and subdirectories in this page directory.
    public func listFiles() throws -> [URL] {
        try manager.listFiles(namespace: namespace, location: location)
    }

    /// Returns `true` when a file with this name exists in the page directory.
    public func containsFile(named fileName: String) throws -> Bool {
        try manager.containsFile(named: fileName, namespace: namespace, location: location)
    }

    /// Returns this page file URL when it already exists, otherwise `nil`.
    public func existingFileURL(named fileName: String) throws -> URL? {
        try manager.existingFileURL(named: fileName, namespace: namespace, location: location)
    }

    /// Copies a source file into this page directory.
    @discardableResult
    public func copyIn(
        from sourceURL: URL,
        preferredName: String? = nil,
        duplicatePolicy: AudioFileDuplicatePolicy = .uniquify
    ) throws -> URL {
        try manager.copyItemIn(
            from: sourceURL,
            preferredName: preferredName,
            duplicatePolicy: duplicatePolicy,
            namespace: namespace,
            location: location,
            securityScoped: false
        )
    }

    /// Imports a potentially security-scoped file URL into this page directory.
    @discardableResult
    public func importSecurityScoped(
        from sourceURL: URL,
        preferredName: String? = nil,
        duplicatePolicy: AudioFileDuplicatePolicy = .uniquify
    ) throws -> URL {
        try manager.copyItemIn(
            from: sourceURL,
            preferredName: preferredName,
            duplicatePolicy: duplicatePolicy,
            namespace: namespace,
            location: location,
            securityScoped: true
        )
    }

    /// Moves a source file into this page directory.
    @discardableResult
    public func moveIn(
        from sourceURL: URL,
        preferredName: String? = nil,
        duplicatePolicy: AudioFileDuplicatePolicy = .uniquify
    ) throws -> URL {
        try manager.moveItemIn(
            from: sourceURL,
            preferredName: preferredName,
            duplicatePolicy: duplicatePolicy,
            namespace: namespace,
            location: location
        )
    }

    /// Removes a file from this page directory by file name.
    public func removeFile(named fileName: String) throws {
        try manager.removeFile(named: fileName, namespace: namespace, location: location)
    }

    /// Removes a file from this page directory by file URL.
    public func removeFile(at fileURL: URL) throws {
        try manager.removeFile(at: fileURL, namespace: namespace, location: location)
    }

    /// Deletes all files and subdirectories in this page directory.
    public func clear() throws {
        try manager.clearDirectory(namespace: namespace, location: location)
    }
}
