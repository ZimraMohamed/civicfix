import SwiftUI

struct RegisterView: View {
    @Environment(SessionStore.self) private var session
    @State private var vm = RegisterViewModel()

    var body: some View {
        @Bindable var vm = vm

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.fieldToField) {
                AppBackButton()

                AuthHeader(title: "Create Account", subtitle: "Join CivicFix and help improve your community.")

                AppTextField(label: "Full Name", placeholder: "Jane Doe",
                             text: $vm.name, type: .plain, errorMessage: vm.nameError,
                             contentTypeOverride: .name)

                AppTextField(label: "Email", placeholder: "you@example.com",
                             text: $vm.email, type: .email, errorMessage: vm.emailError)

                AppTextField(label: "Password", placeholder: "Create a password",
                             text: $vm.password, type: .password, errorMessage: vm.passwordError,
                             contentTypeOverride: .newPassword)

                AppTextField(label: "Confirm Password", placeholder: "Repeat your password",
                             text: $vm.confirmPassword, type: .password, errorMessage: vm.confirmError,
                             contentTypeOverride: .newPassword)

                if let error = vm.formError {
                    Text(error).font(AppFonts.error).foregroundStyle(AppColors.error)
                }

                AppButton(title: "Create Account", isLoading: vm.isLoading) {
                    Task { if await vm.register() { session.didSignIn() } }
                }

                HStack(spacing: 4) {
                    Text("Already have an account?").foregroundStyle(AppColors.textSecondary)
                    BackLink()
                }
                .font(AppFonts.footer)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct BackLink: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button("Sign In") { dismiss() }
            .fontWeight(.semibold)
            .foregroundStyle(AppColors.primary)
    }
}

#Preview {
    NavigationStack { RegisterView() }.environment(SessionStore())
}
