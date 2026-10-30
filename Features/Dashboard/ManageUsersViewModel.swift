import SwiftUI

@MainActor @Observable
/// Feeds the Manage Users list. Streams every user from Firestore (newest
/// first), exposes a search filter, and offers role + disable toggles that
/// are applied optimistically and rolled back on failure.
final class ManageUsersViewModel {
    private(set) var users: [UserAccount] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?
    var search = ""

    private let service: UserServicing

    init(service: UserServicing = UserServiceFactory.make()) {
        self.service = service
    }

    /// Filtered, searchable subset shown in the list.
    var visibleUsers: [UserAccount] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return users }
        return users.filter {
            $0.displayName.lowercased().contains(q)
                || $0.email.lowercased().contains(q)
        }
    }

    func observe() async {
        do {
            for try await list in service.usersStream() {
                users = list
                hasLoaded = true
                errorMessage = nil
            }
        } catch {
            hasLoaded = true
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? UserAdminError.unknown.errorDescription
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        do {
            users = try await service.loadUsers()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? UserAdminError.unknown.errorDescription
        }
    }

    /// Optimistically toggles a role on the user; rolls back on failure.
    func toggle(role: UserRole, on user: UserAccount) async {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        var updated = users[index]
        if updated.roles.contains(role) {
            // Never strip the public role from a non-public role toggle
            guard role != .public else { return }
            updated.roles.remove(role)
        } else {
            updated.roles.insert(role)
        }
        users[index] = updated
        do {
            try await service.setRoles(for: user.id, to: updated.roles)
        } catch {
            if let back = users.firstIndex(where: { $0.id == user.id }) { users[back] = user }
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? UserAdminError.unknown.errorDescription
        }
    }

    /// Optimistically toggles the disabled flag; rolls back on failure.
    func toggleDisabled(on user: UserAccount) async {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        let newValue = !users[index].disabled
        users[index].disabled = newValue
        do {
            try await service.setDisabled(newValue, for: user.id)
        } catch {
            if let back = users.firstIndex(where: { $0.id == user.id }) {
                users[back].disabled = user.disabled
            }
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? UserAdminError.unknown.errorDescription
        }
    }
}
