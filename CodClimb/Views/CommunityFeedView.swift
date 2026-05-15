// CodClimb/Views/CommunityFeedView.swift
import SwiftUI
import PhotosUI

// MARK: - Community Feed (global recent reports)

struct CommunityFeedView: View {
    @EnvironmentObject private var reportStore: ConditionReportStore
    @ObservedObject private var firebase: FirebaseService = .shared
    @State private var showingSubmitSheet = false
    @State private var showingAuth = false
    @State private var selectedCragID: String? = nil
    @State private var selectedRegion: String? = nil

    private var isGuest: Bool { firebase.isAnonymous }

    private var crags: [Crag] {
        (try? CragRepository.loadAll()) ?? []
    }

    /// Unique regions that actually have at least one report, sorted alphabetically.
    private var availableRegions: [String] {
        let allReportCragIDs = Set(reportStore.recentReports(limit: 200).map(\.cragID))
        let regions = crags
            .filter { allReportCragIDs.contains($0.id) }
            .map(\.region)
        return Array(Set(regions)).sorted()
    }

    private var allReports: [ConditionReport] {
        reportStore.recentReports(limit: 40)
    }

    private var filteredReports: [ConditionReport] {
        guard let region = selectedRegion else { return allReports }
        let cragIDsInRegion = Set(crags.filter { $0.region == region }.map(\.id))
        return allReports.filter { cragIDsInRegion.contains($0.cragID) }
    }

    private var displayedReports: [ConditionReport] {
        isGuest ? Array(filteredReports.prefix(5)) : filteredReports
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metrics.sectionSpacing) {
                    feedHeader
                    if !availableRegions.isEmpty {
                        regionFilterBar
                    }
                    liveStatusBanner
                    reportsSection
                }
                .padding(.horizontal, Theme.Metrics.cardPadding)
                .padding(.bottom, 32)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if isGuest { showingAuth = true } else { showingSubmitSheet = true }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .tint(Theme.Palette.accent)
                }
            }
        }
        .sheet(isPresented: $showingSubmitSheet) {
            SubmitReportView(crags: crags)
                .environmentObject(reportStore)
        }
        .sheet(isPresented: $showingAuth) {
            AuthView()
        }
    }

    // MARK: Sub-views

    private var regionFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                RegionChip(label: "All Areas", isSelected: selectedRegion == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedRegion = nil }
                }
                ForEach(availableRegions, id: \.self) { region in
                    RegionChip(label: region, isSelected: selectedRegion == region) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedRegion = (selectedRegion == region) ? nil : region
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Metrics.cardPadding)
            .padding(.vertical, 2)
        }
    }

    private var feedHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live from the Crags")
                .font(Theme.Typography.largeTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Real-time reports from climbers at the wall — conditions, crowds, and beta.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    private var liveStatusBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Theme.Palette.send)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Theme.Palette.send.opacity(0.3), lineWidth: 4)
                        .scaleEffect(1.6)
                )
            Text(selectedRegion == nil
                 ? "\(filteredReports.count) reports in the last 7 days"
                 : "\(filteredReports.count) reports in \(selectedRegion!)")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Button {
                if isGuest { showingAuth = true } else { showingSubmitSheet = true }
            } label: {
                Text("Add yours")
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Palette.accentMuted)
        )
    }

    private var reportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Reports")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)

            if displayedReports.isEmpty {
                emptyState
            } else {
                ForEach(displayedReports) { report in
                    let crag = crags.first(where: { $0.id == report.cragID })
                    ReportCard(report: report, crag: crag)
                        .environmentObject(reportStore)
                }
                // Gate card for guests
                if isGuest && filteredReports.count > 5 {
                    signInGateCard
                }
            }
        }
    }

    private var signInGateCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.Palette.accentMuted).frame(width: 60, height: 60)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.Palette.accent)
            }
            VStack(spacing: 6) {
                Text("\(filteredReports.count - 5) more reports")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Create a free account to see all community reports, post your own conditions, and get crag alerts.")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showingAuth = true
            } label: {
                Text("Sign Up — It's Free")
                    .font(Theme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.Palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button("Sign in to existing account") {
                showingAuth = true
            }
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Palette.accent)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(Theme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .stroke(Theme.Palette.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            // Icon
            ZStack {
                Circle()
                    .fill(Theme.Palette.accentMuted)
                    .frame(width: 96, height: 96)
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Palette.accent)
            }
            .padding(.bottom, 24)

            Text("No Reports This Week")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.bottom, 10)

            Text("CodClimb shows the last 7 days of community beta. Get the feed started — post the first report from your next session.")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 28)

            Button {
                showingSubmitSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                    Text("Post First Report")
                }
                .font(Theme.Typography.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.Palette.accent)
                )
            }
            .padding(.bottom, 20)

            // Tip chips
            HStack(spacing: 8) {
                EmptyStateTipChip(icon: "camera.fill", text: "Add a photo")
                EmptyStateTipChip(icon: "hand.thumbsup.fill", text: "React")
                EmptyStateTipChip(icon: "bell.badge", text: "Set alerts")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.bottom, 48)
        .padding(.horizontal, 8)
    }
}

