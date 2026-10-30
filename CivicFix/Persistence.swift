import CoreData
import OSLog

struct PersistenceController {
    static let shared = PersistenceController()

    /// In-memory store for SwiftUI previews and tests.
    static let preview = PersistenceController(inMemory: true)

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CivicFix")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                // A broken store shouldn't brick the app; the session just won't persist.
                Logger(subsystem: "com.lozaa.CivicFix", category: "persistence")
                    .error("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
