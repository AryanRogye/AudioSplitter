import Foundation

/// Errors emitted by `AudioFileManager` and `AudioPageFileStore`.
public enum AudioFileManagerError: LocalizedError {
    case invalidPathComponent(value: String, label: String)
    case sourceFileMissing(URL)
    case destinationFileExists(URL)

    public var errorDescription: String? {
        switch self {
        case .invalidPathComponent(let value, let label):
            return "Invalid \(label): \(value)"
        case .sourceFileMissing(let url):
            return "Source file is missing: \(url.path)"
        case .destinationFileExists(let url):
            return "Destination file already exists: \(url.path)"
        }
    }
}
