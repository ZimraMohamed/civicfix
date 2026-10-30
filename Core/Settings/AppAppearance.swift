import SwiftUI

/// The user's theme choice. "Auto" follows the system setting.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    /// UserDefaults key, shared by `@AppStorage` in the app root and Settings screen.
    static let storageKey = "civicfix.appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Auto"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light:  "sun.max"
        case .dark:   "moon"
        }
    }

    /// `nil` means "follow the system".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}
