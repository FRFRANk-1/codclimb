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
                            // Best Day This Week planner
                            BestDayPlannerCard(crags: favoriteCrags, snapshots: viewModel.snapshots)

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
                                            isLoading: viewModel.isLoadingCrag(crag.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .task(id: crag.id) {
                                        await viewModel.fetchIfNeeded(for: crag)
                                    }
                                }
                            }

                            // Recommended climbing areas
                            RecommendedCragsSection(viewModel: viewModel)
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

// MARK: - Best Day This Week Planner

private struct BestDayPlannerCard: View {
    let crags: [Crag]
    let snapshots: [String: CragListViewModel.CragSnapshot]

    private let scorer = ScoringService(weights: .current)

    // Find the single best (crag, day) combo in the next 7 days, weekend-weighted
    private struct Recommendation {
        let crag: Crag
        let day: DailySummary
        let isWeekend: Bool
    }

    private var recommendation: Recommendation? {
        let cal = Calendar.current
        var best: (rec: Recommendation, score: Int)? = nil

        for crag in crags {
            guard let snap = snapshots[crag.id] else { continue }
            let days = snap.bundle.dailySummaries(scorer: scorer)
            for day in days {
                let weekday = cal.component(.weekday, from: day.date)
                let isWeekend = weekday == 1 || weekday == 7 // Sun=1, Sat=7
                // Boost weekend score slightly so equal conditions favour the weekend
                let adjusted = day.score.value + (isWeekend ? 3 : 0)
                if best == nil || adjusted > best!.score {
                    best = (Recommendation(crag: crag, day: day, isWeekend: isWeekend), adjusted)
                }
            }
        }
        return best?.rec
    }

    var body: some View {
        Group {
            if let rec = recommendation {
                plannerCard(rec)
            } else {
                loadingCard
            }
        }
    }

    private func plannerCard(_ rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BEST DAY THIS WEEK")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .tracking(0.8)
                    Text(rec.isWeekend ? "Weekend pick 🎉" : "Best window")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                Spacer()
                ScoreBadgeView(score: rec.day.score, isLoading: false, size: .large)
            }

            Divider()

            // Recommendation detail
            HStack(spacing: 14) {
                // Day badge
                VStack(spacing: 4) {
                    Text(dayAbbrev(rec.day.date))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(rec.isWeekend ? Theme.Palette.accent : Theme.Palette.textSecondary)
                    Text(dayNum(rec.day.date))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(monthAbbrev(rec.day.date))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .frame(width: 52)
                .padding(.vertical, 8)
                .background(rec.isWeekend ? Theme.Palette.accentMuted : Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(rec.isWeekend ? Theme.Palette.accent.opacity(0.3) : Theme.Palette.divider, lineWidth: 1))

                VStack(alignment: .leading, spacing: 5) {
                    Text(rec.crag.name)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    Text(rec.crag.region)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)

                    // Mini weather row
                    HStack(spacing: 10) {
                        Label("\(Int(rec.day.highF.rounded()))°F high", systemImage: "thermometer.medium")
                        Label(rec.day.totalPrecipIn < 0.01 ? "Dry" : "\(String(format: "%.2f", rec.day.totalPrecipIn))\" rain",
                              systemImage: rec.day.totalPrecipIn < 0.01 ? "sun.max" : "cloud.rain")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .labelStyle(.titleAndIcon)
                }
            }

            // Verdict
            HStack(spacing: 6) {
                Image(systemName: verdictIcon(rec.day.score))
                    .font(.system(size: 12, weight: .semibold))
                Text(rec.day.score.verdict.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(rec.day.score.verdict.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(rec.day.score.verdict.color.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(Theme.Metrics.cardPadding)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
            .stroke(Theme.Palette.accent.opacity(0.2), lineWidth: 1))
    }

    private var loadingCard: some View {
        HStack(spacing: 14) {
            ProgressView().controlSize(.small)
            Text("Loading forecast…")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Metrics.cardPadding)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
            .stroke(Theme.Palette.divider, lineWidth: 1))
    }

    private func dayAbbrev(_ d: Date) -> String {
        if Calendar.current.isDateInToday(d) { return "TODAY" }
        if Calendar.current.isDateInTomorrow(d) { return "TMRW" }
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: d).uppercased()
    }
    private func dayNum(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: d)
    }
    private func monthAbbrev(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: d)
    }
    private func verdictIcon(_ score: ClimbScore) -> String {
        switch score.value {
        case 80...: return "checkmark.circle.fill"
        case 60...: return "hand.thumbsup.fill"
        case 40...: return "exclamationmark.circle"
        default:    return "xmark.circle"
        }
    }
}

// MARK: - Empty state

private struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon stack
            ZStack {
                Circle()
                    .fill(Theme.Palette.accentMuted)
                    .frame(width: 110, height: 110)
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Theme.Palette.accent)
            }
            .padding(.bottom, 28)

            Text("No Saved Crags Yet")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.bottom, 12)

            Text("Bookmark any crag from the Explore tab and it'll show up here — with its current score, forecast, and climber reports all in one place.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 32)

            // How-to hint
            HStack(spacing: 10) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Palette.accent)
                Text("Tap")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Image(systemName: "bookmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                Text("on any crag card to save it")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.Palette.divider, lineWidth: 1)
            )

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 36)
    }
}

