import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @StateObject private var viewModel = CragListViewModel()

    /// Only the crags the user has saved
    private var favoriteCrags: [Crag] {
        viewModel.sortedCrags.filter { favorites.isFavorite($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if favorites.ids.isEmpty {
                    EmptyFavoritesView()
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Metrics.sectionSpacing) {
                            // Best-conditions banner
                            if let best = favoriteCrags.first,
                               let snap = viewModel.snapshots[best.id] {
                                BestFavoriteCard(crag: best, snapshot: snap)
                            }

                            // Saved crags list
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Saved Crags")
                                        .font(Theme.Typography.title)
                                        .foregroundStyle(Theme.Palette.textPrimary)
                                    Spacer()
                                    if viewModel.isLoading {
                                        ProgressView().controlSize(.small)
                                    }
                                }
                                ForEach(favoriteCrags) { crag in
                                    NavigationLink {
                                        CragDetailView(crag: crag, preloaded: viewModel.snapshots[crag.id])
                                    } label: {
                                        CragCard(
                                            crag: crag,
                                            snapshot: viewModel.snapshots[crag.id],
                                            isLoading: viewModel.isLoading && viewModel.snapshots[crag.id] == nil
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Metrics.cardPadding)
                        .padding(.bottom, 32)
                    }
                    .refreshable { await viewModel.refreshAll() }
                }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await viewModel.load() }
    }
}

// MARK: - Best Favorite Banner

private struct BestFavoriteCard: View {
    let crag: Crag
    let snapshot: CragListViewModel.CragSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BEST CONDITIONS NOW")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .tracking(0.8)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(crag.name)
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(crag.region)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Palette.textSecondary)
                    Text(snapshot.score.summary)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .padding(.top, 2)
                }
                Spacer()
                ScoreBadgeView(score: snapshot.score, isLoading: false, size: .large)
            }
        }
        .padding(Theme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(Theme.Palette.accentMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .stroke(Theme.Palette.accent.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Empty state

private struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bookmark")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text("No saved crags yet")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Tap the bookmark icon on any crag\nto save it here for quick access.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
