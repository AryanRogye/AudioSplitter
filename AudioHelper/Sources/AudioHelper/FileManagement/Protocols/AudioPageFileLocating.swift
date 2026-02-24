import Foundation

/**
 Lookup helpers for files in a page namespace directory.
 */
public protocol AudioPageFileLocating {
    /**
     Returns the URL for a file in this namespace when it already exists, otherwise `nil`.
     */
    func existingFileURL(named fileName: String) throws -> URL?
}
