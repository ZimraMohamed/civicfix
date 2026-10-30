import SwiftUI

struct ChangePasswordView: View {
    @State private var vm = ChangePasswordViewModel()

    var body: some View {
        @Bindable var vm = vm

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.fieldToField) {
                AuthHeader(title: "Change Password",
                           subtitle: "Enter your current password, then choose a new one.")

                AppTextField(label: "Current password", placeholder: "Enter your password",
                             text: $vm.currentPassword, type: .password, errorMessage: vm.currentError)

                AppTextField(label: "New password", placeholder: "At least 8 characters",
                             text: $vm.newPassword, type: .password, errorMessage: vm.newError,
                             contentTypeOverride: .newPassword)

                AppTextField(label: "Confirm new password", placeholder: "Re-enter new password",
                             text: $vm.confirmPassword, type: .password, errorMessage: vm.confirmError,
                             contentTypeOverride: .newPassword)

                if let error = vm.formError {
                    Text(error).font(AppFonts.error).foregroundStyle(AppColors.error)
                }

                if vm.didChange {
                    Label("Password updated.", systemImage: "checkmark.circle.fill")
                        .font(AppFonts.footer)
                        .foregroundStyle(AppColors.success)
                }

                AppButton(title: "Update Password", isLoading: vm.isLoading) {
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
    NavigationStack { ChangePasswordView() }
}
