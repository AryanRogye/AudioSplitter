//
//  TimelineTrackLane.swift
//  ComfyAudio
//

import SwiftUI

struct TimelineTrackLane: View {
    @Bindable var clip: TimelineClip
    let pixelsPerSecond: CGFloat

    @State private var initialStartTime: TimeInterval? = nil
    @State private var waveformSamples: [Float] = []
    @State private var length: CGFloat

    init(clip: TimelineClip, pixelsPerSecond: CGFloat) {
        self.clip = clip
        self.pixelsPerSecond = pixelsPerSecond
        self.length = max(clip.duration, 0.2) * pixelsPerSecond
    }

    var body: some View {
        HStack(spacing: 0) {

            VStack(alignment: .leading, spacing: 6) {
                Text(clip.asset.displayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("M")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 3))

                    Text("S")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(width: 80, alignment: .leading)
            .padding(.horizontal, 8)
            .background(Color(.systemGray6))

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.04))
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)

                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    WaveformShape(samples: waveformSamples)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                        .padding(.vertical, 4)

                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)

                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                }
                .frame(width: length, height: 48)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9))

                        if clip.startTime > 0 {
                            Text("\(clip.startTime, specifier: "%.1f")s")
                                .font(.system(size: 9, design: .monospaced))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(6)
                }
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                .offset(x: clip.startTime * pixelsPerSecond)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if initialStartTime == nil {
                                initialStartTime = clip.startTime
                            }
                            guard let start = initialStartTime else { return }
                            let timeDelta = value.translation.width / pixelsPerSecond
                            clip.startTime = max(0, start + timeDelta)
                        }
                        .onEnded { _ in
                            initialStartTime = nil
                        }
                )
            }
            .clipped()
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
        .task {
            // 1. Request access to the file outside your sandbox
            let isSecured = clip.asset.url.startAccessingSecurityScopedResource()
            
            // 2. Fetch the data
            waveformSamples = await EditorViewModel.generateWaveform(from: clip.asset.url)
            
            // 3. Clean up access
            if isSecured {
                clip.asset.url.stopAccessingSecurityScopedResource()
            }
        }
    }
}
