import SwiftUI

struct ChangeEmailView: View {
    @State private var vm: ChangeEmailViewModel

    init(currentEmail: String) {
        _vm = State(initialValue: ChangeEmailViewModel(currentEmail: currentEmail))
    }

    var body: some View {
        @Bindable var vm = vm

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.fieldToField) {
                AuthHeader(title: "Change Email",
                           subtitle: "We’ll send a verification link to your new address. Your email updates once you tap it.")

                AppTextField(label: "New email", placeholder: "you@example.com",
                             text: $vm.newEmail, type: .email, errorMessage: vm.emailError)

                AppTextField(label: "Current password", placeholder: "Enter your password",
                             text: $vm.password, type: .password, errorMessage: vm.passwordError)

                if let error = vm.formError {
                    Text(error).font(AppFonts.error).foregroundStyle(AppColors.error)
                }

                if let sentTo = vm.sentTo {
                    Label("Verification link sent to \(sentTo). Check your inbox, then come back here.",
                          systemImage: "checkmark.circle.fill")
                        .font(AppFonts.footer)
                        .foregroundStyle(AppColors.success)
                }

                AppButton(title: "Send Verification Link", isLoading: vm.isLoading) {
                    Task { await vm.submit() }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ChangeEmailView(currentEmail: "ahsan@example.com") }
}
