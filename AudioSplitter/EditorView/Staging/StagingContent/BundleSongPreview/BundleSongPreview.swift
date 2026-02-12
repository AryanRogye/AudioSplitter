//
//  BundleSongPreview.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/11/26.
//

import SwiftUI
import Playgrounds

/// Shown in the StagedBundleCard
/// Player for each song in the staging area
struct BundleSongPreview: View {
    
    @Binding var selected: SelectedStageListen
    let vocalURL : URL?
    let instrumentalURL: URL?
    
    /// This is created per item that is staged
    @State fileprivate var vm = BundleSongPreviewViewModel()
    
    var body: some View {
        VStack {
            iOSAudioSlider(vm: vm)
            HStack {
                Button {
                    if let vocalURL, let instrumentalURL {
                        vm.playAudio(
                            for: selected,
                            vocalURL,
                            instrumentalURL
                        )
                    }
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
