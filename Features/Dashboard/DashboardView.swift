import SwiftUI


struct DashboardView: View {
    var onReportTapped: () -> Void = {}

    @Environment(SessionStore.self) private var session

    var body: some View {
        content
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var content: some View {
        if let profile = session.profile {
            if profile.isAdmin {
                AdminDashboardView()
            } else if profile.isOfficer {
                OfficerDashboardView()
            } else {
                PublicDashboardView(onReportTapped: onReportTapped)
            }
        } else {
            ContentUnavailableView(
                "Welcome to CivicFix",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("Sign in to see your dashboard.")
            )
        }
    }
}

#Preview {
    NavigationStack { DashboardView() }
        .environment(SessionStore.preview())
}
