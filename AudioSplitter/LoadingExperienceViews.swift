import Foundation
import Combine
import SwiftUI

enum LoadingStyle: String, CaseIterable, Identifiable {
    case orbitPulse
    case equalizerArc
    case sonarBloom
    case cometTrail
    case radarSweep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .orbitPulse: return "Orbit Pulse"
        case .equalizerArc: return "Equalizer Arc"
        case .sonarBloom: return "Sonar Bloom"
        case .cometTrail: return "Comet Trail"
        case .radarSweep: return "Radar Sweep"
        }
    }

    var subtitle: String {
        switch self {
        case .orbitPulse: return "Notes spinning around the mix core"
        case .equalizerArc: return "Animated bars like a live desk"
        case .sonarBloom: return "Expanding rings scanning stems"
        case .cometTrail: return "A fast-moving track through space"
        case .radarSweep: return "Sweep and lock while splitting"
        }
    }

    var accent: Color {
        switch self {
        case .orbitPulse: return .indigo
        case .equalizerArc: return .orange
        case .sonarBloom: return .mint
        case .cometTrail: return .pink
        case .radarSweep: return .cyan
        }
    }

    var symbolName: String {
        switch self {
        case .orbitPulse: return "music.note"
        case .equalizerArc: return "slider.horizontal.3"
        case .sonarBloom: return "dot.radiowaves.left.and.right"
        case .cometTrail: return "sparkles"
        case .radarSweep: return "scope"
        }
    }
}

struct SplitLoadingExperienceCard: View {
    let style: LoadingStyle
    let startedAt: Date?
    let progressOverride: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 20.0)) { context in
            let elapsed = max(0, startedAt.map { context.date.timeIntervalSince($0) } ?? 0)
            let progress = progressOverride ?? estimatedProgress(for: elapsed)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: style.symbolName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(style.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.title)
                            .font(.headline)
                        Text(style.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                LoadingStyleVisual(style: style, phase: elapsed, progress: progress)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .background(style.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 6) {
                    GeometryReader { proxy in
                        let width = max(0, proxy.size.width * progress)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(style.accent.opacity(0.14))
                            Capsule()
                                .fill(style.accent)
                                .frame(width: width)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("Elapsed: \(formattedElapsed(elapsed))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Splitting stems...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func estimatedProgress(for elapsed: TimeInterval) -> Double {
        // Asymptotic estimate because exact inference progress isn't currently exposed.
        min(0.97, 1 - exp(-elapsed / 52.0))
    }

    private func formattedElapsed(_ elapsed: TimeInterval) -> String {
        let seconds = Int(elapsed.rounded(.down))
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}

private struct LoadingStyleVisual: View {
    let style: LoadingStyle
    let phase: TimeInterval
    let progress: Double

    var body: some View {
        switch style {
        case .orbitPulse:
            orbitPulse
        case .equalizerArc:
            equalizerArc
        case .sonarBloom:
            sonarBloom
        case .cometTrail:
            cometTrail
        case .radarSweep:
            radarSweep
        }
    }

    private var orbitPulse: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                let angle = phase * 140 + (Double(index) * 90)
                Circle()
                    .fill(style.accent)
                    .frame(width: 10, height: 10)
                    .offset(x: cos(angle.radians) * 28, y: sin(angle.radians) * 28)
            }

            Circle()
                .stroke(style.accent.opacity(0.28), lineWidth: 2)
                .frame(width: 62, height: 62)

            Image(systemName: "music.quarternote.3")
                .font(.title3.weight(.bold))
                .foregroundStyle(style.accent)
        }
    }

    private var equalizerArc: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<11, id: \.self) { index in
                let wave = (sin((phase * 5.5) + (Double(index) * 0.7)) + 1) / 2
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(style.accent)
                    .frame(width: 8, height: 16 + (wave * 52))
            }
        }
    }

    private var sonarBloom: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                let t = fract((phase * 0.62) + (Double(index) * 0.23))
                Circle()
                    .stroke(style.accent.opacity(max(0.1, 1 - t)), lineWidth: 2)
                    .scaleEffect(0.3 + (t * 1.5))
            }

            Image(systemName: "waveform.path")
                .font(.title3.weight(.semibold))
                .foregroundStyle(style.accent)
        }
    }

    private var cometTrail: some View {
        ZStack {
            let x = (fract(phase * 0.28) * 140) - 70
            let y = sin(phase * 1.7) * 10

            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(style.accent.opacity(0.12 * Double(5 - index)))
                    .frame(width: CGFloat(8 + index * 3), height: CGFloat(8 + index * 3))
                    .offset(x: x - Double(index * 16), y: y)
            }

            Image(systemName: "sparkles")
                .font(.title2.weight(.bold))
                .foregroundStyle(style.accent)
                .offset(x: x, y: y)
        }
    }

    private var radarSweep: some View {
        ZStack {
            Circle()
                .stroke(style.accent.opacity(0.2), lineWidth: 2)
                .frame(width: 74, height: 74)

            Circle()
                .trim(from: 0.0, to: 0.2)
                .stroke(style.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(phase * 150))
                .frame(width: 74, height: 74)

            let lockX = cos((phase * 90).radians) * 25
            let lockY = sin((phase * 90).radians) * 25
            Circle()
                .fill(style.accent)
                .frame(width: 10, height: 10)
                .offset(x: lockX, y: lockY)

            Image(systemName: progress > 0.6 ? "checkmark.seal.fill" : "scope")
                .font(.title3.weight(.bold))
                .foregroundStyle(style.accent)
        }
    }

    private func fract(_ value: Double) -> Double {
        value - floor(value)
    }
}

