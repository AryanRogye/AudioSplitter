//
//  TimelineEditorView.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/12/26.
//

import SwiftUI

struct TimelineEditorView: View {
    
    @Bindable var editorVM: EditorViewModel
    
    let shape = UnevenRoundedRectangle(
        topLeadingRadius: 0,
        bottomLeadingRadius: 32,
        bottomTrailingRadius: 32,
        topTrailingRadius: 0,
        style: .continuous
    )
    
    let pixelsPerSecond: CGFloat = 20
    
    /**
     
     For Each AudioTrack Gets Added In:
     [      song name     ]
     [     song vocal     ]
     [ song instrumentals ]
     
     */
    
    
    private let headerWidth: CGFloat = 80
    private let headerSpacing: CGFloat = 10
    private let laneHPadding: CGFloat = 8
    
    private var timelineLeftInset: CGFloat {
        headerWidth + headerSpacing + laneHPadding
    }
    @State private var initialPlayheadTime: TimeInterval? = nil

    var body: some View {
        VStack(spacing: 0) {
            /// Controls For Playback, Right now only PlayPasue Button here
            HStack {
                Spacer()
                Button {
                    editorVM.toggleAudio()
                } label: {
                    Image(systemName: editorVM.isPlaying ?  "stop.fill" : "play.fill")
                }
                Spacer()
            }
            .buttonStyle(PlayButtonStyle())
            .padding(.vertical, 6)
            
            Divider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) { // Playhead and tracks are now in the same scrolling space
                    
                    timelineContent
                    
                    TimelineView(.animation) { _ in
                        ZStack(alignment: .top) {
                            // The visual playhead line
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                            
                            // A little handle at the top
                            Image(systemName: "arrowtriangle.down.fill")
                                .foregroundColor(.red)
                                .offset(y: -2)
                        }
                        // Widen the invisible hit area
                        .frame(width: 30)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        // 1. Offset moves the physical hit box
                        .offset(
                            x: timelineLeftInset + (editorVM.timelineSong.currentTime * pixelsPerSecond) - 15,
                            y: 20
                        )
                        // 2. Gesture goes HERE, attached to the moved box
                        .highPriorityGesture(
                            DragGesture()
                                .onChanged { value in
                                    print("Dragging")
                                    if initialPlayheadTime == nil {
                                        initialPlayheadTime = editorVM.timelineSong.currentTime
                                    }
                                    guard let start = initialPlayheadTime else { return }
                                    
                                    let timeDelta = value.translation.width / pixelsPerSecond
                                    let newTime = max(0, start + timeDelta)
                                    
                                    editorVM.timelineSong.seek(to: newTime)
                                }
                                .onEnded { _ in
                                    initialPlayheadTime = nil
                                }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
        .dropDestination(for: EditorFile.self) { items, location in
            withAnimation(.spring()) {
                editorVM.addDroppedItems(items)
            }
            return true
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "square.and.arrow.down")
                .font(.largeTitle)
            Text("Drop stems here")
                .font(.headline)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    

    private var timelineContent: some View {
        let scale = BeatScale(bpm: 120, beatsPerBar: 4, pixelsPerSecond: pixelsPerSecond)
        let gridHeight: CGFloat = 60
        let laneHeight: CGFloat = 60
        let totalWidth = CGFloat(180) * pixelsPerSecond
        
        
        return ZStack(alignment: .topLeading) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(editorVM.timelineSong.clips) { clip in
                        ZStack {
                            BeatGridView(scale: scale, totalSeconds: 180, laneHeight: gridHeight)
                                .padding(.leading, timelineLeftInset)
                                .frame(width: totalWidth + timelineLeftInset)
                                .background(Color(.tertiarySystemBackground))
                            
                            TimelineTrackLane(clip: clip, pixelsPerSecond: pixelsPerSecond)
                                .frame(height: laneHeight)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                editorVM.removeURLFromSong(clip)
                            } label: {
                                Label("Remove Stem", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .clipped()
    }
}

struct BeatScale {
    var bpm: Double = 120
    var beatsPerBar: Int = 4
    var pixelsPerSecond: CGFloat = 20
    
    var secondsPerBeat: Double { 60.0 / bpm }
    var pixelsPerBeat: CGFloat { CGFloat(secondsPerBeat) * pixelsPerSecond }
    var pixelsPerBar: CGFloat { pixelsPerBeat * CGFloat(beatsPerBar) }
}

struct BeatGridView: View {
    var scale: BeatScale
    var totalSeconds: Double = 180   // timeline length
    var laneHeight: CGFloat = 60
    
    var body: some View {
        let totalWidth = CGFloat(totalSeconds) * scale.pixelsPerSecond
        
        Canvas { ctx, size in
            // We’ll draw beats across the visible canvas width (size.width).
            // But we need to know which part of the timeline is visible:
            // For MVP: assume canvas starts at x=0 (works if you put Canvas inside content of ScrollView).
            // Better later: incorporate scroll offset.
            
            let beatPx = max(scale.pixelsPerBeat, 6) // prevent insane density
            let barPx  = max(scale.pixelsPerBar, 6)
            
            // Number of vertical lines to draw in this visible region
            let startX: CGFloat = 0
            let endX: CGFloat = size.width
            
            // First beat line index in view
            let firstBeat = Int(floor(startX / beatPx))
            let lastBeat  = Int(ceil(endX / beatPx))
            
            for i in firstBeat...lastBeat {
                let x = CGFloat(i) * beatPx
                
                let isBar = (Int(round(x / barPx)) * Int(barPx) == Int(x)) // cheap bar check
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                
                ctx.stroke(
                    path,
                    with: .color(.black.opacity(isBar ? 0.18 : 0.07)),
                    lineWidth: isBar ? 1.5 : 1.0
                )
            }
        }
        .frame(width: totalWidth, height: laneHeight)
    }
}

struct TimelineTrackLane: View {
    @Bindable var clip: TimelineClip
    let pixelsPerSecond: CGFloat
    
    @State private var initialStartTime: TimeInterval? = nil
    @State private var length: CGFloat
    
    init(clip: TimelineClip, pixelsPerSecond: CGFloat) {
        self.clip = clip
        self.pixelsPerSecond = pixelsPerSecond
        self.length = max(clip.duration, 0.2) * pixelsPerSecond
    }
    
    var body: some View {
        HStack(spacing: 0) {
            
            // --- HEADER (Pro Look) ---
            VStack(alignment: .leading, spacing: 6) {
                Text(clip.asset.displayName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                
                // Mute / Solo Button Placeholders
                HStack(spacing: 6) {
                    Text("M")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 3))
                    
                    Text("S")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(width: 80, alignment: .leading)
            .padding(.horizontal, 8)
            // Optional: Give the header a slightly different background to separate it from the timeline
            .background(Color(.systemGray6))
            
            // --- TIMELINE LANE ---
            ZStack(alignment: .leading) {
                // Lane Background
                Rectangle()
                    .fill(Color.black.opacity(0.04))
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                
                // The Clip (Styled without waveforms)
                ZStack {
                    // Gradient background for a 3D/glassy feel
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Subtle border
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    
                    // Fake "stereo" center split line common in DAWs
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 1)
                }
                .frame(width: length, height: 48) // Slightly shorter than the lane for padding
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
                
                // MARK: - LIVE DRAG LOGIC
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
        // Add a bottom divider to clearly separate lanes vertically
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