// MARK: - Shared empty-state tip chip

struct EmptyStateTipChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Theme.Palette.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.Palette.accentMuted))
    }
}

// MARK: - Region filter chip

struct RegionChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Theme.Palette.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.Palette.accent : Theme.Palette.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Theme.Palette.divider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Crag-specific feed (embedded in CragDetailView)

struct CragConditionFeedView: View {
    let crag: Crag
    @EnvironmentObject private var reportStore: ConditionReportStore
    @State private var showingSubmitSheet = false

    private var reports: [ConditionReport] {
        reportStore.reports(for: crag.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Climber Reports")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button {
                    showingSubmitSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Report")
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Theme.Palette.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.Palette.accentMuted)
                    )
                }
                .buttonStyle(.plain)
            }

            if reports.isEmpty {
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Theme.Palette.accentMuted)
                                .frame(width: 48, height: 48)
                            Image(systemName: "person.wave.2")
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.Palette.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Be the first to report")
                                .font(Theme.Typography.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text("No one has posted conditions here yet. Tap Report after your session.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .lineSpacing(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        showingSubmitSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Post Conditions")
                                .font(Theme.Typography.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(Theme.Palette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.Palette.accentMuted)
                        )
                    }
                    .buttonStyle(.plain)
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
            } else {
                ForEach(reports.prefix(5)) { report in
                    ReportCard(report: report, crag: crag)
                        .environmentObject(reportStore)
                }
                if reports.count > 5 {
                    NavigationLink {
                        AllReportsView(crag: crag)
                            .environmentObject(reportStore)
                    } label: {
                        Text("See all \(reports.count) reports")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSubmitSheet) {
            SubmitReportView(preselectedCrag: crag, crags: (try? CragRepository.loadAll()) ?? [])
                .environmentObject(reportStore)
        }
    }
}

// MARK: - ReportCard

