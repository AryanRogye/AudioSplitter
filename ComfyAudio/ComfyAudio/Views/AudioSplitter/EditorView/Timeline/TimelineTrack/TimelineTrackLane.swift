//
//  TimelineTrackLane.swift
//  ComfyAudio
//

import SwiftUI

struct TimelineTrackLane: View {
    @Bindable var clip: TimelineClip
    let pixelsPerSecond: CGFloat
    let headerWidth: CGFloat

    @State private var initialStartTime: TimeInterval? = nil
    @State private var waveformSamples: [Float] = []
    @Binding private var selected: Bool

    init(clip: TimelineClip, headerWidth: CGFloat, pixelsPerSecond: CGFloat, selected: Binding<Bool>) {
        self.clip = clip
        self.headerWidth = headerWidth
        self.pixelsPerSecond = pixelsPerSecond
        self._selected = selected
    }
    
    private var laneWidth: CGFloat {
        max(clip.duration, 0.2) * pixelsPerSecond
    }
    
    var color: LinearGradient {
        if selected {
            return LinearGradient(
                colors: [Color.red.opacity(0.1), Color.red.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(clip.asset.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Start time chip
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 9, weight: .semibold))
                    Text("\(clip.startTime, specifier: "%.2f")s")
                        .font(.system(size: 10, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .clipShape(Capsule())
                .fixedSize()
                
                // Duration chip
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9, weight: .semibold))
                    Text("\(clip.duration, specifier: "%.2f")s")
                        .font(.system(size: 10, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .clipShape(Capsule())
                .fixedSize()
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: headerWidth, alignment: .leading)
            .padding(.horizontal, 8)
            .background(Color(.systemGray6))

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.04))
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)

                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                    
                    WaveformShape(samples: waveformSamples)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                        .padding(.vertical, 4)

                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)

                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                }
                .frame(width: laneWidth, height: 48)
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
        .task(id: "\(clip.asset.url.absoluteString)|\(clip.sourceStart)|\(clip.duration)") {
            // 1. Request access to the file outside your sandbox
            let isSecured = clip.asset.url.startAccessingSecurityScopedResource()
            
            // 2. Fetch the data
            waveformSamples = await EditorViewModel.generateWaveform(
                from: clip.asset.url,
                startTime: clip.sourceStart,
                endTime: clip.sourceStart + clip.duration
            )
            
            // 3. Clean up access
            if isSecured {
                clip.asset.url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

