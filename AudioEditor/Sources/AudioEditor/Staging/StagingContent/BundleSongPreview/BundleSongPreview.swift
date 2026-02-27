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
    
    let url: URL
    var onRemove: (() -> Void)? = nil
    
    /// This is created per item that is staged
    @State fileprivate var vm = BundleSongPreviewViewModel()
    
    var body: some View {
        VStack {
            iOSAudioSlider(vm: vm)
            HStack {
                Button {
                    vm.playAudio(url)
                } label: {
                    Image(systemName: "play.fill")
                        .imageScale(.medium)
                        .padding(8)
                        .background(
                            Circle().stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .accessibilityLabel("Play preview")

                
                Button(action: { /* TODO: handle add to timeline */ }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .imageScale(.medium)
                        Text("Add To Timeline")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .circular)
                            .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Add to timeline")

                Spacer()
                
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary.opacity(0.65))
                            .imageScale(.large)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(.thinMaterial)
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
