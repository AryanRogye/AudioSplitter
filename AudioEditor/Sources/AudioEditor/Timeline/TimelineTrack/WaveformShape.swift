//
//  WaveformShape.swift
//  ComfyAudio
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
        let count = samples.count
        let step = count > 1 ? width / CGFloat(count - 1) : 0

        path.move(to: CGPoint(x: 0, y: midY))

        // Upper envelope (left -> right)
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * step
            let clamped = max(0, min(sample, 1))
            let sampleHeight = CGFloat(clamped) * midY
            path.addLine(to: CGPoint(x: x, y: midY - sampleHeight))
        }

        // Lower envelope (right -> left) to create a filled waveform body
        for index in samples.indices.reversed() {
            let x = CGFloat(index) * step
            let clamped = max(0, min(samples[index], 1))
            let sampleHeight = CGFloat(clamped) * midY
            path.addLine(to: CGPoint(x: x, y: midY + sampleHeight))
        }

        path.closeSubpath()
        return path
    }
}
