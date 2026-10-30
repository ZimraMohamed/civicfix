import SwiftUI

/// Placeholder for the "Role permissions" screen.
///
/// The admin dashboard links here now so navigation is wired up end-to-end.
/// The real logic (pick a user, toggle officer/admin roles via
/// `AuthServicing.setRoles(for:to:)`) lands in the next pass.
struct RolePermissionsView: View {
    var body: some View {
        ContentUnavailableView(
            "Coming soon",
            systemImage: "shield.lefthalf.filled.badge.checkmark",
            description: Text("You'll be able to grant or revoke officer and admin roles here.")
        )
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Role permissions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { RolePermissionsView() }
}
