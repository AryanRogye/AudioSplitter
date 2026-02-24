//
//  SplitLoadingCard.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/23/26.
//

import SwiftUI

struct SplitActivityPill: View {
    let label: String
    let symbol: String
    
    var body: some View {
        Label(label, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
    }
}


struct SplitLoadingExperienceCard: View {
    let startedAt: Date?
    let progressOverride: Double?
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 20.0)) { context in
            let elapsed = max(0, startedAt.map { context.date.timeIntervalSince($0) } ?? 0)
            let progress = progressOverride ?? estimatedProgress(for: elapsed)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.goldAccent ?? .orange)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<11, id: \.self) { index in
                        let wave = (sin((elapsed * 5.5) + (Double(index) * 0.7)) + 1) / 2
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Theme.goldAccent ?? .orange)
                            .frame(width: 8, height: 16 + (wave * 52))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .background((Theme.goldAccent ?? .orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                VStack(spacing: 6) {
                    GeometryReader { proxy in
                        let width = max(0, proxy.size.width * progress)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill((Theme.goldAccent ?? .orange).opacity(0.14))
                            Capsule()
                                .fill((Theme.goldAccent ?? .orange))
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
