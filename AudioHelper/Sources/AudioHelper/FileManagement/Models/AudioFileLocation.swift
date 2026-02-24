import Foundation

/// Represents the top-level sandbox location used by `AudioFileManager`.
public enum AudioFileLocation: Sendable {
    case applicationSupport
    case caches
    case documents
    case temporary
}
