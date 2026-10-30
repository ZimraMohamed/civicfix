import SwiftUI

/// Admin form to create a brand-new account. Lives in a sheet so the admin's
/// own session is never disturbed — creation happens on a secondary Firebase
/// app instance inside `FirebaseUserService.createUser`.
struct AddUserView: View {
    @State private var vm = AddUserViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = vm

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.fieldToField) {
                AuthHeader(
                    title: "Add new user",
                    subtitle: "Create an account on behalf of someone else. You’ll stay signed in as yourself."
                )

                AppTextField(label: "Full name", placeholder: "e.g. Nimal Perera",
                             text: $vm.name, errorMessage: vm.nameError)

                AppTextField(label: "Email", placeholder: "you@example.com",
                             text: $vm.email, type: .email, errorMessage: vm.emailError)

                AppTextField(label: "Password", placeholder: "Choose a password",
                             text: $vm.password, type: .password, errorMessage: vm.passwordError,
                             contentTypeOverride: .newPassword)

                AppTextField(label: "Confirm password", placeholder: "Re-enter the password",
                             text: $vm.confirmPassword, type: .password, errorMessage: vm.confirmError,
                             contentTypeOverride: .newPassword)

                rolesSection

                if let error = vm.formError {
                    Text(error).font(AppFonts.error).foregroundStyle(AppColors.error)
                }

                AppButton(title: "Create account", isLoading: vm.isLoading) {
                    Task {
                        if await vm.submit() { dismiss() }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Add user")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.labelToInput) {
            Text("Grant roles")
                .font(AppFonts.fieldLabel)
                .foregroundStyle(AppColors.textPrimary)
            VStack(spacing: 8) {
                roleToggle(.public, label: "Public", subtitle: "Everyone has this by default.", isOn: .constant(true))
                roleToggle(.officer, label: "Officer", subtitle: "Triage and update report status.",
                           isOn: Binding(get: { vm.grantOfficer },
                                         set: { vm.grantOfficer = $0 }))
                roleToggle(.admin, label: "Admin", subtitle: "Full management access.",
                           isOn: Binding(get: { vm.grantAdmin },
                                         set: { vm.grantAdmin = $0 }))
            }
        }
    }

    private func roleToggle(_ role: UserRole, label: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        let locked = role == .public
        return Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppFonts.input)
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(AppFonts.error)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .disabled(locked)
        .tint(AppColors.primary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

#Preview {
    NavigationStack { AddUserView() }
}
