//
//  BundleSongPreview.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/11/26.
//

import SwiftUI
import Playgrounds
import AudioPlayback


/// Shown in the StagedBundleCard
/// Player for each song in the staging area
struct BundleSongPreview: View {
    
    @Environment(EditorTheme.self) var theme
    let url: URL
    var onRemove: (() -> Void)? = nil
    var onAddToTimeline: (() -> Void)? = nil
    
    /// This is created per item that is staged
    @State fileprivate var vm = BundleSongPreviewViewModel()
    
    var body: some View {
        VStack {
            iOSAudioSlider(vm: vm)
            
            HStack {
                Button {
                    vm.playAudio(url)
                } label: {
                    Image(systemName: vm.preview.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundStyle(theme.accent)
                        .imageScale(.medium)
                        .padding(8)
                        .background(
                            Circle().stroke(theme.accent.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play preview")

                Button(
                    action: { onAddToTimeline?() }
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(theme.accent)
                            .imageScale(.medium)
                        Text("Add To Timeline")
                            .foregroundStyle(theme.accent)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .circular)
                            .stroke(theme.accent.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Add to timeline")

                Spacer()
                
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary.opacity(0.55))
                            .imageScale(.large)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(theme.accent.opacity(0.3))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove preview")
                }
            }
        }
        .alert(isPresented: $vm.shouldShowError) {
            Alert(title: Text("Playback Error"), message: Text(vm.playbackError ?? "Unkown Error"))
        }
    }
}
