import Foundation

/// What a signed-in user is allowed to do. A user can hold several roles at once.
/// Stored in Firestore as an array of these raw values: users/{uid}.roles
nonisolated enum UserRole: String, CaseIterable, Hashable, Sendable {
    case `public`      // everyone starts here
    case officer
    case admin

    var title: String { rawValue.capitalized }
}
    