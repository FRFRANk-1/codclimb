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
        } catch let urlErr as URLError {
            self.error = "Network error \(urlErr.code.rawValue): \(urlErr.localizedDescription)"
            print("[CragDetailView] URLError \(urlErr.code.rawValue): \(urlErr)")
        } catch let decodeErr as DecodingError {
            self.error = "Parse error — \(decodeErr.localizedDescription)"
            print("[CragDetailView] DecodingError: \(decodeErr)")
        } catch {
            self.error = "Error: \(error.localizedDescription)"
            print("[CragDetailView] Unknown error: \(error)")
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
    @State private var shareImage: UIImage? = nil
    @State private var showingShareSheet = false
    @AppStorage("codclimb.useMetric") private var useMetric: Bool = false

    // Solar times recomputed whenever crag or date changes
    private var solar: SolarCalculator.SolarTimes {
        SolarCalculator.solarTimes(latitude: crag.latitude, longitude: crag.longitude)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metrics.sectionSpacing) {
                CragHeroPhotoView(crag: crag)
                if let error = viewModel.error {
                    Text(error)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Palette.nogo)
                }
                if let bundle = viewModel.bundle, let score = viewModel.score {
                    scoreCard(score: score, solar: solar)
                    // ── Rain forecast warning ──────────────────────────────
                    if let warning = bundle.rainWarning {
                        RainWarningBanner(warning: warning)
                    }
                    if !solar.isDaytime {
                        overnightCard(bundle: bundle)
                    }
                    statsGrid(snapshot: bundle.current)
                    if !solar.isDaytime, let nextWindow = viewModel.bestWindow {
                        tomorrowWindowCard(nextWindow, solar: solar)
                    } else if solar.isDaytime, let best = viewModel.bestWindow {
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
                HStack(spacing: 14) {
                    if let score = viewModel.score {
                        Button {
                            renderShareCard(score: score)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                    BookmarkButton(crag: crag)
                }
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
        .sheet(isPresented: $showingShareSheet) {
            if let img = shareImage {
                ShareActivitySheet(image: img, cragName: crag.name)
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

    private func scoreCard(score: ClimbScore, solar: SolarCalculator.SolarTimes) -> some View {
        HStack(spacing: 16) {
            // Badge dims after sunset
            ZStack(alignment: .topTrailing) {
                ScoreBadgeView(
                    score: score,
                    isLoading: false,
                    size: .large,
                    textColor: solar.isDaytime ? Theme.Palette.textPrimary : .white
                )
                .opacity(solar.isDaytime ? 1.0 : 0.9)
                if !solar.isDaytime {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Color(red: 0.25, green: 0.28, blue: 0.45)))
                        .offset(x: 4, y: -4)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                if solar.isDaytime {
                    Text(score.verdict.rawValue.uppercased())
                        .font(Theme.Typography.caption)
                        .foregroundStyle(score.verdict.color)
                        .tracking(1.0)
                    Text(score.summary)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Sunset context
                    Text("AFTER SUNSET")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Color(red: 0.55, green: 0.55, blue: 0.75))
                        .tracking(1.0)
                    let sunriseF = DateFormatter()
                    let _ = { sunriseF.dateFormat = "h:mm a" }()
                    Text("Sunrise at \(sunriseF.string(from: solar.sunrise)) — check tomorrow's window below")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(solar.isDaytime
                      ? Theme.Palette.surface
                      : Color(red: 0.13, green: 0.14, blue: 0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .stroke(solar.isDaytime
                        ? Theme.Palette.divider
                        : Color(red: 0.30, green: 0.32, blue: 0.52),
                        lineWidth: 1)
        )
    }

    private func overnightCard(bundle: WeatherBundle) -> some View {
        // Find tonight's min temperature from upcoming hourly
        let nightHours = bundle.hourly.filter { snap in
            let h = Calendar.current.component(.hour, from: snap.time)
            return h >= 20 || h < 6
        }
        let tonightTemp = nightHours.map(\.temperatureF).min() ?? bundle.current.temperatureF
        let msg = SolarCalculator.overnightMessage(tempF: tonightTemp)

        return HStack(spacing: 14) {
            Image(systemName: msg.icon)
                .font(.system(size: 24))
                .foregroundStyle(Color(red: 0.65, green: 0.68, blue: 0.90))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(msg.headline)
                    .font(Theme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: 0.88, green: 0.88, blue: 0.96))
                Text(msg.subtext)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Color(red: 0.60, green: 0.62, blue: 0.80))
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(Theme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(Color(red: 0.13, green: 0.14, blue: 0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .stroke(Color(red: 0.30, green: 0.32, blue: 0.52), lineWidth: 1)
        )
    }

    private func tomorrowWindowCard(_ snap: WeatherSnapshot, solar: SolarCalculator.SolarTimes) -> some View {
        let f = DateFormatter()
        f.dateFormat = "EEE h a"
        return HStack(spacing: 12) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(red: 0.95, green: 0.70, blue: 0.30))
            VStack(alignment: .leading, spacing: 3) {
                Text("TOMORROW'S BEST WINDOW")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .tracking(0.6)
                Text(f.string(from: snap.time))
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("\(UnitFormatter.tempShort(snap.temperatureF))\(UnitFormatter.tempSymbol) · \(UnitFormatter.windShort(snap.windMph)) \(UnitFormatter.windUnit) · \(Int(snap.humidityPct.rounded()))% humidity")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            let sunriseF = DateFormatter()
            let _ = { sunriseF.dateFormat = "h:mm a" }()
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "alarm")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Palette.textTertiary)
                Text(sunriseF.string(from: solar.sunrise))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                Text("sunrise")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(Theme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .stroke(Color(red: 0.95, green: 0.70, blue: 0.30).opacity(0.4), lineWidth: 1)
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
            // Section header
            HStack(spacing: 6) {
                Text("Score breakdown")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Palette.textPrimary)
                if !solar.isDaytime {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.65, green: 0.68, blue: 0.90))
                }
            }

            VStack(spacing: 0) {
                // Night context banner — full-width strip at the top of the card
                if !solar.isDaytime {
                    HStack(spacing: 10) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.65, green: 0.68, blue: 0.90))
                        Text("Scores reflect daytime conditions for tomorrow's planning — most climbers aren't out at night.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Color(red: 0.60, green: 0.62, blue: 0.80))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Theme.Metrics.cardPadding)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.13, green: 0.14, blue: 0.22))

                    Divider()
                        .overlay(Color(red: 0.30, green: 0.32, blue: 0.52))
                }

                // Factor rows
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
            }
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                    .stroke(
                        solar.isDaytime
                            ? Theme.Palette.divider
                            : Color(red: 0.30, green: 0.32, blue: 0.52),
                        lineWidth: 1
                    )
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
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Forecast")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
            ScoreSparklineView(days: days)
            DailyForecastView(days: days)
        }
    }

    // MARK: - Share card rendering

    @MainActor
    private func renderShareCard(score: ClimbScore) {
        guard let bundle = viewModel.bundle else { return }
        let card = ConditionsShareCard(
            crag: crag,
            score: score,
            snapshot: bundle.current
        )
        let renderer = ImageRenderer(content: card.frame(width: 375))
        renderer.scale = UIScreen.main.scale * 2
        shareImage = renderer.uiImage
        showingShareSheet = true
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

// MARK: - Rain Warning Banner

struct RainWarningBanner: View {
    let warning: WeatherBundle.RainWarning

    private var bannerColor: Color {
        switch warning.urgency {
        case .critical: return Color(red: 0.78, green: 0.20, blue: 0.18)
        case .high:     return Color(red: 0.85, green: 0.42, blue: 0.18)
        case .moderate: return Color(red: 0.85, green: 0.65, blue: 0.20)
        case .low:      return Color(red: 0.55, green: 0.60, blue: 0.72)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: warning.iconName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(bannerColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(warning.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(bannerColor)
                Text(warning.advice)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(bannerColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .stroke(bannerColor.opacity(0.30), lineWidth: 1)
        )
    }
}

// MARK: - Score Sparkline (7-day trend)

struct ScoreSparklineView: View {
    let days: [DailySummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Canvas sparkline
            Canvas { ctx, size in
                guard days.count >= 2 else { return }
                let W = size.width
                let H = size.height - 20  // leave room for day labels
                let scores = days.map { Double($0.score.value) }
                let minS: Double = 0
                let maxS: Double = 100
                let stepX = W / Double(days.count - 1)

                func pt(_ i: Int) -> CGPoint {
                    let x = Double(i) * stepX
                    let y = H - ((scores[i] - minS) / (maxS - minS)) * H
                    return CGPoint(x: x, y: y)
                }

                // Gradient fill under the line
                var fillPath = Path()
                fillPath.move(to: CGPoint(x: 0, y: H))
                for i in 0..<days.count { fillPath.addLine(to: pt(i)) }
                fillPath.addLine(to: CGPoint(x: W, y: H))
                fillPath.closeSubpath()
                ctx.fill(fillPath, with: .linearGradient(
                    Gradient(colors: [Theme.Palette.accent.opacity(0.25), Theme.Palette.accent.opacity(0.03)]),
                    startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: H)
                ))

                // Line
                var linePath = Path()
                linePath.move(to: pt(0))
                for i in 1..<days.count { linePath.addLine(to: pt(i)) }
                ctx.stroke(linePath, with: .color(Theme.Palette.accent.opacity(0.7)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Score dots
                for i in 0..<days.count {
                    let p = pt(i)
                    let color = days[i].score.verdict.color
                    let dotRect = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                    ctx.fill(Path(ellipseIn: dotRect), with: .color(color))
                    ctx.stroke(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.5))
                }

                // Highlight best day
                if let bestIdx = scores.indices.max(by: { scores[$0] < scores[$1] }) {
                    let p = pt(bestIdx)
                    let glowRect = CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)
                    ctx.fill(Path(ellipseIn: glowRect), with: .color(days[bestIdx].score.verdict.color.opacity(0.25)))
                }
            }
            .frame(height: 80)

            // Day labels
            HStack(spacing: 0) {
                ForEach(days) { day in
                    VStack(spacing: 2) {
                        Text(dayLabel(day.date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(day.isToday ? Theme.Palette.accent : Theme.Palette.textTertiary)
                        Text("\(day.score.value)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(day.score.verdict.color)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Theme.Metrics.cardPadding)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
            .stroke(Theme.Palette.divider, lineWidth: 1))
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Conditions Share Card (rendered to image)

struct ConditionsShareCard: View {
    let crag: Crag
    let score: ClimbScore
    let snapshot: WeatherSnapshot

    var body: some View {
        VStack(spacing: 0) {
            // Header strip
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(crag.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(crag.region.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(0.8)
                }
                Spacer()
                // Score circle
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 64, height: 64)
                    VStack(spacing: 1) {
                        Text("\(score.value)")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(score.verdict.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .tracking(0.5)
                    }
                }
            }
            .padding(20)
            .background(score.verdict.color.gradient)

            // Stats strip
            HStack(spacing: 0) {
                shareStatCell(icon: "thermometer.medium",
                              value: "\(Int(snapshot.temperatureF.rounded()))°F",
                              label: "Temp")
                Divider().frame(height: 36)
                shareStatCell(icon: "drop",
                              value: "\(Int(snapshot.humidityPct.rounded()))%",
                              label: "Humidity")
                Divider().frame(height: 36)
                shareStatCell(icon: "wind",
                              value: "\(Int(snapshot.windMph.rounded())) mph",
                              label: "Wind")
                Divider().frame(height: 36)
                shareStatCell(icon: "cloud",
                              value: "\(Int(snapshot.cloudCoverPct.rounded()))%",
                              label: "Clouds")
            }
            .background(Color(UIColor.systemBackground))

            // Footer
            HStack {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.accent)
                Text("CodClimb")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Palette.accent)
                Spacer()
                Text(Date(), style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func shareStatCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Palette.accent)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Share activity sheet wrapper

struct ShareActivitySheet: UIViewControllerRepresentable {
    let image: UIImage
    let cragName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let text = "Conditions at \(cragName) — via CodClimb 🧗"
        return UIActivityViewController(activityItems: [image, text], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
