import Testing
import Foundation
@testable import CivicFix

// Login

@MainActor
struct LoginViewModelTests {
    private func make(auth: StubAuthService = StubAuthService(),
                      biometric: StubBiometric = StubBiometric()) -> (LoginViewModel, StubAuthService, StubBiometric) {
        (LoginViewModel(auth: auth, biometric: biometric), auth, biometric)
    }

    @Test func invalidEmailBlocksSignIn() async {
        let (vm, auth, _) = make()
        vm.email = "not-an-email"
        vm.password = "secret"
        let ok = await vm.signIn()
        #expect(!ok)
        #expect(vm.emailError == "Enter a valid email address")
        #expect(vm.passwordError == nil)
        #expect(auth.signInCalls.isEmpty)
    }

    @Test func emptyPasswordBlocksSignIn() async {
        let (vm, auth, _) = make()
        vm.email = "a@b.com"
        let ok = await vm.signIn()
        #expect(!ok)
        #expect(vm.passwordError == "Enter your password")
        #expect(auth.signInCalls.isEmpty)
    }

    @Test func successfulSignInCallsServiceAndClearsErrors() async {
        let (vm, auth, _) = make()
        vm.email = "a@b.com"
        vm.password = "secret"
        let ok = await vm.signIn()
        #expect(ok)
        #expect(vm.emailError == nil)
        #expect(vm.passwordError == nil)
        #expect(vm.formError == nil)
        #expect(!vm.isLoading)
        #expect(auth.signInCalls.count == 1)
        #expect(auth.signInCalls.first?.email == "a@b.com")
        #expect(auth.signInCalls.first?.password == "secret")
    }

    @Test func serviceFailureSurfacesMessage() async {
        let auth = StubAuthService()
        auth.error = AuthError.invalidCredentials
        let (vm, _, _) = make(auth: auth)
        vm.email = "a@b.com"
        vm.password = "wrong"
        let ok = await vm.signIn()
        #expect(!ok)
        #expect(vm.formError == AuthError.invalidCredentials.errorDescription)
        #expect(!vm.isLoading)
    }

    @Test func formErrorIsClearedOnNextAttempt() async {
        let auth = StubAuthService()
        auth.error = AuthError.network
        let (vm, _, _) = make(auth: auth)
        vm.email = "a@b.com"
        vm.password = "secret"
        _ = await vm.signIn()
        #expect(vm.formError != nil)

        auth.error = nil
        let ok = await vm.signIn()
        #expect(ok)
        #expect(vm.formError == nil)
    }

    @Test func biometricSuccessRestoresSession() async {
        let (vm, auth, biometric) = make()
        let ok = await vm.signInWithBiometrics()
        #expect(ok)
        #expect(auth.restoreCount == 1)
        #expect(biometric.reasons == ["Sign in to CivicFix"])
        #expect(vm.formError == nil)
    }

    @Test func biometricFailureShowsMessageAndSkipsRestore() async {
        let biometric = StubBiometric()
        biometric.error = BiometricError.failed
        let (vm, auth, _) = make(biometric: biometric)
        let ok = await vm.signInWithBiometrics()
        #expect(!ok)
        #expect(vm.formError == BiometricError.failed.errorDescription)
        #expect(auth.restoreCount == 0)
    }

    @Test func biometricCancellationIsSilent() async {
        let biometric = StubBiometric()
        biometric.error = CancellationError()
        let (vm, auth, _) = make(biometric: biometric)
        let ok = await vm.signInWithBiometrics()
        #expect(!ok)
        #expect(vm.formError == nil)
        #expect(auth.restoreCount == 0)
    }

    @Test func biometricWithoutSavedSessionShowsMessage() async {
        let auth = StubAuthService()
        auth.error = AuthError.noSavedSession
        let (vm, _, _) = make(auth: auth)
        let ok = await vm.signInWithBiometrics()
        #expect(!ok)
        #expect(vm.formError == AuthError.noSavedSession.errorDescription)
    }
}

// Register

@MainActor
struct RegisterViewModelTests {
    private func filled(_ auth: StubAuthService = StubAuthService()) -> (RegisterViewModel, StubAuthService) {
        let vm = RegisterViewModel(auth: auth)
        vm.name = "Ahsan Ilyas"
        vm.email = "ahsan@example.com"
        vm.password = validPassword
        vm.confirmPassword = validPassword
        return (vm, auth)
    }

