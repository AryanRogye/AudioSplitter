//
//  StemRow.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/23/26.
//

import SwiftUI
import AudioHelper

/**
 * Simple Stem Row Card View that let us input a stemfile and listen to it
 */
struct StemRow: View {
    let stem: StemFile
    let isPlaying: Bool
    let onPlayPause: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: stem.kind.rawValue)
                .font(.headline)
                .foregroundStyle(stem.kind.tint)
                .frame(width: 34, height: 34)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stem.displayName)
                    .font(.headline)
                Text(stem.fileURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .foregroundStyle(stem.kind.tint)
                    .frame(width: 34, height: 34)
                    .glassEffect(.regular, in: Circle())
            }
            .buttonStyle(.plain)
            
            ShareLink(item: stem.fileURL) {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline)
                    .frame(width: 34, height: 34)
                    .glassEffect(.regular, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(stem.kind.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
