import Testing
import CoreData
import Foundation
@testable import CivicFix

// MARK: - SessionStore

@MainActor
struct SessionStoreTests {
    private let ahsan = UserProfile(uid: "u1", email: "ahsan@example.com", displayName: "Ahsan Ilyas")

    private func make(auth: StubAuthService = StubAuthService(),
                      repository: InMemorySessionRepository = InMemorySessionRepository())
        -> (SessionStore, StubAuthService, InMemorySessionRepository) {
        (SessionStore(auth: auth, repository: repository), auth, repository)
    }

    @Test func startsOnSplashWithNoProfile() {
        let (store, _, _) = make()
        #expect(store.state == .splash)
        #expect(store.profile == nil)
    }

    @Test func didSignInStoresProfileAndMovesToLoggedIn() {
        let auth = StubAuthService()
        auth.user = ahsan
        let (store, _, repo) = make(auth: auth)
        store.didSignIn()
        #expect(store.state == .loggedIn)
        #expect(store.profile == ahsan)
        #expect(repo.load() == ahsan)
    }

    @Test func didSignInWithoutCurrentUserDoesNothing() {
        let (store, _, repo) = make()
        store.didSignIn()
        #expect(store.state == .splash)
        #expect(store.profile == nil)
        #expect(repo.load() == nil)
    }

    @Test func signOutClearsEverything() {
        let auth = StubAuthService()
        auth.user = ahsan
        let (store, _, repo) = make(auth: auth)
        store.didSignIn()
        store.signOut()
        #expect(auth.signOutCount == 1)
        #expect(store.state == .loggedOut)
        #expect(store.profile == nil)
        #expect(repo.load() == nil)
    }

    @Test func refreshRolesUpdatesProfile() async {
        let auth = StubAuthService()
        auth.user = ahsan
        auth.roles = [.public, .admin]
        let (store, _, _) = make(auth: auth)
        store.didSignIn()
        await store.refreshRoles()
        #expect(store.profile?.roles == [.public, .admin])
        #expect(store.profile?.isAdmin == true)
    }

    @Test func refreshRolesWithoutProfileIsNoOp() async {
        let auth = StubAuthService()
        auth.roles = [.admin]
        let (store, _, _) = make(auth: auth)
        await store.refreshRoles()
        #expect(store.profile == nil)
    }

    @Test func refreshProfilePicksUpChangesAndKeepsRoles() async {
        let auth = StubAuthService()
        auth.user = ahsan
        auth.roles = [.public, .officer]
        let (store, _, repo) = make(auth: auth)
        store.didSignIn()
        await store.refreshRoles()
        try? await Task.sleep(for: .milliseconds(50))   // let didSignIn's background refresh finish

        auth.user = UserProfile(uid: "u1", email: "new@example.com", displayName: "Ahsan Ilyas")
        await store.refreshProfile()

        #expect(auth.reloadCount == 1)
        #expect(store.profile?.email == "new@example.com")
        #expect(store.profile?.roles == [.public, .officer])
        #expect(repo.load()?.email == "new@example.com")
    }

    @Test func rolesAreDroppedWhenADifferentUserSignsIn() async {
        let auth = StubAuthService()
        auth.user = ahsan
        auth.roles = [.public, .admin]
        let (store, _, _) = make(auth: auth)
        store.didSignIn()
        await store.refreshRoles()
        try? await Task.sleep(for: .milliseconds(50))   // let didSignIn's background refresh finish

        auth.user = UserProfile(uid: "u2", email: "other@example.com", displayName: "Other")
        await store.refreshProfile()
        #expect(store.profile?.uid == "u2")
        #expect(store.profile?.roles == [.public])
    }

    // bootstrap() keeps the splash up for at least 1.5 s, so these tests take that long.

    @Test func bootstrapRestoresValidSession() async {
        let auth = StubAuthService()
        auth.loggedIn = true
        auth.user = ahsan
        auth.roles = [.public, .officer]
        let (store, _, repo) = make(auth: auth)
        await store.bootstrap()
        #expect(store.state == .loggedIn)
        #expect(store.profile?.uid == "u1")
        #expect(store.profile?.roles == [.public, .officer])
        #expect(auth.reloadCount == 1)
        #expect(repo.load()?.uid == "u1")
    }

    @Test func bootstrapWithExpiredLoginClearsStaleRecord() async {
        let auth = StubAuthService()          // not logged in
        let (store, _, repo) = make(auth: auth, repository: InMemorySessionRepository(profile: ahsan))
        await store.bootstrap()
        #expect(store.state == .loggedOut)
        #expect(store.profile == nil)
        #expect(repo.load() == nil)
    }

    @Test func bootstrapLoggedInButNoUserEndsSession() async {
        let auth = StubAuthService()
        auth.loggedIn = true                  // user stays nil
        let (store, _, repo) = make(auth: auth, repository: InMemorySessionRepository(profile: ahsan))
        await store.bootstrap()
        #expect(store.state == .loggedOut)
        #expect(repo.load() == nil)
    }

