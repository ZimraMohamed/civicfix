import SwiftUI

/// The signed-in shell.
/// - iPhone (and iPad in compact multitasking widths): a bottom tab bar.
/// - iPad (regular width): a sidebar + detail layout (`NavigationSplitView`).
/// Each destination has its own navigation stack either way.
/// Home tab (role-aware dashboard): everyone. Report tab (camera + location + hashtags): `.public` users.
/// Reports tab (review list): `.admin` users.
struct MainTabView: View {
    enum Tab: Hashable {
        case home, report, map, reports, settings

        var title: String {
            switch self {
            case .home:     "Home"
            case .report:   "Report"
            case .map:      "Map"
            case .reports:  "Reports"
            case .settings: "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .home:     "house.fill"
            case .report:   "camera.fill"
            case .map:      "map.fill"
            case .reports:  "tray.full.fill"
            case .settings: "gearshape.fill"
            }
        }
    }

    @Environment(SessionStore.self) private var session
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: Tab = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var router = NotificationRouter.shared

    private var isAdmin: Bool { session.profile?.isAdmin ?? false }
    private var canReport: Bool { session.profile?.has(.public) ?? true }

    /// Tabs this user may see, in display order.
    private var visibleTabs: [Tab] {
        var tabs: [Tab] = [.home]
        if canReport { tabs.append(.report) }
        tabs.append(.map)
        if isAdmin { tabs.append(.reports) }
        tabs.append(.settings)
        return tabs
    }

    /// Sidebar layout only on iPad when there is room (not in a narrow Split View / Slide Over).
    private var usesSidebar: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    /// Falls back to Home if the selected tab is no longer allowed (e.g. a role change).
    private var currentSelection: Tab {
        visibleTabs.contains(selection) ? selection : .home
    }

    var body: some View {
        Group {
            if usesSidebar { sidebarLayout } else { tabLayout }
        }
        .tint(AppColors.primary)
        .overlay(alignment: .top) {
            if let banner = router.banner {
                InAppBanner(banner: banner) {
                    router.handle(type: banner.type)
                    router.banner = nil
                }
                .frame(maxWidth: 560)
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
        // Start listening for report changes as soon as we are signed in and know the role.
        .task(id: isAdmin) {
            NotificationService.shared.configure()
            if let uid = session.profile?.uid {
                ReportWatcher.shared.start(uid: uid, isAdmin: isAdmin)
            }
        }
        .task { openPendingDestination() }
        .onChange(of: router.destination) { _, _ in openPendingDestination() }
        // Roles load shortly after launch, so a tapped "new report" push may have to wait for them.
        .onChange(of: isAdmin) { _, _ in openPendingDestination() }
    }

    // MARK: - Compact: bottom tab bar (unchanged behaviour)

    private var tabLayout: some View {
        TabView(selection: $selection) {
            ForEach(visibleTabs, id: \.self) { tab in
                destination(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
    }

    // MARK: - Regular: sidebar + detail

    private var sidebarLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: Binding<Tab?>(
                get: { currentSelection },
                set: { if let tab = $0 { selection = tab } }
            )) {
                ForEach(visibleTabs, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .navigationTitle("CivicFix")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            destination(for: currentSelection)
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Screens

    @ViewBuilder
    private func destination(for tab: Tab) -> some View {
        switch tab {
        case .home:
            NavigationStack {
                // The Home tab is a role-aware dashboard (admin / officer / public).
                DashboardView(onReportTapped: { selection = .report })
                    .readableContentWidth()
            }
        case .report:
            NavigationStack { ReportView().readableContentWidth() }
        case .map:
            // The map uses the full width.
            NavigationStack { ReportsMapView() }
        case .reports:
            NavigationStack { AdminReportsView().readableContentWidth() }
        case .settings:
            NavigationStack { SettingsView().readableContentWidth() }
        }
    }

    /// Jumps to the tab a tapped notification points at.
    private func openPendingDestination() {
        guard let destination = router.destination else { return }
        switch destination {
        case .home:
            selection = .home
            router.destination = nil
        case .adminReports:
            guard isAdmin else { return }   // keep it pending until roles are known
            selection = .reports
            router.destination = nil
        }
    }
}

// MARK: - Responsive width helper

/// Keeps content at a comfortable reading width on wide screens (iPad) and centers it.
/// On iPhone / compact widths it does nothing. Apply it to the root view of a screen,
/// inside its `NavigationStack`, so the navigation bar still spans the full width.
private struct ReadableContentWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity)
            .background(AppColors.background.ignoresSafeArea())
    }
}

extension View {
    func readableContentWidth(_ maxWidth: CGFloat = 760) -> some View {
        modifier(ReadableContentWidth(maxWidth: maxWidth))
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
