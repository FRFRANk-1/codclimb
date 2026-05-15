import SwiftUI

@MainActor
final class CragListViewModel: ObservableObject {
    @Published private(set) var crags: [Crag] = []
    @Published private(set) var snapshots: [String: CragSnapshot] = [:]
    @Published private(set) var isLoading: Bool = false   // true only during pull-to-refresh
    @Published private(set) var loadError: String?

    private let client = OpenMeteoClient()
    private let scorer = ScoringService(weights: .current)

    /// Crag IDs whose fetch is currently in-flight (prevents duplicate concurrent requests).
    private var inFlight: Set<String> = []

    struct CragSnapshot {
        let bundle: WeatherBundle
        let score: ClimbScore
    }

    /// Crags sorted by score descending (unscored crags go to the end).
    var sortedCrags: [Crag] {
        crags.sorted { a, b in
            let sa = snapshots[a.id]?.score.value ?? -1
            let sb = snapshots[b.id]?.score.value ?? -1
            return sa > sb
        }
    }

    /// True while this crag's weather request is in-flight.
    func isLoadingCrag(_ id: String) -> Bool {
        inFlight.contains(id)
    }

    /// All unique state/region tokens derived from crag regions.
    var regions: [String] {
        let states = crags.compactMap { $0.stateAbbreviation }
        return Array(Set(states)).sorted()
    }

    // MARK: - Loading

    /// Initial load: reads the JSON crag list only. Weather is fetched lazily per-card.
    func load() async {
        guard crags.isEmpty else { return }
        do {
            crags = try CragRepository.loadAll()
        } catch {
            loadError = "Couldn't load crag list."
        }
    }

    /// On-demand fetch for a single crag — called when its card scrolls into view.
    /// Skips if already loaded or in-flight. Retries automatically on next appear if it failed.
    func fetchIfNeeded(for crag: Crag) async {
        guard snapshots[crag.id] == nil,
              !inFlight.contains(crag.id) else { return }

        inFlight.insert(crag.id)
        defer { inFlight.remove(crag.id) }

        do {
            let bundle = try await client.fetch(latitude: crag.latitude, longitude: crag.longitude)
            snapshots[crag.id] = CragSnapshot(bundle: bundle, score: scorer.score(for: bundle))
        } catch {
            // Don't mark as permanently failed — next time the card appears it will retry
            print("[CragListViewModel] \(crag.name): \(error.localizedDescription)")
        }
    }

    /// Pull-to-refresh: clears cache and re-fetches all crags with a concurrency cap.
    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }

        let maxConcurrent = 8
        var iterator = crags.makeIterator()

        await withTaskGroup(of: (String, CragSnapshot?).self) { group in
            var active = 0
            while active < maxConcurrent, let crag = iterator.next() {
                let c = crag
                group.addTask { [client, scorer] in
                    guard let bundle = try? await client.fetch(latitude: c.latitude, longitude: c.longitude)
                    else { return (c.id, nil) }
                    return (c.id, CragSnapshot(bundle: bundle, score: scorer.score(for: bundle)))
                }
                active += 1
            }
            for await (id, snap) in group {
                if let snap { snapshots[id] = snap }
                if let crag = iterator.next() {
                    let c = crag
                    group.addTask { [client, scorer] in
                        guard let bundle = try? await client.fetch(latitude: c.latitude, longitude: c.longitude)
                        else { return (c.id, nil) }
                        return (c.id, CragSnapshot(bundle: bundle, score: scorer.score(for: bundle)))
                    }
                }
            }
        }
    }
}

// MARK: - State abbreviation helper

private extension Crag {
    /// Extracts the 2-letter state abbreviation from the region string, e.g. "Rumney, NH" → "NH"
    var stateAbbreviation: String? {
        let parts = region.components(separatedBy: ", ")
        if let last = parts.last, last.count == 2 {
            return last.uppercased()
        }
        // Fallback: look for a known state suffix after the last comma
        let lower = region.lowercased()
        let stateMap: [String: String] = [
            "nh": "NH", "ny": "NY", "wv": "WV", "ky": "KY", "wi": "WI",
            "ar": "AR", "tn": "TN", "nc": "NC", "al": "AL", "md": "MD",
            "ca": "CA", "or": "OR", "wa": "WA", "id": "ID", "co": "CO",
            "wy": "WY", "ut": "UT", "nv": "NV", "tx": "TX", "az": "AZ",
            "ga": "GA", "mo": "MO"
        ]
        for (key, value) in stateMap {
            if lower.hasSuffix(", \(key)") || lower.contains(" \(key)") { return value }
        }
        return nil
    }
}

// MARK: - CragListView

struct CragListView: View {
    @StateObject private var viewModel = CragListViewModel()
    @State private var searchText = ""
    @State private var selectedRegion: String? = nil

