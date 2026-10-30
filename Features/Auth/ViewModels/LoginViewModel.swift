import SwiftUI

@MainActor @Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var emailError: String?
    var passwordError: String?
    var formError: String?
    var isLoading = false

    private let auth: AuthServicing
    private let biometric: BiometricAuthenticating

    init(auth: AuthServicing = AuthServiceFactory.make(),
         biometric: BiometricAuthenticating = BiometricService()) {
        self.auth = auth
        self.biometric = biometric
    }

    /// Returns true on success.
    func signIn() async -> Bool {
        formError = nil
        emailError = Validator.isValidEmail(email) ? nil : "Enter a valid email address"
        passwordError = password.isEmpty ? "Enter your password" : nil
        guard emailError == nil, passwordError == nil else { return false }

        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.signIn(email: email, password: password)
            return true
        } catch {
            formError = error.localizedDescription
            return false
        }
    }

    func signInWithBiometrics() async -> Bool {
        formError = nil
        do {
            try await biometric.authenticate(reason: "Sign in to CivicFix")
            try await auth.restoreSession()
            return true
        } catch is CancellationError {
            return false
        } catch {
            formError = error.localizedDescription
            return false
        }
    }
}
