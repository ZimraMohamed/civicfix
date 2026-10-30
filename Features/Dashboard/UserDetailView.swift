import SwiftUI


struct UserDetailView: View {
    let user: UserAccount
    @Bindable var vm: ManageUsersViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.fieldToField) {
                summary
                rolesSection
                accessSection
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 16)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("User")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Text(user.initials)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(user.disabled ? AppColors.placeholder : AppColors.primary))
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName.isEmpty ? "Unknown" : user.displayName)
                        .font(AppFonts.input)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(user.email)
                        .font(AppFonts.subtitle)
                        .foregroundStyle(AppColors.textSecondary)
                    if let created = user.createdAt {
                        Text("Joined \(created.formatted(date: .abbreviated, time: .omitted))")
                            .font(AppFonts.error)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
        }
    }

    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.labelToInput) {
            Text("Roles")
                .font(AppFonts.fieldLabel)
                .foregroundStyle(AppColors.textSecondary)

            roleRow(.public, "Public", "Default. Lets the user file reports.")
            roleRow(.officer, "Officer", "Triage and update report status.")
            roleRow(.admin, "Admin", "Full management access.")
        }
    }

    private func roleRow(_ role: UserRole, _ label: String, _ subtitle: String) -> some View {
        let isOn = user.effectiveRoles.contains(role)
        let locked = role == .public
        return Toggle(isOn: Binding(
            get: { isOn },
            set: { newValue in
                guard !locked else { return }
                Task { await vm.toggle(role: role, on: user) }
            }
        )) {
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

    private var accessSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.labelToInput) {
            Text("Access")
                .font(AppFonts.fieldLabel)
                .foregroundStyle(AppColors.textSecondary)

            Button {
                Task { await vm.toggleDisabled(on: user) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.disabled ? "Re-enable account" : "Disable account")
                            .font(AppFonts.input)
                            .foregroundStyle(user.disabled ? AppColors.success : AppColors.error)
                        Text(user.disabled
                             ? "The user can sign back in."
                             : "Stops the user from signing in. Their data is kept.")
                            .font(AppFonts.error)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: user.disabled ? "checkmark.circle.fill" : "nosign")
                        .foregroundStyle(user.disabled ? AppColors.success : AppColors.error)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
