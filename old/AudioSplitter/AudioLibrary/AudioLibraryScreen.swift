import SwiftUI

struct AudioLibraryScreen: View {
    @ObservedObject var viewModel: AudioLibraryViewModel
    let onUseAsSource: (URL) -> Void
    @State private var renameTarget: RenameTarget?
    @State private var deleteTarget: DeleteTarget?
    @State private var deleteSavedMixTarget: DeleteSavedMixTarget?
    @State private var renameDraft = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.98, blue: 0.95),
                    Color(red: 0.96, green: 0.99, blue: 0.98),
                    Color(red: 0.95, green: 0.97, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    LibraryCard(tint: .mint) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Split History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                .font(.headline)

                            Text("\(viewModel.history.count) processed track\(viewModel.history.count == 1 ? "" : "s") saved")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if viewModel.history.isEmpty {
                                Text("Split a track on the main screen to start building your reusable library.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(viewModel.history) { item in
                                        HistoryRow(item: item) {
                                            onUseAsSource(item.sourceFileURL)
                                        } onRename: {
                                            beginRenamingHistoryItem(item)
                                        } onDelete: {
                                            beginDeletingHistoryItem(item)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    LibraryCard(tint: .green) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Staging Area", systemImage: "slider.horizontal.below.rectangle")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Vocal")
                                        .font(.subheadline.weight(.semibold))

                                    Spacer()

                                    if let vocalAsset = viewModel.selectedVocalAsset {
                                        Button {
                                            beginRenamingStem(vocalAsset, role: .vocal)
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }

                                Picker("Vocal", selection: $viewModel.selectedVocalID) {
                                    Text("Select vocal").tag(Optional<StoredStemAsset.ID>.none)
                                    ForEach(viewModel.availableVocalAssets) { asset in
                                        Text(asset.displayName).tag(Optional(asset.id))
                                    }
                                }

                                if let selectedVocal = viewModel.selectedVocalAsset {
                                    Text(selectedVocal.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                timelineRow(
                                    current: viewModel.vocalStartTime,
                                    total: viewModel.selectedVocalDuration
                                )

                                Slider(
                                    value: Binding(
                                        get: { viewModel.vocalStartTime },
                                        set: { viewModel.setVocalStartTime($0) }
                                    ),
                                    in: 0...max(0.1, viewModel.maxVocalStartTime),
                                    step: 0.01
                                )
                                .disabled(viewModel.selectedVocalAsset == nil || viewModel.maxVocalStartTime <= 0)

                                precisionNudgeRow(
                                    current: viewModel.vocalStartTime,
                                    total: viewModel.selectedVocalDuration
                                ) {
                                    viewModel.nudgeVocalStartTime(by: -0.1)
                                } onMinusSmall: {
                                    viewModel.nudgeVocalStartTime(by: -0.01)
                                } onPlusSmall: {
                                    viewModel.nudgeVocalStartTime(by: 0.01)
                                } onPlusLarge: {
                                    viewModel.nudgeVocalStartTime(by: 0.1)
                                }
                                .disabled(viewModel.selectedVocalAsset == nil || viewModel.maxVocalStartTime <= 0)

                                Button {
                                    viewModel.toggleVocalPreview()
                                } label: {
                                    Label(
                                        viewModel.currentlyPreviewingRole == .vocal ? "Stop Vocal Preview" : "Preview Vocal",
                                        systemImage: viewModel.currentlyPreviewingRole == .vocal ? "stop.fill" : "play.fill"
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.selectedVocalAsset == nil)

                                if viewModel.currentlyPreviewingRole == .vocal {
                                    playheadScrubberRow(
                                        label: "Preview",
                                        current: viewModel.previewPlaybackTime,
                                        total: max(0.1, viewModel.previewPlaybackDuration)
                                    ) { position in
                                        viewModel.scrubActivePreview(to: position)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Instrumental / Bass")
                                        .font(.subheadline.weight(.semibold))

                                    Spacer()

                                    if let instrumentalAsset = viewModel.selectedInstrumentalAsset {
                                        Button {
                                            beginRenamingStem(instrumentalAsset, role: .instrumental)
                                        } label: {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }

                                Picker("Instrumental", selection: $viewModel.selectedInstrumentalID) {
                                    Text("Select instrumental").tag(Optional<StoredStemAsset.ID>.none)
                                    ForEach(viewModel.availableInstrumentalAssets) { asset in
                                        Text(asset.displayName).tag(Optional(asset.id))
                                    }
                                }

                                if let selectedInstrumental = viewModel.selectedInstrumentalAsset {
                                    Text(selectedInstrumental.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                timelineRow(
                                    current: viewModel.instrumentalStartTime,
                                    total: viewModel.selectedInstrumentalDuration
                                )

                                Slider(
                                    value: Binding(
                                        get: { viewModel.instrumentalStartTime },
                                        set: { viewModel.setInstrumentalStartTime($0) }
                                    ),
                                    in: 0...max(0.1, viewModel.maxInstrumentalStartTime),
                                    step: 0.01
                                )
                                .disabled(viewModel.selectedInstrumentalAsset == nil || viewModel.maxInstrumentalStartTime <= 0)

                                precisionNudgeRow(
                                    current: viewModel.instrumentalStartTime,
                                    total: viewModel.selectedInstrumentalDuration
                                ) {
                                    viewModel.nudgeInstrumentalStartTime(by: -0.1)
                                } onMinusSmall: {
                                    viewModel.nudgeInstrumentalStartTime(by: -0.01)
                                } onPlusSmall: {
                                    viewModel.nudgeInstrumentalStartTime(by: 0.01)
                                } onPlusLarge: {
                                    viewModel.nudgeInstrumentalStartTime(by: 0.1)
                                }
                                .disabled(viewModel.selectedInstrumentalAsset == nil || viewModel.maxInstrumentalStartTime <= 0)

                                Button {
                                    viewModel.toggleInstrumentalPreview()
                                } label: {
                                    Label(
                                        viewModel.currentlyPreviewingRole == .instrumental ? "Stop Instrumental Preview" : "Preview Instrumental",
                                        systemImage: viewModel.currentlyPreviewingRole == .instrumental ? "stop.fill" : "play.fill"
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.selectedInstrumentalAsset == nil)

                                if viewModel.currentlyPreviewingRole == .instrumental {
                                    playheadScrubberRow(
                                        label: "Preview",
                                        current: viewModel.previewPlaybackTime,
                                        total: max(0.1, viewModel.previewPlaybackDuration)
                                    ) { position in
                                        viewModel.scrubActivePreview(to: position)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Layer Delay")
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(viewModel.formattedPreciseSignedSeconds(viewModel.stageDelay))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }

                                Slider(
                                    value: Binding(
                                        get: { viewModel.stageDelay },
                                        set: { viewModel.setStageDelay($0) }
                                    ),
                                    in: viewModel.minStageDelay...viewModel.maxStageDelay,
                                    step: 0.01
                                )

                                delayNudgeRow(
                                    current: viewModel.stageDelay
                                ) {
                                    viewModel.nudgeStageDelay(by: -1.0)
                                } onMinusLarge: {
                                    viewModel.nudgeStageDelay(by: -0.1)
                                } onMinusSmall: {
                                    viewModel.nudgeStageDelay(by: -0.01)
                                } onPlusSmall: {
                                    viewModel.nudgeStageDelay(by: 0.01)
                                } onPlusLarge: {
                                    viewModel.nudgeStageDelay(by: 0.1)
                                } onPlusXL: {
                                    viewModel.nudgeStageDelay(by: 1.0)
                                }

                                Text("Positive delays instrumental. Negative delays vocal. Range: ±\(viewModel.formattedPreciseTime(viewModel.maxStageDelay)).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                viewModel.toggleStagePlayback()
                            } label: {
                                Label(
                                    viewModel.isStagePlaying ? "Stop Layered Playback" : "Play Vocal + Instrumental",
                                    systemImage: viewModel.isStagePlaying ? "stop.fill" : "play.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(viewModel.selectedVocalAsset == nil || viewModel.selectedInstrumentalAsset == nil)

                            if viewModel.isStagePlaying {
                                playheadScrubberRow(
                                    label: "Layered",
                                    current: viewModel.stagePlaybackTime,
                                    total: max(0.1, viewModel.stagePlaybackDuration)
                                ) { position in
                                    viewModel.scrubStagePlayback(to: position)
                                }
                            }

                            Button {
                                viewModel.saveCurrentLayeredMix()
                            } label: {
                                HStack(spacing: 10) {
                                    if viewModel.isSavingLayeredMix {
                                        ProgressView()
                                    }
                                    Label(
                                        viewModel.isSavingLayeredMix ? "Saving Layered Mix..." : "Save Layered Mix",
                                        systemImage: "square.and.arrow.down.fill"
                                    )
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(
                                viewModel.selectedVocalAsset == nil ||
                                viewModel.selectedInstrumentalAsset == nil ||
                                viewModel.isSavingLayeredMix
                            )

                            if viewModel.savedLayeredMixes.isEmpty {
                                Text("No saved layered mixes yet.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 10) {
                                    HStack {
                                        Label("Saved Layered Mixes", systemImage: "waveform.badge.plus")
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text("\(viewModel.savedLayeredMixes.count)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }

                                    ForEach(viewModel.savedLayeredMixes) { mix in
                                        SavedLayeredMixRow(mix: mix) {
                                            beginDeletingSavedMix(mix)
                                        }
                                    }
                                }
                            }

                            if let stageErrorText = viewModel.stageErrorText {
                                Label(stageErrorText, systemImage: "exclamationmark.triangle.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Library & Stage")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.selectedVocalID) { _ in
            viewModel.handleSelectionChanged()
        }
        .onChange(of: viewModel.selectedInstrumentalID) { _ in
            viewModel.handleSelectionChanged()
        }
        .onDisappear {
            viewModel.stopStagePlayback()
            viewModel.stopPreview()
        }
        .alert(
            "Rename",
            isPresented: Binding(
                get: { renameTarget != nil },
                set: { isPresented in
                    if !isPresented {
                        renameTarget = nil
                    }
                }
            ),
            presenting: renameTarget
        ) { target in
            TextField("Name", text: $renameDraft)
            Button("Save") {
                applyRename(target)
            }
            Button("Clear Name", role: .destructive) {
                applyRename(target, clear: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text("Set a custom name for \(target.label).")
        }
        .alert(
            "Delete Song?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { isPresented in
                    if !isPresented {
                        deleteTarget = nil
                    }
                }
            ),
            presenting: deleteTarget
        ) { target in
            Button("Delete", role: .destructive) {
                viewModel.deleteHistoryItem(id: target.id)
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text("This removes \"\(target.name)\" from history and deletes its stored files.")
        }
        .alert(
            "Delete Saved Mix?",
            isPresented: Binding(
                get: { deleteSavedMixTarget != nil },
                set: { isPresented in
                    if !isPresented {
                        deleteSavedMixTarget = nil
                    }
                }
            ),
            presenting: deleteSavedMixTarget
        ) { target in
            Button("Delete", role: .destructive) {
                viewModel.deleteSavedLayeredMix(id: target.id)
                deleteSavedMixTarget = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text("This removes \"\(target.name)\" from saved layered mixes.")
        }
    }

    private func timelineRow(current: Double, total: Double) -> some View {
        HStack {
            Text("Start: \(viewModel.formattedPreciseTime(current))")
            Spacer()
            Text("Length: \(viewModel.formattedPreciseTime(total))")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func playheadScrubberRow(
        label: String,
        current: Double,
        total: Double,
        onScrub: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(label): \(viewModel.formattedPreciseTime(current))")
                Spacer()
                Text("Total: \(viewModel.formattedPreciseTime(total))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { current },
                    set: { onScrub($0) }
                ),
                in: 0...max(0.1, total)
            )
            .tint(.green)

            Text("Drag to scrub playback while previewing.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func precisionNudgeRow(
        current: Double,
        total: Double,
        onMinusLarge: @escaping () -> Void,
        onMinusSmall: @escaping () -> Void,
        onPlusSmall: @escaping () -> Void,
        onPlusLarge: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                precisionNudgeButton("-0.10", action: onMinusLarge)
                precisionNudgeButton("-0.01", action: onMinusSmall)
                precisionNudgeButton("+0.01", action: onPlusSmall)
                precisionNudgeButton("+0.10", action: onPlusLarge)
            }

            Text("Precision: \(viewModel.formattedPreciseTime(current)) / \(viewModel.formattedPreciseTime(total))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func precisionNudgeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.monospacedDigit().weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func delayNudgeRow(
        current: Double,
        onMinusXL: @escaping () -> Void,
        onMinusLarge: @escaping () -> Void,
        onMinusSmall: @escaping () -> Void,
        onPlusSmall: @escaping () -> Void,
        onPlusLarge: @escaping () -> Void,
        onPlusXL: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                precisionNudgeButton("-1.00", action: onMinusXL)
                precisionNudgeButton("-0.10", action: onMinusLarge)
                precisionNudgeButton("-0.01", action: onMinusSmall)
                precisionNudgeButton("+0.01", action: onPlusSmall)
                precisionNudgeButton("+0.10", action: onPlusLarge)
                precisionNudgeButton("+1.00", action: onPlusXL)
            }

            Text("Delay Precision: \(viewModel.formattedPreciseSignedSeconds(current))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func beginRenamingHistoryItem(_ item: ProcessedTrackHistoryItem) {
        renameTarget = .historyItem(id: item.id, label: item.displayName)
        renameDraft = item.displayName
    }

    private func beginRenamingStem(_ item: StoredStemAsset, role: StageTrackRole) {
        let label = role == .vocal ? "vocal track" : "instrumental track"
        renameTarget = .stemAsset(id: item.id, label: label)
        renameDraft = item.displayName
    }

    private func applyRename(_ target: RenameTarget, clear: Bool = false) {
        let newName = clear ? nil : renameDraft

        switch target {
        case .historyItem(let id, _):
            viewModel.renameHistoryItem(id: id, newName: newName)
        case .stemAsset(let id, _):
            viewModel.renameStemAsset(id: id, newName: newName)
        }

        renameTarget = nil
    }

    private func beginDeletingHistoryItem(_ item: ProcessedTrackHistoryItem) {
        deleteTarget = DeleteTarget(id: item.id, name: item.displayName)
    }

    private func beginDeletingSavedMix(_ mix: SavedLayeredMix) {
        deleteSavedMixTarget = DeleteSavedMixTarget(id: mix.id, name: mix.displayName)
    }
}

private struct HistoryRow: View {
    let item: ProcessedTrackHistoryItem
    let onUseAsSource: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    if item.displayName != item.sourceFileName {
                        Text(item.sourceFileName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Use as Source", action: onUseAsSource)
                    .buttonStyle(.bordered)
                Button(action: onRename) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }

            if !item.stems.isEmpty {
                Text(item.stems.map { $0.kind.rawValue.capitalized }.joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DeleteTarget: Identifiable {
    let id: UUID
    let name: String
}

private struct DeleteSavedMixTarget: Identifiable {
    let id: UUID
    let name: String
}

private struct SavedLayeredMixRow: View {
    let mix: SavedLayeredMix
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mix.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Text("Delay: \(mix.delaySeconds, specifier: "%+.1fs")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(mix.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ShareLink(item: mix.fileURL) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private enum RenameTarget: Identifiable {
    case historyItem(id: UUID, label: String)
    case stemAsset(id: UUID, label: String)

    var id: String {
        switch self {
        case .historyItem(let id, _):
            return "history-\(id.uuidString)"
        case .stemAsset(let id, _):
            return "stem-\(id.uuidString)"
        }
    }

    var label: String {
        switch self {
        case .historyItem(_, let label):
            return label
        case .stemAsset(_, let label):
            return label
        }
    }
}

private struct LibraryCard<Content: View>: View {
    let tint: Color
    let content: Content

    init(tint: Color = .blue, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.12), radius: 14, x: 0, y: 10)
    }
}
