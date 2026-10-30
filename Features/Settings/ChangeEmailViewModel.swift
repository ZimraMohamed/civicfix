import SwiftUI

@MainActor @Observable
final class ChangeEmailViewModel {
    var newEmail = ""
    var password = ""
    var emailError: String?
    var passwordError: String?
    var formError: String?
    var isLoading = false
    /// The address the verification link was sent to, once sent.
    var sentTo: String?

    private let auth: AuthServicing
    private let currentEmail: String

    init(auth: AuthServicing = AuthServiceFactory.make(), currentEmail: String) {
        self.auth = auth
        self.currentEmail = currentEmail
    }

    func submit() async {
        formError = nil
        sentTo = nil
        let target = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        if !Validator.isValidEmail(target) {
            emailError = "Enter a valid email address"
        } else if target.caseInsensitiveCompare(currentEmail) == .orderedSame {
            emailError = "That’s already your email"
        } else {
            emailError = nil
        }
        passwordError = password.isEmpty ? "Enter your current password" : nil
        guard emailError == nil, passwordError == nil else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.changeEmail(to: target, currentPassword: password)
            sentTo = target
            password = ""
        } catch {
            formError = error.localizedDescription
        }
    }
}
