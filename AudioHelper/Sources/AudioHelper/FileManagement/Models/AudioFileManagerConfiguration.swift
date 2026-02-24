import Foundation

/// Configuration for `AudioFileManager`.
public struct AudioFileManagerConfiguration: Sendable {
    /// Folder placed inside the selected `AudioFileLocation`.
    public var containerFolderName: String
    /// Location used when callers do not pass a specific location.
    public var defaultLocation: AudioFileLocation

    public init(
        containerFolderName: String = "AudioHelper",
        defaultLocation: AudioFileLocation = .applicationSupport
    ) {
        self.containerFolderName = containerFolderName
        self.defaultLocation = defaultLocation
    }
}
