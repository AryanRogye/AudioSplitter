//
//  HomeView.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/23/26.
//

import SwiftUI
import AudioHelper

struct HomeView: View {
    @State private var vm = HomeViewModel(
        files: AudioFileManager(
            configuration: .init(
                containerFolderName: "ComfyAudio",
                defaultLocation: .documents
            )
        )
    )
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 14) {
                        titleCard
                        splitStatusCard
                        openSourceCard
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    vm.refresh()
                }
            }
            .navigationTitle("Home")
            .task {
                vm.refresh()
            }
            .alert("Home Status", isPresented: Binding(
                get: { vm.errorText != nil },
                set: { newValue in if !newValue { vm.errorText = nil } }
            )) {
                Button("OK") {
                    vm.errorText = nil
                }
            } message: {
                Text(vm.errorText ?? "Unknown error.")
            }
        }
    }
    
    private var titleCard: some View {
        ComfyAudioCard {
            Text("ComfyAudio")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Quick status from your local split history.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var splitStatusCard: some View {
        ComfyAudioCard {
            Label("Split Status", systemImage: "waveform.path.ecg.rectangle")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 10) {
                statTile(
                    title: "Items Split",
                    value: "\(vm.splitItemCount)"
                )
                
                statTile(
                    title: "Stem Files",
                    value: "\(vm.savedStemFileCount)"
                )
            }
            
            if let latestSplitFolderName = vm.latestSplitFolderName {
                Text("Latest: \(latestSplitFolderName)")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No split items yet. Split and save a song to populate this.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var openSourceCard: some View {
        ComfyAudioCard {
            Label("Open Source", systemImage: "shippingbox")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("ComfyAudio is open source.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                Link(destination: URL(string: "https://github.com/AryanRogye/AudioSplitter")!) {
                    Label("View GitHub Repository", systemImage: "link")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background((Theme.surface ?? .white).opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .foregroundStyle(.white)

                Link(destination: URL(string: "https://github.com/AryanRogye/AudioSplitter/blob/main/LICENSE")!) {
                    Label("View License (LGPL-2.1-or-later)", systemImage: "doc.text")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background((Theme.surface ?? .white).opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .foregroundStyle(.white)
            }
        }
    }
    
    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.goldAccent ?? .white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background((Theme.surface ?? .white).opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@Observable
@MainActor
final class HomeViewModel {
    private let store: any AudioPageFileStoring
    private let fileManager: FileManager
    
    var splitItemCount: Int = 0
    var savedStemFileCount: Int = 0
    var latestSplitFolderName: String?
    var errorText: String?
    
    init(
        files: any AudioFileManaging,
        fileManager: FileManager = .default
    ) {
        self.store = files.page("Separations")
        self.fileManager = fileManager
    }
    
    func refresh() {
        do {
            let items = try store.listFiles()
            let stemSuffixes = StemKind.allCases.map { "_\($0.rawValue)" }
            
            var splitDirectories: [(url: URL, modifiedAt: Date)] = []
            var stemCount = 0
            
            for item in items {
                let values = try item.resourceValues(
                    forKeys: [.isDirectoryKey, .contentModificationDateKey]
                )
                
                guard values.isDirectory == true else {
                    // Top-level source files can exist in this namespace; only folders are split items.
                    continue
                }
                
                let modifiedAt = values.contentModificationDate ?? .distantPast
                splitDirectories.append((item, modifiedAt))
                
                let folderItems = try fileManager.contentsOfDirectory(
                    at: item,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                
                for folderItem in folderItems {
                    guard let isRegularFile = try folderItem.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                          isRegularFile else {
                        continue
                    }
                    
                    let baseName = folderItem.deletingPathExtension().lastPathComponent
                    if stemSuffixes.contains(where: { baseName.hasSuffix($0) }) {
                        stemCount += 1
                    }
                }
            }
            
            splitItemCount = splitDirectories.count
            savedStemFileCount = stemCount
            latestSplitFolderName = splitDirectories
                .max(by: { $0.modifiedAt < $1.modifiedAt })?
                .url
                .lastPathComponent
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
