//
//  AudioSplitterViewModel.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/23/26.
//

import Foundation
import AudioHelper
import AudioEditor
import AudioPlayback

@Observable
@MainActor
final class AudioSplitterViewModel {
    
    private let files: any AudioFileManaging
    private let store: any AudioPageFileStoring
    
    let playbackController = AVAudioPreviewPlayback()
    private let separator: StemSeparating = CoreMLMDXStemSeparatorAdapter()
    
    var isProcessing: Bool = false
    var selectedFileURL: URL?
    var errorText: String?
    var statusText: String?
    var outputStems: [StemFile] = []
    private(set) var allOutputStems: [StemFile] = []
    private(set) var latestSeparatedStems: [StemFile] = []
    private(set) var latestSeparatedSourceURL: URL?
    var isPaused = true
    private var splitTaskJob: Task<Void, Never>?
    private var splitTask: Task<[StemFile], Error>?
    
    
    init(files: any AudioFileManaging) {
        self.files = files
        self.store = files.page("Separations")
    }
    
    /**
     * This is where the user will first interact with the app,
     * by importing a mp3 file
     */
    func importPickedFile(from sourceURL: URL) {
        do {
            playbackController.stopPreview()
            outputStems = []
            errorText = nil
            allOutputStems = []
            latestSeparatedStems = []
            latestSeparatedSourceURL = nil
            
            let dest = try store.existingFileURL(named: sourceURL.lastPathComponent) ?? store.importSecurityScoped(from: sourceURL)
            selectedFileURL = dest
            
            statusText = "Loaded: \(dest.lastPathComponent)"
        } catch {
            errorText = error.localizedDescription
            statusText = "Import failed"
        }
    }
    
    public func isPlaying(_ url: URL) -> Bool {
        return playbackController.url == url
    }
    
    public func togglePlayback(for url: URL? = nil) {
        guard let audioURL = url ?? selectedFileURL else {
            return
        }
        
        if playbackController.url == audioURL {
            playbackController.stopPreview()
        } else {
            do {
                try playbackController.togglePreview(fileURL: audioURL, startTime: 0, volume: 1.0)
                isPaused = false
            } catch {
                isPaused = true
                errorText = error.localizedDescription
                statusText = "Coudlnt Playback Audio"
            }
        }
    }
    
    public func togglePlayback() {
        if let selectedFileURL {
            if playbackController.isPlaying {
                playbackController.pause()
                isPaused = true
            } else {
                if playbackController.canResume {
                    playbackController.play()
                    isPaused = false
                } else {
                    do {
                        try playbackController.togglePreview(fileURL: selectedFileURL, startTime: 0, volume: 1.0)
                        isPaused = false
                    } catch {
                        isPaused = true
                        errorText = error.localizedDescription
                        statusText = "Coudlnt Playback Audio"
                    }
                }
            }
        }
    }
    
    func splitSelectedFile() async {
        guard let selectedFileURL else {
            errorText = "Please choose an MP3 first."
            return
        }
        cancelSplitTasks()
        
        isProcessing = true
        errorText = nil
        outputStems = []
        allOutputStems = []
        latestSeparatedStems = []
        latestSeparatedSourceURL = nil
        playbackController.stopPreview()
        statusText = "Splitting track..."
        
        let processingURL = selectedFileURL
        let separator = self.separator
        
        splitTaskJob = Task {
            defer {
                splitTask = nil
                splitTaskJob = nil
                isProcessing = false
            }

            do {
                splitTask = Task.detached(priority: .userInitiated) {
                    try separator.separate(fileURL: processingURL)
                }
                if let st = splitTask {
                    let stems = try await st.value
                    allOutputStems = stems
                    outputStems = stems
                    latestSeparatedStems = stems
                    latestSeparatedSourceURL = processingURL
                    statusText = "Created \(stems.count) stems."
                }
            } catch is CancellationError {
                errorText = nil
                statusText = "Split canceled."
                latestSeparatedSourceURL = nil
            } catch {
                errorText = error.localizedDescription
                statusText = "Separation failed"
                latestSeparatedSourceURL = nil
            }
        }
    }

    public func cancelSplit() {
        guard isProcessing else { return }

        cancelSplitTasks()
        isProcessing = false
        errorText = nil
        statusText = "Split canceled."
    }
    
    public func saveStems() {
        guard !outputStems.isEmpty else {
            statusText = "No stems to save. Try splitting an audio file first."
            return
        }
        guard let sourceURL = selectedFileURL else {
            statusText = "Make Sure to load an audio file before saving the stems."
            return
        }

        do {
            /// Extract name
            let folderName = savedStemsFolderName()
            
            /// Create folder
            let destinationFolder = try store.makeSubdirectory(named: folderName)
            
            let fileManager = FileManager.default
            
            /// Copy the old file to the new one
            let originalDestinationURL = destinationFolder.appendingPathComponent(
                sourceURL.lastPathComponent,
                isDirectory: false
            )
            
            if fileManager.fileExists(atPath: originalDestinationURL.path) {
                try fileManager.removeItem(at: originalDestinationURL)
            }
            
            try fileManager.copyItem(at: sourceURL, to: originalDestinationURL)
            
            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            for stem in outputStems {
                let ext = stem.fileURL.pathExtension
                let newFileName = "\(baseName)_\(stem.kind.rawValue).\(ext)"
                
                let destinationURL = destinationFolder.appendingPathComponent(
                    newFileName,
                    isDirectory: false
                )
                
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                
                try fileManager.copyItem(at: stem.fileURL, to: destinationURL)
            }
            errorText = nil
            statusText = "Saved \(outputStems.count) stems to \(folderName)"
        } catch {
            errorText = error.localizedDescription
            statusText = "Save failed"
        }
    }

    private func savedStemsFolderName() -> String {
        let sourceBaseName = (
            latestSeparatedSourceURL?.deletingPathExtension().lastPathComponent
            ?? selectedFileURL?.deletingPathExtension().lastPathComponent
            ?? ""
        )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = sourceBaseName.isEmpty ? "Split" : sourceBaseName
        let suffix = String(UUID().uuidString.prefix(8))
        return "\(baseName)-\(Int(Date().timeIntervalSince1970))-\(suffix)"
    }

    private func cancelSplitTasks() {
        splitTask?.cancel()
        splitTaskJob?.cancel()
        splitTask = nil
        splitTaskJob = nil
    }

    func editorSeedFiles() -> [EditorFile] {
        let fileManager = FileManager.default

        do {
            let topLevelItems = try store.listFiles()
            var files: [EditorFile] = []

            for item in topLevelItems {
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    // Ignore top-level files in Separations (e.g. imported source mp3 files).
                    continue
                }

                let enumerator = fileManager.enumerator(
                    at: item,
                    includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )

                while let next = enumerator?.nextObject() as? URL {
                    guard let values = try? next.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                          values.isRegularFile == true else {
                        continue
                    }

                    let createdAt = values.contentModificationDate ?? Date()
                    files.append(
                        EditorFile(
                            next,
                            name: next.lastPathComponent,
                            created: createdAt,
                            type: editorSongType(for: next)
                        )
                    )
                }
            }

            return files.sorted { $0.createdAt > $1.createdAt }
        } catch {
            return []
       
        }
    }

    private func editorSongType(for fileURL: URL) -> SongType {
        let name = fileURL.deletingPathExtension().lastPathComponent.lowercased()

        if name.contains("vocal") {
            return .vocal
        }
        if name.contains("instrumental") {
            return .instrumental
        }

        return .all
    }
}
