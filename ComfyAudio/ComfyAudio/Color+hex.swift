//
//  Color+hex.swift
//  ComfyAudio
//
//  Created by Aryan Rogye on 2/23/26.
//

import SwiftUI

extension Color {
    init?(hex: String) {
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