struct ReportCard: View {
    let report: ConditionReport
    let crag: Crag?
    @EnvironmentObject private var reportStore: ConditionReportStore
    @EnvironmentObject private var profileStore: UserProfileStore
    @ObservedObject private var firebase: FirebaseService = .shared
    @State private var didThumbsUp = false
    @State private var showingDetail = false
    @State private var showingAuthForReaction = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack(alignment: .center, spacing: 10) {
                    avatarCircle
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(report.author)
                                .font(Theme.Typography.headline)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text("·")
                                .foregroundStyle(Theme.Palette.textTertiary)
                            Text(report.relativeTime)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                        if let crag {
                            Text(crag.name)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.accent)
                        }
                    }
                    Spacer()
                    conditionBadge
                }

                // Body text
                if !report.bodyText.isEmpty {
                    Text(report.bodyText)
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(6)
                }

                // Photos (single or multi-photo grid)
                let urls = report.allPhotoURLs
                if urls.count == 1, let url = URL(string: urls[0]) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        case .failure: EmptyView()
                        case .empty:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.Palette.surfaceElevated).frame(height: 200)
                                .overlay(ProgressView())
                        @unknown default: EmptyView()
                        }
                    }
                } else if urls.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(urls, id: \.self) { urlStr in
                                if let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                                .frame(width: 160, height: 160)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        case .failure: EmptyView()
                                        case .empty:
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Theme.Palette.surfaceElevated)
                                                .frame(width: 160, height: 160)
                                                .overlay(ProgressView())
                                        @unknown default: EmptyView()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Footer: crowd + thumbs up
                HStack(spacing: 14) {
                    // Crowd level
                    HStack(spacing: 4) {
                        Image(systemName: report.crowdLevel.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.textTertiary)
                        Text(report.crowdLevel.rawValue)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    Spacer()
                    // Thumbs up — gated behind sign-in
                    Button {
                        if firebase.isAnonymous {
                            showingAuthForReaction = true
                        } else {
                            guard !didThumbsUp else { return }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                didThumbsUp = true
                                reportStore.thumbsUp(report: report)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: didThumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.system(size: 13))
                                .foregroundStyle(didThumbsUp ? Theme.Palette.accent : Theme.Palette.textTertiary)
                            Text("\(report.thumbsUp + (didThumbsUp ? 1 : 0))")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
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
                    .stroke(
                        report.rockCondition.isClimbable
                            ? Theme.Palette.accent.opacity(0.2)
                            : Theme.Palette.divider,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            ReportDetailSheet(report: report, crag: crag)
                .environmentObject(profileStore)
                .environmentObject(reportStore)
        }
        .sheet(isPresented: $showingAuthForReaction) {
            AuthView()
                .environmentObject(profileStore)
        }
    }

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(Theme.Palette.accentMuted)
                .frame(width: 36, height: 36)
            Text(String(report.author.prefix(1)).uppercased())
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
        }
    }

    private var conditionBadge: some View {
        HStack(spacing: 4) {
            Text(report.rockCondition.emoji)
                .font(.system(size: 12))
            Text(report.rockCondition.rawValue)
                .font(Theme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(badgeColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.12))
        )
    }

    private var badgeColor: Color {
        switch report.rockCondition {
        case .perfect:  return Theme.Palette.send
        case .good:     return Theme.Palette.good
        case .damp:     return Theme.Palette.marginal
        case .wet, .seeping: return Theme.Palette.nogo
        case .icy:      return Color(red: 0.4, green: 0.6, blue: 0.85)
        }
    }
}

// MARK: - Report Detail Sheet

struct ReportDetailSheet: View {
    let report: ConditionReport
    let crag: Crag?

    @EnvironmentObject private var reportStore: ConditionReportStore
    @EnvironmentObject private var profileStore: UserProfileStore
    @StateObject private var listVM = CragListViewModel()
    @Environment(\.dismiss) private var dismiss

    private var userReports: [ConditionReport] {
        reportStore.recentReports(limit: 100).filter { $0.author == report.author }
    }

    private var allCrags: [Crag] {
        (try? CragRepository.loadAll()) ?? []
    }

    private var badgeColor: Color {
        switch report.rockCondition {
        case .perfect:  return Theme.Palette.send
        case .good:     return Theme.Palette.good
        case .damp:     return Theme.Palette.marginal
        case .wet, .seeping: return Theme.Palette.nogo
        case .icy:      return Color(red: 0.4, green: 0.6, blue: 0.85)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Full report card ────────────────────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        // Condition badge + crag name header
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Text(report.rockCondition.emoji)
                                    .font(.system(size: 14))
                                Text(report.rockCondition.rawValue)
                                    .font(Theme.Typography.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(badgeColor)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(badgeColor.opacity(0.12)))

                            if let crag {
                                Text("at \(crag.name)")
                                    .font(Theme.Typography.callout)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            Spacer()
                            Text(report.relativeTime)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }

                        // Body text
                        if !report.bodyText.isEmpty {
                            Text(report.bodyText)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Photo
                        if let urlStr = report.photoURL, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 240)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure:
                                    EmptyView()
                                case .empty:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Theme.Palette.surfaceElevated)
                                        .frame(height: 240)
                                        .overlay(ProgressView())
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }

                        // Crowd level pill
                        HStack(spacing: 6) {
                            Image(systemName: report.crowdLevel.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Palette.textTertiary)
                            Text("Crowd: \(report.crowdLevel.rawValue)")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                    }
                    .padding(Theme.Metrics.cardPadding)
                    .background(Theme.Palette.surface)

