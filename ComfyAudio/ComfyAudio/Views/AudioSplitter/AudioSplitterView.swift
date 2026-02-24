//
//  AudioSplitterView.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/23/26.
//

import SwiftUI
import AudioHelper
import UniformTypeIdentifiers

struct AudioSplitterView: View {
    
    @State private var isFileImporterPresented = false
    @State private var vm = AudioSplitterViewModel(
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
                    editorEntry
                        .padding(.horizontal)
                    
                    /// Title
                    title
                        .padding(.horizontal)
                    
                    /// FilePicker
                    filePicker
                        .padding(.horizontal)
                    
                    /// Results
                    resultView
                        .padding(.horizontal)
                    
                    /// Stem View
                    stemView
                        .padding(.horizontal)
                    
                    /// Save Stem View
                    saveStemsView
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.mp3, .audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let first = urls.first {
                        vm.importPickedFile(from: first)
                    }
                case .failure(let error):
                    vm.errorText = error.localizedDescription
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.errorText != nil },
                set: { newValue in if !newValue { vm.errorText = nil } }
            )) {
                Button("OK") { vm.errorText = nil }
            } message: {
                Text(vm.errorText ?? "No Error Message Provided")
            }
            .overlay(alignment: .bottom) {
                if let status = vm.statusText {
                    Text(status)
                        .font(.caption.bold())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                        .id(status)
                }
            }
            .animation(.spring(), value: vm.statusText)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        EditorView(
                            allSongs: vm.editorSeedFiles()
                        )
                    } label: {
                        Label("Editor", systemImage: "timeline.selection")
                    }
                    .disabled(vm.editorSeedFiles().isEmpty)
                }
            }
        }
    }
    
    private var editorEntry: some View {
        ComfyAudioCard {
            Label("Editor", systemImage: "timeline.selection")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Open Editor with files from your saved split folders.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink {
                EditorView(
                    allSongs: vm.editorSeedFiles()
                )
            } label: {
                Label("Open Editor", systemImage: "timeline.selection")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassProminentButtonStyle())
            .controlSize(.large)
            .disabled(vm.editorSeedFiles().isEmpty)
        }
        .padding(.top)
    }

    // MARK: - Title
    private var title: some View {
        ComfyAudioCard {
            Text("Audio Splitting")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("""
            Fast local seperation with an iOS-native workflow.
            """)
            .font(.system(size: 18, weight: .light, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            
        }
        .padding(.top)
    }
    
    // MARK: - Audio Picker
    private var filePicker: some View {
        ComfyAudioCard {
            Label("Source File", systemImage: "music.note")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("MP3", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .buttonStyle(GlassProminentButtonStyle())
                .controlSize(.large)
                
                Button {
                    vm.togglePlayback()
                } label: {
                    Label(
                        !vm.isPaused ? "Pause" : "Play",
                        systemImage: !vm.isPaused ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassButtonStyle())
                .controlSize(.large)
                .disabled(vm.selectedFileURL == nil)

            }
            .frame(height: 50)
            
            Button {
                if vm.isProcessing {
                    vm.cancelSplit()
                } else {
                    Task {
                        await vm.splitSelectedFile()
                    }
                }
            } label: {
                Label(
                    vm.isProcessing ? "Cancel Split" : "Split Track",
                    systemImage: vm.isProcessing ? "stop.fill" : "sparkles.rectangle.stack.fill"
                )
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassProminentButtonStyle())
            .controlSize(.large)
            .disabled(vm.selectedFileURL == nil && !vm.isProcessing)

        }
        .padding(.top)
    }
    
    @ViewBuilder
    private var resultView: some View {
        if vm.isProcessing {
            VStack(alignment: .leading, spacing: 12) {
                SplitActivityPill(
                    label: "Splitting in progress", 
                    symbol: "waveform.and.magnifyingglass"
                )
                
                SplitLoadingExperienceCard(
                    startedAt: .now,
                    progressOverride: nil
                )
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }
    
    // MARK: - Stem View
    @ViewBuilder
    private var stemView: some View {
        if !vm.outputStems.isEmpty {
            VStack(spacing: 10) {
                ForEach(vm.outputStems) { stem in
                    StemRow(
                        stem: stem,
                        isPlaying: vm.isPlaying(stem.fileURL)
                    ) {
                        vm.togglePlayback(for: stem.fileURL)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.94).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
        }
    }
    
    @ViewBuilder
    private var saveStemsView: some View {
        Button {
            vm.saveStems()
        } label: {
            Text("Save Stems?")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GlassProminentButtonStyle())
    }
}
