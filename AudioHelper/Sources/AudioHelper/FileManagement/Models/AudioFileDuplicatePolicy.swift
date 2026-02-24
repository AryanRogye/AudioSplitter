import Foundation

/// Controls what happens when a destination file already exists.
public enum AudioFileDuplicatePolicy: Sendable {
    case fail
    case replace
    case uniquify
}
