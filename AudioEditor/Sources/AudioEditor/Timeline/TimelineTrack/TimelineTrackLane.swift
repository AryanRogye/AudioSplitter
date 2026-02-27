//
//  TimelineTrackLane.swift
//  ComfyAudio
//

import SwiftUI

struct TimelineTrackLane: View {
    @Environment(EditorTheme.self) var theme
    @Bindable var clip: TimelineClip
    let pixelsPerSecond: CGFloat
    let headerWidth: CGFloat

    @State private var lastSnappedTime: Double? = nil
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
    
    var waveformColor: Color {
        if selected {
            return Color.black.opacity(0.4)
        } else {
            return Color.white.opacity(0.7)
        }
    }
    var color: LinearGradient {
        if selected {
            return LinearGradient(
                colors: [
                    theme.accent.opacity(0.8),
                    theme.accent.mix(with: .white, by: 0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [theme.accent.opacity(0.6), theme.accent.mix(with: .black, by: 0.4).opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(clip.asset.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(theme.accent.opacity(0.9))
                
                // Start time chip
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 9, weight: .semibold))
                    Text("\(clip.startTime, specifier: "%.2f")s")
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(theme.accent.opacity(0.8))
                .padding(.horizontal, 6)
                
                // Duration chip
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9, weight: .semibold))
                    Text("\(clip.duration, specifier: "%.2f")s")
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(theme.accent.opacity(0.8))
                .padding(.horizontal, 6)
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: headerWidth, alignment: .leading)
            .padding(.horizontal, 8)
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.04))
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)

                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .scaleEffect(isDragging ? 1.02 : 1.0)
                        .shadow(color: .black.opacity(isDragging ? 0.35 : 0.2),
                                radius: isDragging ? 6 : 2, x: 0, y: 2)
                        .animation(.snappy(duration: 0.12), value: isDragging)
                    
                    WaveformShape(samples: waveformSamples)
                        .fill(waveformColor)
                        .padding(.vertical, 4)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                }
                .frame(width: laneWidth, height: 48)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                .offset(x: clip.startTime * pixelsPerSecond)
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            if initialStartTime == nil {
                                initialStartTime = clip.startTime
                                isDragging = true
                            }
                            guard let start = initialStartTime else { return }
                            
                            let raw = max(0, start + (value.translation.width / pixelsPerSecond))
                            
                            let step = 0.10
                            let snapped = snap(raw, step: step)
                            let useSnap = abs(snapped - raw) < 0.03
                            
                            if useSnap {
                                // Only trigger haptic if we just snapped to a NEW line
                                if lastSnappedTime != snapped {
                                    lastSnappedTime = snapped
                                    
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            } else {
                                // Reset when pulled away from a snap point
                                lastSnappedTime = nil
                            }
                            
                            clip.startTime = useSnap ? snapped : raw
                        }
                        .onEnded { _ in
                            initialStartTime = nil
                            isDragging = false
                            lastSnappedTime = nil
                        }
                )
            }
            .clipped()
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.backgroundSecondary)
        }
        .task(id: "\(clip.asset.url.absoluteString)|\(clip.sourceStart)|\(clip.duration)") {
            // 1. Request access to the file outside your sandbox
            let isSecured = clip.asset.url.startAccessingSecurityScopedResource()
            
            // 2. Fetch the data
            waveformSamples = await EditorViewModel.generateWaveform(
                from: clip.asset.url,
                startTime: clip.sourceStart,
                endTime: clip.sourceStart + clip.duration,
                sampleCount: max(300, min(2000, Int(laneWidth * 2)))
            )
            
            // 3. Clean up access
            if isSecured {
                clip.asset.url.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    private func snap(_ t: Double, step: Double) -> Double {
        (t / step).rounded() * step
    }
}
