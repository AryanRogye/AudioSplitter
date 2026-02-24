import Foundation
import SwiftUI
import YoutubeDL
import PythonKit

@MainActor
final class CaptureBox: Sendable {
    var latestFilename: String? = nil
}

@MainActor
public final class DownloaderViewModel: ObservableObject {
    @Published public var urlString: String = ""
    @Published public var isDownloading: Bool = false
    @Published public var statusMessage: String = "Paste a YouTube link to start"
    @Published public var downloadedFiles: [URL] = []
    @Published public var downloadLogs: [String] = []
    @Published public var selectedFileForConversion: URL?

    private let ydl = YoutubeDL()
    private let maxVisibleLogLines = 200
    private let supportedDownloadExtensions: Set<String> = [
        "aac", "flac", "m4a", "m4b", "mp3", "mp4", "ogg", "oga", "opus", "wav", "webm"
    ]

    public init() {}

    public func onAppear() {
        refreshFiles()
    }

    @MainActor
    public func startDownloadTapped() {
        Task { await downloadSong() }
    }

    public func clearLogs() {
        downloadLogs.removeAll()
    }

    public func deleteFile(at offsets: IndexSet) {
        offsets.forEach { index in
            try? FileManager.default.removeItem(at: downloadedFiles[index])
        }
        refreshFiles()
    }

    public func downloadSong() async {
        guard !isDownloading else { return }

        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let userURL = URL(string: trimmedURL) else {
            statusMessage = "Please enter a valid URL."
            appendLog("Invalid URL input: \(trimmedURL)")
            return
        }

        let url = normalizedVideoURL(from: userURL)
        if url.absoluteString != userURL.absoluteString {
            appendLog("Normalized URL to single video: \(url.absoluteString)")
        }

        isDownloading = true
        statusMessage = "Starting download..."
        appendLog("Preparing download for \(url.absoluteString)")

        do {
            try await YoutubeDL.downloadPythonModule()
            appendLog("yt-dlp module ready")
            statusMessage = "Downloading..."

            let downloadedURL = try await downloadViaYtDlp(url: url)

            statusMessage = "Finalizing file..."
            let confirmedURL = await waitForFile(at: downloadedURL)
            refreshFiles(preferred: confirmedURL ?? downloadedURL)

            if confirmedURL != nil {
                statusMessage = "Download Successful!"
                appendLog("Saved: \(downloadedURL.lastPathComponent)")
            } else {
                statusMessage = "Download finished, but file is still syncing. Try refresh in a moment."
                appendLog("Download finished but file sync is delayed: \(downloadedURL.lastPathComponent)")
            }

            isDownloading = false
            urlString = ""
        } catch {
            if let error = error as? YoutubeDLError, case .canceled = error {
                statusMessage = "Error: No compatible progressive format found for this video."
                appendLog("No compatible progressive format found")
            } else {
                statusMessage = "Error: \(error.localizedDescription)"
                appendLog("Download failed: \(error.localizedDescription)")
            }
            isDownloading = false
        }
    }

