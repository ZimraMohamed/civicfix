import SwiftUI

@MainActor @Observable
final class ChangePasswordViewModel {
    var currentPassword = ""
    var newPassword = ""
    var confirmPassword = ""
    var currentError: String?
    var newError: String?
    var confirmError: String?
    var formError: String?
    var isLoading = false
    var didChange = false

    private let auth: AuthServicing

    init(auth: AuthServicing = AuthServiceFactory.make()) { self.auth = auth }

    func submit() async {
        formError = nil
        didChange = false
        currentError = currentPassword.isEmpty ? "Enter your current password" : nil
        if !Validator.isValidPassword(newPassword) {
            newError = "Use 8+ characters with a letter and a number"
        } else if newPassword == currentPassword {
            newError = "Choose a password you haven’t used here"
        } else {
            newError = nil
        }
        confirmError = Validator.passwordsMatch(newPassword, confirmPassword) ? nil : "Passwords don’t match"
        guard [currentError, newError, confirmError].allSatisfy({ $0 == nil }) else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.changePassword(current: currentPassword, new: newPassword)
            currentPassword = ""; newPassword = ""; confirmPassword = ""
            didChange = true
        } catch {
            formError = error.localizedDescription
        }
    }
}
