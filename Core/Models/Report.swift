import Foundation


nonisolated struct ReportLocation: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var accuracy: Double
}


nonisolated struct ReportDraft: Sendable {
    var details: String
    
    var hashtags: [String]
   
    var imageData: Data
  
    var location: ReportLocation?
}


nonisolated enum HashTag {
    static let maxCount = 10
    static let maxLength = 30

    static let suggestions = [
        "pothole", "streetlight", "garbage", "waterleak",
        "drainage", "roaddamage", "graffiti", "urgent"
    ]

    
    static func normalize(_ raw: String) -> String? {
        let cleaned = raw.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let trimmed = String(cleaned.prefix(maxLength))
        return trimmed.isEmpty ? nil : trimmed
    }

    
    static func parse(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "#" })
            .compactMap { normalize(String($0)) }
    }
}


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
  
    var imageData: Data?
    var location: ReportLocation?
    var status: ReportStatus
    var createdAt: Date?
}
