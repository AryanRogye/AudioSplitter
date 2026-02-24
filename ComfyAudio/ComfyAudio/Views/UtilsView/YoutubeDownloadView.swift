//
//  YoutubeDownloadView.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/23/26.
//

import SwiftUI
import AudioHelper
import FFmpegSupport

struct DownloaderView: View {
    @StateObject private var vm = DownloaderViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Song Downloader")
                .font(.largeTitle)
                .bold()
            
            TextField("YouTube URL", text: $vm.urlString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .textInputAutocapitalization(.never)
            
            Button(action: vm.startDownloadTapped) {
                Text(vm.isDownloading ? "Processing..." : "Download for Mixing")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(vm.isDownloading || vm.urlString.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(vm.isDownloading || vm.urlString.isEmpty)
            .padding(.horizontal)
            
            Text(vm.statusMessage)
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Divider()
            
            List {
                Section {
                    if vm.downloadLogs.isEmpty {
                        Text("No logs yet. Start a download to see progress messages.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(vm.downloadLogs.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    HStack {
                        Text("Download Log")
                        Spacer()
                        if !vm.downloadLogs.isEmpty {
                            Button("Clear", action: vm.clearLogs)
                                .font(.caption)
                        }
                    }
                }
                
                Section(header: Text("Downloaded Songs")) {
                    if vm.downloadedFiles.isEmpty {
                        Text("No files found. Try downloading a song.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(vm.downloadedFiles, id: \.self) { file in
                            HStack {
                                Button(action: { vm.selectedFileForConversion = file }) {
                                    HStack {
                                        Image(systemName: "waveform")
                                            .foregroundColor(.blue)
                                        Text(file.lastPathComponent)
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                    }
                                }
                                
                                Spacer()
                                
                                ShareLink(item: file) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                        .onDelete(perform: vm.deleteFile)
                    }
                }
            }
        }
        .onAppear { vm.onAppear() }
//        .sheet(item: $vm.selectedFileForConversion) { fileURL in
//            ConverterView(inputURL: fileURL) {
//                vm.refreshFiles()
//                vm.selectedFileForConversion = nil
//            }
//        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { self.path }
}

struct ConverterView: View {
    let inputURL: URL
    var onComplete: () -> Void
    
    @Environment(\.dismiss) var dismiss // To close the sheet manually
    @State private var isConverting = false
    @State private var status = "Ready to convert"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source File:")
                        .font(.headline)
                    Text(inputURL.lastPathComponent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                if isConverting {
                    ProgressView("Converting to MP3...")
                } else {
                    Button(action: startConversion) {
                        Text("Convert & Save to Files")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                
                Text(status)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Audio Converter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    func startConversion() {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = docs.appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent + ".mp3")
        
        isConverting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Ensure no duplicate exists
            try? fileManager.removeItem(at: outputURL)
            
            let args = ["ffmpeg", "-i", inputURL.path, "-vn", "-acodec", "libmp3lame", "-b:a", "192k", outputURL.path]
            let result = ffmpeg(args)
            
            DispatchQueue.main.async {
                if result == 0 {
                    // Optional: Delete webm after success
                    try? fileManager.removeItem(at: inputURL)
                    onComplete()
                } else {
                    isConverting = false
                    status = "Error during conversion."
                }
            }
        }
    }
}
