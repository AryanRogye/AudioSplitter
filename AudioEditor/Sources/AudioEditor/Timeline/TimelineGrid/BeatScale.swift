//
//  BeatScale.swift
//  ComfyAudio
//

import SwiftUI

struct BeatScale: Equatable {
    var bpm: Double = 120
    var beatsPerBar: Int = 4
    var pixelsPerSecond: CGFloat = 20

    private var safeBPM: Double { max(1, bpm) }
    var secondsPerBeat: Double { 60.0 / safeBPM }
    var beatsPerSecond: Double { safeBPM / 60.0 }
    var secondsPerBar: Double { secondsPerBeat * Double(beatsPerBar) }
    var pixelsPerBeat: CGFloat { CGFloat(secondsPerBeat) * pixelsPerSecond }
    var pixelsPerBar: CGFloat { pixelsPerBeat * CGFloat(beatsPerBar) }

    func beat(at seconds: Double) -> Double {
        max(0, seconds) * beatsPerSecond
    }

    func seconds(forBeat beat: Double) -> Double {
        max(0, beat) * secondsPerBeat
    }
}
