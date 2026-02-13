import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = StemSeparationViewModel()
    @StateObject private var libraryViewModel = AudioLibraryViewModel()
    @State private var isFileImporterPresented = false
    @State private var isConfigurationPresented = false
    @State private var isLabsPresented = false
    @State private var pendingDuplicateMatch: DuplicateAudioMatch?
    @State private var splitStartedAt: Date?

    @AppStorage("preferredStemKinds") private var preferredStemKindsStorage = StemKind.allCases.map(\.rawValue).joined(separator: ",")
    @AppStorage("autoPlayFirstStem") private var autoPlayFirstStem = false
    @AppStorage("splitLoadingStyle") private var splitLoadingStyleRaw = LoadingStyle.equalizerArc.rawValue
    @AppStorage("didMigrateLoadingStyleToEqualizerArc") private var didMigrateLoadingStyleToEqualizerArc = false

    @State private var preferredStemKinds: Set<StemKind> = Set(StemKind.allCases)
    @State private var hasLoadedPreferences = false
    @Namespace private var glassNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()

                ScrollView(showsIndicators: false) {
                    GlassEffectContainer(spacing: 30) {
                        VStack(alignment: .leading, spacing: 16) {
                            FrostedCard(tint: .blue, glassID: "hero-card", namespace: glassNamespace) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Label("On-Device Stem Splitting", systemImage: "waveform.path.ecg.rectangle")
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Text("\(preferredStemKinds.count) stem\(preferredStemKinds.count == 1 ? "" : "s") visible")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .glassEffect(.regular, in: Capsule())
                                    }

                                    Text("Fast local separation with an iOS-native workflow. Configure playback and visible stems from the top-right controls.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            FrostedCard(tint: .indigo, glassID: "source-card", namespace: glassNamespace) {
                                VStack(alignment: .leading, spacing: 14) {
                                    Label("Source File", systemImage: "music.note.list")
                                        .font(.headline)

                                    Text(viewModel.selectedFileURL?.lastPathComponent ?? "No file selected")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                                    ViewThatFits(in: .horizontal) {
                                        HStack(spacing: 10) {
                                            chooseButton
                                            sourcePlaybackButton
                                        }

                                        VStack(spacing: 10) {
                                            chooseButton
                                            sourcePlaybackButton
                                        }
                                    }

                                    Button {
                                        splitWithDuplicateCheck()
                                    } label: {
                                        SplitActionLabel(isProcessing: viewModel.isProcessing)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(GlassProminentButtonStyle())
                                    .controlSize(.large)
                                    .disabled(viewModel.selectedFileURL == nil || viewModel.isProcessing)

                                    if libraryViewModel.isCheckingSimilarity {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                            Text("Checking against your history...")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .glassEffect(.regular, in: Capsule())
                                    } else if let match = libraryViewModel.selectionDuplicateMatch {
                                        Label(
                                            "Yo, this sounds \(Int(match.similarity * 100))% like \(match.entry.sourceFileName).",
                                            systemImage: "exclamationmark.bubble.fill"
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .glassEffect(.regular, in: Capsule())
                                    }
                                }
                            }

                            if viewModel.isProcessing {
                                FrostedCard(tint: splitLoadingStyle.accent, glassID: "activity-card", namespace: glassNamespace) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        SplitActivityPill(label: "Splitting in progress", symbol: "waveform.and.magnifyingglass")
                                            .matchedGeometryEffect(id: "split-activity-pill", in: glassNamespace)

                                        SplitLoadingExperienceCard(
                                            style: splitLoadingStyle,
                                            startedAt: splitStartedAt,
                                            progressOverride: nil
                                        )
                                    }
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            } else {
                                FrostedCard(tint: viewModel.errorText == nil ? .gray : .red, glassID: "activity-card", namespace: glassNamespace) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        SplitActivityPill(
                                            label: viewModel.errorText == nil ? "Ready to split" : "Action needed",
                                            symbol: viewModel.errorText == nil ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                                        )
                                        .matchedGeometryEffect(id: "split-activity-pill", in: glassNamespace)

                                        Text(viewModel.statusText)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        if let errorText = viewModel.errorText {
                                            Label(errorText, systemImage: "exclamationmark.triangle.fill")
                                                .font(.footnote)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            }

                            FrostedCard(tint: .orange, glassID: "stems-card", namespace: glassNamespace) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Separated Stems", systemImage: "square.stack.3d.forward.dottedline")
                                        .font(.headline)

                                    if viewModel.outputStems.isEmpty {
                                        Text("Split a track to preview, play, and share each stem.")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        VStack(spacing: 10) {
                                            ForEach(viewModel.outputStems) { stem in
                                                StemRow(
                                                    stem: stem,
                                                    isPlaying: viewModel.isPlaying(stem.fileURL)
                                                ) {
                                                    viewModel.togglePlayback(for: stem.fileURL)
                                                }
                                                .transition(.asymmetric(
                                                    insertion: .scale(scale: 0.94).combined(with: .opacity),
                                                    removal: .opacity
                                                ))
                                            }
                                        }
                                    }
                                }
                            }

                            Spacer(minLength: 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Audio Splitter")
            .toolbarBackground(.hidden, for: .navigationBar)
            .animation(.spring(response: 0.62, dampingFraction: 0.86), value: viewModel.isProcessing)
            .animation(.spring(response: 0.58, dampingFraction: 0.86), value: viewModel.outputStems.map(\.kind))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        DownloaderView()
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        EditorView(
                            allSongs: libraryViewModel.fileUrls(),
                            historyStore: libraryViewModel.historyStore
                        )
                    } label: {
                        Label("Timeline", systemImage: "timeline.selection")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        AudioLibraryScreen(viewModel: libraryViewModel) { sourceURL in
                            viewModel.importPickedFile(from: sourceURL)
                        }
                    } label: {
                        Label("Library & Stage", systemImage: "square.stack.3d.up")
                    }
                    .buttonStyle(GlassButtonStyle())
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isLabsPresented = true
                    } label: {
                        Label("Labs", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(GlassButtonStyle())

                    Button {
                        isConfigurationPresented = true
                    } label: {
                        Label("Configure", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(GlassButtonStyle())
                }
            }
        }
        .onAppear {
            if !didMigrateLoadingStyleToEqualizerArc {
                splitLoadingStyleRaw = LoadingStyle.equalizerArc.rawValue
                didMigrateLoadingStyleToEqualizerArc = true
            }

            guard !hasLoadedPreferences else { return }
            preferredStemKinds = decodeStemKinds(from: preferredStemKindsStorage)
            viewModel.setPreferredStemKinds(preferredStemKinds)
            hasLoadedPreferences = true
        }
        .onChange(of: preferredStemKinds) { _, newValue in
            preferredStemKindsStorage = encodeStemKinds(newValue)
            viewModel.setPreferredStemKinds(newValue)
        }
        .onChange(of: viewModel.selectedFileURL) { _, newValue in
            libraryViewModel.evaluateSelectionForDuplicate(newValue)
        }
        .onChange(of: viewModel.latestSeparatedStems) { _, stems in
            guard let sourceURL = viewModel.latestSeparatedSourceURL else { return }
            libraryViewModel.persistProcessedTrack(sourceURL: sourceURL, stems: stems)
        }
        .onChange(of: viewModel.isProcessing) { _, isProcessing in
            if isProcessing {
                splitStartedAt = Date()
            } else {
                splitStartedAt = nil
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.mp3, .audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let first = urls.first {
                    viewModel.importPickedFile(from: first)
                }
            case .failure(let error):
                viewModel.errorText = error.localizedDescription
            }
        }
        .sheet(isPresented: $isConfigurationPresented) {
            ConfigurationSheet(
                preferredStemKinds: $preferredStemKinds,
                autoPlayFirstStem: $autoPlayFirstStem
            )
        }
        .sheet(isPresented: $isLabsPresented) {
            LabsHubView(
                selectedLoadingStyle: loadingStyleBinding,
                libraryViewModel: libraryViewModel
            ) { sourceURL in
                viewModel.importPickedFile(from: sourceURL)
            }
        }
        .alert(
            "Possible duplicate track",
            isPresented: Binding(
                get: { pendingDuplicateMatch != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDuplicateMatch = nil
                    }
                }
            ),
            presenting: pendingDuplicateMatch
        ) { _ in
            Button("Split Again") {
                performSplit()
            }
            Button("Cancel", role: .cancel) {}
        } message: { match in
            Text("This file sounds \(Int(match.similarity * 100))% similar to \(match.entry.sourceFileName). Split anyway?")
        }
    }

    private var chooseButton: some View {
        Button {
            isFileImporterPresented = true
        } label: {
            Label("Choose MP3", systemImage: "folder.badge.plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GlassProminentButtonStyle())
        .controlSize(.large)
    }

    private var sourcePlaybackButton: some View {
        Button {
            viewModel.togglePlayback(for: viewModel.selectedFileURL)
        } label: {
            Label(
                viewModel.isPlaying(viewModel.selectedFileURL) ? "Pause" : "Play",
                systemImage: viewModel.isPlaying(viewModel.selectedFileURL) ? "pause.fill" : "play.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GlassButtonStyle())
        .controlSize(.large)
        .disabled(viewModel.selectedFileURL == nil)
    }

    private func decodeStemKinds(from storage: String) -> Set<StemKind> {
        let decoded = Set(
            storage
                .split(separator: ",")
                .compactMap { StemKind(rawValue: String($0)) }
        )

        return decoded.isEmpty ? Set(StemKind.allCases) : decoded
    }

    private func encodeStemKinds(_ kinds: Set<StemKind>) -> String {
        let normalizedKinds = kinds.isEmpty ? Set(StemKind.allCases) : kinds
        let ordered = StemKind.allCases.filter { normalizedKinds.contains($0) }
        return ordered.map(\.rawValue).joined(separator: ",")
    }

    private func splitWithDuplicateCheck() {
        guard let sourceURL = viewModel.selectedFileURL else {
            return
        }

        Task {
            let duplicate = await libraryViewModel.findDuplicateCandidate(for: sourceURL)
            if let duplicate {
                await MainActor.run {
                    pendingDuplicateMatch = duplicate
                }
            } else {
                await MainActor.run {
                    performSplit()
                }
            }
        }
    }

    private func performSplit() {
        viewModel.splitSelectedFile(autoPlayFirstStem: autoPlayFirstStem)
    }

    private var splitLoadingStyle: LoadingStyle {
        LoadingStyle(rawValue: splitLoadingStyleRaw) ?? .equalizerArc
    }

    private var loadingStyleBinding: Binding<LoadingStyle> {
        Binding(
            get: { splitLoadingStyle },
            set: { splitLoadingStyleRaw = $0.rawValue }
        )
    }
}

private struct GlassBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.70, green: 0.82, blue: 0.97),
                    Color(red: 0.87, green: 0.94, blue: 1.0),
                    Color(red: 0.93, green: 0.87, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(0.22))
                .frame(width: 340)
                .offset(x: -150, y: -280)
                .blur(radius: 55)

            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 320)
                .offset(x: 180, y: 260)
                .blur(radius: 65)

            Circle()
                .fill(Color.indigo.opacity(0.16))
                .frame(width: 230)
                .offset(x: 170, y: -220)
                .blur(radius: 50)
        }
        .ignoresSafeArea()
    }
}