                    Divider()

                    // ── Poster profile section ──────────────────────────────
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About the Climber")
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Palette.textPrimary)

                        HStack(spacing: 14) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(Theme.Palette.accentMuted)
                                    .frame(width: 56, height: 56)
                                Text(String(report.author.prefix(1)).uppercased())
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.accent)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(report.author)
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text("\(userReports.count) report\(userReports.count == 1 ? "" : "s") posted")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            Spacer()
                        }

                        // Recent reports by this user
                        if userReports.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Other reports by \(report.author)")
                                    .font(Theme.Typography.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.Palette.textSecondary)

                                ForEach(userReports.filter { $0.id != report.id }.prefix(3)) { r in
                                    MiniReportRow(report: r, cragName: allCrags.first(where: { $0.id == r.cragID })?.name)
                                }
                            }
                        }
                    }
                    .padding(Theme.Metrics.cardPadding)

                    Divider()
                        .padding(.horizontal, Theme.Metrics.cardPadding)

                    // ── Discover climbing areas ─────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        RecommendedCragsSection(viewModel: listVM)
                    }
                    .padding(.horizontal, Theme.Metrics.cardPadding)
                    .padding(.bottom, 40)
                }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle(report.author)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .tint(Theme.Palette.accent)
                }
            }
            .task {
                await listVM.load()
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - All Reports for a Crag

struct AllReportsView: View {
    let crag: Crag
    @EnvironmentObject private var reportStore: ConditionReportStore
    @State private var showingSubmitSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(reportStore.reports(for: crag.id)) { report in
                    ReportCard(report: report, crag: crag)
                        .environmentObject(reportStore)
                }
            }
            .padding(.horizontal, Theme.Metrics.cardPadding)
            .padding(.bottom, 32)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingSubmitSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .tint(Theme.Palette.accent)
            }
        }
        .sheet(isPresented: $showingSubmitSheet) {
            SubmitReportView(preselectedCrag: crag, crags: (try? CragRepository.loadAll()) ?? [])
                .environmentObject(reportStore)
        }
    }
}

// MARK: - Submit Report Sheet

struct SubmitReportView: View {
    var preselectedCrag: Crag? = nil
    let crags: [Crag]

    @EnvironmentObject private var reportStore: ConditionReportStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCrag: Crag?
    @AppStorage("codclimb.username") private var savedUsername: String = ""
    @State private var authorName: String = ""
    @State private var rockCondition: ConditionReport.RockCondition = .good
    @State private var crowdLevel: ConditionReport.CrowdLevel = .moderate
    @State private var bodyText: String = ""
    @State private var showingValidationAlert = false
    @State private var showingAuth = false

    // Multi-photo picker (max 4)
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photoDatas: [Data] = []
    @State private var photoPreviews: [Image] = []
    @State private var isUploading = false

