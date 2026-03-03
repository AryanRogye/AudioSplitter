//
//  TimeRulerView.swift
//  AudioEditor
//
//  Created by Aryan Rogye on 2/28/26.
//

import SwiftUI

struct TimeRulerView: View {
    
    @Environment(EditorTheme.self) var theme
    let totalSeconds: Double
    let scale: BeatScale
    let headerWidth: CGFloat
    
    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: headerWidth)
                .padding(.horizontal, 8)
            
            ZStack(alignment: .bottomLeading) {
                let totalBeats = max(1, Int(ceil(scale.beat(at: totalSeconds))))
                let safeBeatsPerBar = max(1, scale.beatsPerBar)
                
                ForEach(0...totalBeats, id: \.self) { beatIndex in
                    let seconds = scale.seconds(forBeat: Double(beatIndex))
                    let x = seconds * scale.pixelsPerSecond
                    let isBar = beatIndex % safeBeatsPerBar == 0
                    
                    if isBar {
                        bar((beatIndex / safeBeatsPerBar) + 1)
                            .offset(x: x)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        regularBar()
                            .offset(x: x)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: scale)
    }
    
    private func regularBar() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(theme.accent.opacity(0.2))
                .frame(width: 1)
                .frame(height: 10)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
    
    private func bar(_ bar: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(bar)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.accent.opacity(0.5))
            
            Rectangle()
                .fill(theme.accent.opacity(0.5))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        }
    }
}
