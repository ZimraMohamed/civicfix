import Foundation

/// Where the photo was taken. Stored in Firestore as a `GeoPoint` plus accuracy in metres.
nonisolated struct ReportLocation: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var accuracy: Double
}

/// Everything the user filled in on the Report screen, ready to be saved.
nonisolated struct ReportDraft: Sendable {
    var details: String
    /// Normalised tags without the leading "#", e.g. ["pothole", "urgent"].
    var hashtags: [String]
    /// JPEG bytes, already resized.
    var imageData: Data
    /// nil when the user chose not to share their location.
    var location: ReportLocation?
}

/// Hashtag helpers. Tags are stored lowercase and without "#" so they can be
/// queried with `whereField("hashtags", arrayContains: "pothole")`.
nonisolated enum HashTag {
    static let maxCount = 10
    static let maxLength = 30

    static let suggestions = [
        "pothole", "streetlight", "garbage", "waterleak",
        "drainage", "roaddamage", "graffiti", "urgent"
    ]

    /// "#Pothole!" -> "pothole". Returns nil if nothing usable is left.
    static func normalize(_ raw: String) -> String? {
        let cleaned = raw.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let trimmed = String(cleaned.prefix(maxLength))
        return trimmed.isEmpty ? nil : trimmed
    }

    /// "#pothole #urgent, broken_light" -> ["pothole", "urgent", "broken_light"]
    static func parse(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "#" })
            .compactMap { normalize(String($0)) }
    }
}

/// Where a report is in the admin's workflow. Stored in Firestore as the raw value.
nonisolated enum ReportStatus: String, CaseIterable, Sendable {
    case open
    case inProgress = "in_progress"
    case resolved

    var title: String {
        switch self {
        case .open: "Open"
        case .inProgress: "In progress"
        case .resolved: "Resolved"
        }
    }

    var systemImage: String {
        switch self {
        case .open: "exclamationmark.circle.fill"
        case .inProgress: "clock.fill"
        case .resolved: "checkmark.circle.fill"
        }
    }
}

/// A submitted report as read back from Firestore.
nonisolated struct Report: Identifiable, Equatable, Sendable {
    var id: String
    var userName: String
    var userEmail: String
    var details: String
    var hashtags: [String]
    /// JPEG bytes stored inside the Firestore document.
    var imageData: Data?
    var location: ReportLocation?
    var status: ReportStatus
    var createdAt: Date?
}
