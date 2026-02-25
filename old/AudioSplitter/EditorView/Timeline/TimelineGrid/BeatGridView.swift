//
//  BeatGridView.swift
//  AudioSplitter
//

import SwiftUI

struct BeatGridView: View {
    var scale: BeatScale
    var totalSeconds: Double = 180
    var laneHeight: CGFloat = 60

    var body: some View {
        let totalWidth = CGFloat(totalSeconds) * scale.pixelsPerSecond

        Canvas { ctx, size in
            let beatPx = max(scale.pixelsPerBeat, 6)
            let barPx = max(scale.pixelsPerBar, 6)

            let startX: CGFloat = 0
            let endX: CGFloat = size.width

            let firstBeat = Int(floor(startX / beatPx))
            let lastBeat = Int(ceil(endX / beatPx))

            for i in firstBeat...lastBeat {
                let x = CGFloat(i) * beatPx

                let isBar = (Int(round(x / barPx)) * Int(barPx) == Int(x))
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
