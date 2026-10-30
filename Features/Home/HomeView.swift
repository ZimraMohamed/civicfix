import SwiftUI

/// Landing tab after sign-in. Settings now lives in its own tab (see MainTabView).
struct HomeView: View {
    @Environment(SessionStore.self) private var session

    private var firstName: String {
        session.profile?.displayName.split(separator: " ").first.map(String.init) ?? ""
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(firstName.isEmpty ? "Welcome to CivicFix" : "Welcome, \(firstName)")
                .font(AppFonts.screenTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text("Report. Track. Improve.")
                .font(AppFonts.subtitle)
                .foregroundStyle(AppColors.textSecondary)
            if let roles = session.profile?.roles {
                Text(UserRole.allCases.filter(roles.contains).map(\.title).joined(separator: " · "))
                    .font(AppFonts.subtitle)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.screenHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { NavigationStack { HomeView() }.environment(SessionStore.preview()) }
