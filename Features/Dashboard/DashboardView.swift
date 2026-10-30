import SwiftUI

/// Role-aware landing screen shown in the Home tab.
///
/// Picks the right dashboard for the signed-in user's highest role:
/// `admin` > `officer` > `public`. A user holding several roles sees the most
/// powerful one they have. `onReportTapped` lets the public dashboard's
/// "New report" button jump to the Report tab.
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