    private var filteredCrags: [Crag] {
        viewModel.sortedCrags.filter { crag in
            let matchesSearch = searchText.isEmpty
                || crag.name.localizedCaseInsensitiveContains(searchText)
                || crag.region.localizedCaseInsensitiveContains(searchText)
                || crag.rockType.localizedCaseInsensitiveContains(searchText)
            let matchesRegion = selectedRegion == nil
                || crag.stateAbbreviation == selectedRegion
            return matchesSearch && matchesRegion
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metrics.sectionSpacing) {
                    HeroHeader()
                    FeaturesRow()

                    // Region filter chips
                    if !viewModel.regions.isEmpty {
                        RegionFilterRow(
                            regions: viewModel.regions,
                            selected: $selectedRegion
                        )
                    }

                    AreasSection(
                        crags: filteredCrags,
                        viewModel: viewModel
                    )
                }
                .padding(.horizontal, Theme.Metrics.cardPadding)
                .padding(.bottom, 32)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("CodClimb")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search crags, states, rock type…")
            .refreshable { await viewModel.refreshAll() }
        }
        .task { await viewModel.load() }
        .tint(Theme.Palette.accent)
    }
}

private struct HeroHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Know Before You Go")
                .font(Theme.Typography.largeTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Real-time conditions, weather forecasts, and a climbability score for the crags you actually climb.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }
}

private struct FeaturesRow: View {
    var body: some View {
        HStack(spacing: 10) {
            FeatureChip(icon: "cloud.sun.fill", title: "Weather", subtitle: "Live + forecast")
            FeatureChip(icon: "drop.fill", title: "Dryness", subtitle: "Hours since rain")
            FeatureChip(icon: "checkmark.seal.fill", title: "Score", subtitle: "Best first")
        }
    }
}

// MARK: - Region filter chips

private struct RegionFilterRow: View {
    let regions: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: selected == nil) {
                    selected = nil
                }
                ForEach(regions, id: \.self) { region in
                    FilterChip(label: region, isSelected: selected == region) {
                        selected = selected == region ? nil : region
                    }
                }
            }
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Typography.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.Palette.accent : Theme.Palette.surface)
                )
                .foregroundStyle(isSelected ? .white : Theme.Palette.textSecondary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Theme.Palette.accent : Theme.Palette.divider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FeatureChip: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Palette.accent)
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Palette.accentMuted)
        )
    }
}

private struct AreasSection: View {
    let crags: [Crag]
    @ObservedObject var viewModel: CragListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(crags.isEmpty ? "No results" : "Areas")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text("\(crags.count)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            if let error = viewModel.loadError {
                Text(error)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.nogo)
            }
            if crags.isEmpty && !viewModel.isLoading {
                Text("Try a different search or filter.")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            }
            LazyVStack(spacing: 12) {
                ForEach(crags) { crag in
                    CragCardRow(crag: crag, viewModel: viewModel)
                }
            }
        }
    }
}

/// Wraps a CragCard and triggers its weather fetch the moment it scrolls into view.
private struct CragCardRow: View {
    let crag: Crag
    @ObservedObject var viewModel: CragListViewModel

    var body: some View {
        NavigationLink {
            CragDetailView(crag: crag, preloaded: viewModel.snapshots[crag.id])
        } label: {
            CragCard(
                crag: crag,
                snapshot: viewModel.snapshots[crag.id],
                isLoading: viewModel.isLoadingCrag(crag.id)
            )
        }
        .buttonStyle(.plain)
        .task(id: crag.id) {
            await viewModel.fetchIfNeeded(for: crag)
        }
    }
}

struct CragCard: View {
    let crag: Crag
    let snapshot: CragListViewModel.CragSnapshot?
    let isLoading: Bool
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(crag.name)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(crag.region)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                HStack(spacing: 14) {
                    InlineStat(icon: "thermometer.medium",
                               value: snapshot.map { "\(Int($0.bundle.current.temperatureF.rounded()))°F" } ?? "—")
                    InlineStat(icon: "humidity.fill",
                               value: snapshot.map { "\(Int($0.bundle.current.humidityPct.rounded()))%" } ?? "—")
                    InlineStat(icon: "wind",
                               value: snapshot.map { "\(Int($0.bundle.current.windMph.rounded())) mph" } ?? "—")
                }
                .padding(.top, 4)
            }
            Spacer()
            VStack(spacing: 10) {
                ScoreBadgeView(score: snapshot?.score, isLoading: isLoading, size: .medium)
                BookmarkButton(crag: crag)
            }
        }
        .padding(Theme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(Theme.Palette.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .stroke(favorites.isFavorite(crag) ? Theme.Palette.accent.opacity(0.4) : Theme.Palette.divider,
                        lineWidth: 1)
        )
    }
}

/// Reusable bookmark toggle button — used in CragCard and CragDetailView.
struct BookmarkButton: View {
    let crag: Crag
    @EnvironmentObject private var favorites: FavoritesStore

    var isFav: Bool { favorites.isFavorite(crag) }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                favorites.toggle(crag)
            }
        } label: {
            Image(systemName: isFav ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isFav ? Theme.Palette.accent : Theme.Palette.textTertiary)
                .scaleEffect(isFav ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFav)
        }
        .buttonStyle(.plain)
    }
}

private struct InlineStat: View {
    let icon: String
    let value: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text(value)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }
}

#Preview {
    CragListView()
}
