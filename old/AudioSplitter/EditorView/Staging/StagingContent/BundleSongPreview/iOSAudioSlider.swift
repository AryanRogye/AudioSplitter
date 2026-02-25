//
//  iOSAudioSlider.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/12/26.
//

import SwiftUI

/// This is the slider that is used to seek the song to the new position based on finger
/// position
extension BundleSongPreview {
    struct iOSAudioSlider: View {
        
        @Bindable internal var vm: BundleSongPreviewViewModel
        
        @State private var isDragging = false
        @State private var manualDragPosition: Double = 0
        
        let trackHeight: CGFloat = 8
        let hitHeight: CGFloat = 24
        
        // local UI clock so it updates smoothly
        @State private var uiPosition: Double = 0
        
        var duration: Double { vm.preview.currentDuration }
        var position: Double { vm.preview.currentPlaybackTime }
        
        var body: some View {
            HStack(alignment: .center, spacing: 6) {
                Text(formatDuration(isDragging ? manualDragPosition : uiPosition))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                
                GeometryReader { geometry in
                    let effectivePosition = isDragging ? manualDragPosition : uiPosition
                    let denom = max(duration, 0.0001)
                    let pct = min(max(effectivePosition / denom, 0), 1)
                    
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.25))
                            .frame(height: 6)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: pct * geometry.size.width, height: 6)
                            .cornerRadius(2)
                    }
                    .overlay {
                        Color.clear
                            .frame(height: hitHeight)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDragging = true
                                        let percentage = min(max(0, value.location.x / geometry.size.width), 1)
                                        manualDragPosition = percentage * duration
                                    }
                                    .onEnded { value in
                                        let percentage = min(max(0, value.location.x / geometry.size.width), 1)
                                        let newTime = percentage * duration
                                        
                                        manualDragPosition = newTime
                                        vm.preview.seek(to: newTime)
                                        uiPosition = newTime
                                        isDragging = false
                                        startTicking()
                                    }
                            )
                    }
                }
                .frame(height: trackHeight)
                
                Text(formatDuration(duration))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(height: trackHeight)
            .onAppear { uiPosition = position }
            .onChange(of: vm.preview.isPlaying) { _, playing in
                if playing { startTicking() }
            }
        }
        
        private func startTicking() {
            // cheap 30fps-ish UI tick; stops when playback stops
            Task { @MainActor in
                while vm.preview.isPlaying && !isDragging {
                    uiPosition = position
                    try? await Task.sleep(nanoseconds: 33_000_000)
                }
                uiPosition = position
            }
        }
        
        private func formatDuration(_ seconds: Double) -> String {
            let s = max(0, seconds)
            let minutes = Int(s) / 60
            let remainingSeconds = Int(s) % 60
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}
