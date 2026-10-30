import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct CivicFixApp: App {
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue
    @State private var session: SessionStore

    init() {
        // Must run before anything touches Auth.auth().
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        _session = State(initialValue: SessionStore())
    }

    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .splash:    SplashView()
                case .loggedOut: NavigationStack { LoginView() }
                case .loggedIn:  MainTabView()
                }
            }
            .animation(.easeInOut, value: session.state)
            .environment(session)
            .preferredColorScheme(appearance.colorScheme)
            .task { await session.bootstrap() }
        }
    }
}
