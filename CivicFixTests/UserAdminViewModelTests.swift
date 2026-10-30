import Testing
import Foundation
@testable import CivicFix

// Manage users

@MainActor
struct ManageUsersViewModelTests {
    private func sample() -> [UserAccount] {
        [makeUser(id: "u1", name: "Ahsan Ilyas", email: "ahsan@example.com", roles: [.public]),
         makeUser(id: "u2", name: "Nimal Perera", email: "nimal@work.org", roles: [.public, .officer]),
         makeUser(id: "u3", name: "Sara Khan", email: "sara@example.com", roles: [.public, .admin])]
    }

    private func loaded(_ service: StubUserService = StubUserService()) async -> (ManageUsersViewModel, StubUserService) {
        service.users = sample()
        let vm = ManageUsersViewModel(service: service)
        await vm.load()
        return (vm, service)
    }

    private func user(_ id: String, in vm: ManageUsersViewModel) -> UserAccount? {
        vm.users.first { $0.id == id }
    }

    @Test func loadPopulatesUsers() async {
        let (vm, _) = await loaded()
        #expect(vm.users.count == 3)
        #expect(vm.hasLoaded)
        #expect(!vm.isLoading)
        #expect(vm.errorMessage == nil)
    }

    @Test func loadFailureShowsMessage() async {
        let service = StubUserService()
        service.loadError = UserAdminError.permissionDenied
        let vm = ManageUsersViewModel(service: service)
        await vm.load()
        #expect(vm.errorMessage == UserAdminError.permissionDenied.errorDescription)
        #expect(vm.hasLoaded)
    }

    @Test func loadFailureWithUnknownErrorUsesGenericMessage() async {
        let service = StubUserService()
        service.loadError = TestError.boom
        let vm = ManageUsersViewModel(service: service)
        await vm.load()
        #expect(vm.errorMessage == UserAdminError.unknown.errorDescription)
    }

    @Test func searchMatchesNameAndEmail() async {
        let (vm, _) = await loaded()
        vm.search = "NIMAL"
        #expect(vm.visibleUsers.map(\.id) == ["u2"])
        vm.search = "example.com"
        #expect(vm.visibleUsers.map(\.id) == ["u1", "u3"])
        vm.search = "  "
        #expect(vm.visibleUsers.count == 3)
        vm.search = "zzz"
        #expect(vm.visibleUsers.isEmpty)
    }

    @Test func observeReplacesUsers() async {
        let service = StubUserService()
        service.streamBatches = [[makeUser(id: "a")], [makeUser(id: "b"), makeUser(id: "c")]]
        let vm = ManageUsersViewModel(service: service)
        await vm.observe()
        #expect(vm.users.map(\.id) == ["b", "c"])
        #expect(vm.hasLoaded)
    }

    @Test func observeErrorShowsMessage() async {
        let service = StubUserService()
        service.streamError = UserAdminError.network
        let vm = ManageUsersViewModel(service: service)
        await vm.observe()
        #expect(vm.errorMessage == UserAdminError.network.errorDescription)
        #expect(vm.hasLoaded)
    }

    @Test func toggleAddsRole() async throws {
        let (vm, service) = await loaded()
        let target = try #require(user("u1", in: vm))
        await vm.toggle(role: .officer, on: target)
        #expect(user("u1", in: vm)?.roles.contains(.officer) == true)
        #expect(service.roleCalls.count == 1)
        #expect(service.roleCalls.first?.uid == "u1")
        #expect(service.roleCalls.first?.roles == [.public, .officer])
    }

    @Test func toggleRemovesRole() async throws {
        let (vm, service) = await loaded()
        let target = try #require(user("u2", in: vm))
        await vm.toggle(role: .officer, on: target)
        #expect(user("u2", in: vm)?.roles == [.public])
        #expect(service.roleCalls.first?.roles == [.public])
    }

    @Test func publicRoleCanNeverBeRemoved() async throws {
        let (vm, service) = await loaded()
        let target = try #require(user("u1", in: vm))
        await vm.toggle(role: .public, on: target)
        #expect(user("u1", in: vm)?.roles.contains(.public) == true)
        #expect(service.roleCalls.isEmpty)
    }

