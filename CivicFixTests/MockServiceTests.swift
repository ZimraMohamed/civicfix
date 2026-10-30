import Testing
import Foundation
@testable import CivicFix

// MARK: - Unavailable / mock report services

struct UnavailableReportServiceTests {
    @Test func everyOperationFailsWithNotConfigured() async {
        let service = UnavailableReportService()
        let draft = ReportDraft(details: "", hashtags: [], imageData: Data([1]), location: nil)
        await #expect(throws: ReportError.notConfigured) { try await service.submit(draft) }
        await #expect(throws: ReportError.notConfigured) { _ = try await service.loadReports() }
        await #expect(throws: ReportError.notConfigured) {
            try await service.updateStatus(ofReport: "1", to: .resolved)
        }
    }

    @Test func streamFailsWithNotConfigured() async {
        await #expect(throws: ReportError.notConfigured) {
            for try await _ in UnavailableReportService().reportsStream() {}
        }
    }
}

struct MockReportServiceTests {
    @Test func loadReturnsSampleDataWithAllStatuses() async throws {
        let reports = try await MockReportService().loadReports()
        #expect(reports.count == 3)
        #expect(Set(reports.map(\.status)) == Set(ReportStatus.allCases))
    }

    @Test func streamEmitsOnceThenFinishes() async throws {
        var emissions = 0
        for try await list in MockReportService().reportsStream() {
            emissions += 1
            #expect(list.count == 3)
        }
        #expect(emissions == 1)
    }
}

// MARK: - Mock user service

struct MockUserServiceTests {
    @Test func loadReturnsSeedUsersNewestFirst() async throws {
        let users = try await MockUserService().loadUsers()
        #expect(users.map(\.id) == ["u1", "u2", "u3"])
    }

    @Test func createdUserAppearsFirstWithGivenRoles() async throws {
        let service = MockUserService()
        try await service.createUser(name: "New Person", email: "new@example.com",
                                     password: validPassword, roles: [.public, .officer])
        let users = try await service.loadUsers()
        #expect(users.count == 4)
        #expect(users.first?.email == "new@example.com")
        #expect(users.first?.roles == [.public, .officer])
        #expect(users.first?.disabled == false)
    }

    @Test func duplicateEmailIsRejectedIgnoringCase() async {
        let service = MockUserService()
        await #expect(throws: UserAdminError.emailInUse) {
            try await service.createUser(name: "Dup", email: "AHSAN@example.com",
                                         password: validPassword, roles: [.public])
        }
    }

    @Test func setRolesAndDisabledUpdateTheUser() async throws {
        let service = MockUserService()
        _ = try await service.loadUsers()           // seeds
        try await service.setRoles(for: "u1", to: [.public, .admin])
        try await service.setDisabled(true, for: "u1")
        let all = try await service.loadUsers()
        let user = try #require(all.first { $0.id == "u1" })
        #expect(user.roles == [.public, .admin])
        #expect(user.disabled)
    }

    @Test func updatingUnknownUserIsIgnored() async throws {
        let service = MockUserService()
        try await service.setRoles(for: "ghost", to: [.admin])
        try await service.setDisabled(true, for: "ghost")
        #expect(try await service.loadUsers().count == 3)
    }
}

// MARK: - Mock auth service (offline backend)
// It persists to UserDefaults.standard, so these tests run one at a time and
// remove their keys before and after.

@Suite(.serialized)
struct MockAuthServiceTests {
    private static let keys = ["hasSession", "hasSignedInBefore", "email", "name", "password"]
        .map { "civicfix.mock.\($0)" }

    private func clean() { Self.keys.forEach { UserDefaults.standard.removeObject(forKey: $0) } }

    @Test func signInStartsASession() async throws {
        clean(); defer { clean() }
        let auth = MockAuthService()
        #expect(!auth.isLoggedIn)
        try await auth.signIn(email: "a@b.com", password: validPassword)
        #expect(auth.isLoggedIn)
        #expect(auth.currentUser?.email == "a@b.com")
    }

    @Test func registerStoresNameAndSignOutEndsSession() async throws {
        clean(); defer { clean() }
        let auth = MockAuthService()
        try await auth.register(name: "Ahsan Ilyas", email: "a@b.com", password: validPassword)
        #expect(auth.currentUser?.displayName == "Ahsan Ilyas")
        auth.signOut()
        #expect(!auth.isLoggedIn)
        #expect(auth.currentUser == nil)
    }

    @Test func restoreSessionNeedsAPreviousSignIn() async throws {
        clean(); defer { clean() }
        let auth = MockAuthService()
        await #expect(throws: AuthError.noSavedSession) { try await auth.restoreSession() }

        try await auth.signIn(email: "a@b.com", password: validPassword)
        auth.signOut()
        try await auth.restoreSession()
        #expect(auth.isLoggedIn)
    }

    @Test func changePasswordChecksCurrentPassword() async throws {
        clean(); defer { clean() }
        let auth = MockAuthService()
        try await auth.signIn(email: "a@b.com", password: validPassword)
        await #expect(throws: AuthError.wrongCurrentPassword) {
            try await auth.changePassword(current: "wrong", new: "newpass123")
        }
        try await auth.changePassword(current: validPassword, new: "newpass123")
        // The new password is now the one that must be supplied.
        await #expect(throws: AuthError.wrongCurrentPassword) {
            try await auth.changePassword(current: validPassword, new: "another123")
        }
    }

    @Test func changeEmailChecksCurrentPassword() async throws {
        clean(); defer { clean() }
        let auth = MockAuthService()
        try await auth.signIn(email: "a@b.com", password: validPassword)
        await #expect(throws: AuthError.wrongCurrentPassword) {
            try await auth.changeEmail(to: "new@b.com", currentPassword: "wrong")
        }
        try await auth.changeEmail(to: "new@b.com", currentPassword: validPassword)
        #expect(auth.currentUser?.email == "new@b.com")
    }

    @Test func rolesDefaultToPublic() async {
        let auth = MockAuthService()
        #expect(await auth.loadRoles() == [.public])
    }
}
