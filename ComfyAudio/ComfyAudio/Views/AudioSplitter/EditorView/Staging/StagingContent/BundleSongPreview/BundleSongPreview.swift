//
//  BundleSongPreview.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/11/26.
//

import SwiftUI
import Playgrounds
import AudioHelper

/// Shown in the StagedBundleCard
/// Player for each song in the staging area
struct BundleSongPreview: View {
    
    let url: URL
    
    /// This is created per item that is staged
    @State fileprivate var vm = BundleSongPreviewViewModel()
    
    var body: some View {
        VStack {
            iOSAudioSlider(vm: vm)
            HStack {
                Button {
                    vm.playAudio(url)
                } label: {
                    Image(systemName: vm.preview.isPlaying ? "stop.fill" : "play.fill")
                }
                .buttonStyle(PlayButtonStyle())
            }
        }
        .alert(isPresented: $vm.shouldShowError) {
            Alert(title: Text("Playback Error"), message: Text(vm.playbackError ?? "Unkown Error"))
        }
    }
}
