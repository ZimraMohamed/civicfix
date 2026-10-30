import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var vm = LoginViewModel()
    /// Login is the root screen after Splash, so the back button is off by default.
    var showsBackButton = false

    var body: some View {
        @Bindable var vm = vm

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.fieldToField) {
                if showsBackButton { AppBackButton() }

                AuthHeader(title: "Welcome Back", subtitle: "Sign in to continue reporting and tracking issues.")

                AppTextField(label: "Email", placeholder: "you@example.com",
                             text: $vm.email, type: .email, errorMessage: vm.emailError)

                AppTextField(label: "Password", placeholder: "Enter your password",
                             text: $vm.password, type: .password, errorMessage: vm.passwordError)

                NavigationLink("Forgot Password?") { ForgotPasswordView(prefilledEmail: vm.email) }
                    .font(AppFonts.fieldLabel)
                    .foregroundStyle(AppColors.primary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if let error = vm.formError {
                    Text(error).font(AppFonts.error).foregroundStyle(AppColors.error)
                }

                AppButton(title: "Sign In", isLoading: vm.isLoading) {
                    Task { if await vm.signIn() { session.didSignIn() } }
                }

                LabeledDivider()

                AppButton(title: "Sign in with Face ID", style: .secondary,
                          isDisabled: vm.isLoading, systemImage: "faceid") {
                    Task { if await vm.signInWithBiometrics() { session.didSignIn() } }
                }

                HStack(spacing: 4) {
                    Text("Don’t have an account?").foregroundStyle(AppColors.textSecondary)
                    NavigationLink("Create Account") { RegisterView() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.primary)
                }
                .font(AppFonts.footer)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { LoginView() }.environment(SessionStore())
}
