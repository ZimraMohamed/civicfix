#if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseCore)
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import OSLog

/// Admin-side user management backed by Firebase.
///
/// `createUser` uses a **secondary FirebaseApp instance** so the admin's
/// session on the main app is never disturbed. The new account is created,
/// their Firestore user doc is written, the secondary app is signed out, and
/// the admin stays logged in throughout.
///
/// Roles are then written as the admin (which the Firestore rules allow),
/// so initial officer/admin can be granted at creation time.
///
/// "Disable" is a soft flag on the Firestore doc (`disabled: true`). The
/// client Firebase SDK has no way to delete another user's auth account, so
/// this is the most an admin can do without Cloud Functions.
nonisolated struct FirebaseUserService: UserServicing {
    private let log = Logger(subsystem: "com.lozaa.CivicFix", category: "users")

    private var users: CollectionReference { Firestore.firestore().collection("users") }

    // MARK: - Read

    func loadUsers() async throws -> [UserAccount] {
        do {
            let snapshot = try await users.order(by: "createdAt", descending: true).getDocuments()
            return snapshot.documents.map(Self.makeUser)
        } catch { throw map(error) }
    }

    /// Emits the full list again whenever any user changes. Runs until the
    /// view cancels it.
    func usersStream() -> AsyncThrowingStream<[UserAccount], Error> {
        AsyncThrowingStream { continuation in
            nonisolated(unsafe) let registration = users
                .order(by: "createdAt", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: self.map(error)); return
                    }
                    guard let snapshot else { return }
                    continuation.yield(snapshot.documents.map(Self.makeUser))
                }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    // MARK: - Create

    func createUser(name: String, email: String, password: String, roles: Set<UserRole>) async throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Set up the secondary app once; reuse if it already exists.
        let secondary = configureSecondaryApp()
        do {
            let secondaryAuth = Auth.auth(app: secondary)
            let result = try await secondaryAuth.createUser(withEmail: cleanEmail, password: password)
            // While signed in on the secondary app, write the user doc with public role
            // (the existing Firestore create rule allows this). We'll upgrade roles next.
            let newUID = result.user.uid
            try await Firestore.firestore(app: secondary).collection("users").document(newUID).setData([
                "displayName": cleanName,
                "email": cleanEmail,
                "roles": [UserRole.public.rawValue],
                "disabled": false,
                "createdAt": FieldValue.serverTimestamp()
            ])
            // Stop being signed in as the new user on the secondary app.
            try? await secondaryAuth.signOut()

            // Back on the main app, grant any non-public roles as the admin.
            let extras = roles.subtracting([.public])
            if !extras.isEmpty {
                try await setRoles(for: newUID, to: roles)
            }
            log.info("Admin created user \(newUID) (\(cleanEmail))")
        } catch {
            // Always clean up the secondary session, even on failure.
            try? await Auth.auth(app: secondary).signOut()
            throw map(error)
        }
    }

    // MARK: - Update

    func setRoles(for uid: String, to roles: Set<UserRole>) async throws {
        let values = roles.union([.public]).map(\.rawValue).sorted()
        do { try await users.document(uid).updateData(["roles": values]) }
        catch { throw map(error) }
    }

    func setDisabled(_ disabled: Bool, for uid: String) async throws {
        do { try await users.document(uid).updateData(["disabled": disabled]) }
        catch { throw map(error) }
    }

    // MARK: - Helpers

    /// Lazily configures (and returns) a secondary `FirebaseApp` that mirrors
    /// the main app's options. Safe to call repeatedly.
    private func configureSecondaryApp() -> FirebaseApp {
        if let existing = FirebaseApp.app(name: "CivicFixAdmin") { return existing }
        let main = FirebaseApp.app()!
        let opts = FirebaseOptions(googleAppID: main.options.googleAppID,
                                   gcmSenderID: main.options.gcmSenderID)
        opts.apiKey = main.options.apiKey
        opts.projectID = main.options.projectID
        opts.bundleID = main.options.bundleID
        FirebaseApp.configure(name: "CivicFixAdmin", options: opts)
        return FirebaseApp.app(name: "CivicFixAdmin")!
    }

    private static func makeUser(_ doc: QueryDocumentSnapshot) -> UserAccount {
        let data = doc.data()
        let rawRoles = data["roles"] as? [String] ?? []
        let roles = Set(rawRoles.compactMap(UserRole.init(rawValue:)))
        return UserAccount(
            id: doc.documentID,
            displayName: data["displayName"] as? String ?? "",
            email: data["email"] as? String ?? "",
            roles: roles,
            disabled: data["disabled"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }

    private func map(_ error: Error) -> UserAdminError {
        if let known = error as? UserAdminError { return known }
        let ns = error as NSError

        // Firebase Auth errors
        if ns.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: ns.code) {
            switch code {
            case .emailAlreadyInUse: return .emailInUse
            case .weakPassword: return .weakPassword
            case .invalidEmail: return .invalidEmail
            case .networkError: return .network
            case .tooManyRequests: return .network
            default: return .unknown
            }
        }
        // Firestore errors
        if ns.domain == FirestoreErrorDomain, let code = FirestoreErrorCode.Code(rawValue: ns.code) {
            switch code {
            case .permissionDenied, .unauthenticated: return .permissionDenied
            case .unavailable, .deadlineExceeded: return .network
            default: return .unknown
            }
        }
        if ns.domain == NSURLErrorDomain { return .network }
        return .unknown
    }
}
#endif
