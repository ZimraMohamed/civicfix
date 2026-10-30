#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firebase Authentication backend. Firebase keeps the login itself in the Keychain
/// and refreshes tokens automatically; `SessionStore` mirrors the user into Core Data.
nonisolated struct FirebaseAuthService: AuthServicing {
    private let credentials = KeychainCredentialStore()

    var isLoggedIn: Bool { Auth.auth().currentUser != nil }

    var currentUser: UserProfile? {
        guard let user = Auth.auth().currentUser else { return nil }
        return UserProfile(uid: user.uid, email: user.email ?? "", displayName: user.displayName ?? "")
    }

    func signIn(email: String, password: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            credentials.save(email: email, password: password)
        } catch { throw map(error) }
    }

    func register(name: String, email: String, password: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let change = result.user.createProfileChangeRequest()
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            change.displayName = cleanName
            try? await change.commitChanges()   // account exists; a name hiccup shouldn't fail sign-up
            // Every new account starts as a plain public user.
            try? await createUserDocument(uid: result.user.uid, name: cleanName, email: email)
            credentials.save(email: email, password: password)
        } catch { throw map(error) }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(
                withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch { throw map(error) }
    }

    /// Face ID: reuse the live Firebase session if there is one, otherwise sign in
    /// with the credentials saved in the Keychain.
    func restoreSession() async throws {
        if isLoggedIn { return }
        guard let saved = credentials.load() else { throw AuthError.noSavedSession }
        do {
            _ = try await Auth.auth().signIn(withEmail: saved.email, password: saved.password)
        } catch {
            credentials.clear()          // password changed elsewhere; require a fresh sign in
            throw AuthError.noSavedSession
        }
    }

    func reloadUser() async {
        try? await Auth.auth().currentUser?.reload()
    }

    func changeEmail(to newEmail: String, currentPassword: String) async throws {
        let newEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let user = Auth.auth().currentUser, let oldEmail = user.email else {
            throw AuthError.notSignedIn
        }
        do {
            try await reauthenticate(user, email: oldEmail, password: currentPassword)
            // updateEmail(to:) is deprecated and rejected by projects with email-enumeration
            // protection (the default). This sends a link; the address changes once it's tapped.
            try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
        } catch { throw map(error, reauth: true) }
    }

    func changePassword(current: String, new: String) async throws {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            throw AuthError.notSignedIn
        }
        do {
            try await reauthenticate(user, email: email, password: current)
            try await user.updatePassword(to: new)
            credentials.save(email: email, password: new)
        } catch { throw map(error, reauth: true) }
    }

    func signOut() {
        try? Auth.auth().signOut()       // keychain credentials stay so Face ID still works
    }

    // MARK: - Roles (Firestore: users/{uid})

    private var users: CollectionReference { Firestore.firestore().collection("users") }

    func loadRoles() async -> Set<UserRole> {
        guard let user = Auth.auth().currentUser else { return [.public] }
        do {
            let snapshot = try await users.document(user.uid).getDocument()
            if snapshot.exists {
                let raw = snapshot.data()?["roles"] as? [String] ?? []
                return Set(raw.compactMap(UserRole.init(rawValue:))).union([.public])
            }
            // Account created before roles existed: give it the default record.
            try await createUserDocument(uid: user.uid,
                                         name: user.displayName ?? "",
                                         email: user.email ?? "")
        } catch {
            // Offline or rules problem: stay safe with the lowest role.
        }
        return [.public]
    }

    func setRoles(for uid: String, to roles: Set<UserRole>) async throws {
        let values = roles.union([.public]).map(\.rawValue).sorted()
        do { try await users.document(uid).updateData(["roles": values]) }
        catch { throw map(error) }
    }

    private func createUserDocument(uid: String, name: String, email: String) async throws {
        try await users.document(uid).setData([
            "displayName": name,
            "email": email,
            "roles": [UserRole.public.rawValue],
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Helpers

    private func reauthenticate(_ user: User, email: String, password: String) async throws {
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
    }

    /// Translates Firebase errors into messages we control.
    /// `reauth` is true when a bad credential means "wrong current password".
    private func map(_ error: Error, reauth: Bool = false) -> AuthError {
        if let known = error as? AuthError { return known }
        let ns = error as NSError
        guard ns.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: ns.code) else { return .unknown }
        switch code {
        case .wrongPassword, .invalidCredential, .userNotFound, .invalidEmail:
            return reauth ? .wrongCurrentPassword : .invalidCredentials
        case .emailAlreadyInUse: return .emailInUse
        case .weakPassword: return .weakPassword
        case .tooManyRequests: return .tooManyAttempts
        case .networkError: return .network
        case .requiresRecentLogin, .userTokenExpired, .userDisabled: return .notSignedIn
        default: return .unknown
        }
    }
}
#endif
