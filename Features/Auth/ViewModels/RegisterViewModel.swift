import SwiftUI

@MainActor @Observable
final class RegisterViewModel {
    var name = ""
    var email = ""
    var password = ""
    var confirmPassword = ""
    var nameError: String?
    var emailError: String?
    var passwordError: String?
    var confirmError: String?
    var formError: String?
    var isLoading = false

    private let auth: AuthServicing

    init(auth: AuthServicing = AuthServiceFactory.make()) { self.auth = auth }

    func register() async -> Bool {
        formError = nil
        nameError = Validator.isValidName(name) ? nil : "Enter your full name"
        emailError = Validator.isValidEmail(email) ? nil : "Enter a valid email address"
        passwordError = Validator.isValidPassword(password)
            ? nil : "Use 8+ characters with a letter and a number"
        confirmError = Validator.passwordsMatch(password, confirmPassword)
            ? nil : "Passwords don’t match"
        guard [nameError, emailError, passwordError, confirmError].allSatisfy({ $0 == nil }) else {
            return false
        }

        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.register(name: name, email: email, password: password)
            return true
        } catch {
            formError = error.localizedDescription
            return false
        }
    }
}
