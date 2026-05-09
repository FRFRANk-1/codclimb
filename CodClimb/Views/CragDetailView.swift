import SwiftUI

@MainActor
final class CragDetailViewModel: ObservableObject {
    @Published private(set) var bundle: WeatherBundle?
    @Published private(set) var score: ClimbScore?
    @Published private(set) var bestWindow: WeatherSnapshot?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?

    private let client = OpenMeteoClient()
    private let scorer = ScoringService()

    func seed(_ snap: CragListViewModel.CragSnapshot?) {
        guard let snap else { return }
        self.bundle = snap.bundle
        self.score = snap.score
        self.bestWindow = scorer.bestUpcomingWindow(in: snap.bundle)
    }

    func refresh(for crag: Crag) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let bundle = try await client.fetch(latitude: crag.latitude, longitude: crag.longitude)
            self.bundle = bundle
            self.score = scorer.score(for: bundle)
            self.bestWindow = scorer.bestUpcomingWindow(in: bundle)
            self.error = nil
        } catch {
            self.error = "Couldn't reach Open-Meteo. Pull to retry."
        }
    }
}

struct CragDetailView: View {
    let crag: Crag
    let preloaded: CragListViewModel.CragSnapshot?

    @StateObject private var viewModel = CragDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metrics.sectionSpacing) {
                header
                if let error = viewModel.error {
                    Text(error)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Palette.nogo)
                }
                if let bundle = viewModel.bundle, let score = viewModel.score {
                    scoreCard(score: score)
                    statsGrid(snapshot: bundle.current)
                    if let best = viewModel.bestWindow {
                        bestWindowCard(best)
                    }
                    factorsSection(score: score)
                    forecastSection(bundle: bundle)
                } else {
                    ProgressView().padding(.top, 40)
                        .frame(maxWidth: .infinity)
                }
                cragInfoCard
            }
            .padding(.horizontal, Theme.Metrics.cardPadding)
            .padding(.bottom, 32)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle(crag.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.refresh(for: crag) }
        .task {
            viewModel.seed(preloaded)
            if viewModel.bundle == nil {
                await viewModel.refresh(for: crag)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(crag.name)
                .font(Theme.Typography.largeTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(crag.region)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.top, 8)
    }

    private func scoreCard(score: ClimbScore) -> some View {
        HStack(spacing: 16) {
            ScoreBadgeView(score: score, isLoading: false, size: .large)
            VStack(alignment: .leading, spacing: 6) {
                Text(score.verdict.rawValue.uppercased())
                    .font(Theme.Typography.caption)
                    .foregroundStyle(score.verdict.color)
                    .tracking(1.0)
                Text(score.summary)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .stroke(Theme.Palette.divider, lineWidth: 1)
        )
    }

    private func statsGrid(snapshot: WeatherSnapshot) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            StatTile(icon: "thermometer.medium", label: "Temperature",
                     value: "\(Int(snapshot.temperatureF.rounded()))°", trailing: "F")
            StatTile(icon: "humidity.fill", label: "Humidity",
                     value: "\(Int(snapshot.humidityPct.rounded()))", trailing: "%")
            StatTile(icon: "wind", label: "Wind",
                     value: "\(Int(snapshot.windMph.rounded()))", trailing: "mph")
            StatTile(icon: "cloud.fill", label: "Cloud cover",
                     value: "\(Int(snapshot.cloudCoverPct.rounded()))", trailing: "%")
        }
    }

    private func bestWindowCard(_ snap: WeatherSnapshot) -> some View {
        let f = DateFormatter()
        f.dateFormat = "EEE h a"
        return HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("BEST WINDOW NEXT 48H")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .tracking(0.5)
                Text(f.string(from: snap.time))
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("\(Int(snap.temperatureF.rounded()))°F · \(snap.conditionLabel) · \(Int(snap.windMph.rounded())) mph wind")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
        }
        .padding(Theme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(Theme.Palette.accentMuted)
        )
    }

    private func factorsSection(score: ClimbScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Score breakdown")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
            VStack(spacing: 0) {
                ForEach(score.factors) { factor in
                    FactorRow(factor: factor)
                    if factor.id != score.factors.last?.id {
                        Divider().background(Theme.Palette.divider)
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.cardPadding)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                    .stroke(Theme.Palette.divider, lineWidth: 1)
            )
        }
    }

    private func forecastSection(bundle: WeatherBundle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next 24 hours")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, 0)
            HourlyForecastView(hours: bundle.hourly)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                        .fill(Theme.Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                        .stroke(Theme.Palette.divider, lineWidth: 1)
                )
        }
    }

    private var cragInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About this crag")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Rock", value: crag.rockType)
                infoRow(label: "Aspect", value: crag.aspect)
                infoRow(label: "Elevation", value: "\(crag.elevationFt) ft")
                infoRow(label: "Sub-areas", value: crag.subAreas.joined(separator: " · "))
                Text(crag.notes)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                    .stroke(Theme.Palette.divider, lineWidth: 1)
            )
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .tracking(0.5)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
        }
    }
}
