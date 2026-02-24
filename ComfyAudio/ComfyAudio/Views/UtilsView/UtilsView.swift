//
//  UtilsView.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/23/26.
//

import SwiftUI

struct UtilsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary?.ignoresSafeArea()
                ScrollView {
                    NavigationLink(destination: YoutubeDownloaderView()) {
                        ComfyAudioCard {
                            Text("Download Youtube Audio")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview {
    UtilsView()
}
