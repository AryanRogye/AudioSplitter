import SwiftUI

struct LibraryStageStyleLabView: View {
    @ObservedObject var viewModel: AudioLibraryViewModel
    let onUseAsSource: (URL) -> Void

    @State private var renameTarget: StyleLabRenameTarget?
    @State private var deleteTarget: StyleLabDeleteTarget?
    @State private var deleteSavedMixTarget: StyleLabDeleteSavedMixTarget?
    @State private var renameDraft = ""

    @State private var posterStep: PosterFlowStep = .library
    @State private var tapeSearchText = ""
    @State private var tapeSavedMixesExpanded = true

    @State private var cueA: StageCuePreset?
    @State private var cueB: StageCuePreset?

    @State private var clipZoom: Double = 1.25
    @State private var clipSnapEnabled = true
    @State private var timelinePlayheadTime: Double = 0

    var body: some View {
        TabView {
            tapeStudioTab
                .tabItem {
                    Label("Tape Studio", systemImage: "opticaldisc.fill")
                }

            posterFlowTab
                .tabItem {
                    Label("Poster Flow", systemImage: "sparkles.square.filled.on.square")
                }

            clipTimelineTab
                .tabItem {
                    Label("Clip Timeline", systemImage: "timeline.selection")
                }
        }
        .navigationTitle("Library + Stage Styles")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.selectedVocalID) { _, _ in
            viewModel.handleSelectionChanged()
        }
        .onChange(of: viewModel.selectedInstrumentalID) { _, _ in
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

    private var filteredHistory: [ProcessedTrackHistoryItem] {
        let query = tapeSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.history }

        return viewModel.history.filter { item in
            item.displayName.localizedCaseInsensitiveContains(query) ||
            item.sourceFileName.localizedCaseInsensitiveContains(query)
        }
    }

