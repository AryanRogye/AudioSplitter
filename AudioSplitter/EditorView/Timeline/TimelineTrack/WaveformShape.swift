//
//  WaveformShape.swift
//  AudioSplitter
//

import SwiftUI

struct WaveformShape: Shape {
    var samples: [Float]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !samples.isEmpty else { return path }

        let width = rect.width
        let height = rect.height
        let midY = height / 2
        let step = width / CGFloat(samples.count)

        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * step
            let sampleHeight = CGFloat(sample) * midY

            path.move(to: CGPoint(x: x, y: midY - sampleHeight))
            path.addLine(to: CGPoint(x: x, y: midY + sampleHeight))
        }

        return path
    }
}
