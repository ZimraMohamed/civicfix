import SwiftUI

@MainActor @Observable
final class SessionStore {
    enum State { case splash, loggedOut, loggedIn }

    var state: State = .splash
    /// The signed-in user, restored from Core Data on launch.
    private(set) var profile: UserProfile?

    private let auth: AuthServicing
    private let repository: SessionRepository

    init(auth: AuthServicing = AuthServiceFactory.make(),
         repository: SessionRepository = CoreDataSessionRepository()) {
        self.auth = auth
        self.repository = repository
    }

    /// Restores the saved session. The Core Data record says who was signed in;
    /// the auth service says whether that login is still valid.
    func bootstrap() async {
        let started = ContinuousClock.now

        if auth.isLoggedIn {
            await auth.reloadUser()          // picks up e-mail changes verified elsewhere
            if let user = auth.currentUser {
                apply(user)
                await refreshRoles()
            } else {
                endSession()
            }
        } else {
            endSession()                     // stale record, e.g. login expired or revoked
        }

        // Keep the splash up for at least 1.5s so it doesn't flash.
        let remaining = Duration.seconds(1.5) - (ContinuousClock.now - started)
        if remaining > .zero { try? await Task.sleep(for: remaining) }
        state = profile == nil ? .loggedOut : .loggedIn
    }

    /// Call after a successful sign in, registration or Face ID login.
    func didSignIn() {
        guard let user = auth.currentUser else { return }
        apply(user)
        state = .loggedIn
        Task { await refreshRoles() }
    }

    /// Call after the profile changes (e.g. name or e-mail) so the UI and store stay in sync.
    func refreshProfile() async {
        await auth.reloadUser()
        if let user = auth.currentUser { apply(user) }
    }

    func signOut() {
        auth.signOut()
        endSession()
        state = .loggedOut
    }

    // MARK: - Private

    private func apply(_ user: UserProfile) {
        var user = user
        // Keep roles we already fetched for this same user.
        if let current = profile, current.uid == user.uid { user.roles = current.roles }
        profile = user
        repository.save(user)
    }

    /// Loads the signed-in user's roles from the server.
    func refreshRoles() async {
        guard let uid = profile?.uid else { return }
        let roles = await auth.loadRoles()
        if profile?.uid == uid { profile?.roles = roles }
    }

    private func endSession() {
        profile = nil
        repository.clear()
    }

    /// Signed-in store with in-memory storage, for SwiftUI previews.
    static func preview(name: String = "Ahsan Ilyas", email: String = "ahsan@example.com") -> SessionStore {
        let store = SessionStore(auth: MockAuthService(), repository: InMemorySessionRepository())
        store.profile = UserProfile(uid: "preview", email: email, displayName: name)
        store.state = .loggedIn
        return store
    }
}
