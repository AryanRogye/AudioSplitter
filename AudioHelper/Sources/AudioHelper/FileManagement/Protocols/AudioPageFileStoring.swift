import Foundation

/**
 Page-scoped file operations for one feature namespace.

 Each conforming store points to a single directory:
 `<root>/<containerFolderName>/<namespace>/`
 */
public protocol AudioPageFileStoring: AudioPageFileLocating {
    /**
     Namespace this store belongs to (for example: `StemSeparation`, `Library`).
     */
    var namespace: AudioFileNamespace { get }

    /**
     Sandbox root location used by this store (`applicationSupport`, `caches`, etc.).
     */
    var location: AudioFileLocation { get }

    /**
     Returns the namespace directory URL, creating it if needed.
     */
    func directoryURL() throws -> URL

    /**
     Returns a file URL inside this namespace directory for a given file name.
     This does not create the file.
     */
    func fileURL(named fileName: String) throws -> URL

    /**
     Returns a non-conflicting file URL for a desired file name.
     If needed, suffixes names like `name-1.ext`, `name-2.ext`, etc.
     */
    func uniqueFileURL(for fileName: String) throws -> URL

    /**
     Creates and returns a subdirectory under this namespace directory.
     */
    func makeSubdirectory(named name: String) throws -> URL

    /**
     Lists non-hidden files/folders in this namespace directory.
     */
    func listFiles() throws -> [URL]

    /**
     Returns `true` if a file with the given name exists in this namespace directory.
     */
    func containsFile(named fileName: String) throws -> Bool

    /**
     Copies a source file into this namespace directory.

     - Parameters:
       - sourceURL: File URL to copy from.
       - preferredName: Optional name to use in destination. If `nil`, source file name is used.
       - duplicatePolicy: Behavior when destination already exists (`fail`, `replace`, `uniquify`).
     */
    func copyIn(
        from sourceURL: URL,
        preferredName: String?,
        duplicatePolicy: AudioFileDuplicatePolicy
    ) throws -> URL

    /**
     Imports a possibly security-scoped URL (for example from `fileImporter`) into this namespace.
     */
    func importSecurityScoped(
        from sourceURL: URL,
        preferredName: String?,
        duplicatePolicy: AudioFileDuplicatePolicy
    ) throws -> URL

    /**
     Moves a source file into this namespace directory.
     */
    func moveIn(
        from sourceURL: URL,
        preferredName: String?,
        duplicatePolicy: AudioFileDuplicatePolicy
    ) throws -> URL

    /**
     Removes a file by name from this namespace directory.
     */
    func removeFile(named fileName: String) throws

    /**
     Removes a file by URL, validating it belongs to this namespace directory.
     */
    func removeFile(at fileURL: URL) throws

    /**
     Deletes all non-hidden files/folders in this namespace directory.
     */
    func clear() throws
}

public extension AudioPageFileStoring {
    /**
     Convenience overload that keeps the source file name.
     */
    @discardableResult
    func copyIn(
        from sourceURL: URL,
        duplicatePolicy: AudioFileDuplicatePolicy = .uniquify
    ) throws -> URL {
        try copyIn(
            from: sourceURL,
            preferredName: nil,
            duplicatePolicy: duplicatePolicy
        )
    }

    /**
     Convenience overload that keeps the source file name for security-scoped imports.
     */
    @discardableResult
    func importSecurityScoped(
        from sourceURL: URL,
        duplicatePolicy: AudioFileDuplicatePolicy = .uniquify
    ) throws -> URL {
        try importSecurityScoped(
            from: sourceURL,
            preferredName: nil,
            duplicatePolicy: duplicatePolicy
        )
    }

    /**
     Convenience overload that keeps the source file name when moving.
     */
    @discardableResult
    func moveIn(
        from sourceURL: URL,
        duplicatePolicy: AudioFileDuplicatePolicy = .uniquify
    ) throws -> URL {
        try moveIn(
            from: sourceURL,
            preferredName: nil,
            duplicatePolicy: duplicatePolicy
        )
    }
}
