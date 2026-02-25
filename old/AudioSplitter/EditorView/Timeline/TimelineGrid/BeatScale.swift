//
//  BeatScale.swift
//  AudioSplitter
//

import SwiftUI

struct BeatScale {
    var bpm: Double = 120
    var beatsPerBar: Int = 4
    var pixelsPerSecond: CGFloat = 20

    var secondsPerBeat: Double { 60.0 / bpm }
    var pixelsPerBeat: CGFloat { CGFloat(secondsPerBeat) * pixelsPerSecond }
    var pixelsPerBar: CGFloat { pixelsPerBeat * CGFloat(beatsPerBar) }
}
