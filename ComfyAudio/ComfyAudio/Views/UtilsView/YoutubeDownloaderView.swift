//
//  YoutubeDownloaderView.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/24/26.
//

import SwiftUI
import AudioHelper

struct YoutubeDownloaderView: View {
    
    @StateObject private var vm = DownloaderViewModel()
    
    private var backgroundColor: Color { Theme.backgroundPrimary ?? .black }
    private var surfaceColor: Color { Theme.surface ?? Color(.secondarySystemBackground) }
    private var accentColor: Color { Theme.goldAccent ?? .orange }
    private var primaryTextColor: Color { Theme.textPrimary ?? .white }
    private var secondaryTextColor: Color { Theme.textSecondary ?? .gray }
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 12) {
                TextField("YouTube URL", text: $vm.urlString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .foregroundStyle(primaryTextColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(surfaceColor.opacity(0.95))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(accentColor.opacity(0.35), lineWidth: 1)
                    )
                    .tint(accentColor)
                    .padding(.top)
                
                Button(action: vm.startDownloadTapped) {
                    Label(vm.isDownloading ? "Processing..." : "Download for Mixing", systemImage: "arrow.down.circle.fill")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .disabled(vm.isDownloading || vm.urlString.isEmpty)
                .buttonStyle(GlassProminentButtonStyle())
                .controlSize(.large)
                .tint(accentColor)
                .opacity(vm.isDownloading || vm.urlString.isEmpty ? 0.65 : 1)
                
                Text(vm.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("Warning: this screen might crash sometimes, but it should eventually work if you reopen and try again.")
                        .font(.caption2)
                        .foregroundStyle(primaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(surfaceColor.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.yellow.opacity(0.35), lineWidth: 1)
                )

                Text("Tip: Tap any downloaded song below to convert it to MP3.")
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                List {
                    Section {
                        if vm.downloadLogs.isEmpty {
                            Text("No logs yet. Start a download to see progress messages.")
                                .font(.caption)
                                .foregroundStyle(secondaryTextColor)
                                .listRowBackground(surfaceColor.opacity(0.9))
                        } else {
                            ForEach(Array(vm.downloadLogs.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.caption2.monospaced())
                                    .textSelection(.enabled)
                                    .foregroundStyle(accentColor)
                                    .listRowBackground(surfaceColor.opacity(0.9))
                                    .listRowSeparatorTint(accentColor.opacity(0.2))
                            }
                        }
                    } header: {
                        HStack {
                            Text("Download Log")
                                .foregroundStyle(primaryTextColor)
                            Spacer()
                            if !vm.downloadLogs.isEmpty {
                                Button("Clear", action: vm.clearLogs)
                                    .font(.caption)
                                    .foregroundStyle(accentColor)
                            }
                        }
                    }
                    
                    Section {
                        if vm.downloadedFiles.isEmpty {
                            Text("No files found. Try downloading a song.")
                                .font(.caption)
                                .foregroundStyle(secondaryTextColor)
                                .listRowBackground(surfaceColor.opacity(0.9))
                        } else {
                            ForEach(vm.downloadedFiles, id: \.self) { file in
                                HStack {
                                    Button(action: { vm.selectedFileForConversion = file }) {
                                        HStack {
                                            Image(systemName: "waveform")
                                                .foregroundStyle(accentColor)
                                            Text(file.lastPathComponent)
                                                .font(.caption2)
                                                .foregroundStyle(primaryTextColor)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                    
                                    ShareLink(item: file) {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundStyle(accentColor)
                                    }
                                }
                                .listRowBackground(surfaceColor.opacity(0.9))
                                .listRowSeparatorTint(accentColor.opacity(0.2))
                            }
                            .onDelete(perform: vm.deleteFile)
                        }
                    } header: {
                        Text("Downloaded Songs")
                            .foregroundStyle(primaryTextColor)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .padding(.horizontal)
        }
        .navigationTitle("YouTube Audio")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accentColor)
        .onAppear { vm.onAppear() }
        .sheet(item: $vm.selectedFileForConversion) { fileURL in
            ConverterView(inputURL: fileURL) {
                vm.refreshFiles()
                vm.selectedFileForConversion = nil
            }
        }
    }
}
