import SwiftUI

/// Uses Dynamic Type text styles so the UI scales with accessibility settings.
/// To use Inter instead: Font.custom("Inter-Bold", size: 28, relativeTo: .title)
enum AppFonts {
    static let screenTitle = Font.title.weight(.bold)
    static let subtitle    = Font.subheadline
    static let fieldLabel  = Font.subheadline.weight(.semibold)
    static let input       = Font.callout
    static let button      = Font.headline          // 17 semibold; closest scalable style to 16
    static let footer      = Font.footnote
    static let error       = Font.caption
}
