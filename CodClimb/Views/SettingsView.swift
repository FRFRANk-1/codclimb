// CodClimb/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var reportStore: ConditionReportStore
    @EnvironmentObject private var favorites: FavoritesStore

    @AppStorage("codclimb.useMetric") private var useMetric: Bool = false
    @AppStorage("codclimb.username") private var username: String = ""

    private var shortUID: String {
        let uid = FirebaseService.shared.currentUserID
        guard uid.count >= 6 else { return "—" }
        return "#" + uid.prefix(6).uppercased()
    }

    @State private var showingNameEditor = false
    @State private var showingTierSheet = false
    @State private var draftName = ""

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Units
                Section {
                    HStack {
                        Label("Units", systemImage: "ruler")
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        Picker("", selection: $useMetric) {
                            Text("Imperial").tag(false)
                            Text("Metric").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                } header: {
                    Text("Display")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                } footer: {
                    Text(useMetric
                         ? "Showing °C, km/h, and mm"
                         : "Showing °F, mph, and inches")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }

                // MARK: - Community profile
                Section {
                    Button {
                        draftName = username
                        showingNameEditor = true
                    } label: {
                        HStack {
                            Label("Display Name", systemImage: "person.circle")
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Spacer()
                            Text(username.isEmpty ? "Not set" : username)
                                .foregroundStyle(username.isEmpty
                                                 ? Theme.Palette.textTertiary
                                                 : Theme.Palette.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                    }

                    HStack {
                        Label("Account ID", systemImage: "number.circle")
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        Text(shortUID)
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .font(Theme.Typography.body.monospaced())
                    }

                    HStack {
                        Label("Reports posted", systemImage: "square.and.pencil")
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        Text("\(myReportCount)")
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .monospacedDigit()
                    }

                    Button {
                        showingTierSheet = true
                    } label: {
                        HStack {
                            Label("Climber title", systemImage: "rosette")
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Spacer()
                            Text(climberTitle)
                                .foregroundStyle(Theme.Palette.accent)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                    }

                    HStack {
                        Label("Thumbs-up received", systemImage: "hand.thumbsup")
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        Text("\(totalThumbsUp)")
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .monospacedDigit()
                    }
                } header: {
                    Text("Community")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }

                // MARK: - Notifications
                Section {
                    NavigationLink {
                        NotificationsListView()
                            .environmentObject(notifications)
                    } label: {
                        Label("Manage Alerts", systemImage: "bell.badge")
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }

                    if watchedPrefs.isEmpty {
                        Label("No crag alerts set", systemImage: "bell.slash")
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .font(Theme.Typography.callout)
                    } else {
                        ForEach(watchedPrefs) { pref in
                            AlertPrefRow(pref: pref)
                                .environmentObject(notifications)
                        }
                        .onDelete { indices in
                            for index in indices {
                                let pref = watchedPrefs[index]
                                notifications.preferences.removeValue(forKey: pref.cragId)
                            }
                        }
                    }
                } header: {
                    Text("Crag Alerts")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                } footer: {
                    Text("Alerts fire when your watched crag hits your score threshold.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }

                // MARK: - Data Sources
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "cloud.sun")
                            .foregroundStyle(Theme.Palette.accent)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weather data")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text("Provided by Open-Meteo (open-meteo.com) under the CC BY 4.0 license.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                    }
                    .padding(.vertical, 4)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(Theme.Palette.accent)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Crag data")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text("Crag locations are independently researched. Always verify conditions before climbing.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Data Sources")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }

                // MARK: - App info
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    Link(destination: URL(string: "https://instagram.com/codclimb")!) {
                        Label("Follow @codclimb", systemImage: "camera.fill")
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    Link(destination: URL(string: "mailto:rlifrank18@gmail.com?subject=CodClimb%20Bug%20Report&body=Describe%20the%20issue%3A%0A%0ADevice%3A%20%0AiOS%20version%3A%20%0AApp%20version%3A%20")!) {
                        Label("Report a Bug", systemImage: "ladybug")
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    NavigationLink {
                        LegalView()
                    } label: {
                        Label("Terms & Privacy", systemImage: "doc.text")
                            .foregroundStyle(Theme.Palette.textPrimary)
                    }
                } header: {
                    Text("About")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingNameEditor) {
                NameEditorSheet(name: $username, draft: $draftName)
            }
            .sheet(isPresented: $showingTierSheet) {
                ClimberTierSheet(reportCount: myReportCount, totalThumbsUp: totalThumbsUp)
            }
        }
    }

    // MARK: - Computed

    private var watchedPrefs: [CragAlertPreference] {
        notifications.preferences.values.sorted { $0.cragName < $1.cragName }
    }

    private var myReportCount: Int {
        guard !username.isEmpty else { return 0 }
        return reportStore.reportsByID.values.filter { $0.author == username }.count
    }

    private var totalThumbsUp: Int {
        guard !username.isEmpty else { return 0 }
        return reportStore.reportsByID.values
            .filter { $0.author == username }
            .map(\.thumbsUp)
            .reduce(0, +)
    }

    private var climberTitle: String {
        switch myReportCount {
        case 0:       return "New to the wall"
        case 1..<5:   return "Crag Scout"
        case 5..<25:  return "Trail Crusher"
        case 25..<50: return "Route Setter's Eye"
        default:      return "Active Goat 🐐"
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

// MARK: - Alert pref row

private struct AlertPrefRow: View {
    let pref: CragAlertPreference
    @EnvironmentObject private var notifications: NotificationService

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(pref.cragName)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Score ≥ \(pref.threshold) · \(pref.isEnabled ? "Active" : "Paused")")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(pref.isEnabled
                                     ? Theme.Palette.textTertiary
                                     : Theme.Palette.nogo)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { pref.isEnabled },
                set: { newVal in
                    var updated = pref
                    updated.isEnabled = newVal
                    notifications.preferences[pref.cragId] = updated
                }
            ))
            .labelsHidden()
            .tint(Theme.Palette.accent)
        }
    }
}

// MARK: - Name editor sheet

private struct NameEditorSheet: View {
    @Binding var name: String
    @Binding var draft: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Frank_Climbs", text: $draft)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Your display name")
                } footer: {
                    Text("Shown on your community condition reports.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Display Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        name = draft.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Climber Tier Sheet

private struct TierRow: View {
    let emoji: String
    let title: String
    let range: String
    let isCurrent: Bool
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 28))
                .opacity(isUnlocked ? 1.0 : 0.3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.callout)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundStyle(isCurrent ? Theme.Palette.accent : (isUnlocked ? Theme.Palette.textPrimary : Theme.Palette.textTertiary))
                Text(range)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            Spacer()

            if isCurrent {
                Text("YOU ARE HERE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.Palette.accent))
            } else if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Palette.good)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct ClimberTierSheet: View {
    let reportCount: Int
    let totalThumbsUp: Int
    @Environment(\.dismiss) private var dismiss

    private struct Tier {
        let emoji: String
        let title: String
        let minReports: Int
        let maxReports: Int? // nil = unlimited
        var range: String {
            if let max = maxReports { return "\(minReports)–\(max - 1) reports" }
            return "\(minReports)+ reports"
        }
    }

    private let tiers: [Tier] = [
        Tier(emoji: "🧗", title: "New to the Wall",   minReports: 0,  maxReports: 1),
        Tier(emoji: "🔍", title: "Crag Scout",        minReports: 1,  maxReports: 5),
        Tier(emoji: "💥", title: "Trail Crusher",     minReports: 5,  maxReports: 25),
        Tier(emoji: "👁",  title: "Route Setter's Eye",minReports: 25, maxReports: 50),
        Tier(emoji: "🐐", title: "Active Goat",       minReports: 50, maxReports: nil),
    ]

    private var currentTierIndex: Int {
        var idx = 0
        for (i, t) in tiers.enumerated() {
            if reportCount >= t.minReports { idx = i }
        }
        return idx
    }

    private var nextTier: Tier? {
        let next = currentTierIndex + 1
        return next < tiers.count ? tiers[next] : nil
    }

    private var progressToNext: Double {
        guard let next = nextTier else { return 1.0 }
        let current = tiers[currentTierIndex]
        let range = Double(next.minReports - current.minReports)
        let earned = Double(reportCount - current.minReports)
        return min(1.0, earned / range)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Stats summary
                    HStack(spacing: 0) {
                        StatPill(value: "\(reportCount)", label: "Reports")
                        Divider().frame(height: 32)
                        StatPill(value: "\(totalThumbsUp)", label: "Thumbs-up")
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.Palette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.Palette.divider, lineWidth: 1)
                    )

                    // Progress to next tier
                    if let next = nextTier {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Progress to \(next.title)")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Theme.Palette.divider)
                                        .frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Theme.Palette.accent)
                                        .frame(width: geo.size.width * progressToNext, height: 8)
                                }
                            }
                            .frame(height: 8)
                            Text("\(next.minReports - reportCount) more report\(next.minReports - reportCount == 1 ? "" : "s") to unlock")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    } else {
                        Text("You've reached the highest tier! 🐐")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Palette.accent)
                    }

                    // All tiers list
                    VStack(spacing: 0) {
                        ForEach(Array(tiers.enumerated()), id: \.offset) { i, tier in
                            TierRow(
                                emoji: tier.emoji,
                                title: tier.title,
                                range: tier.range,
                                isCurrent: i == currentTierIndex,
                                isUnlocked: reportCount >= tier.minReports
                            )
                            if i < tiers.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 4)

                    Text("Tier is based on how many condition reports you post. Titles are visible to other climbers on your reports.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineSpacing(3)
                }
                .padding(20)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Climber Tiers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
