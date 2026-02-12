//
//  StemBundleCardToggleButton.swift
//  AudioSplitter
//
//  Created by Aryan Rogye on 2/11/26.
//

import SwiftUI

/// Shown in the StagedBundleCard
/// Button to toggle between which selected stem in each song
struct StemBundleCardToggleButton: View {
    let stem: StoredStemAsset
    @Binding var selected: SelectedStageListen
    
    var isSelected: Bool {
        if let kind = selected.kind {
            return kind == stem.kind
        }
        return false
    }
    
    var body: some View {
        Button {
            if stem.kind == .vocals, selected == .vocal {
                selected = .none
                return
            } else if stem.kind == .instrumental, selected == .instrumental {
                selected = .none
                return
            }
            selected = stem.kind == .vocals ? .vocal : .instrumental
        } label: {
            Text(stem.kind.rawValue.prefix(1).uppercased())
                .font(.system(size: 12, weight: .bold))
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                }
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
