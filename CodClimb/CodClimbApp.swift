import SwiftUI
import Firebase

@main
struct CodClimbApp: App {
    @StateObject private var favorites      = FavoritesStore()
    @StateObject private var notifications  = NotificationService()
    @StateObject private var reportStore    = ConditionReportStore()

    @State private var showSplash = true

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                    .environmentObject(favorites)
                    .environmentObject(notifications)
                    .environmentObject(reportStore)

                if showSplash {
                    SplashView(isShowing: $showSplash)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            CragListView()
                .tabItem {
                    Label("Explore", systemImage: "map")
                }

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "bookmark.fill")
                }

            CommunityFeedView()
                .tabItem {
                    Label("Community", systemImage: "person.2.wave.2")
                }

            NotificationsListView()
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(Theme.Palette.accent)
    }
}
