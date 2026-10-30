import Foundation


nonisolated struct UserAccount: Identifiable, Equatable, Sendable {
    var id: String            // Firestore document id == Firebase Auth uid
    var displayName: String
    var email: String
    var roles: Set<UserRole>
    var disabled: Bool
    var createdAt: Date?

  
    var effectiveRoles: Set<UserRole> { roles.union([.public]) }
    var isOfficer: Bool { effectiveRoles.contains(.officer) }
    var isAdmin: Bool { effectiveRoles.contains(.admin) }


    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2).compactMap(\.first)
        if !parts.isEmpty { return String(parts).uppercased() }
        return email.first.map { String($0).uppercased() } ?? "?"
    }

    var rolesText: String {
        UserRole.allCases.filter(effectiveRoles.contains).map(\.title).joined(separator: " · ")
    }
}
