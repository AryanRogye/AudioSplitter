//
//  BundleSongPreview.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/11/26.
//

import SwiftUI

#Preview {
    
    @Previewable @State var selected: SelectedStageListen = .vocal
    
    BundleSongPreview(selected: $selected, vocalURL: nil, instrumentalURL: nil)
}

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
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5).opacity(0.5))
                        .frame(height: 4)
                    
                }
            }
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
                .buttonStyle(.plain)
            }
        }
        .alert(isPresented: $vm.shouldShowError) {
            Alert(title: Text("Playback Error"), message: Text(vm.playbackError ?? "Unkown Error"))
        }
    }
}

struct PlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                
            }
    }
}

@Observable
@MainActor
private final class BundleSongPreviewViewModel {
    
    var preview = AVAudioPreviewPlayback()
    var playbackError: String?
    var shouldShowError = false
    
    init() {
        print("Initialized")
    }
    
    public func playAudio(
        for selected: SelectedStageListen,
        _ vocalURL: URL,
        _ instrumentalURL: URL
    ) {
        if preview.isPlaying {
            preview.stopPreview()
            return
        }
        if let role = selected.stageTrackRole {
            do {
                if role == .vocal {
                    try preview.togglePreview(
                        role: role,
                        fileURL: vocalURL,
                        startTime: 0
                    )
                } else if role == .instrumental {
                    try preview.togglePreview(
                        role: role,
                        fileURL: instrumentalURL,
                        startTime: 0
                    )
                }
            } catch let error as StagePreviewPlaybackError {
                switch error {
                case .missingTrack(let role):
                    playbackError = "Missing Track: \(role)"
                case .fileMissing(let path):
                    playbackError = "File Missing: \(path)"
                case .failedToStart:
                    playbackError = "Failed To Start"
                case .playbackFailed(let details):
                    playbackError = "Playback Failed: \(details)"
                }
                shouldShowError = true
            } catch {
                playbackError = error.localizedDescription
                shouldShowError = true
            }
        }
    }
}
