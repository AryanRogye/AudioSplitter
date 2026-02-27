//
//  EditorView.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/8/26.
//

import SwiftUI

@Observable
@MainActor
public class EditorTheme {
    let backgroundPrimary: Color
    let backgroundSecondary: Color
    let surface: Color
    let accent: Color
    let textPrimary: Color
    let textSecondary: Color
    
    public init(backgroundPrimary: Color, backgroundSecondary: Color, surface: Color, accent: Color, textPrimary: Color, textSecondary: Color) {
        self.backgroundPrimary = backgroundPrimary
        self.backgroundSecondary = backgroundSecondary
        self.surface = surface
        self.accent = accent
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
    }
}

public struct EditorView: View {
    
    @State private var editorVM : EditorViewModel
    @State private var theme: EditorTheme
    
    public init(
        allSongs: [EditorFile],
        theme: EditorTheme = EditorTheme(
            backgroundPrimary : Color(hex: "#0A0A0A")!,
            backgroundSecondary : Color(hex: "#121212")!,
            surface : Color(hex: "#1A1A1A")!,
            accent : Color(hex: "#F2D675")!,
            textPrimary : Color(hex: "#F5F5F5")!,
            textSecondary : Color(hex: "#B8B8B8")!,
        )
    ) {
        self.editorVM = EditorViewModel(allSongs: allSongs)
        self.theme = theme
        /// DEBUG: REMOVE THIS IN PRODUCTION
//        editorVM.addToStaged(allSongs.first!)
//        editorVM.addDroppedItems(allSongs)
    }
    
    public var body: some View {
        ZStack {
            
            theme.backgroundPrimary.ignoresSafeArea()
            
            GeometryReader { geo in
                let libraryHeight = geo.size.height * 0.30
                let timelineHeight = geo.size.height * 0.70;
                
                VStack(spacing: 6) {
                    StagingArea(
                        editorVM: editorVM,
                        areaHeight: libraryHeight
                    )
                    .frame(height: libraryHeight)
                    .padding(.horizontal, 6)
                    
                    TimelineEditorView(
                        editorVM: editorVM
                    )
                    .frame(height: timelineHeight)
                    .padding(.horizontal, 6)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .environment(theme)
    }
}


#if DEBUG
#Preview {
    return EditorView(allSongs: [.previewSong])
        .task {
            
        }
}
#endif

#if DEBUG
extension EditorFile {
    static var previewSong: EditorFile {
        let bundle = Bundle.module
        
        let url = bundle.url(forResource: "Belong to the City", withExtension: "mp3")
        return EditorFile(
            url ?? URL(fileURLWithPath: "/dev/null"),
            id: UUID(),
            name: "Belong to the City",
            created: .now,
            type: .all
        )
    }
}
#endif

extension Color {
    public init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        
        // Ensure valid length (6 for RGB, 8 for RGBA)
        guard hexString.count == 6 || hexString.count == 8 else {
            return nil
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)
        
        var red, green, blue, alpha: UInt64
        switch hexString.count {
        case 6: // RGB
            red = (rgbValue >> 16) & 0xFF
            green = (rgbValue >> 8) & 0xFF
            blue = rgbValue & 0xFF
            alpha = 255
        case 8: // RGBA
            red = (rgbValue >> 16) & 0xFF
            green = (rgbValue >> 8) & 0xFF
            blue = rgbValue & 0xFF
            alpha = (rgbValue >> 24) & 0xFF // Alpha is first in some formats, but last here for clarity
        default:
            return nil
        }
        
        // Note: The standard format in web dev is RRGGBB or RRGGBBAA. The above code assumes RRGGBB(AA).
        // For common RRGGBB format you just need to ensure the length is 6.
        
        self.init(
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0,
            opacity: Double(alpha) / 255.0
        )
    }
    
}