// MARK: - Recommended Climbing Areas

private struct RecommendedArea: Identifiable {
    let id = UUID()
    let name: String
    let region: String
    let imageName: String
    let badge: String
    let fact: String
    let tags: [String]
    let cragID: String       // matches crags.json id — enables tap-through
}

struct RecommendedCragsSection: View {
    // Passed in from FavoritesView so we reuse the already-loaded weather data
    let viewModel: CragListViewModel

    private let areas: [RecommendedArea] = [
        RecommendedArea(
            name: "Yosemite Valley",
            region: "California",
            imageName: "climb-outdoor-1",
            badge: "Big wall mecca",
            fact: "Home to El Capitan and Half Dome — the proving ground of modern free climbing and aid climbing history.",
            tags: ["Trad", "Big Wall", "Iconic"],
            cragID: "yosemite-valley"
        ),
        RecommendedArea(
            name: "Red River Gorge",
            region: "Kentucky",
            imageName: "climb-outdoor-2",
            badge: "Sport climbing paradise",
            fact: "Over 1,500 routes on sandstone cliffs tucked inside a stunning river gorge — legendary for pumpy overhangs.",
            tags: ["Sport", "Overhangs", "Sandstone"],
            cragID: "red-river-gorge"
        ),
        RecommendedArea(
            name: "Acadia National Park",
            region: "Maine",
            imageName: "climb-acadia-1",
            badge: "Coastal slab & trad",
            fact: "Granite slabs with ocean views and crisp Atlantic air — mornings here are unlike anywhere else in US climbing.",
            tags: ["Trad", "Slab", "Scenic"],
            cragID: "acadia-otter-cliffs"
        ),
        RecommendedArea(
            name: "Joshua Tree",
            region: "California",
            imageName: "climb-outdoor-3",
            badge: "Crack climbing classic",
            fact: "Thousands of crack routes on monzogranite domes rising from the desert — a rite of passage for crack technique.",
            tags: ["Trad", "Cracks", "Desert"],
            cragID: "joshua-tree"
        ),
        RecommendedArea(
            name: "Rumney",
            region: "New Hampshire",
            imageName: "climb-acadia-2",
            badge: "Northeast sport hub",
            fact: "Compact limestone cliffs with 400+ sport routes from 5.5 to 5.14 — the best single-day sport destination in New England.",
            tags: ["Sport", "Limestone", "All Grades"],
            cragID: "rumney-main"
        ),
        RecommendedArea(
            name: "Red Rock Canyon",
            region: "Nevada",
            imageName: "climb-outdoor-4",
            badge: "Multi-pitch adventure",
            fact: "Towering sandstone escarpment just 20 minutes from Las Vegas — world-renowned for long, exposed multi-pitch routes.",
            tags: ["Trad", "Multi-pitch", "Sandstone"],
            cragID: "red-rock-canyon"
        ),
    ]

    // Flat list of all crags so we can look up by id
    private var allCrags: [Crag] { (try? CragRepository.loadAll()) ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Discover Climbing Areas")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Iconic destinations worth adding to your climbing bucket list.")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.textSecondary)

            VStack(spacing: 14) {
                ForEach(areas) { area in
                    // Look up the live Crag object for this recommendation
                    let matchedCrag = allCrags.first(where: { $0.id == area.cragID })
                    let snapshot    = matchedCrag.flatMap { viewModel.snapshots[$0.id] }

                    if let crag = matchedCrag {
                        NavigationLink {
                            CragDetailView(crag: crag, preloaded: snapshot)
                        } label: {
                            RecommendedAreaCard(area: area, snapshot: snapshot)
                        }
                        .buttonStyle(.plain)
                    } else {
                        RecommendedAreaCard(area: area, snapshot: nil)
                    }
                }
            }
        }
    }
}

private struct RecommendedAreaCard: View {
    let area: RecommendedArea
    let snapshot: CragListViewModel.CragSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero photo
            ZStack(alignment: .bottom) {
                Image(area.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(area.badge.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .tracking(1.0)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.Palette.accent.opacity(0.85)))
                        Text(area.name)
                            .font(Theme.Typography.headline)
                            .foregroundStyle(.white)
                        Text(area.region)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer()
                    // Live score badge if loaded
                    if let snap = snapshot {
                        VStack(spacing: 2) {
                            Text("\(snap.score.value)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(snap.score.verdict.color)
                            Text(snap.score.verdict.rawValue.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(snap.score.verdict.color)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(14)
            }

            // Info section
            VStack(alignment: .leading, spacing: 10) {
                Text(area.fact)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                HStack(spacing: 6) {
                    ForEach(area.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Palette.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.Palette.accentMuted))
                    }
                    Spacer()
                    // Tap indicator
                    HStack(spacing: 3) {
                        Text("View details")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.accent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.Palette.accent)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Palette.divider, lineWidth: 1)
        )
    }
}
