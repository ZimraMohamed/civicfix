import Foundation


nonisolated enum UserRole: String, CaseIterable, Hashable, Sendable {
    case `public`      // everyone starts here
    case officer
    case admin

    var title: String { rawValue.capitalized }
}
    
