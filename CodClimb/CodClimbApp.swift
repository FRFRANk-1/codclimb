import SwiftUI
import Firebase

@main
struct CodClimbApp: App {
    @StateObject private var favorites      = FavoritesStore()
    @StateObject private var notifications  = NotificationService()
    @StateObject private var reportStore    = ConditionReportStore()
    @StateObject private var profileStore   = UserProfileStore()

    @State private var showSplash = true
    @AppStorage("codclimb.hasSeenOnboarding") private var hasSeenOnboarding = false

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
                    .environmentObject(profileStore)
                    .task { await WeatherCacheClient.shared.prefetch() }

                if showSplash {
                    SplashView(isShowing: $showSplash)
                        .transition(.opacity)
                        .zIndex(2)
                }

                if !hasSeenOnboarding && !showSplash {
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: showSplash)
            .animation(.easeInOut(duration: 0.4), value: hasSeenOnboarding)
        }
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            CragListView()
                .tabItem {
                    Label("Explore", systemImage: "list.bullet")
                }

            CragMapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "bookmark.fill")
                }

            CommunityFeedView()
                .tabItem {
                    Label("Community", systemImage: "person.2.wave.2")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .tint(Theme.Palette.accent)
    }
}
