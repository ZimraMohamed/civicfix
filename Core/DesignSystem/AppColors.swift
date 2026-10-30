import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// A color that resolves to `light` or `dark` depending on the current interface style.
    /// It follows `.preferredColorScheme`, so the in-app appearance setting works.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

enum AppColors {
    static let background    = Color(light: 0xF8FAFC, dark: 0x0B1220)
    static let surface       = Color(light: 0xFFFFFF, dark: 0x131C2E)
    static let textPrimary   = Color(light: 0x0F172A, dark: 0xF1F5F9)
    static let textSecondary = Color(light: 0x64748B, dark: 0x94A3B8)
    static let placeholder   = Color(light: 0x94A3B8, dark: 0x64748B)
    static let border        = Color(light: 0xE2E8F0, dark: 0x263247)
    static let primary       = Color(light: 0x155EEF, dark: 0x4C82F7)
    static let error         = Color(light: 0xDC2626, dark: 0xF87171)
    static let success       = Color(light: 0x15803D, dark: 0x4ADE80)
}