    @Test func emptyFormShowsEveryError() async {
        let auth = StubAuthService()
        let vm = RegisterViewModel(auth: auth)
        let ok = await vm.register()
        #expect(!ok)
        #expect(vm.nameError == "Enter your full name")
        #expect(vm.emailError == "Enter a valid email address")
        #expect(vm.passwordError == "Use 8+ characters with a letter and a number")
        #expect(vm.confirmError == "Passwords don’t match")
        #expect(auth.registerCalls.isEmpty)
    }

    @Test func mismatchedConfirmationIsRejected() async {
        let (vm, auth) = filled()
        vm.confirmPassword = "different1"
        let ok = await vm.register()
        #expect(!ok)
        #expect(vm.confirmError == "Passwords don’t match")
        #expect(vm.nameError == nil && vm.emailError == nil && vm.passwordError == nil)
        #expect(auth.registerCalls.isEmpty)
    }

    @Test func weakPasswordIsRejected() async {
        let (vm, _) = filled()
        vm.password = "short"
        vm.confirmPassword = "short"
        let ok = await vm.register()
        #expect(!ok)
        #expect(vm.passwordError != nil)
    }

    @Test func validFormRegisters() async {
        let (vm, auth) = filled()
        let ok = await vm.register()
        #expect(ok)
        #expect(!vm.isLoading)
        #expect(vm.formError == nil)
        #expect(auth.registerCalls.count == 1)
        #expect(auth.registerCalls.first?.name == "Ahsan Ilyas")
        #expect(auth.registerCalls.first?.email == "ahsan@example.com")
        #expect(auth.registerCalls.first?.password == validPassword)
    }

    @Test func serviceErrorIsShown() async {
        let auth = StubAuthService()
        auth.error = AuthError.emailInUse
        let (vm, _) = filled(auth)
        let ok = await vm.register()
        #expect(!ok)
        #expect(vm.formError == AuthError.emailInUse.errorDescription)
        #expect(!vm.isLoading)
    }
}

// MARK: - Forgot password

@MainActor
struct ForgotPasswordViewModelTests {
    @Test func prefilledEmailIsUsed() {
        let vm = ForgotPasswordViewModel(auth: StubAuthService(), prefilledEmail: "a@b.com")
        #expect(vm.email == "a@b.com")
    }

    @Test func invalidEmailShowsErrorAndDoesNotCallService() async {
        let auth = StubAuthService()
        let vm = ForgotPasswordViewModel(auth: auth)
        vm.email = "nope"
        await vm.sendReset()
        #expect(vm.emailError == "Enter a valid email address")
        #expect(!vm.didSend)
        #expect(auth.resetEmails.isEmpty)
    }

    @Test func successSendsTrimmedEmail() async {
        let auth = StubAuthService()
        let vm = ForgotPasswordViewModel(auth: auth)
        vm.email = "  a@b.com "
        await vm.sendReset()
        #expect(vm.didSend)
        #expect(vm.emailError == nil)
        #expect(vm.formError == nil)
        #expect(!vm.isLoading)
        #expect(auth.resetEmails == ["a@b.com"])
    }

    @Test func serviceFailureShowsMessage() async {
        let auth = StubAuthService()
        auth.error = AuthError.emailNotFound
        let vm = ForgotPasswordViewModel(auth: auth)
        vm.email = "a@b.com"
        await vm.sendReset()
        #expect(!vm.didSend)
        #expect(vm.formError == AuthError.emailNotFound.errorDescription)
    }
}

// Change e-mail

@MainActor
struct ChangeEmailViewModelTests {
    private func make(_ auth: StubAuthService = StubAuthService()) -> (ChangeEmailViewModel, StubAuthService) {
        (ChangeEmailViewModel(auth: auth, currentEmail: "old@example.com"), auth)
    }

    @Test func invalidEmailIsRejected() async {
        let (vm, auth) = make()
        vm.newEmail = "bad"
        vm.password = "pw"
        await vm.submit()
        #expect(vm.emailError == "Enter a valid email address")
        #expect(auth.changeEmailCalls.isEmpty)
    }

