import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ForgotPasswordViewModel

    init(prefilledEmail: String = "") {
        _vm = State(initialValue: ForgotPasswordViewModel(prefilledEmail: prefilledEmail))
    }

    var body: some View {
        @Bindable var vm = vm

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.fieldToField) {
                AppBackButton()

                AuthHeader(title: "Reset Password",
                           subtitle: "Enter the email linked to your account and we’ll send you a reset link.")

                if vm.didSend {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Check your inbox", systemImage: "envelope.badge")
                            .font(AppFonts.fieldLabel)
                            .foregroundStyle(AppColors.primary)
                        Text("If an account exists for \(vm.email), a reset link is on its way.")
                            .font(AppFonts.subtitle)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: AppSpacing.inputRadius).fill(AppColors.surface))
                    .overlay(RoundedRectangle(cornerRadius: AppSpacing.inputRadius)
                        .stroke(AppColors.border, lineWidth: 1))

                    AppButton(title: "Back to Sign In") { dismiss() }
                } else {
                    AppTextField(label: "Email", placeholder: "you@example.com",
                                 text: $vm.email, type: .email, errorMessage: vm.emailError)

                    if let error = vm.formError {
                        Text(error).font(AppFonts.error).foregroundStyle(AppColors.error)
                    }

                    AppButton(title: "Send Reset Link", isLoading: vm.isLoading) {
                        Task { await vm.sendReset() }
                    }
                }
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

#Preview {
    NavigationStack { ForgotPasswordView() }
}
