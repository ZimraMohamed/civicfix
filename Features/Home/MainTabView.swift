import SwiftUI


struct MainTabView: View {
    enum Tab: Hashable { case home, report, map, reports, settings }

    @Environment(SessionStore.self) private var session
    @State private var selection: Tab = .home
    @State private var router = NotificationRouter.shared

    private var isAdmin: Bool { session.profile?.isAdmin ?? false }
    private var canReport: Bool { session.profile?.has(.public) ?? true }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
               
                DashboardView(onReportTapped: { selection = .report })
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(Tab.home)

            if canReport {
                NavigationStack { ReportView() }
                    .tabItem { Label("Report", systemImage: "camera.fill") }
                    .tag(Tab.report)
            }

            NavigationStack { ReportsMapView() }
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(Tab.map)

            if isAdmin {
                NavigationStack { AdminReportsView() }
                    .tabItem { Label("Reports", systemImage: "tray.full.fill") }
                    .tag(Tab.reports)
            }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(AppColors.primary)
        .overlay(alignment: .top) {
            if let banner = router.banner {
                InAppBanner(banner: banner) {
                    router.handle(type: banner.type)
                    router.banner = nil
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: banner.id) {
                    try? await Task.sleep(for: .seconds(4))
                    router.banner = nil
                }
            }
        }
        .animation(.spring(duration: 0.35), value: router.banner)
       
        .task(id: isAdmin) {
            NotificationService.shared.configure()
            if let uid = session.profile?.uid {
                ReportWatcher.shared.start(uid: uid, isAdmin: isAdmin)
            }
        }
        .task { openPendingDestination() }
        .onChange(of: router.destination) { _, _ in openPendingDestination() }
       
        .onChange(of: isAdmin) { _, _ in openPendingDestination() }
    }

    
    private func openPendingDestination() {
        guard let destination = router.destination else { return }
        switch destination {
        case .home:
            selection = .home
            router.destination = nil
        case .adminReports:
            guard isAdmin else { return }   
            selection = .reports
            router.destination = nil
        }
    }
}

private struct InAppBanner: View {
    let banner: NotificationRouter.Banner
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.fill")
                    .foregroundStyle(AppColors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(banner.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(banner.body)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.surface))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border, lineWidth: AppSpacing.borderWidth))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

#Preview { MainTabView().environment(SessionStore.preview()) }