struct LoadingAnimationLabView: View {
    @Binding var selectedStyle: LoadingStyle

    @State private var demoProgress: Double = 0.15
    @State private var autoAdvance = true
    @State private var demoStartDate = Date()

    private let demoTimer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SplitLoadingExperienceCard(
                    style: selectedStyle,
                    startedAt: demoStartDate,
                    progressOverride: demoProgress
                )

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Auto progress", isOn: $autoAdvance)
                    HStack {
                        Text("Manual Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(demoProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $demoProgress, in: 0...1, step: 0.01)
                    Button("Restart Demo") {
                        demoProgress = 0
                        demoStartDate = Date()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Pick a loading style")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(LoadingStyle.allCases) { style in
                            Button {
                                selectedStyle = style
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: style.symbolName)
                                        Text(style.title)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(selectedStyle == style ? .primary : .secondary)

                                    Text(style.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    selectedStyle == style
                                        ? style.accent.opacity(0.20)
                                        : Color.white.opacity(0.35),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedStyle == style ? style.accent.opacity(0.6) : .clear, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationTitle("Loading Lab")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(demoTimer) { _ in
            guard autoAdvance else { return }
            demoProgress += 0.003
            if demoProgress > 1 {
                demoProgress = 0
                demoStartDate = Date()
            }
        }
    }
}

struct LabsHubView: View {
    @Binding var selectedLoadingStyle: LoadingStyle
    @ObservedObject var libraryViewModel: AudioLibraryViewModel
    let onUseAsSource: (URL) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Animation Labs") {
                    NavigationLink {
                        LoadingAnimationLabView(selectedStyle: $selectedLoadingStyle)
                    } label: {
                        LabRow(
                            icon: "waveform.badge.magnifyingglass",
                            title: "Loading Lab",
                            subtitle: "Tune split-time animations and pick active style.",
                            accent: .orange
                        )
                    }

                    NavigationLink {
                        StageSyncLabView()
                    } label: {
                        LabRow(
                            icon: "metronome.fill",
                            title: "Stage Sync Lab",
                            subtitle: "Try timing offsets and blend experiments.",
                            accent: .teal
                        )
                    }

                    NavigationLink {
                        ThemeLabView()
                    } label: {
                        LabRow(
                            icon: "paintpalette.fill",
                            title: "Theme Lab",
                            subtitle: "Prototype visual skins and card vibes.",
                            accent: .indigo
                        )
                    }
                }

                Section("UI Experiments") {
                    NavigationLink {
                        LibraryStageStyleLabView(
                            viewModel: libraryViewModel,
                            onUseAsSource: onUseAsSource
                        )
                    } label: {
                        LabRow(
                            icon: "rectangle.3.group.bubble.left.fill",
                            title: "Library + Stage Styles",
                            subtitle: "Try five bold interface directions for remix workflows.",
                            accent: .pink
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Labs")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct LabRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct StageSyncLabView: View {
    @State private var delay: Double = 0
    @State private var blend: Double = 0.5

    var body: some View {
        Form {
            Section("Timing Prototype") {
                HStack {
                    Text("Delay")
                    Spacer()
                    Text(String(format: "%+.2fs", delay))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $delay, in: -1.5...1.5, step: 0.05)
            }

            Section("Blend Prototype") {
                HStack {
                    Text("Vocal / Instrumental")
                    Spacer()
                    Text("\(Int((blend * 100).rounded())) / \(Int(((1 - blend) * 100).rounded()))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $blend, in: 0...1, step: 0.01)
            }
        }
        .navigationTitle("Stage Sync Lab")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ThemeLabView: View {
    @State private var intensity: Double = 0.6

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.36, blue: 0.70),
                                Color(red: 0.78, green: 0.29, blue: 0.52),
                                Color(red: 0.92, green: 0.52, blue: 0.34)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white.opacity(intensity * 0.20))
                    }
                    .frame(height: 160)
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Theme Preview")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Adjust intensity to feel the visual direction.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(14)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Intensity")
                        Spacer()
                        Text("\(Int((intensity * 100).rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $intensity, in: 0.1...1.0, step: 0.01)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(16)
        }
        .navigationTitle("Theme Lab")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Double {
    var radians: Double {
        self * .pi / 180
    }
}
