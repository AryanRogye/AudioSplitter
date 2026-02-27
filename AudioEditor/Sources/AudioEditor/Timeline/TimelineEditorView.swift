//
//  TimelineEditorView.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/12/26.
//

import SwiftUI

struct TimelineEditorView: View {

    @Environment(EditorTheme.self) var theme
    @Bindable var editorVM: EditorViewModel

    let pixelsPerSecond: CGFloat = 20

    /// left section
    private let headerWidth: CGFloat = 90
    private let headerSpacing: CGFloat = 9
    private let laneHPadding: CGFloat = 8

    private var timelineLeftInset: CGFloat {
        headerWidth + headerSpacing + laneHPadding
    }

    @State private var initialPlayheadTime: TimeInterval? = nil

    var body: some View {
        VStack(spacing: 0) {
            TimelinePlaybackControls(isPlaying: editorVM.isPlaying) {
                editorVM.toggleAudio()
            }

            Rectangle()
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .foregroundStyle(theme.accent.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    TimelineContent(
                        editorVM: editorVM,
                        pixelsPerSecond: pixelsPerSecond,
                        timelineLeftInset: timelineLeftInset,
                        headerWidth: headerWidth
                    )

                    TimelinePlayhead(
                        editorVM: editorVM,
                        pixelsPerSecond: pixelsPerSecond,
                        timelineLeftInset: timelineLeftInset,
                        initialPlayheadTime: $initialPlayheadTime
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundPrimary)
        .dropDestination(for: EditorFile.self) { items, _ in
            withAnimation(.spring()) {
                editorVM.addDroppedItems(items)
            }
            return true
        }
        .overlay(alignment: .bottom) {
            if let id = editorVM.selectedClip {
                GlassEffectContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        // Header
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Selection Tools")
                                    .font(.headline)
                                Text("Selected: \(id)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        // Primary action row
                        HStack(spacing: 12) {
                            Button {
                                Task { try? await editorVM.splitAtCurrentSelection() }
                            } label: {
                                Label("Split at Playhead", systemImage: "scissors")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(Color.accentColor.opacity(0.15))
                                    )
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)

                            Button {
                                // TODO: More actions soon
                            } label: {
                                Label("More", systemImage: "ellipsis")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().stroke(.secondary.opacity(0.35), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)

                            Spacer()
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        ZStack {
                            // Material base
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                            // Subtle accent gradient sheen
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(colors: [
                                        Color.white.opacity(0.10),
                                        Color.accentColor.opacity(0.08)
                                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .blendMode(.overlay)
                            // Inner stroke for definition
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                        }
                    )
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