    @Test func toggleRollsBackWhenServerRefuses() async throws {
        let service = StubUserService()
        service.rolesError = UserAdminError.permissionDenied
        let (vm, _) = await loaded(service)
        let target = try #require(user("u1", in: vm))
        await vm.toggle(role: .admin, on: target)
        #expect(user("u1", in: vm)?.roles == [.public])
        #expect(vm.errorMessage == UserAdminError.permissionDenied.errorDescription)
    }

    @Test func toggleForUnknownUserDoesNothing() async {
        let (vm, service) = await loaded()
        await vm.toggle(role: .officer, on: makeUser(id: "ghost"))
        #expect(service.roleCalls.isEmpty)
    }

    @Test func toggleDisabledFlipsFlagBothWays() async throws {
        let (vm, service) = await loaded()
        let target = try #require(user("u1", in: vm))
        await vm.toggleDisabled(on: target)
        #expect(user("u1", in: vm)?.disabled == true)

        let disabledNow = try #require(user("u1", in: vm))
        await vm.toggleDisabled(on: disabledNow)
        #expect(user("u1", in: vm)?.disabled == false)

        #expect(service.disabledCalls.map { $0.disabled } == [true, false])
    }

    @Test func toggleDisabledRollsBackOnFailure() async throws {
        let service = StubUserService()
        service.disabledError = UserAdminError.network
        let (vm, _) = await loaded(service)
        let target = try #require(user("u1", in: vm))
        await vm.toggleDisabled(on: target)
        #expect(user("u1", in: vm)?.disabled == false)
        #expect(vm.errorMessage == UserAdminError.network.errorDescription)
    }
}

// MARK: - Add user

@MainActor
struct AddUserViewModelTests {
    private func filled(_ service: StubUserService = StubUserService()) -> (AddUserViewModel, StubUserService) {
        let vm = AddUserViewModel(service: service)
        vm.name = "Nimal Perera"
        vm.email = "nimal@example.com"
        vm.password = validPassword
        vm.confirmPassword = validPassword
        return (vm, service)
    }

    @Test func emptyFormShowsEveryError() async {
        let service = StubUserService()
        let vm = AddUserViewModel(service: service)
        let ok = await vm.submit()
        #expect(!ok)
        #expect(vm.nameError == "Enter a full name")
        #expect(vm.emailError == "Enter a valid email address")
        #expect(vm.passwordError == "Use 8+ characters with a letter and a number")
        #expect(vm.confirmError == "Passwords don’t match")
        #expect(service.createCalls.isEmpty)
        #expect(!vm.didSucceed)
    }

    @Test func mismatchedPasswordsAreRejected() async {
        let (vm, service) = filled()
        vm.confirmPassword = "nope12345"
        let ok = await vm.submit()
        #expect(!ok)
        #expect(vm.confirmError == "Passwords don’t match")
        #expect(service.createCalls.isEmpty)
    }

    @Test func defaultsToPublicRoleOnly() async {
        let (vm, service) = filled()
        let ok = await vm.submit()
        #expect(ok)
        #expect(vm.didSucceed)
        #expect(!vm.isLoading)
        #expect(service.createCalls.count == 1)
        #expect(service.createCalls.first?.name == "Nimal Perera")
        #expect(service.createCalls.first?.email == "nimal@example.com")
        #expect(service.createCalls.first?.roles == [.public])
    }

    @Test func grantsSelectedRoles() async {
        let (vm, service) = filled()
        vm.grantOfficer = true
        _ = await vm.submit()
        #expect(service.createCalls.last?.roles == [.public, .officer])

        let (vm2, service2) = filled()
        vm2.grantOfficer = true
        vm2.grantAdmin = true
        _ = await vm2.submit()
        #expect(service2.createCalls.last?.roles == [.public, .officer, .admin])
    }

    @Test func serviceFailureShowsMessageAndDoesNotSucceed() async {
        let service = StubUserService()
        service.createError = UserAdminError.emailInUse
        let (vm, _) = filled(service)
        let ok = await vm.submit()
        #expect(!ok)
        #expect(!vm.didSucceed)
        #expect(vm.formError == UserAdminError.emailInUse.errorDescription)
        #expect(!vm.isLoading)
    }
}
