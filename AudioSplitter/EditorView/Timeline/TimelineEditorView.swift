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
            
            timelineContent
            
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
        
        return ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                BeatGridView(scale: scale, totalSeconds: 180, laneHeight: 60)
                
                // Later: stack your lanes over the SAME width
                // ForEach(vm.timelineSong.clips) { clip in ... }
                ForEach(editorVM.timelineSong.clips) { clip in
                    TimelineTrackLane(
                        clip: clip,
                        pixelsPerSecond: pixelsPerSecond
                    )
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
    
//    private var timelineContent: some View {
//        ScrollView([.vertical, .horizontal], showsIndicators: false) {
//            VStack(alignment: .leading, spacing: 12) {
//                if vm.timelineSong.clips.isEmpty {
//                    emptyStateView
//                } else {
//                    ForEach(vm.timelineSong.clips) { clip in
//                        TimelineTrackLane(
//                            clip: clip,
//                            pixelsPerSecond: pixelsPerSecond
//                        )
//                        .contextMenu {
//                            Button(role: .destructive) {
//                                vm.removeURLFromSong(clip)
//                            } label: {
//                                Label("Remove Stem", systemImage: "trash")
//                            }
//                        }
//                    }
//                }
//            }
//            .padding(.vertical, 20)
//        }
//    }
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

extension TimelineEditorView {
    
    struct TimelineTrackLane: View {
        // 1. Use @Bindable so we can write to it directly
        @Bindable var clip: TimelineClip
        let pixelsPerSecond: CGFloat
        
        // 2. We store the "Original" time when you start dragging
        @State private var initialStartTime: TimeInterval? = nil
        
        let mockDuration: TimeInterval = 30
        
        var body: some View {
            HStack(spacing: 0) {
                
                // --- HEADER (Same as before) ---
                VStack(alignment: .trailing, spacing: 4) {
                    Text(clip.asset.displayName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    
//                    Text(clip.asset.kind.rawValue.capitalized)
//                        .font(.system(size: 9, weight: .semibold))
//                        .foregroundStyle(clip.asset.kind == .vocals ? .blue : .green)
//                        .padding(.horizontal, 4)
//                        .padding(.vertical, 2)
//                        .background(
//                            (clip.asset.kind == .vocals ? Color.blue : Color.green).opacity(0.1),
//                            in: Capsule()
//                        )
                }
                .frame(width: 80, alignment: .trailing)
                .padding(.trailing, 10)
                
                // --- TIMELINE LANE ---
                ZStack(alignment: .leading) {
                    // Lane Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.03))
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                    
                    // The Clip
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: mockDuration * pixelsPerSecond, height: 40)
                        .overlay(alignment: .leading) {
                            HStack(spacing: 4) {
                                Image(systemName: "hifispeaker.fill")
                                    .font(.caption2)
                                
                                // Show live time update
                                if clip.startTime > 0 {
                                    Text("+\(clip.startTime, specifier: "%.1f")s")
                                        .font(.caption2)
                                        .opacity(0.8)
                                        .monospacedDigit()
                                }
                            }
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.leading, 8)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                    
                    // MARK: - LIVE DRAG LOGIC
                    // We use the actual model time for the offset. No separate "dragOffset" variable.
                        .offset(x: clip.startTime * pixelsPerSecond)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // 1. Snapshot the start time if this is the first frame of the drag
                                    if initialStartTime == nil {
                                        initialStartTime = clip.startTime
                                    }
                                    
                                    guard let start = initialStartTime else { return }
                                    
                                    // 2. Calculate the delta in seconds
                                    let timeDelta = value.translation.width / pixelsPerSecond
                                    
                                    // 3. Update the model LIVE (Preventing negative time)
                                    clip.startTime = max(0, start + timeDelta)
                                }
                                .onEnded { _ in
                                    // 4. Clear the snapshot so the next drag starts fresh
                                    initialStartTime = nil
                                }
                        )
                }
                .clipped()
            }
            .padding(.horizontal, 8)
            .frame(height: 60)
        }
    }
}
