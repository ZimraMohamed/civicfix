import Foundation

/// Error surface for the admin user-management service.
nonisolated enum UserAdminError: LocalizedError {
    case emailInUse, weakPassword, invalidEmail, network, permissionDenied, notSignedIn, unknown

    var errorDescription: String? {
        switch self {
        case .emailInUse: "That email is already used by another account."
        case .weakPassword: "Choose a stronger password (8+ characters with a letter and a number)."
        case .invalidEmail: "Enter a valid email address."
        case .network: "Can’t reach the server. Check your connection and try again."
        case .permissionDenied: "Only admins can manage users."
        case .notSignedIn: "You’re not signed in. Please sign in again."
        case .unknown: "Something went wrong. Please try again."
        }
    }
}

/// Admin-side user management. Read the list of users, create new accounts
/// (without disturbing the admin's own session), and toggle roles / disable.
nonisolated protocol UserServicing: Sendable {
    /// Live list, newest first: emits again whenever any user changes. Admin only.
    func usersStream() -> AsyncThrowingStream<[UserAccount], Error>
    /// One-shot fetch, newest first. Admin only.
    func loadUsers() async throws -> [UserAccount]
    /// Creates a new account as the admin — does NOT sign the admin out.
    /// Writes the user doc with the given roles. Admin only.
    func createUser(name: String, email: String, password: String,
                    roles: Set<UserRole>) async throws
    /// Replace the user's roles (`.public` is always added). Admin only.
    func setRoles(for uid: String, to roles: Set<UserRole>) async throws
    /// Toggle the account's `disabled` flag (soft-disable). Admin only.
    func setDisabled(_ disabled: Bool, for uid: String) async throws
}

enum UserServiceFactory {
    /// Uses Firebase when the Firebase packages are linked; otherwise the mock,
    /// so the project builds before and after you add Firebase.
    static func make() -> UserServicing {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        return FirebaseUserService()
        #else
        return MockUserService()
        #endif
    }
}

/// Offline fake for previews, tests, and builds without Firebase.
nonisolated final class MockUserService: UserServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var users: [UserAccount] = []
    private var seeded = false

    private func seedIfNeeded() {
        guard !seeded else { return }
        seeded = true
        users = [
            UserAccount(id: "u1", displayName: "Ahsan Ilyas", email: "ahsan@example.com",
                        roles: [.public], disabled: false, createdAt: .now.addingTimeInterval(-3_600)),
            UserAccount(id: "u2", displayName: "Nimal Perera", email: "nimal@example.com",
                        roles: [.public, .officer], disabled: false, createdAt: .now.addingTimeInterval(-86_400)),
            UserAccount(id: "u3", displayName: "Sara Khan", email: "sara@example.com",
                        roles: [.public, .admin], disabled: false, createdAt: .now.addingTimeInterval(-172_800))
        ]
    }

    func usersStream() -> AsyncThrowingStream<[UserAccount], Error> {
        AsyncThrowingStream { continuation in
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                continuation.yield(self.snapshot())
                continuation.finish()
            }
        }
    }

    func loadUsers() async throws -> [UserAccount] {
        try await Task.sleep(for: .milliseconds(300))
        return snapshot()
    }

    func createUser(name: String, email: String, password: String, roles: Set<UserRole>) async throws {
        try await Task.sleep(for: .seconds(1))
        lock.lock()
        seedIfNeeded()
        let lower = email.lowercased()
        if users.contains(where: { $0.email.lowercased() == lower }) {
            lock.unlock(); throw UserAdminError.emailInUse
        }
        let next = UserAccount(
            id: "u\(users.count + 1)", displayName: name, email: email,
            roles: roles, disabled: false, createdAt: .now
        )
        users.insert(next, at: 0)
        lock.unlock()
    }

    func setRoles(for uid: String, to roles: Set<UserRole>) async throws {
        try await Task.sleep(for: .milliseconds(300))
        lock.lock(); defer { lock.unlock() }
        guard let i = users.firstIndex(where: { $0.id == uid }) else { return }
        users[i].roles = roles
    }

    func setDisabled(_ disabled: Bool, for uid: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
        lock.lock(); defer { lock.unlock() }
        guard let i = users.firstIndex(where: { $0.id == uid }) else { return }
        users[i].disabled = disabled
    }

    private func snapshot() -> [UserAccount] {
        lock.lock(); defer { lock.unlock() }
        seedIfNeeded()
        return users.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }
}