    @Test func sameEmailIgnoringCaseIsRejected() async {
        let (vm, auth) = make()
        vm.newEmail = "OLD@Example.com"
        vm.password = "pw"
        await vm.submit()
        #expect(vm.emailError == "That’s already your email")
        #expect(auth.changeEmailCalls.isEmpty)
    }

    @Test func missingPasswordIsRejected() async {
        let (vm, auth) = make()
        vm.newEmail = "new@example.com"
        await vm.submit()
        #expect(vm.passwordError == "Enter your current password")
        #expect(auth.changeEmailCalls.isEmpty)
    }

    @Test func successRecordsTargetAndClearsPassword() async {
        let (vm, auth) = make()
        vm.newEmail = "  new@example.com "
        vm.password = "pw"
        await vm.submit()
        #expect(vm.sentTo == "new@example.com")
        #expect(vm.password.isEmpty)
        #expect(vm.formError == nil)
        #expect(!vm.isLoading)
        #expect(auth.changeEmailCalls.first?.email == "new@example.com")
        #expect(auth.changeEmailCalls.first?.password == "pw")
    }

    @Test func failureKeepsPasswordAndShowsMessage() async {
        let auth = StubAuthService()
        auth.error = AuthError.wrongCurrentPassword
        let (vm, _) = make(auth)
        vm.newEmail = "new@example.com"
        vm.password = "pw"
        await vm.submit()
        #expect(vm.sentTo == nil)
        #expect(vm.password == "pw")
        #expect(vm.formError == AuthError.wrongCurrentPassword.errorDescription)
    }
}

// Change password

@MainActor
struct ChangePasswordViewModelTests {
    private func filled(_ auth: StubAuthService = StubAuthService()) -> (ChangePasswordViewModel, StubAuthService) {
        let vm = ChangePasswordViewModel(auth: auth)
        vm.currentPassword = "oldpass123"
        vm.newPassword = "newpass456"
        vm.confirmPassword = "newpass456"
        return (vm, auth)
    }

    @Test func emptyCurrentPasswordIsRejected() async {
        let (vm, auth) = filled()
        vm.currentPassword = ""
        await vm.submit()
        #expect(vm.currentError == "Enter your current password")
        #expect(auth.changePasswordCalls.isEmpty)
    }

    @Test func weakNewPasswordIsRejected() async {
        let (vm, auth) = filled()
        vm.newPassword = "weak"
        vm.confirmPassword = "weak"
        await vm.submit()
        #expect(vm.newError == "Use 8+ characters with a letter and a number")
        #expect(auth.changePasswordCalls.isEmpty)
    }

    @Test func reusingCurrentPasswordIsRejected() async {
        let (vm, auth) = filled()
        vm.newPassword = vm.currentPassword
        vm.confirmPassword = vm.currentPassword
        await vm.submit()
        #expect(vm.newError == "Choose a password you haven’t used here")
        #expect(auth.changePasswordCalls.isEmpty)
    }

    @Test func mismatchedConfirmationIsRejected() async {
        let (vm, auth) = filled()
        vm.confirmPassword = "other12345"
        await vm.submit()
        #expect(vm.confirmError == "Passwords don’t match")
        #expect(auth.changePasswordCalls.isEmpty)
    }

    @Test func successChangesPasswordAndClearsFields() async {
        let (vm, auth) = filled()
        await vm.submit()
        #expect(vm.didChange)
        #expect(vm.currentPassword.isEmpty && vm.newPassword.isEmpty && vm.confirmPassword.isEmpty)
        #expect(vm.formError == nil)
        #expect(!vm.isLoading)
        #expect(auth.changePasswordCalls.first?.current == "oldpass123")
        #expect(auth.changePasswordCalls.first?.new == "newpass456")
    }

    @Test func failureKeepsFieldsAndShowsMessage() async {
        let auth = StubAuthService()
        auth.error = AuthError.wrongCurrentPassword
        let (vm, _) = filled(auth)
        await vm.submit()
        #expect(!vm.didChange)
        #expect(vm.formError == AuthError.wrongCurrentPassword.errorDescription)
        #expect(vm.currentPassword == "oldpass123")
    }

    @Test func didChangeResetsOnNextSubmit() async {
        let (vm, _) = filled()
        await vm.submit()
        #expect(vm.didChange)
        await vm.submit()      // fields are now empty -> validation fails
        #expect(!vm.didChange)
    }
}