    @Test func bootstrapShowsSplashForAtLeastOneAndAHalfSeconds() async {
        let (store, _, _) = make()
        let start = ContinuousClock.now
        await store.bootstrap()
        let elapsed = ContinuousClock.now - start
        #expect(elapsed >= .seconds(1.4))     // small tolerance for timer granularity
    }

    @Test func previewStoreIsSignedIn() {
        let store = SessionStore.preview(name: "Test User", email: "t@example.com")
        #expect(store.state == .loggedIn)
        #expect(store.profile?.displayName == "Test User")
    }
}

// MARK: - In-memory repository

@MainActor
struct InMemorySessionRepositoryTests {
    private let profile = UserProfile(uid: "u1", email: "a@b.com", displayName: "A B")

    @Test func saveLoadClear() {
        let repo = InMemorySessionRepository()
        #expect(repo.load() == nil)
        repo.save(profile)
        #expect(repo.load() == profile)
        repo.clear()
        #expect(repo.load() == nil)
    }

    @Test func canStartWithProfile() {
        #expect(InMemorySessionRepository(profile: profile).load() == profile)
    }
}

// MARK: - Core Data repository (in-memory store)

@MainActor
struct CoreDataSessionRepositoryTests {
    /// A throw-away in-memory container that reuses the app's compiled model, so
    /// Core Data never sees two models claiming the `UserSession` class.
    private func makeContainer() -> NSPersistentContainer {
        let model = PersistenceController.shared.container.managedObjectModel
        let container = NSPersistentContainer(name: "CivicFix", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error { Issue.record("In-memory store failed to load: \(error)") }
        }
        return container
    }

    private func rowCount(_ context: NSManagedObjectContext) throws -> Int {
        try context.fetch(NSFetchRequest<UserSession>(entityName: "UserSession")).count
    }

    private func signedInAt(_ context: NSManagedObjectContext) -> Date? {
        (try? context.fetch(NSFetchRequest<UserSession>(entityName: "UserSession")))?.first?.signedInAt
    }

    private let ahsan = UserProfile(uid: "u1", email: "ahsan@example.com", displayName: "Ahsan Ilyas")

    @Test func loadOnEmptyStoreIsNil() {
        let container = makeContainer()
        let repo = CoreDataSessionRepository(context: container.viewContext)
        #expect(repo.load() == nil)
    }

    @Test func saveThenLoadRoundTrips() {
        let container = makeContainer()
        let repo = CoreDataSessionRepository(context: container.viewContext)
        repo.save(ahsan)
        #expect(repo.load() == ahsan)
    }

    @Test func savingTwiceKeepsASingleRowAndUpdatesIt() throws {
        let container = makeContainer()
        let repo = CoreDataSessionRepository(context: container.viewContext)
        repo.save(ahsan)
        var renamed = ahsan
        renamed.displayName = "Ahsan I."
        repo.save(renamed)
        #expect(try rowCount(container.viewContext) == 1)
        #expect(repo.load()?.displayName == "Ahsan I.")
    }

    @Test func saveRemovesStrayRows() throws {
        let container = makeContainer()
        let context = container.viewContext
        for index in 0..<3 {
            let row = UserSession(context: context)
            row.uid = "stray\(index)"
            row.email = "stray\(index)@example.com"
        }
        try context.save()
        #expect(try rowCount(context) == 3)

        CoreDataSessionRepository(context: context).save(ahsan)
        #expect(try rowCount(context) == 1)
    }

    @Test func signedInAtIsKeptForSameUserAndRefreshedForNewUser() throws {
        let container = makeContainer()
        let context = container.viewContext
        let repo = CoreDataSessionRepository(context: context)

        repo.save(ahsan)
        let first = try #require(signedInAt(context))

        repo.save(ahsan)   // same user
        let second = try #require(signedInAt(context))
        #expect(second == first)

        repo.save(UserProfile(uid: "u2", email: "other@example.com", displayName: "Other"))
        let third = try #require(signedInAt(context))
        #expect(third >= first)
        #expect(repo.load()?.uid == "u2")
    }

    @Test func clearRemovesSession() throws {
        let container = makeContainer()
        let repo = CoreDataSessionRepository(context: container.viewContext)
        repo.save(ahsan)
        repo.clear()
        #expect(repo.load() == nil)
        #expect(try rowCount(container.viewContext) == 0)
    }

    @Test func clearOnEmptyStoreIsHarmless() {
        let container = makeContainer()
        let repo = CoreDataSessionRepository(context: container.viewContext)
        repo.clear()
        #expect(repo.load() == nil)
    }

    @Test func loadIgnoresRowWithoutEmail() throws {
        let container = makeContainer()
        let row = UserSession(context: container.viewContext)
        row.uid = "u1"          // email missing
        try container.viewContext.save()
        #expect(CoreDataSessionRepository(context: container.viewContext).load() == nil)
    }
}
