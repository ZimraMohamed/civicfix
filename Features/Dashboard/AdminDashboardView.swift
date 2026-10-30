import SwiftUI


struct AdminDashboardView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.fieldToField) {
                header
                managementSection
                accountCard
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, 16)
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Admin")
                .font(AppFonts.screenTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text("Manage users, roles, and reports.")
                .font(AppFonts.subtitle)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var managementSection: some View {
        VStack(spacing: 12) {
            NavigationLink {
                ManageUsersView()
            } label: {
                DashboardTile(
                    title: "Manage users",
                    subtitle: "Add, view, and remove accounts",
                    systemImage: "person.2.fill",
                    tint: AppColors.primary
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                RolePermissionsView()
            } label: {
                DashboardTile(
                    title: "Role permissions",
                    subtitle: "Assign officer or admin roles",
                    systemImage: "shield.lefthalf.filled",
                    tint: AppColors.success
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AdminReportsView()
            } label: {
                DashboardTile(
                    title: "All reports",
                    subtitle: "Review and update every submitted report",
                    systemImage: "tray.full.fill",
                    tint: .orange
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.labelToInput) {
            Text("Signed in as")
                .font(AppFonts.fieldLabel)
                .foregroundStyle(AppColors.textSecondary)
            HStack(spacing: 12) {
                Avatar(initials: session.profile?.initials ?? "?")
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.profile?.displayName.isEmpty == false
                         ? session.profile!.displayName : "Unknown")
                        .font(AppFonts.input)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(session.profile?.email ?? "")
                        .font(AppFonts.error)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .appCard()
        }
    }
}



private struct DashboardTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(tint))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFonts.input)
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(AppFonts.error)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.placeholder)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .contentShape(Rectangle())
    }
}

private struct Avatar: View {
    let initials: String
    var body: some View {
        Text(initials)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Circle().fill(AppColors.primary))
    }
}

#Preview {
    NavigationStack { AdminDashboardView() }
        .environment(SessionStore.preview())
}
