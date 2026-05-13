import SwiftUI

// MARK: - CragDetailView

@MainActor
final class CragDetailViewModel: ObservableObject {
    @Published private(set) var bundle: WeatherBundle?
    @Published private(set) var score: ClimbScore?
    @Published private(set) var bestWindow: WeatherSnapshot?
    @Published private(set) var dailySummaries: [DailySummary] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?

    private let client = OpenMeteoClient()
    private let scorer = ScoringService()

    func seed(_ snap: CragListViewModel.CragSnapshot?) {
        guard let snap else { return }
        self.bundle = snap.bundle
        self.score = snap.score
        self.bestWindow = scorer.bestUpcomingWindow(in: snap.bundle)
        self.dailySummaries = snap.bundle.dailySummaries(scorer: scorer)
    }

    func refresh(for crag: Crag) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let bundle = try await client.fetch(latitude: crag.latitude, longitude: crag.longitude)
            self.bundle = bundle
            self.score = scorer.score(for: bundle)
            self.bestWindow = scorer.bestUpcomingWindow(in: bundle)
            self.dailySummaries = bundle.dailySummaries(scorer: scorer)
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
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var reportStore: ConditionReportStore
    @State private var showingAlertSheet = false
    @AppStorage("codclimb.useMetric") private var useMetric: Bool = false

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
                    if !viewModel.dailySummaries.isEmpty {
                        sevenDaySection(days: viewModel.dailySummaries)
                    }
                } else {
                    ProgressView().padding(.top, 40)
                        .frame(maxWidth: .infinity)
                }
                CragConditionFeedView(crag: crag)
                    .environmentObject(reportStore)
                alertRow
                cragInfoCard
            }
            .padding(.horizontal, Theme.Metrics.cardPadding)
            .padding(.bottom, 32)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle(crag.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                BookmarkButton(crag: crag)
            }
        }
        .refreshable { await viewModel.refresh(for: crag) }
        .task {
            viewModel.seed(preloaded)
            if viewModel.bundle == nil {
                await viewModel.refresh(for: crag)
            }
        }
        .sheet(isPresented: $showingAlertSheet) {
            CragAlertSheet(crag: crag)
                .environmentObject(notifications)
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
                     value: UnitFormatter.tempShort(snapshot.temperatureF),
                     trailing: UnitFormatter.tempUnit)
            StatTile(icon: "humidity.fill", label: "Humidity",
                     value: "\(Int(snapshot.humidityPct.rounded()))", trailing: "%")
            StatTile(icon: "wind", label: "Wind",
                     value: UnitFormatter.windShort(snapshot.windMph),
                     trailing: UnitFormatter.windUnit)
            StatTile(icon: "cloud.fill", label: "Cloud cover",
                     value: "\(Int(snapshot.cloudCoverPct.rounded()))", trailing: "%")
        }
        .id(useMetric) // force redraw when units toggle
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
                Text("\(UnitFormatter.temperature(snap.temperatureF)) · \(snap.conditionLabel) · \(UnitFormatter.wind(snap.windMph))")
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

    private func sevenDaySection(days: [DailySummary]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7-Day Forecast")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
            DailyForecastView(days: days)
        }
    }

    private var alertRow: some View {
        let existing = notifications.preference(for: crag)
        return Button {
            showingAlertSheet = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(existing != nil ? Theme.Palette.accentMuted : Theme.Palette.surfaceElevated)
                        .frame(width: 40, height: 40)
                    Image(systemName: existing != nil ? "bell.badge.fill" : "bell")
                        .font(.system(size: 17))
                        .foregroundStyle(existing != nil ? Theme.Palette.accent : Theme.Palette.textTertiary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing != nil ? "Edit Alert" : "Set Alert")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if let existing {
                        Text("Score ≥ \(existing.threshold) · \(existing.isEnabled ? "On" : "Off")")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    } else {
                        Text("Notify me when conditions are right")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .padding(Theme.Metrics.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                    .stroke(existing != nil ? Theme.Palette.accent.opacity(0.3) : Theme.Palette.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
