import SwiftUI

@MainActor @Observable
final class SessionStore {
    enum State { case splash, loggedOut, loggedIn }

    var state: State = .splash
    
    private(set) var profile: UserProfile?

    private let auth: AuthServicing
    private let repository: SessionRepository

    init(auth: AuthServicing = AuthServiceFactory.make(),
         repository: SessionRepository = CoreDataSessionRepository()) {
        self.auth = auth
        self.repository = repository
    }

   
    func bootstrap() async {
        let started = ContinuousClock.now

        if auth.isLoggedIn {
            await auth.reloadUser()
            if let user = auth.currentUser {
                apply(user)
                await refreshRoles()
            } else {
                endSession()
            }
        } else {
            endSession()
        }

        // Keep the splash up for at least 1.5s so it doesn't flash.
        let remaining = Duration.seconds(1.5) - (ContinuousClock.now - started)
        if remaining > .zero { try? await Task.sleep(for: remaining) }
        state = profile == nil ? .loggedOut : .loggedIn
    }

    
    func didSignIn() {
        guard let user = auth.currentUser else { return }
        apply(user)
        state = .loggedIn
        Task { await refreshRoles() }
    }

   
    func refreshProfile() async {
        await auth.reloadUser()
        if let user = auth.currentUser { apply(user) }
    }

    func signOut() {
        auth.signOut()
        endSession()
        state = .loggedOut
    }

 

    private func apply(_ user: UserProfile) {
        var user = user
        // Keep roles we already fetched for this same user.
        if let current = profile, current.uid == user.uid { user.roles = current.roles }
        profile = user
        repository.save(user)
    }

   
    func refreshRoles() async {
        guard let uid = profile?.uid else { return }
        let roles = await auth.loadRoles()
        if profile?.uid == uid { profile?.roles = roles }
    }

    private func endSession() {
        profile = nil
        repository.clear()
    }

    
    static func preview(name: String = "Ahsan Ilyas", email: String = "ahsan@example.com") -> SessionStore {
        let store = SessionStore(auth: MockAuthService(), repository: InMemorySessionRepository())
        store.profile = UserProfile(uid: "preview", email: email, displayName: name)
        store.state = .loggedIn
        return store
    }
}
