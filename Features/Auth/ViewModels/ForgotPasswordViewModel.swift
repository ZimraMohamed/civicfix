import SwiftUI

@MainActor @Observable
final class ForgotPasswordViewModel {
    var email = ""
    var emailError: String?
    var formError: String?
    var isLoading = false
    var didSend = false

    private let auth: AuthServicing

    init(auth: AuthServicing = AuthServiceFactory.make(), prefilledEmail: String = "") {
        self.auth = auth
        self.email = prefilledEmail
    }

    func sendReset() async {
        formError = nil
        emailError = Validator.isValidEmail(email) ? nil : "Enter a valid email address"
        guard emailError == nil else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.sendPasswordReset(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            didSend = true
        } catch {
            formError = error.localizedDescription
        }
    }
}
