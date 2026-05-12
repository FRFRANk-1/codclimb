import SwiftUI

/// Sheet for creating or editing a score-threshold alert for a single crag.
/// Present from CragDetailView toolbar or the Alerts tab edit button.
struct CragAlertSheet: View {
    let crag: Crag
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.dismiss) private var dismiss

    // Local editable state
    @State private var threshold: Double = 65
    @State private var enabledDays: Set<Int> = []
    @State private var isEnabled: Bool = true
    @State private var requestedPermission = false

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metrics.sectionSpacing) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.Palette.accentMuted)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "bell.badge.fill")
                                    .foregroundStyle(Theme.Palette.accent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(crag.name)
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text(crag.region)
                                    .font(Theme.Typography.callout)
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                        Text("Notify me when the score hits my target so I never miss a perfect day.")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .padding(.top, 4)
                    }

                    // Score threshold
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Score Threshold")
                                .font(Theme.Typography.title)
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Spacer()
                            Text("\(Int(threshold))")
                                .font(Theme.Typography.metric)
                                .foregroundStyle(thresholdColor)
                            Text("/ 100")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }

                        Slider(value: $threshold, in: 30...95, step: 5)
                            .tint(thresholdColor)

                        // Threshold presets
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.value) { preset in
                                PresetChip(
                                    label: preset.label,
                                    sublabel: "\(preset.value)",
                                    isSelected: Int(threshold) == preset.value
                                ) {
                                    withAnimation { threshold = Double(preset.value) }
                                }
                            }
                        }

                        Text(thresholdDescription)
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .padding(.top, 2)
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

                    // Days of week
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Days to Check")
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text(enabledDays.isEmpty ? "Every day" : "Only on selected days")
                            .font(Theme.Typography.callout)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        HStack(spacing: 8) {
                            ForEach(0..<7) { day in
                                DayChip(
                                    label: dayNames[day],
                                    isSelected: enabledDays.contains(day)
                                ) {
                                    withAnimation {
                                        if enabledDays.contains(day) {
                                            enabledDays.remove(day)
                                        } else {
                                            enabledDays.insert(day)
                                        }
                                    }
                                }
                            }
                        }
                        if !enabledDays.isEmpty {
                            Button("Clear — check every day") {
                                withAnimation { enabledDays = [] }
                            }
                            .font(Theme.Typography.caption)
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
                            .stroke(Theme.Palette.divider, lineWidth: 1)
                    )

                    // Delete (only if already exists)
                    if notifications.preference(for: crag) != nil {
                        Button(role: .destructive) {
                            notifications.removePreference(for: crag)
                            dismiss()
                        } label: {
                            Label("Remove Alert", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
                                        .fill(Theme.Palette.nogo.opacity(0.08))
                                )
                                .foregroundStyle(Theme.Palette.nogo)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Metrics.cardPadding)
                .padding(.bottom, 32)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .navigationTitle(notifications.preference(for: crag) != nil ? "Edit Alert" : "Set Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
        }
        .onAppear { loadExisting() }
    }

    // MARK: - Helpers

    private var thresholdColor: Color {
        switch Int(threshold) {
        case 80...: return Theme.Palette.send
        case 60..<80: return Theme.Palette.good
        case 40..<60: return Theme.Palette.marginal
        default:    return Theme.Palette.nogo
        }
    }

    private var thresholdDescription: String {
        switch Int(threshold) {
        case 80...: return "Only alerts on near-perfect send days."
        case 65..<80: return "Good balance — alerts on solid climbing days."
        case 50..<65: return "Broad — alerts even on marginal days."
        default:    return "Very broad — you'll get frequent alerts."
        }
    }

    private let presets: [(label: String, value: Int)] = [
        ("Marginal", 50),
        ("Good", 65),
        ("Great", 80),
        ("Perfect", 90),
    ]

    private func loadExisting() {
        guard let pref = notifications.preference(for: crag) else { return }
        threshold   = Double(pref.threshold)
        enabledDays = pref.enabledDays
        isEnabled   = pref.isEnabled
    }

    private func save() {
        // Request permission if not yet determined
        if notifications.authStatus == .notDetermined {
            Task {
                let granted = await notifications.requestPermission()
                if granted { persist() }
            }
        } else {
            persist()
        }
        dismiss()
    }

    private func persist() {
        let pref = CragAlertPreference(
            cragId:      crag.id,
            cragName:    crag.name,
            threshold:   Int(threshold),
            enabledDays: enabledDays,
            isEnabled:   true
        )
        notifications.setPreference(pref)
        notifications.scheduleBackgroundCheck()
    }
}

// MARK: - Sub-components

private struct PresetChip: View {
    let label: String
    let sublabel: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(Theme.Typography.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(sublabel)
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.Palette.accent : Theme.Palette.surfaceElevated)
            )
            .foregroundStyle(isSelected ? .white : Theme.Palette.textSecondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

private struct DayChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Theme.Palette.accent : Theme.Palette.surfaceElevated)
                )
                .foregroundStyle(isSelected ? .white : Theme.Palette.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