    private var tapeStudioTab: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.96, blue: 0.89),
                    Color(red: 0.95, green: 0.90, blue: 0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tape Studio")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(Color(red: 0.25, green: 0.17, blue: 0.08))

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            tapeLibraryPane
                                .frame(maxWidth: 360)
                            tapeStagePane
                        }

                        VStack(spacing: 14) {
                            tapeLibraryPane
                            tapeStagePane
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 26)
            }
        }
    }

    private var tapeLibraryPane: some View {
        tapeCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Library Crate", systemImage: "shippingbox.fill")
                    .font(.headline)

                TextField("Filter tracks", text: $tapeSearchText)
                    .textFieldStyle(.roundedBorder)

                if filteredHistory.isEmpty {
                    Text(tapeSearchText.isEmpty ? "No processed tracks yet." : "No matches for \"\(tapeSearchText)\".")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredHistory.prefix(8)) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Capsule()
                                .fill(Color.black.opacity(0.10))
                                .frame(width: 12, height: 36)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if item.displayName != item.sourceFileName {
                                    Text(item.sourceFileName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            Menu {
                                Button("Use as Source") {
                                    onUseAsSource(item.sourceFileURL)
                                }
                                Button("Rename") {
                                    beginRenamingHistoryItem(item)
                                }
                                Button("Delete", role: .destructive) {
                                    beginDeletingHistoryItem(item)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private var tapeStagePane: some View {
        tapeCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Stage Desk", systemImage: "dial.medium.fill")
                    .font(.headline)

                cueRack

                Divider()

                vocalSectionTape
                instrumentalSectionTape
                delaySectionTape

                HStack(spacing: 10) {
                    Button {
                        viewModel.toggleStagePlayback()
                    } label: {
                        Label(
                            viewModel.isStagePlaying ? "Stop Layered" : "Play Layered",
                            systemImage: viewModel.isStagePlaying ? "stop.fill" : "play.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(viewModel.selectedVocalAsset == nil || viewModel.selectedInstrumentalAsset == nil)

                    Button {
                        viewModel.saveCurrentLayeredMix()
                    } label: {
                        Label(
                            viewModel.isSavingLayeredMix ? "Saving..." : "Save Mix",
                            systemImage: "square.and.arrow.down.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.brown)
                    .disabled(
                        viewModel.selectedVocalAsset == nil ||
                        viewModel.selectedInstrumentalAsset == nil ||
                        viewModel.isSavingLayeredMix
                    )
                }

                if viewModel.currentlyPreviewingRole != nil {
                    playheadScrubber(
                        label: "Preview",
                        current: viewModel.previewPlaybackTime,
                        total: max(0.1, viewModel.previewPlaybackDuration),
                        tint: .orange,
                        textColor: .secondary
                    ) { position in
                        viewModel.scrubActivePreview(to: position)
                    }
                }

                if viewModel.isStagePlaying {
                    playheadScrubber(
                        label: "Layered",
                        current: viewModel.stagePlaybackTime,
                        total: max(0.1, viewModel.stagePlaybackDuration),
                        tint: .brown,
                        textColor: .secondary
                    ) { position in
                        viewModel.scrubStagePlayback(to: position)
                    }
                }

                DisclosureGroup("Saved Mixes", isExpanded: $tapeSavedMixesExpanded) {
                    savedMixesSection(primary: .primary, secondary: .secondary, tint: .brown)
                }

                if let stageErrorText = viewModel.stageErrorText {
                    Text(stageErrorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var cueRack: some View {
        HStack(spacing: 8) {
            cueButton(label: "Store A", tint: .brown) {
                cueA = currentCue
            }
            cueButton(label: "Recall A", tint: .brown) {
                if let cueA {
                    applyCue(cueA)
                }
            }
            .disabled(cueA == nil)

            cueButton(label: "Store B", tint: .orange) {
                cueB = currentCue
            }
            cueButton(label: "Recall B", tint: .orange) {
                if let cueB {
                    applyCue(cueB)
                }
            }
            .disabled(cueB == nil)
        }
    }

    private var currentCue: StageCuePreset {
        StageCuePreset(
            vocalStart: viewModel.vocalStartTime,
            instrumentalStart: viewModel.instrumentalStartTime,
            stageDelay: viewModel.stageDelay
        )
    }

    private func applyCue(_ cue: StageCuePreset) {
        viewModel.setVocalStartTime(cue.vocalStart)
        viewModel.setInstrumentalStartTime(cue.instrumentalStart)
        viewModel.setStageDelay(cue.stageDelay)
    }

    private var vocalSectionTape: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vocal")
                .font(.subheadline.weight(.semibold))

            Picker("Vocal", selection: $viewModel.selectedVocalID) {
                Text("Select vocal").tag(Optional<StoredStemAsset.ID>.none)
                ForEach(viewModel.availableVocalAssets) { asset in
                    Text(asset.displayName).tag(Optional(asset.id))
                }
            }

            HStack {
                Text("Start: \(viewModel.formattedPreciseTime(viewModel.vocalStartTime))")
                    .font(.caption.monospacedDigit())
                Spacer()
                Button {
                    viewModel.toggleVocalPreview()
                } label: {
                    Label(
                        viewModel.currentlyPreviewingRole == .vocal ? "Stop" : "Preview",
                        systemImage: viewModel.currentlyPreviewingRole == .vocal ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(viewModel.selectedVocalAsset == nil)
            }

            Stepper("Fine ±0.01") {
                viewModel.nudgeVocalStartTime(by: 0.01)
            } onDecrement: {
                viewModel.nudgeVocalStartTime(by: -0.01)
            }
            .disabled(viewModel.selectedVocalAsset == nil)

            Stepper("Coarse ±0.10") {
                viewModel.nudgeVocalStartTime(by: 0.1)
            } onDecrement: {
                viewModel.nudgeVocalStartTime(by: -0.1)
            }
            .disabled(viewModel.selectedVocalAsset == nil)
        }
    }

    private var instrumentalSectionTape: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instrumental")
                .font(.subheadline.weight(.semibold))

            Picker("Instrumental", selection: $viewModel.selectedInstrumentalID) {
                Text("Select instrumental").tag(Optional<StoredStemAsset.ID>.none)
                ForEach(viewModel.availableInstrumentalAssets) { asset in
                    Text(asset.displayName).tag(Optional(asset.id))
                }
            }

            HStack {
                Text("Start: \(viewModel.formattedPreciseTime(viewModel.instrumentalStartTime))")
                    .font(.caption.monospacedDigit())
                Spacer()
                Button {
                    viewModel.toggleInstrumentalPreview()
                } label: {
                    Label(
                        viewModel.currentlyPreviewingRole == .instrumental ? "Stop" : "Preview",
                        systemImage: viewModel.currentlyPreviewingRole == .instrumental ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(viewModel.selectedInstrumentalAsset == nil)
            }

            Stepper("Fine ±0.01") {
                viewModel.nudgeInstrumentalStartTime(by: 0.01)
            } onDecrement: {
                viewModel.nudgeInstrumentalStartTime(by: -0.01)
            }
            .disabled(viewModel.selectedInstrumentalAsset == nil)

            Stepper("Coarse ±0.10") {
                viewModel.nudgeInstrumentalStartTime(by: 0.1)
            } onDecrement: {
                viewModel.nudgeInstrumentalStartTime(by: -0.1)
            }
            .disabled(viewModel.selectedInstrumentalAsset == nil)
        }
    }

    private var delaySectionTape: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Delay")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(viewModel.formattedPreciseSignedSeconds(viewModel.stageDelay))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Stepper("Fine ±0.01") {
                viewModel.nudgeStageDelay(by: 0.01)
            } onDecrement: {
                viewModel.nudgeStageDelay(by: -0.01)
            }

            Stepper("Coarse ±0.10") {
                viewModel.nudgeStageDelay(by: 0.1)
            } onDecrement: {
                viewModel.nudgeStageDelay(by: -0.1)
            }
        }
    }

    private var posterFlowTab: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.44, blue: 0.28),
                    Color(red: 1.0, green: 0.77, blue: 0.24),
                    Color(red: 0.15, green: 0.65, blue: 0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Mix Festival Flow")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.black)

                    Picker("Step", selection: $posterStep) {
                        ForEach(PosterFlowStep.allCases) { step in
                            Text(step.title).tag(step)
                        }
                    }
                    .pickerStyle(.segmented)

                    if posterStep == .library {
                        posterLibraryStep
                    } else if posterStep == .align {
                        posterAlignStep
                    } else {
                        posterPerformStep
                    }

                    HStack(spacing: 10) {
                        Button("Back") {
                            posterStep = posterStep.previous
                        }
                        .buttonStyle(.bordered)
                        .tint(.black)
                        .disabled(posterStep == .library)

                        Button("Next") {
                            posterStep = posterStep.next
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.black)
                        .disabled(posterStep == .perform)
                    }
                }
                .padding(16)
                .padding(.bottom, 26)
            }
        }
    }

    private var posterLibraryStep: some View {
        posterCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Step 1: Library + Selection")
                    .font(.headline.weight(.black))

                if viewModel.history.isEmpty {
                    Text("No processed tracks yet. Split one on the main screen.")
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.65))
                } else {
                    ForEach(viewModel.history.prefix(6)) { item in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName)
                                    .font(.subheadline.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)

                                Text(item.sourceFileName)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(.black.opacity(0.62))
                            }

                            Spacer()

                            Button("Use") {
                                onUseAsSource(item.sourceFileURL)
                            }
                            .buttonStyle(.bordered)
                            .tint(.black)

                            Menu {
                                Button("Rename") {
                                    beginRenamingHistoryItem(item)
                                }
                                Button("Delete", role: .destructive) {
                                    beginDeletingHistoryItem(item)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                Picker("Vocal", selection: $viewModel.selectedVocalID) {
                    Text("Select vocal").tag(Optional<StoredStemAsset.ID>.none)
                    ForEach(viewModel.availableVocalAssets) { asset in
                        Text(asset.displayName).tag(Optional(asset.id))
                    }
                }

                Picker("Instrumental", selection: $viewModel.selectedInstrumentalID) {
                    Text("Select instrumental").tag(Optional<StoredStemAsset.ID>.none)
                    ForEach(viewModel.availableInstrumentalAssets) { asset in
                        Text(asset.displayName).tag(Optional(asset.id))
                    }
                }
            }
        }
    }

    private var posterAlignStep: some View {
        posterCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Step 2: Align")
                    .font(.headline.weight(.black))

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        posterVocalAlign
                        posterInstrumentAlign
                    }

                    VStack(spacing: 12) {
                        posterVocalAlign
                        posterInstrumentAlign
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Delay")
                            .font(.subheadline.weight(.black))
                        Spacer()
                        Text(viewModel.formattedPreciseSignedSeconds(viewModel.stageDelay))
                            .font(.caption.monospacedDigit())
                    }

                    Slider(
                        value: Binding(
                            get: { viewModel.stageDelay },
                            set: { viewModel.setStageDelay($0) }
                        ),
                        in: viewModel.minStageDelay...viewModel.maxStageDelay,
                        step: 0.01
                    )
                    .tint(.black)

                    nudgeChips(
                        labels: ["-1.00", "-0.10", "-0.01", "+0.01", "+0.10", "+1.00"],
                        tint: .black
                    ) { label in
                        let value = Double(label) ?? 0
                        viewModel.nudgeStageDelay(by: value)
                    }
                }
            }
        }
    }

    private var posterVocalAlign: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vocal")
                .font(.subheadline.weight(.black))

            Text(viewModel.formattedPreciseTime(viewModel.vocalStartTime))
                .font(.caption.monospacedDigit())

            Slider(
                value: Binding(
                    get: { viewModel.vocalStartTime },
                    set: { viewModel.setVocalStartTime($0) }
                ),
                in: 0...max(0.1, viewModel.maxVocalStartTime),
                step: 0.01
            )
            .tint(.black)
            .disabled(viewModel.selectedVocalAsset == nil)

            nudgeChips(labels: ["-0.10", "-0.01", "+0.01", "+0.10"], tint: .black) { label in
                let value = Double(label) ?? 0
                viewModel.nudgeVocalStartTime(by: value)
            }
            .disabled(viewModel.selectedVocalAsset == nil)

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
            .tint(.black)
            .disabled(viewModel.selectedVocalAsset == nil)
        }
        .padding(10)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var posterInstrumentAlign: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instrumental")
                .font(.subheadline.weight(.black))

            Text(viewModel.formattedPreciseTime(viewModel.instrumentalStartTime))
                .font(.caption.monospacedDigit())

            Slider(
                value: Binding(
                    get: { viewModel.instrumentalStartTime },
                    set: { viewModel.setInstrumentalStartTime($0) }
                ),
                in: 0...max(0.1, viewModel.maxInstrumentalStartTime),
                step: 0.01
            )
            .tint(.black)
            .disabled(viewModel.selectedInstrumentalAsset == nil)

            nudgeChips(labels: ["-0.10", "-0.01", "+0.01", "+0.10"], tint: .black) { label in
                let value = Double(label) ?? 0
                viewModel.nudgeInstrumentalStartTime(by: value)
            }
            .disabled(viewModel.selectedInstrumentalAsset == nil)

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
            .tint(.black)
            .disabled(viewModel.selectedInstrumentalAsset == nil)
        }
        .padding(10)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var posterPerformStep: some View {
        posterCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Step 3: Perform + Save")
                    .font(.headline.weight(.black))

                HStack(spacing: 10) {
                    Button {
                        viewModel.toggleStagePlayback()
                    } label: {
                        Label(
                            viewModel.isStagePlaying ? "Stop Layered" : "Play Layered",
                            systemImage: viewModel.isStagePlaying ? "stop.fill" : "play.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                    .disabled(viewModel.selectedVocalAsset == nil || viewModel.selectedInstrumentalAsset == nil)

                    Button {
                        viewModel.saveCurrentLayeredMix()
                    } label: {
                        Label(
                            viewModel.isSavingLayeredMix ? "Saving..." : "Save Mix",
                            systemImage: "square.and.arrow.down.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.black)
                    .disabled(
                        viewModel.selectedVocalAsset == nil ||
                        viewModel.selectedInstrumentalAsset == nil ||
                        viewModel.isSavingLayeredMix
                    )
                }

                if viewModel.currentlyPreviewingRole != nil {
                    playheadScrubber(
                        label: "Preview",
                        current: viewModel.previewPlaybackTime,
                        total: max(0.1, viewModel.previewPlaybackDuration),
                        tint: .black,
                        textColor: .secondary
                    ) { position in
                        viewModel.scrubActivePreview(to: position)
                    }
                }

                if viewModel.isStagePlaying {
                    playheadScrubber(
                        label: "Layered",
                        current: viewModel.stagePlaybackTime,
                        total: max(0.1, viewModel.stagePlaybackDuration),
                        tint: .black,
                        textColor: .secondary
                    ) { position in
                        viewModel.scrubStagePlayback(to: position)
                    }
                }

                savedMixesSection(primary: .black, secondary: .secondary, tint: .black)
            }
        }
    }

    private var clipTimelineTab: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.10),
                    Color(red: 0.10, green: 0.11, blue: 0.14),
                    Color(red: 0.06, green: 0.07, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Clip Timeline")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    clipCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Timeline", systemImage: "timeline.selection")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)

                                Spacer()

                                Toggle("Snap", isOn: $clipSnapEnabled)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .tint(.cyan)
                            }

                            HStack {
                                Text("Zoom")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Slider(value: $clipZoom, in: 0.5...3.0, step: 0.05)
                                    .tint(.cyan)
                                Text(String(format: "%.1fx", clipZoom))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Text("Span: \(formattedTimelineDuration(clipTimelineDuration))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }

                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 10) {
                                    Picker("Vocal", selection: $viewModel.selectedVocalID) {
                                        Text("Select vocal")
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                            .tag(Optional<StoredStemAsset.ID>.none)
                                        ForEach(viewModel.availableVocalAssets) { asset in
                                            Text(asset.displayName)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.75)
                                                .tag(Optional(asset.id))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)

                                    Picker("Instrumental", selection: $viewModel.selectedInstrumentalID) {
                                        Text("Select instrumental")
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                            .tag(Optional<StoredStemAsset.ID>.none)
                                        ForEach(viewModel.availableInstrumentalAssets) { asset in
                                            Text(asset.displayName)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.75)
                                                .tag(Optional(asset.id))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }

                                VStack(spacing: 10) {
                                    Picker("Vocal", selection: $viewModel.selectedVocalID) {
                                        Text("Select vocal")
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                            .tag(Optional<StoredStemAsset.ID>.none)
                                        ForEach(viewModel.availableVocalAssets) { asset in
                                            Text(asset.displayName)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.75)
                                                .tag(Optional(asset.id))
                                        }
                                    }

                                    Picker("Instrumental", selection: $viewModel.selectedInstrumentalID) {
                                        Text("Select instrumental")
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                            .tag(Optional<StoredStemAsset.ID>.none)
                                        ForEach(viewModel.availableInstrumentalAssets) { asset in
                                            Text(asset.displayName)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.75)
                                                .tag(Optional(asset.id))
                                        }
                                    }
                                }
                            }

                            fullTimelineEditor

                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 8) {
                                    clipControlStrip(
                                        label: "Vocals",
                                        tint: .pink,
                                        onPreview: { viewModel.toggleVocalPreview() },
                                        isPreviewing: viewModel.currentlyPreviewingRole == .vocal,
                                        isDisabled: viewModel.selectedVocalAsset == nil
                                    ) { delta in
                                        viewModel.nudgeVocalStartTime(by: delta)
                                    }

                                    clipControlStrip(
                                        label: "Instrumental",
                                        tint: .cyan,
                                        onPreview: { viewModel.toggleInstrumentalPreview() },
                                        isPreviewing: viewModel.currentlyPreviewingRole == .instrumental,
                                        isDisabled: viewModel.selectedInstrumentalAsset == nil
                                    ) { delta in
                                        viewModel.nudgeInstrumentalStartTime(by: delta)
                                    }
                                }

                                VStack(spacing: 8) {
                                    clipControlStrip(
                                        label: "Vocals",
                                        tint: .pink,
                                        onPreview: { viewModel.toggleVocalPreview() },
                                        isPreviewing: viewModel.currentlyPreviewingRole == .vocal,
                                        isDisabled: viewModel.selectedVocalAsset == nil
                                    ) { delta in
                                        viewModel.nudgeVocalStartTime(by: delta)
                                    }

                                    clipControlStrip(
                                        label: "Instrumental",
                                        tint: .cyan,
                                        onPreview: { viewModel.toggleInstrumentalPreview() },
                                        isPreviewing: viewModel.currentlyPreviewingRole == .instrumental,
                                        isDisabled: viewModel.selectedInstrumentalAsset == nil
                                    ) { delta in
                                        viewModel.nudgeInstrumentalStartTime(by: delta)
                                    }
                                }
                            }
                        }
                    }

                    clipCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Perform", systemImage: "play.rectangle.on.rectangle")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            HStack(spacing: 10) {
                                Button {
                                    viewModel.toggleStagePlayback()
                                } label: {
                                    Label(
                                        viewModel.isStagePlaying ? "Stop Layered" : "Play Layered",
                                        systemImage: viewModel.isStagePlaying ? "stop.fill" : "play.fill"
                                    )
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.mint)
                                .disabled(viewModel.selectedVocalAsset == nil || viewModel.selectedInstrumentalAsset == nil)

                                Button {
                                    viewModel.saveCurrentLayeredMix()
                                } label: {
                                    Label(
                                        viewModel.isSavingLayeredMix ? "Saving..." : "Save Mix",
                                        systemImage: "square.and.arrow.down.fill"
                                    )
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.mint)
                                .disabled(
                                    viewModel.selectedVocalAsset == nil ||
                                    viewModel.selectedInstrumentalAsset == nil ||
                                    viewModel.isSavingLayeredMix
                                )
                            }

                            if viewModel.currentlyPreviewingRole != nil {
                                playheadScrubber(
                                    label: "Preview",
                                    current: viewModel.previewPlaybackTime,
                                    total: max(0.1, viewModel.previewPlaybackDuration),
                                    tint: .cyan,
                                    textColor: .white.opacity(0.75)
                                ) { position in
                                    viewModel.scrubActivePreview(to: position)
                                }
                            }

                            if viewModel.isStagePlaying {
                                playheadScrubber(
                                    label: "Layered",
                                    current: viewModel.stagePlaybackTime,
                                    total: max(0.1, viewModel.stagePlaybackDuration),
                                    tint: .mint,
                                    textColor: .white.opacity(0.75)
                                ) { position in
                                    viewModel.scrubStagePlayback(to: position)
                                }
                            }
                        }
                    }

                    clipCard {
                        savedMixesSection(primary: .white, secondary: .white.opacity(0.75), tint: .mint)
                    }

                    if let stageErrorText = viewModel.stageErrorText {
                        Text(stageErrorText)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .padding(16)
                .padding(.bottom, 26)
            }
        }
    }

    private var clipTimelineDuration: Double {
        let vocalDuration = max(0.1, viewModel.selectedVocalDuration)
        let instrumentalDuration = max(0.1, viewModel.selectedInstrumentalDuration)
        let vocalEnd = viewModel.vocalStartTime + vocalDuration
        let instrumentalEnd = viewModel.instrumentalStartTime + instrumentalDuration
        let base = max(vocalEnd, instrumentalEnd)
        return max(45, base + abs(viewModel.stageDelay) + 20)
    }

    private var timelinePointsPerSecond: CGFloat {
        CGFloat(56 * clipZoom)
    }

    private var timelineInset: CGFloat {
        24
    }

    private var timelineHeaderColumnWidth: CGFloat {
        178
    }

    private var timelineLaneHeight: CGFloat {
        84
    }

    private var timelineRulerHeight: CGFloat {
        40
    }

    private var timelineLaneSpacing: CGFloat {
        10
    }

    private var timelineContentWidth: CGFloat {
        (CGFloat(clipTimelineDuration) * timelinePointsPerSecond) + (timelineInset * 2)
    }

    private var fullTimelineEditor: some View {
        GeometryReader { proxy in
            let viewportWidth = max(240, proxy.size.width - timelineHeaderColumnWidth - 10)
            let contentWidth = max(viewportWidth, timelineContentWidth)
            let timelineHeight = timelineRulerHeight + (timelineLaneHeight * 3) + (timelineLaneSpacing * 2)

            HStack(alignment: .top, spacing: 10) {
                timelineLaneHeaders
                    .frame(width: timelineHeaderColumnWidth, height: timelineHeight, alignment: .topLeading)

                ScrollView(.horizontal, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        timelineGridBackdrop(contentWidth: contentWidth, totalHeight: timelineHeight)

                        VStack(alignment: .leading, spacing: timelineLaneSpacing) {
                            timelineRuler(contentWidth: contentWidth)

                            timelineTrackLane(
                                clipName: viewModel.selectedVocalAsset?.displayName ?? "No vocal selected",
                                startTime: viewModel.vocalStartTime,
                                clipDuration: max(0.1, viewModel.selectedVocalDuration),
                                tint: .pink,
                                contentWidth: contentWidth,
                                maxStart: max(0, viewModel.maxVocalStartTime),
                                isActive: viewModel.selectedVocalAsset != nil
                            ) { value in
                                viewModel.setVocalStartTime(value)
                            }

                            timelineTrackLane(
                                clipName: viewModel.selectedInstrumentalAsset?.displayName ?? "No instrumental selected",
                                startTime: viewModel.instrumentalStartTime,
                                clipDuration: max(0.1, viewModel.selectedInstrumentalDuration),
                                tint: .cyan,
                                contentWidth: contentWidth,
                                maxStart: max(0, viewModel.maxInstrumentalStartTime),
                                isActive: viewModel.selectedInstrumentalAsset != nil
                            ) { value in
                                viewModel.setInstrumentalStartTime(value)
                            }

                            timelineDelayLane(contentWidth: contentWidth)
                        }
                        .padding(.vertical, 8)

                        timelinePlayheadIndicator(contentWidth: contentWidth, totalHeight: timelineHeight)
                    }
                    .frame(width: contentWidth, height: timelineHeight + 16, alignment: .topLeading)
                }
                .frame(height: timelineHeight + 16)
            }
        }
        .frame(height: 332)
        .onAppear {
            syncTimelinePlayhead()
        }
        .onChange(of: viewModel.stagePlaybackTime) { _, _ in
            syncTimelinePlayhead()
        }
        .onChange(of: viewModel.previewPlaybackTime) { _, _ in
            syncTimelinePlayhead()
        }
        .onChange(of: viewModel.vocalStartTime) { _, _ in
            if !viewModel.isStagePlaying && viewModel.currentlyPreviewingRole == nil {
                syncTimelinePlayhead()
            }
        }
        .onChange(of: viewModel.instrumentalStartTime) { _, _ in
            if !viewModel.isStagePlaying && viewModel.currentlyPreviewingRole == nil {
                syncTimelinePlayhead()
            }
        }
    }

    private var timelineLaneHeaders: some View {
        VStack(alignment: .leading, spacing: timelineLaneSpacing) {
            timelineHeaderRow(
                title: "Ruler",
                subtitle: "Drag anywhere to scrub timeline",
                value: viewModel.formattedPreciseTime(timelinePlayheadTime),
                accent: .orange,
                rowHeight: timelineRulerHeight
            )

            timelineHeaderRow(
                title: "Vocals",
                subtitle: viewModel.selectedVocalAsset?.displayName ?? "Select a vocal to begin",
                value: viewModel.formattedPreciseTime(viewModel.vocalStartTime),
                accent: .pink,
                rowHeight: timelineLaneHeight
            )

            timelineHeaderRow(
                title: "Instrumental",
                subtitle: viewModel.selectedInstrumentalAsset?.displayName ?? "Select an instrumental to begin",
                value: viewModel.formattedPreciseTime(viewModel.instrumentalStartTime),
                accent: .cyan,
                rowHeight: timelineLaneHeight
            )

            timelineHeaderRow(
                title: "Delay",
                subtitle: "Shift instrumental against vocals",
                value: viewModel.formattedPreciseSignedSeconds(viewModel.stageDelay),
                accent: .mint,
                rowHeight: timelineLaneHeight
            )
        }
    }

    private func timelineHeaderRow(
        title: String,
        subtitle: String,
        value: String,
        accent: Color,
        rowHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 6)
                Text(value)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(height: rowHeight, alignment: .center)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accent.opacity(0.26), lineWidth: 1)
        }
    }

    private func timelineGridBackdrop(contentWidth: CGFloat, totalHeight: CGFloat) -> some View {
        let halfSecondCount = max(1, Int((clipTimelineDuration * 2).rounded(.up)))

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.34))

            ForEach(0...halfSecondCount, id: \.self) { index in
                let second = Double(index) * 0.5
                let x = timelineX(for: second)
                let isWholeSecond = index % 2 == 0

                Rectangle()
                    .fill(Color.white.opacity(isWholeSecond ? 0.12 : 0.05))
                    .frame(width: 1, height: totalHeight + 16)
                    .offset(x: x)
            }
        }
    }

    private func timelineRuler(contentWidth: CGFloat) -> some View {
        let secondCount = max(1, Int(clipTimelineDuration.rounded(.up)))

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))

            ForEach(0...secondCount, id: \.self) { second in
                let x = timelineX(for: Double(second))
                let isMajor = second % 5 == 0

                Rectangle()
                    .fill(Color.white.opacity(isMajor ? 0.42 : 0.20))
                    .frame(width: 1, height: isMajor ? timelineRulerHeight - 10 : 11)
                    .offset(x: x, y: isMajor ? 5 : timelineRulerHeight - 14)

                if isMajor {
                    Text(formattedTimelineDuration(Double(second)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .offset(x: x + 4, y: 4)
                }
            }
        }
        .frame(width: contentWidth, height: timelineRulerHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let newTime = snappedTimelineTime(timeForX(value.location.x, contentWidth: contentWidth))
                    timelinePlayheadTime = newTime
                    scrubTimelinePlayhead(to: newTime)
                }
        )
    }

    private func timelineTrackLane(
        clipName: String,
        startTime: Double,
        clipDuration: Double,
        tint: Color,
        contentWidth: CGFloat,
        maxStart: Double,
        isActive: Bool,
        onMove: @escaping (Double) -> Void
    ) -> some View {
        let width = max(320, CGFloat(max(0.1, clipDuration)) * timelinePointsPerSecond)
        let minX = timelineInset
        let maxX = max(minX, contentWidth - timelineInset - width)
        let clipX = min(max(timelineX(for: startTime), minX), maxX)
        let clipTint = isActive ? tint : .gray

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .offset(y: (timelineLaneHeight / 2) - 0.5)

            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [clipTint.opacity(0.56), clipTint.opacity(0.30)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: timelineLaneHeight - 16)
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(clipTint.opacity(0.95), lineWidth: 1.4)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<70, id: \.self) { index in
                            let level = 0.18 + abs(sin(Double(index) * 0.34)) * 0.82
                            Capsule()
                                .fill(Color.white.opacity(0.28 + (level * 0.32)))
                                .frame(width: 2, height: 8 + CGFloat(level * 22))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 9)
                }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(clipName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .truncationMode(.middle)

                        Text("\(viewModel.formattedPreciseTime(startTime)) - \(viewModel.formattedPreciseTime(startTime + clipDuration))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.74))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(clipTint.opacity(0.92))
                        .frame(width: 6, height: 36)
                        .padding(.leading, 6)
                }
                .overlay(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(clipTint.opacity(0.92))
                        .frame(width: 6, height: 36)
                        .padding(.trailing, 6)
                }
                .shadow(color: clipTint.opacity(0.24), radius: 7, x: 0, y: 3)
                .offset(x: clipX, y: 8)
                .allowsHitTesting(isActive)
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            let proposedX = clipX + value.translation.width
                            let clampedX = min(max(minX, proposedX), maxX)
                            let proposedTime = Double((clampedX - timelineInset) / timelinePointsPerSecond)
                            let clampedTime = min(max(0, proposedTime), maxStart)
                            onMove(snappedTimelineTime(clampedTime))
                        }
                )
        }
        .frame(width: contentWidth, height: timelineLaneHeight)
    }

    private func timelineDelayLane(contentWidth: CGFloat) -> some View {
        let minX = timelineInset
        let maxX = max(minX, contentWidth - timelineInset)
        let range = max(0.0001, viewModel.maxStageDelay - viewModel.minStageDelay)
        let ratio = (viewModel.stageDelay - viewModel.minStageDelay) / range
        let knobX = minX + (maxX - minX) * CGFloat(ratio)

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 2)
                .offset(x: minX, y: (timelineLaneHeight / 2) - 1)
                .frame(width: maxX - minX, alignment: .leading)

            Rectangle()
                .fill(Color.mint.opacity(0.5))
                .frame(width: max(0, knobX - minX), height: 3)
                .offset(x: minX, y: (timelineLaneHeight / 2) - 1.5)

            Capsule()
                .fill(Color.mint.opacity(0.35))
                .frame(width: 24, height: timelineLaneHeight - 24)
                .overlay {
                    Capsule()
                        .stroke(Color.mint.opacity(0.95), lineWidth: 1.3)
                }
                .offset(x: knobX - 12, y: 12)
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            let proposedX = knobX + value.translation.width
                            let clampedX = min(max(minX, proposedX), maxX)
                            let normalized = Double((clampedX - minX) / max(1, maxX - minX))
                            let rawDelay = viewModel.minStageDelay + (normalized * range)
                            viewModel.setStageDelay(snappedDelayValue(rawDelay))
                        }
                )

            Text("Drag delay clip to align instrumental pocket")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 12)
                .offset(y: 8)
        }
        .frame(width: contentWidth, height: timelineLaneHeight)
    }

    private func timelinePlayheadIndicator(contentWidth: CGFloat, totalHeight: CGFloat) -> some View {
        let clampedX = min(max(timelineInset, timelineX(for: timelinePlayheadTime)), contentWidth - timelineInset)

        return VStack(spacing: 0) {
            Capsule()
                .fill(Color.orange)
                .frame(width: 62, height: 22)
                .overlay {
                    Text(viewModel.formattedPreciseTime(timelinePlayheadTime))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 5)
                }

            Rectangle()
                .fill(Color.orange.opacity(0.96))
                .frame(width: 2, height: totalHeight - 22)
        }
        .offset(x: clampedX - 1, y: 0)
        .shadow(color: Color.orange.opacity(0.33), radius: 5, x: 0, y: 2)
        .allowsHitTesting(false)
    }

    private func clipControlStrip(
        label: String,
        tint: Color,
        onPreview: @escaping () -> Void,
        isPreviewing: Bool,
        isDisabled: Bool,
        onNudge: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Button {
                    onPreview()
                } label: {
                    Label(isPreviewing ? "Stop" : "Preview", systemImage: isPreviewing ? "stop.fill" : "play.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .buttonStyle(.bordered)
                .tint(tint)
                .disabled(isDisabled)
            }

            nudgeChips(labels: ["-0.10", "-0.01", "+0.01", "+0.10"], tint: tint) { label in
                let value = Double(label) ?? 0
                onNudge(value)
            }
            .disabled(isDisabled)
        }
        .padding(8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
    }

    private func snappedTimelineTime(_ value: Double) -> Double {
        let bounded = min(max(0, value), clipTimelineDuration)
        guard clipSnapEnabled else { return bounded }
        return snapValue(bounded, step: 0.01)
    }

    private func snappedDelayValue(_ value: Double) -> Double {
        let bounded = min(max(viewModel.minStageDelay, value), viewModel.maxStageDelay)
        guard clipSnapEnabled else { return bounded }
        return snapValue(bounded, step: 0.01)
    }

    private func snapValue(_ value: Double, step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    private func timelineX(for time: Double) -> CGFloat {
        timelineInset + CGFloat(max(0, time)) * timelinePointsPerSecond
    }

    private func timeForX(_ x: CGFloat, contentWidth: CGFloat) -> Double {
        let clamped = min(max(timelineInset, x), contentWidth - timelineInset)
        return Double((clamped - timelineInset) / timelinePointsPerSecond)
    }

    private func scrubTimelinePlayhead(to time: Double) {
        if viewModel.isStagePlaying {
            viewModel.scrubStagePlayback(to: time)
        } else if viewModel.currentlyPreviewingRole != nil {
            viewModel.scrubActivePreview(to: time)
        }
    }

    private func syncTimelinePlayhead() {
        if viewModel.isStagePlaying {
            timelinePlayheadTime = viewModel.stagePlaybackTime
        } else if viewModel.currentlyPreviewingRole != nil {
            timelinePlayheadTime = viewModel.previewPlaybackTime
        } else {
            timelinePlayheadTime = max(viewModel.vocalStartTime, viewModel.instrumentalStartTime)
        }
    }

    private func formattedTimelineDuration(_ seconds: Double) -> String {
        let total = Int(max(0, seconds.rounded(.down)))
        let minutes = total / 60
        let remaining = total % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    private func cueButton(label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.bordered)
            .tint(tint)
            .frame(maxWidth: .infinity)
    }

    private func nudgeChips(
        labels: [String],
        tint: Color,
        onTap: @escaping (String) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(labels, id: \ .self) { label in
                compactChip(label, tint: tint) {
                    onTap(label)
                }
            }
        }
    }

    private func compactChip(_ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(tint)
    }

    private func playheadScrubber(
        label: String,
        current: Double,
        total: Double,
        tint: Color,
        textColor: Color,
        onScrub: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(label): \(viewModel.formattedPreciseTime(current))")
                Spacer()
                Text("Total: \(viewModel.formattedPreciseTime(total))")
            }
            .font(.caption)
            .foregroundStyle(textColor)

            Slider(
                value: Binding(
                    get: { current },
                    set: { onScrub($0) }
                ),
                in: 0...max(0.1, total)
            )
            .tint(tint)
        }
    }

    private func savedMixesSection(primary: Color, secondary: Color, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Saved Layered Mixes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primary)

                Spacer()

                Text("\(viewModel.savedLayeredMixes.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(secondary)
            }

            if viewModel.savedLayeredMixes.isEmpty {
                Text("No saved layered mixes yet.")
                    .font(.caption)
                    .foregroundStyle(secondary)
            } else {
                ForEach(viewModel.savedLayeredMixes) { mix in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mix.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text("Delay: \(mix.delaySeconds, specifier: "%+.1fs")")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(secondary)
                        }

                        Spacer()

                        ShareLink(item: mix.fileURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .tint(tint)

                        Button(role: .destructive) {
                            beginDeletingSavedMix(mix)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                    .background(primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func tapeCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
    }

    private func posterCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(Color.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.35), lineWidth: 2)
            }
    }

    private func clipCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
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

    private func applyRename(_ target: StyleLabRenameTarget, clear: Bool = false) {
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
        deleteTarget = StyleLabDeleteTarget(id: item.id, name: item.displayName)
    }

    private func beginDeletingSavedMix(_ mix: SavedLayeredMix) {
        deleteSavedMixTarget = StyleLabDeleteSavedMixTarget(id: mix.id, name: mix.displayName)
    }
}

private enum PosterFlowStep: Int, CaseIterable, Identifiable {
    case library
    case align
    case perform

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .library:
            return "1. Library"
        case .align:
            return "2. Align"
        case .perform:
            return "3. Perform"
        }
    }

    var previous: PosterFlowStep {
        switch self {
        case .library:
            return .library
        case .align:
            return .library
        case .perform:
            return .align
        }
    }

    var next: PosterFlowStep {
        switch self {
        case .library:
            return .align
        case .align:
            return .perform
        case .perform:
            return .perform
        }
    }
}

private struct StageCuePreset {
    let vocalStart: Double
    let instrumentalStart: Double
    let stageDelay: Double
}

private enum StyleLabRenameTarget: Identifiable {
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

private struct StyleLabDeleteTarget: Identifiable {
    let id: UUID
    let name: String
}

private struct StyleLabDeleteSavedMixTarget: Identifiable {
    let id: UUID
    let name: String
}