    public func refreshFiles(preferred: URL? = nil) {
        let fileManager = FileManager.default

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

        var searchPaths: [URL] = [
            ydl.downloadsDirectory,
            appSupport.appendingPathComponent("Downloads"),
            documents.appendingPathComponent("Downloads"),
            documents
        ]

        if let preferred {
            searchPaths.insert(preferred.deletingLastPathComponent(), at: 0)
        }

        var foundFiles: [URL] = []

        for path in searchPaths {
            if let enumerator = fileManager.enumerator(
                at: path,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                for case let fileURL as URL in enumerator {
                    if isSupportedDownloadFile(fileURL) {
                        foundFiles.append(fileURL)
                    }
                }
            }
        }

        if let preferred, fileManager.fileExists(atPath: preferred.path), !foundFiles.contains(preferred) {
            foundFiles.append(preferred)
        }

        downloadedFiles = Array(Set(foundFiles)).sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    private func isSupportedDownloadFile(_ fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        if supportedDownloadExtensions.contains(ext) { return true }

        let stem = fileURL.deletingPathExtension().lastPathComponent.lowercased()
        return stem.contains("-audioonly")
    }

    private func waitForFile(at url: URL, attempts: Int = 12, delayNs: UInt64 = 250_000_000) async -> URL? {
        let fileManager = FileManager.default

        for _ in 0..<attempts {
            if fileManager.fileExists(atPath: url.path),
               let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
               (values.fileSize ?? 0) > 0 {
                return url
            }
            try? await Task.sleep(nanoseconds: delayNs)
        }

        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func downloadViaYtDlp(url: URL) async throws -> URL {
        let outputDirectory = ydl.downloadsDirectory
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let startDate = Date()

        let capture = CaptureBox()

        let args = [
            "--no-playlist",
            "--no-check-certificates",
            "-f", "bestaudio[ext=m4a]/bestaudio/best",
            "-P", outputDirectory.path,
            "-o", "%(title).40s.%(ext)s",
            url.absoluteString
        ]

        appendLog("Starting yt-dlp direct mode")

        try await yt_dlp(
            argv: args,
            progress: { @Sendable dict in
                guard let status = dict["status"].flatMap({ String($0) }) else { return }

                if let filename = dict["filename"].flatMap({ String($0) }), !filename.isEmpty {
                    Task { @MainActor in
                        capture.latestFilename = filename
                    }
                }

                if status == "finished" {
                    Task { @MainActor in
                        self.appendLog("Download finished, processing output...")
                    }
                }
            },
            log: { @Sendable level, message in
                guard level == "warning" || level == "error" else { return }
                let levelStr = String(level)
                let messageStr = String(message)
                Task { @MainActor in
                    self.appendLog("[\(levelStr.uppercased())] \(messageStr)")
                }
            }
        )

        if let latestFilename = capture.latestFilename {
            let candidate = URL(fileURLWithPath: latestFilename)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        if let fallback = newestDownloadedFile(in: outputDirectory, after: startDate) {
            return fallback
        }

        throw DownloadFlowError.outputNotFound
    }

    private func newestDownloadedFile(in directory: URL, after startDate: Date) -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        var newestURL: URL?
        var newestDate: Date = startDate

        for case let fileURL as URL in enumerator {
            guard isSupportedDownloadFile(fileURL) else { continue }
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate else { continue }

            if modified >= newestDate {
                newestDate = modified
                newestURL = fileURL
            }
        }

        return newestURL
    }

    private func normalizedVideoURL(from url: URL) -> URL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased() else { return url }

        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            let videoID = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !videoID.isEmpty else { return url }
            var normalized = URLComponents()
            normalized.scheme = "https"
            normalized.host = "www.youtube.com"
            normalized.path = "/watch"
            normalized.queryItems = [URLQueryItem(name: "v", value: videoID)]
            return normalized.url ?? url
        }

        guard host.contains("youtube.com") else { return url }

        if components.path == "/watch",
           let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value,
           !videoID.isEmpty {
            var normalized = URLComponents()
            normalized.scheme = "https"
            normalized.host = "www.youtube.com"
            normalized.path = "/watch"
            normalized.queryItems = [URLQueryItem(name: "v", value: videoID)]
            return normalized.url ?? url
        }

        if components.path.hasPrefix("/shorts/") {
            let videoID = components.path.replacingOccurrences(of: "/shorts/", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !videoID.isEmpty else { return url }
            var normalized = URLComponents()
            normalized.scheme = "https"
            normalized.host = "www.youtube.com"
            normalized.path = "/watch"
            normalized.queryItems = [URLQueryItem(name: "v", value: videoID)]
            return normalized.url ?? url
        }

        return url
    }

    private func appendLog(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        downloadLogs.append("[\(timestamp)] \(message)")
        if downloadLogs.count > maxVisibleLogLines {
            downloadLogs.removeFirst(downloadLogs.count - maxVisibleLogLines)
        }
    }
}

private enum DownloadFlowError: LocalizedError {
    case outputNotFound

    var errorDescription: String? {
        switch self {
        case .outputNotFound:
            return "Download finished but output file was not found."
        }
    }
}