private struct FrostedCard<Content: View>: View {
    let tint: Color
    let glassID: String?
    let namespace: Namespace.ID?
    let content: Content

    init(
        tint: Color = .blue,
        glassID: String? = nil,
        namespace: Namespace.ID? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.glassID = glassID
        self.namespace = namespace
        self.content = content()
    }

    var body: some View {
        Group {
            if let glassID, let namespace {
                cardBody
                    .matchedGeometryEffect(id: glassID, in: namespace)
            } else {
                cardBody
            }
        }
    }

    private var cardBody: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.14), radius: 16, x: 0, y: 12)
    }
}

private struct SplitActionLabel: View {
    let isProcessing: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isProcessing {
                ProgressView()
            }

            Label(
                isProcessing ? "Splitting..." : "Split Track",
                systemImage: isProcessing ? "waveform" : "sparkles.rectangle.stack.fill"
            )
            .labelStyle(.titleAndIcon)
        }
    }
}

private struct SplitActivityPill: View {
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

private struct StemRow: View {
    let stem: StemFile
    let isPlaying: Bool
    let onPlayPause: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: stem.kind.symbolName)
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

private struct ConfigurationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var preferredStemKinds: Set<StemKind>
    @Binding var autoPlayFirstStem: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    Toggle("Auto-play first visible stem", isOn: $autoPlayFirstStem)
                    Text("When enabled, playback starts automatically after a successful split.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Visible stems") {
                    ForEach(StemKind.allCases, id: \.self) { kind in
                        Toggle(isOn: binding(for: kind)) {
                            Label(kind.displayName, systemImage: kind.symbolName)
                        }
                        .disabled(preferredStemKinds.count == 1 && preferredStemKinds.contains(kind))
                    }

                    Text("At least one stem must stay visible.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Roadmap-ready controls") {
                    Label("This panel is prepared for more options such as model presets, export defaults, and post-processing.", systemImage: "gearshape.2")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Legal") {
                    NavigationLink {
                        OpenSourceNoticesView()
                    } label: {
                        Label("Open Source Notices", systemImage: "doc.text.magnifyingglass")
                    }
                }
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func binding(for kind: StemKind) -> Binding<Bool> {
        Binding(
            get: { preferredStemKinds.contains(kind) },
            set: { isOn in
                if isOn {
                    preferredStemKinds.insert(kind)
                } else if preferredStemKinds.count > 1 {
                    preferredStemKinds.remove(kind)
                }
            }
        )
    }
}

private struct OpenSourceNoticesView: View {
    var body: some View {
        List {
            Section("App License") {
                Text("AudioSplitter source code is licensed under LGPL-2.1-or-later.")
                Text("See LICENSE in the repository root.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Third-Party Components") {
                LabeledContent("FFmpeg-iOS-Lame", value: "LGPL-2.1+")
                LabeledContent("FFmpeg-iOS-Support", value: "LGPL-2.1+")
                LabeledContent("YoutubeDL-iOS", value: "MIT")
                LabeledContent("Python-iOS", value: "PSF-2.0")
                LabeledContent("PythonKit", value: "MIT")
                Text("See THIRD_PARTY_NOTICES.md for versions, source links, and attribution details.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Upstream License Links") {
                Link("LGPL v2.1 text", destination: URL(string: "https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html")!)
                Link("FFmpeg legal guidance", destination: URL(string: "https://ffmpeg.org/legal.html")!)
                Link("FFmpeg-iOS-Lame", destination: URL(string: "https://github.com/kewlbear/FFmpeg-iOS-Lame")!)
                Link("FFmpeg-iOS-Support", destination: URL(string: "https://github.com/kewlbear/FFmpeg-iOS-Support")!)
                Link("YoutubeDL-iOS", destination: URL(string: "https://github.com/kewlbear/YoutubeDL-iOS")!)
            }
        }
        .navigationTitle("Open Source Notices")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension StemKind {
    var symbolName: String {
        switch self {
        case .vocals:
            return "music.mic"
        case .drums:
            return "metronome"
        case .bass:
            return "guitars"
        case .other:
            return "waveform"
        case .instrumental:
            return "music.note"
        }
    }

    var tint: Color {
        switch self {
        case .vocals:
            return .pink
        case .drums:
            return .orange
        case .bass:
            return .indigo
        case .other:
            return .teal
        case .instrumental:
            return .green
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

#Preview {
    ContentView()
}
