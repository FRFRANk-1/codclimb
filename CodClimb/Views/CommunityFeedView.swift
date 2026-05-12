// CodClimb/Views/CommunityFeedView.swift
// Drop into CodClimb/Views/ alongside CragListView.swift

import SwiftUI

// MARK: - Community Feed (global recent reports)

struct CommunityFeedView: View {
    @EnvironmentObject private var reportStore: ConditionReportStore
    @State private var showingSubmitSheet = false
    @State private var selectedCragID: String? = nil

    private var crags: [Crag] {
        (try? CragRepository.loadAll()) ?? []
    }

    private var displayedReports: [ConditionReport] {
        reportStore.recentReports(limit: 40)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metrics.sectionSpacing) {
                    feedHeader
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
                        showingSubmitSheet = true
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
    }

    // MARK: Sub-views

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
            Text("\(displayedReports.count) reports in the last 7 days")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Button {
                showingSubmitSheet = true
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
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text("No reports yet")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Be the first to post conditions from the wall.")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showingSubmitSheet = true
            } label: {
                Text("Post a report")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.Palette.accent))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
                HStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.Palette.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No reports yet for this crag")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Text("Tap \"Report\" to share current conditions.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
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
    @State private var didThumbsUp = false

    var body: some View {
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
                // Thumbs up
                Button {
                    guard !didThumbsUp else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        didThumbsUp = true
                        reportStore.thumbsUp(report: report)
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
    @State private var authorName: String = ""
    @State private var rockCondition: ConditionReport.RockCondition = .good
    @State private var crowdLevel: ConditionReport.CrowdLevel = .moderate
    @State private var bodyText: String = ""
    @State private var showingValidationAlert = false

    private var isValid: Bool {
        selectedCrag != nil && !authorName.trimmingCharacters(in: .whitespaces).isEmpty
    }

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
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Post Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Theme.Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        guard isValid else { showingValidationAlert = true; return }
                        submit()
                    }
                    .fontWeight(.semibold)
                    .tint(Theme.Palette.accent)
                }
            }
            .alert("Missing info", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please select a crag and enter your name.")
            }
        }
    }

    private func submit() {
        guard let crag = selectedCrag ?? preselectedCrag else { return }
        let report = ConditionReport(
            cragID: crag.id,
            author: authorName.trimmingCharacters(in: .whitespaces),
            rockCondition: rockCondition,
            crowdLevel: crowdLevel,
            bodyText: bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        reportStore.add(report)
        dismiss()
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

