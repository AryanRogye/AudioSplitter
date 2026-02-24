import Foundation
import SwiftUI
import YoutubeDL
import PythonKit
import PythonSupport

@_silgen_name("_PyImport_IsInitialized")
private func _PyImport_IsInitialized() -> Int32

@_silgen_name("PyCMethod_New")
private func _PyCMethod_New(
    _ methodDef: UnsafeMutableRawPointer?,
    _ selfObject: UnsafeMutableRawPointer?,
    _ module: UnsafeMutableRawPointer?,
    _ cls: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer?

@_silgen_name("PyMethod_New")
private func _PyMethod_New(
    _ function: UnsafeMutableRawPointer?,
    _ selfObject: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer?

// YoutubeDL-iOS resolves `Py_IsInitialized` using `dlsym`. In Release, that
// symbol is missing by default, which makes the resolved function pointer nil.
// Exporting this shim keeps the lookup valid and prevents a null jump at runtime.
@_cdecl("Py_IsInitialized")
public func audioHelperPyIsInitializedShim() -> Int32 {
    _PyImport_IsInitialized()
}

// PythonKit lazily loads these symbols with `dlsym`. Python-iOS on iOS 26 only
// exports adjacent APIs, so we forward these calls to equivalent exported APIs.
@_cdecl("PyCFunction_NewEx")
public func audioHelperPyCFunctionNewExShim(
    _ methodDef: UnsafeMutableRawPointer?,
    _ selfObject: UnsafeMutableRawPointer?,
    _ module: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer? {
    _PyCMethod_New(methodDef, selfObject, module, nil)
}

@_cdecl("PyInstanceMethod_New")
public func audioHelperPyInstanceMethodNewShim(
    _ function: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer? {
    _PyMethod_New(function, nil)
}

@MainActor
final class CaptureBox: Sendable {
    var latestFilename: String? = nil
}

private actor DownloadProgressTracker {
    private var lastStatus: String?
    private var lastFilename: String?
    private var lastProgressStep: Int = -1

    func consume(
        status: String,
        filename: String?,
        percentText: String?,
        speedText: String?,
        etaText: String?
    ) -> (messages: [String], progressLabel: String?) {
        var messages: [String] = []
        var progressLabel: String?

        if let filename, !filename.isEmpty, filename != lastFilename {
            lastFilename = filename
            messages.append("Output: \(URL(fileURLWithPath: filename).lastPathComponent)")
        }

        if status != lastStatus {
            lastStatus = status
            switch status {
            case "downloading":
                messages.append("Download started")
            case "finished":
                messages.append("Download finished, processing output...")
            case "error":
                messages.append("yt-dlp reported an error state")
            default:
                messages.append("yt-dlp status: \(status)")
            }
        }

        if status == "downloading", let percent = parsePercent(percentText) {
            let step = max(0, min(100, (Int(percent) / 10) * 10))
            if step > lastProgressStep {
                lastProgressStep = step
                let speed = speedText?.trimmingCharacters(in: .whitespacesAndNewlines)
                let eta = etaText?.trimmingCharacters(in: .whitespacesAndNewlines)
                var extras: [String] = []
                if let speed, !speed.isEmpty { extras.append(speed) }
                if let eta, !eta.isEmpty { extras.append("ETA \(eta)") }
                let suffix = extras.isEmpty ? "" : " (\(extras.joined(separator: ", ")))"
                messages.append("Progress \(step)%\(suffix)")
            }
            progressLabel = "Downloading... \(Int(percent))%"
        }

        return (messages, progressLabel)
    }

    private func parsePercent(_ percentText: String?) -> Double? {
        guard let percentText else { return nil }
        let filtered = percentText.filter { $0.isNumber || $0 == "." }
        guard !filtered.isEmpty else { return nil }
        return Double(filtered)
    }
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
    private var didConfigureBundledYtDlp = false

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
        let baselineFileCount = downloadedFiles.count

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
            try configureBundledYtDlpIfNeeded()
            appendLog("yt-dlp module ready (bundled)")
            statusMessage = "Downloading..."

            let downloadedURL = try await downloadViaYtDlp(url: url)

            statusMessage = "Finalizing file..."
            let confirmedURL = await waitForFile(at: downloadedURL)
            let preferredURL = confirmedURL ?? downloadedURL
            let listUpdated = await refreshFilesUntilVisible(
                preferred: preferredURL,
                baselineCount: baselineFileCount
            )

            if confirmedURL != nil && listUpdated {
                statusMessage = "Download Successful!"
                appendLog("Saved: \(downloadedURL.lastPathComponent)")
            } else if confirmedURL != nil {
                statusMessage = "Download successful, list is syncing..."
                appendLog("Download saved, waiting for list sync: \(downloadedURL.lastPathComponent)")
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
    
    private func configureBundledYtDlpIfNeeded() throws {
        guard !didConfigureBundledYtDlp else { return }
        guard let bundledModuleURL = Bundle.module.url(forResource: "yt_dlp", withExtension: nil) else {
            throw DownloadFlowError.bundledModuleMissing
        }
        
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw DownloadFlowError.bundledModuleInstallFailed
        }
        
        let destinationDirectory = appSupport.appendingPathComponent("io.github.kewlbear.youtubedl-ios", isDirectory: true)
        let destinationURL = destinationDirectory.appendingPathComponent("yt_dlp")
        
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: bundledModuleURL, to: destinationURL)
        
        PythonSupport.initialize()
        PythonSupport.runSimpleString("""
            import sys, types
            if 'ctypes' not in sys.modules:
                sys.modules['ctypes'] = types.ModuleType('ctypes')
            """)
        
        didConfigureBundledYtDlp = true
        appendLog("Using bundled yt-dlp module")
    }

    private func refreshFilesUntilVisible(
        preferred: URL?,
        baselineCount: Int,
        attempts: Int = 10,
        delayNs: UInt64 = 400_000_000
    ) async -> Bool {
        for attempt in 0..<attempts {
            refreshFiles(preferred: preferred)

            if let preferred, downloadedFiles.contains(preferred) {
                return true
            }
            if downloadedFiles.count > baselineCount {
                return true
            }

            if attempt < attempts - 1 {
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
        return false
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
        let progressTracker = DownloadProgressTracker()

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
                let filename = dict["filename"].flatMap({ String($0) })
                let percentText = dict["_percent_str"].flatMap({ String($0) })
                let speedText = dict["_speed_str"].flatMap({ String($0) })
                let etaText = dict["_eta_str"].flatMap({ String($0) })

                Task {
                    let update = await progressTracker.consume(
                        status: status,
                        filename: filename,
                        percentText: percentText,
                        speedText: speedText,
                        etaText: etaText
                    )

                    await MainActor.run {
                        if let filename, !filename.isEmpty {
                            capture.latestFilename = filename
                        }
                        if let progressLabel = update.progressLabel {
                            self.statusMessage = progressLabel
                        }
                        for message in update.messages {
                            self.appendLog(message)
                        }
                    }
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
    case bundledModuleMissing
    case bundledModuleInstallFailed

    var errorDescription: String? {
        switch self {
        case .outputNotFound:
            return "Download finished but output file was not found."
        case .bundledModuleMissing:
            return "Bundled yt-dlp module is missing from AudioHelper resources."
        case .bundledModuleInstallFailed:
            return "Unable to prepare bundled yt-dlp module in Application Support."
        }
    }
}
