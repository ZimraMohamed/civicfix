import SwiftUI

@MainActor @Observable

final class AddUserViewModel {
    var name = ""
    var email = ""
    var password = ""
    var confirmPassword = ""
    var grantOfficer = false
    var grantAdmin = false

    var nameError: String?
    var emailError: String?
    var passwordError: String?
    var confirmError: String?
    var formError: String?
    var isLoading = false

    /// Set to true when creation succeeds; the view uses this to dismiss.
    private(set) var didSucceed = false

    private let service: UserServicing

    init(service: UserServicing = UserServiceFactory.make()) {
        self.service = service
    }

    func submit() async -> Bool {
        formError = nil
        nameError = Validator.isValidName(name) ? nil : "Enter a full name"
        emailError = Validator.isValidEmail(email) ? nil : "Enter a valid email address"
        passwordError = Validator.isValidPassword(password)
            ? nil : "Use 8+ characters with a letter and a number"
        confirmError = Validator.passwordsMatch(password, confirmPassword)
            ? nil : "Passwords don’t match"
        guard [nameError, emailError, passwordError, confirmError].allSatisfy({ $0 == nil }) else {
            return false
        }

        var roles: Set<UserRole> = [.public]
        if grantOfficer { roles.insert(.officer) }
        if grantAdmin { roles.insert(.admin) }

        isLoading = true
        defer { isLoading = false }
        do {
            try await service.createUser(name: name, email: email, password: password, roles: roles)
            didSucceed = true
            return true
        } catch {
            formError = error.localizedDescription
            return false
        }
    }
}
