import SwiftUI


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
