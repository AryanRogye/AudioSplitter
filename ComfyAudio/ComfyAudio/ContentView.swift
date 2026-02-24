//
//  ContentView.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/23/26.
//

import SwiftUI

enum ComfyTab: String, CaseIterable {
    case home = "Home"
    case audioSplitter = "Audio Splitter"
    case textToSpeech = "Text to Speech"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .home:
            return "house"
        case .audioSplitter:
            return "waveform"
        case .textToSpeech:
            return "rectangle.3.offgrid.bubble.left.fill"
        case .settings:
            return "gear"
        }
    }
    
    @ViewBuilder
    var view: some View {
        switch self {
        case .settings:         SettingsView()
        case .home:             HomeView()
        case .audioSplitter:    AudioSplitterView()
        case .textToSpeech:     TextToSpeechView()
        }
    }
}

struct ContentView: View {
    
    @State private var selection: ComfyTab = .audioSplitter
    
    var body: some View {
        TabView(selection: $selection) {
            ForEach(ComfyTab.allCases, id: \.self) { tab in
                Tab(value: tab) {
                    tab.view
                } label: {
                    Image(systemName: tab.icon)
                }
            }
        }
        .tint(Theme.goldAccent)
        .toolbarBackground(Theme.backgroundSecondary ?? .white, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview {
    ContentView()
}
