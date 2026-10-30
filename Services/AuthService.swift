import Foundation

nonisolated enum AuthError: LocalizedError {
    case invalidCredentials, noSavedSession, emailNotFound
    case emailInUse, weakPassword, wrongCurrentPassword, tooManyAttempts
    case network, notSignedIn, unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Incorrect email or password."
        case .noSavedSession: "Sign in with your password first to enable Face ID."
        case .emailNotFound: "We couldn’t find an account with that email."
        case .emailInUse: "That email is already used by another account."
        case .weakPassword: "Choose a stronger password (8+ characters with a letter and a number)."
        case .wrongCurrentPassword: "Your current password is incorrect."
        case .tooManyAttempts: "Too many attempts. Please wait a moment and try again."
        case .network: "Can’t reach the server. Check your connection and try again."
        case .notSignedIn: "You’re not signed in. Please sign in again."
        case .unknown: "Something went wrong. Please try again."
        }
    }
}

nonisolated protocol AuthServicing: Sendable {
    var isLoggedIn: Bool { get }
    /// The signed-in user, or nil.
    var currentUser: UserProfile? { get }

    func signIn(email: String, password: String) async throws
    func register(name: String, email: String, password: String) async throws
    func sendPasswordReset(email: String) async throws
    func restoreSession() async throws
    /// Re-fetches the user from the server (e.g. to pick up a verified e-mail change). Never throws.
    func reloadUser() async
    /// Re-authenticates, then sends a verification link to `newEmail`.
    /// The address changes only after the user taps that link.
    func changeEmail(to newEmail: String, currentPassword: String) async throws
    func changePassword(current: String, new: String) async throws
    func signOut()

    /// Reads the signed-in user's roles. Never throws; falls back to `[.public]`.
    func loadRoles() async -> Set<UserRole>
    /// Admin only (enforced by Firestore rules). `.public` is always kept.
    func setRoles(for uid: String, to roles: Set<UserRole>) async throws
}

enum AuthServiceFactory {
    /// Uses Firebase when the Firebase packages are linked, otherwise the offline mock,
    /// so the project builds before and after you add Firebase.
    static func make() -> AuthServicing {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        return FirebaseAuthService()
        #else
        return MockAuthService()
        #endif
    }
}

/// Offline fake backend for previews, tests, and builds without Firebase.
nonisolated struct MockAuthService: AuthServicing {
    private let sessionKey = "civicfix.mock.hasSession"
    private let signedInBeforeKey = "civicfix.mock.hasSignedInBefore"
    private let emailKey = "civicfix.mock.email"
    private let nameKey = "civicfix.mock.name"
    private let passwordKey = "civicfix.mock.password"

    private var defaults: UserDefaults { .standard }

    var isLoggedIn: Bool { defaults.bool(forKey: sessionKey) }

    var currentUser: UserProfile? {
        guard isLoggedIn, let email = defaults.string(forKey: emailKey) else { return nil }
        return UserProfile(uid: "mock-user", email: email,
                           displayName: defaults.string(forKey: nameKey) ?? "")
    }

    func signIn(email: String, password: String) async throws {
        try await Task.sleep(for: .seconds(1))
        startSession(email: email, name: defaults.string(forKey: nameKey) ?? "", password: password)
    }

    func register(name: String, email: String, password: String) async throws {
        try await Task.sleep(for: .seconds(1))
        startSession(email: email, name: name, password: password)
    }

    func sendPasswordReset(email: String) async throws {
        try await Task.sleep(for: .seconds(1))
    }

    func restoreSession() async throws {
        guard defaults.bool(forKey: signedInBeforeKey) else { throw AuthError.noSavedSession }
        defaults.set(true, forKey: sessionKey)
    }

    func reloadUser() async {}

    func changeEmail(to newEmail: String, currentPassword: String) async throws {
        try await Task.sleep(for: .seconds(1))
        guard currentPassword == defaults.string(forKey: passwordKey) else {
            throw AuthError.wrongCurrentPassword
        }
        defaults.set(newEmail, forKey: emailKey)   // the real service waits for verification
    }

    func changePassword(current: String, new: String) async throws {
        try await Task.sleep(for: .seconds(1))
        guard current == defaults.string(forKey: passwordKey) else {
            throw AuthError.wrongCurrentPassword
        }
        defaults.set(new, forKey: passwordKey)
    }

    func signOut() { defaults.set(false, forKey: sessionKey) }

    func loadRoles() async -> Set<UserRole> { [.public] }
    func setRoles(for uid: String, to roles: Set<UserRole>) async throws {}

    private func startSession(email: String, name: String, password: String) {
        defaults.set(true, forKey: sessionKey)
        defaults.set(true, forKey: signedInBeforeKey)
        defaults.set(email, forKey: emailKey)
        defaults.set(name, forKey: nameKey)
        defaults.set(password, forKey: passwordKey)
    }
}
