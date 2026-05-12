import SwiftUI

// MARK: - Alerts Tab (root list)

struct NotificationsListView: View {
    @EnvironmentObject private var notifications: NotificationService

    private var activePrefs: [CragAlertPreference] {
        notifications.preferences.values
            .sorted { $0.cragName < $1.cragName }
    }

    var body: some View {
        NavigationStack {
            Group {
                if notifications.authStatus == .denied {
                    PermissionDeniedView()
                } else if activePrefs.isEmpty {
                    EmptyAlertsView()
                } else {
                    alertList
                }
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await notifications.refreshAuthStatus() }
    }

    private var alertList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Permission banner if not yet authorized
                if notifications.authStatus == .notDetermined {
                    PermissionBanner()
                }

                VStack(spacing: 0) {
                    ForEach(activePrefs) { pref in
                        AlertRow(pref: pref)
                        if pref.id != activePrefs.last?.id {
                            Divider().padding(.horizontal, Theme.Metrics.cardPadding)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                        .fill(Theme.Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                        .stroke(Theme.Palette.divider, lineWidth: 1)
                )

                Text("Alerts fire when a crag's score hits your threshold. Checked every 30 minutes in the background.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
            .padding(.horizontal, Theme.Metrics.cardPadding)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Alert Row

private struct AlertRow: View {
    let pref: CragAlertPreference
    @EnvironmentObject private var notifications: NotificationService
    @State private var showingEdit = false

    private var dayLabels: String {
        if pref.enabledDays.isEmpty { return "Every day" }
        let names = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        return pref.enabledDays.sorted().map { names[$0] }.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(pref.isEnabled ? Theme.Palette.accentMuted : Theme.Palette.surfaceElevated)
                    .frame(width: 40, height: 40)
                Image(systemName: "bell.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(pref.isEnabled ? Theme.Palette.accent : Theme.Palette.textTertiary)
            }

            // Labels
            VStack(alignment: .leading, spacing: 3) {
                Text(pref.cragName)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text("Score ≥ \(pref.threshold) · \(dayLabels)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { pref.isEnabled },
                set: { _ in
                    if let crag = try? CragRepository.loadAll().first(where: { $0.id == pref.cragId }) {
                        notifications.toggleEnabled(for: crag)
                    }
                }
            ))
            .labelsHidden()
            .tint(Theme.Palette.accent)

            // Edit chevron
            Button { showingEdit = true } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Metrics.cardPadding)
        .sheet(isPresented: $showingEdit) {
            // Load the crag to pass into the sheet
            if let crag = try? CragRepository.loadAll().first(where: { $0.id == pref.cragId }) {
                CragAlertSheet(crag: crag)
            }
        }
    }
}

// MARK: - Permission Banner

private struct PermissionBanner: View {
    @EnvironmentObject private var notifications: NotificationService

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(Theme.Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Enable notifications")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Allow alerts so CodClimb can notify you.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            Button("Allow") {
                Task { await notifications.requestPermission() }
            }
            .font(Theme.Typography.callout)
            .foregroundStyle(Theme.Palette.accent)
            .fontWeight(.semibold)
        }
        .padding(Theme.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .fill(Theme.Palette.accentMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                .stroke(Theme.Palette.accent.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Empty state

private struct EmptyAlertsView: View {
    @EnvironmentObject private var notifications: NotificationService

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text("No alerts set")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Open any crag and tap\n\"Set Alert\" to get notified\nwhen conditions are right.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Permission denied

private struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.Palette.nogo)
            Text("Notifications blocked")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Go to Settings → CodClimb → Notifications and turn them on.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Palette.accent)
            .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