    private var isValid: Bool {
        selectedCrag != nil && !authorName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isGuest: Bool { FirebaseService.shared.isAnonymous }

    var body: some View {
        NavigationStack {
            Form {
                // Crag picker
                Section("Crag") {
                    if let pre = preselectedCrag {
                        LabeledContent("Location", value: pre.name)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .onAppear { selectedCrag = pre }
                    } else {
                        Picker("Select crag", selection: $selectedCrag) {
                            Text("Choose…").tag(Optional<Crag>(nil))
                            ForEach(crags) { crag in
                                Text(crag.name).tag(Optional(crag))
                            }
                        }
                    }
                }

                // Author
                Section("Your name") {
                    TextField("Displayed publicly", text: $authorName)
                        .autocorrectionDisabled()
                }

                // Rock condition
                Section("Rock condition") {
                    Picker("Condition", selection: $rockCondition) {
                        ForEach(ConditionReport.RockCondition.allCases) { c in
                            Label(c.rawValue, systemImage: conditionIcon(c))
                                .tag(c)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Crowd
                Section("Crowd level") {
                    Picker("Crowd", selection: $crowdLevel) {
                        ForEach(ConditionReport.CrowdLevel.allCases) { c in
                            Label(c.rawValue, systemImage: c.icon)
                                .tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Notes
                Section("Conditions notes") {
                    TextField(
                        "What's it like? Seeps, crowds, best sectors, temps…",
                        text: $bodyText,
                        axis: .vertical
                    )
                    .lineLimit(5...10)
                }

                // Photos (up to 4)
                Section {
                    // Thumbnail row of selected photos
                    if !photoPreviews.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photoPreviews.indices, id: \.self) { i in
                                    ZStack(alignment: .topTrailing) {
                                        photoPreviews[i]
                                            .resizable().scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        Button {
                                            photoPreviews.remove(at: i)
                                            photoDatas.remove(at: i)
                                            if i < photoItems.count { photoItems.remove(at: i) }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.white)
                                                .background(Circle().fill(Color.black.opacity(0.5)))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if photoPreviews.count < 4 {
                        PhotosPicker(
                            selection: $photoItems,
                            maxSelectionCount: 4,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 10) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.Palette.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(photoPreviews.isEmpty ? "Add photos" : "Add more photos")
                                        .font(Theme.Typography.callout)
                                        .foregroundStyle(Theme.Palette.textPrimary)
                                    Text("\(photoPreviews.count)/4 selected · show conditions at the crag")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Palette.textTertiary)
                                }
                            }
                        }
                        .onChange(of: photoItems) { items in
                            Task {
                                var newDatas: [Data] = []
                                var newPreviews: [Image] = []
                                for item in items.prefix(4) {
                                    guard let data = try? await item.loadTransferable(type: Data.self),
                                          let ui = UIImage(data: data) else { continue }
                                    newDatas.append(data)
                                    newPreviews.append(Image(uiImage: ui))
                                }
                                photoDatas = newDatas
                                photoPreviews = newPreviews
                            }
                        }
                    }
                } header: {
                    Text("Photos (up to 4)")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Post Report")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Pre-fill author from saved username
                if authorName.isEmpty { authorName = savedUsername }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Theme.Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isUploading {
                        ProgressView().tint(Theme.Palette.accent)
                    } else {
                        Button("Post") {
                            guard isValid else { showingValidationAlert = true; return }
                            Task { await submit() }
                        }
                        .fontWeight(.semibold)
                        .tint(Theme.Palette.accent)
                    }
                }
            }
            .alert("Missing info", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please select a crag and enter your name.")
            }
        }
    }

    private func submit() async {
        guard let crag = selectedCrag ?? preselectedCrag else { return }
        isUploading = true
        defer { isUploading = false }

        let reportID = UUID().uuidString

        // Upload all photos concurrently (max 4, compressed to 1 MB each)
        let compressed = photoDatas.map { compressImage($0, maxBytes: 1_000_000) }
        let uploadedURLs = (try? await FirebaseService.shared.uploadPhotos(compressed, reportID: reportID)) ?? []

        let report = ConditionReport(
            id: reportID,
            cragID: crag.id,
            author: authorName.trimmingCharacters(in: .whitespaces),
            rockCondition: rockCondition,
            crowdLevel: crowdLevel,
            bodyText: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            photoURLs: uploadedURLs
        )
        reportStore.add(report)

        // Save author name for next time
        savedUsername = authorName.trimmingCharacters(in: .whitespaces)
        dismiss()
    }

    /// Compress image data to stay under maxBytes while preserving aspect ratio.
    private func compressImage(_ data: Data, maxBytes: Int) -> Data {
        guard let image = UIImage(data: data) else { return data }
        var quality: CGFloat = 0.8
        var result = image.jpegData(compressionQuality: quality) ?? data
        while result.count > maxBytes && quality > 0.1 {
            quality -= 0.1
            result = image.jpegData(compressionQuality: quality) ?? data
        }
        return result
    }

    private func conditionIcon(_ c: ConditionReport.RockCondition) -> String {
        switch c {
        case .perfect:  return "checkmark.circle.fill"
        case .good:     return "checkmark.circle"
        case .damp:     return "drop.halffull"
        case .wet:      return "drop.fill"
        case .seeping:  return "water.waves"
        case .icy:      return "snowflake"
        }
    }
}

