import CoreData
import OSLog


nonisolated struct UserProfile: Equatable, Sendable {
    var uid: String
    var email: String
    var displayName: String
    
    var roles: Set<UserRole> = [.public]

    func has(_ role: UserRole) -> Bool { roles.contains(role) }
    var isAdmin: Bool { has(.admin) }
    var isOfficer: Bool { has(.officer) }

    
    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2).compactMap(\.first)
        if !parts.isEmpty { return String(parts).uppercased() }
        return email.first.map { String($0).uppercased() } ?? "?"
    }
}


protocol SessionRepository {
    func load() -> UserProfile?
    func save(_ profile: UserProfile)
    func clear()
}


final class CoreDataSessionRepository: SessionRepository {
    private let context: NSManagedObjectContext
    private let log = Logger(subsystem: "com.lozaa.CivicFix", category: "session")

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    func load() -> UserProfile? {
        guard let row = fetchRows().first,
              let uid = row.uid, let email = row.email else { return nil }
        return UserProfile(uid: uid, email: email, displayName: row.displayName ?? "")
    }

    func save(_ profile: UserProfile) {
        let rows = fetchRows()
       
        rows.dropFirst().forEach(context.delete)
        let row = rows.first ?? UserSession(context: context)
        if row.signedInAt == nil || row.uid != profile.uid { row.signedInAt = Date() }
        row.uid = profile.uid
        row.email = profile.email
        row.displayName = profile.displayName
        commit()
    }

    func clear() {
        fetchRows().forEach(context.delete)
        commit()
    }

    private func fetchRows() -> [UserSession] {
        let request = NSFetchRequest<UserSession>(entityName: "UserSession")
        do { return try context.fetch(request) }
        catch { log.error("Fetch failed: \(error.localizedDescription)"); return [] }
    }

    private func commit() {
        guard context.hasChanges else { return }
        do { try context.save() }
        catch { context.rollback(); log.error("Save failed: \(error.localizedDescription)") }
    }
}


final class InMemorySessionRepository: SessionRepository {
    private var profile: UserProfile?
    init(profile: UserProfile? = nil) { self.profile = profile }
    func load() -> UserProfile? { profile }
    func save(_ profile: UserProfile) { self.profile = profile }
    func clear() { profile = nil }
}
