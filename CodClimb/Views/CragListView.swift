import SwiftUI

@MainActor
final class CragListViewModel: ObservableObject {
    @Published private(set) var crags: [Crag] = []
    @Published private(set) var snapshots: [String: CragSnapshot] = [:]
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadError: String?

    private let client = OpenMeteoClient()
    private let scorer = ScoringService()

    struct CragSnapshot {
        let bundle: WeatherBundle
        let score: ClimbScore
    }

    func load() async {
        do {
            crags = try CragRepository.loadAll()
        } catch {
            loadError = "Couldn't load crag list."
            return
        }
        await refreshAll()
    }

    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: (String, CragSnapshot?).self) { group in
            for crag in crags {
                group.addTask { [client, scorer] in
                    do {
                        let bundle = try await client.fetch(latitude: crag.latitude, longitude: crag.longitude)
                        let score = scorer.score(for: bundle)
                        return (crag.id, CragSnapshot(bundle: bundle, score: score))
                    } catch {
                        return (crag.id, nil)
                    }
                }
            }
            for await (id, snap) in group {
                if let snap {
                    snapshots[id] = snap
                }
            }
        }
    }
}

struct CragListView: View {
    @StateObject private var viewModel = CragListViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metrics.sectionSpacing) {
                    HeroHeader()
                    FeaturesRow()
                    AreasSection(viewModel: viewModel)
                }
                .padding(.horizontal, Theme.Metrics.cardPadding)
                .padding(.bottom, 32)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("CodClimb")
            .navigationBarTitleDisplayMode(.inline)
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
            FeatureChip(icon: "checkmark.seal.fill", title: "Score", subtitle: "Go / no-go")
        }
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
    @ObservedObject var viewModel: CragListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Areas")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            if let error = viewModel.loadError {
                Text(error)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.nogo)
            }
            ForEach(viewModel.crags) { crag in
                NavigationLink {
                    CragDetailView(crag: crag, preloaded: viewModel.snapshots[crag.id])
                } label: {
                    CragCard(crag: crag, snapshot: viewModel.snapshots[crag.id], isLoading: viewModel.isLoading && viewModel.snapshots[crag.id] == nil)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CragCard: View {
    let crag: Crag
    let snapshot: CragListViewModel.CragSnapshot?
    let isLoading: Bool

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
            ScoreBadgeView(score: snapshot?.score, isLoading: isLoading, size: .medium)
        }
        .padding(Theme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(Theme.Palette.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .stroke(Theme.Palette.divider, lineWidth: 1)
        )
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
