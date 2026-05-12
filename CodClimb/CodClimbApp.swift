import SwiftUI

@main
struct CodClimbApp: App {
    @StateObject private var favorites      = FavoritesStore()
    @StateObject private var notifications  = NotificationService()
    @StateObject private var reportStore    = ConditionReportStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(favorites)
                .environmentObject(notifications)
                .environmentObject(reportStore)
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
        }
        .tint(Theme.Palette.accent)
    }
}
