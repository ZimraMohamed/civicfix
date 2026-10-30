import Foundation

/// A user account as seen from the admin's "Manage users" screen.
///
/// Different from `UserProfile` (which represents the *signed-in* user and is
/// cached locally); this is read straight from Firestore's `users/{uid}` docs
/// and never written to disk.
nonisolated struct UserAccount: Identifiable, Equatable, Sendable {
    var id: String            // Firestore document id == Firebase Auth uid
    var displayName: String
    var email: String
    var roles: Set<UserRole>
    var disabled: Bool
    var createdAt: Date?

    /// Always implicitly `.public`; only the *extra* roles matter in the UI.
    var effectiveRoles: Set<UserRole> { roles.union([.public]) }
    var isOfficer: Bool { effectiveRoles.contains(.officer) }
    var isAdmin: Bool { effectiveRoles.contains(.admin) }

    /// "Ahsan Ilyas" -> "AI". Falls back to the first letter of the email.
    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2).compactMap(\.first)
        if !parts.isEmpty { return String(parts).uppercased() }
        return email.first.map { String($0).uppercased() } ?? "?"
    }

    var rolesText: String {
        UserRole.allCases.filter(effectiveRoles.contains).map(\.title).joined(separator: " · ")
    }
}
