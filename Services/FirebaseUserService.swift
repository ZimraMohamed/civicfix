#if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseCore)
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import OSLog

nonisolated struct FirebaseUserService: UserServicing {
    private let log = Logger(subsystem: "com.lozaa.CivicFix", category: "users")

    private var users: CollectionReference { Firestore.firestore().collection("users") }

    

    func loadUsers() async throws -> [UserAccount] {
        do {
            let snapshot = try await users.order(by: "createdAt", descending: true).getDocuments()
            return snapshot.documents.map(Self.makeUser)
        } catch { throw map(error) }
    }

    
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



    func createUser(name: String, email: String, password: String, roles: Set<UserRole>) async throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        
        let secondary = configureSecondaryApp()
        do {
            let secondaryAuth = Auth.auth(app: secondary)
            let result = try await secondaryAuth.createUser(withEmail: cleanEmail, password: password)
            
            let newUID = result.user.uid
            try await Firestore.firestore(app: secondary).collection("users").document(newUID).setData([
                "displayName": cleanName,
                "email": cleanEmail,
                "roles": [UserRole.public.rawValue],
                "disabled": false,
                "createdAt": FieldValue.serverTimestamp()
            ])
            
            try? await secondaryAuth.signOut()

            
            let extras = roles.subtracting([.public])
            if !extras.isEmpty {
                try await setRoles(for: newUID, to: roles)
            }
            log.info("Admin created user \(newUID) (\(cleanEmail))")
        } catch {
            
            try? await Auth.auth(app: secondary).signOut()
            throw map(error)
        }
    }

    

    func setRoles(for uid: String, to roles: Set<UserRole>) async throws {
        let values = roles.union([.public]).map(\.rawValue).sorted()
        do { try await users.document(uid).updateData(["roles": values]) }
        catch { throw map(error) }
    }

    func setDisabled(_ disabled: Bool, for uid: String) async throws {
        do { try await users.document(uid).updateData(["disabled": disabled]) }
        catch { throw map(error) }
    }

    
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
