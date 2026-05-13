// CodClimb/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var reportStore: ConditionReportStore
    @EnvironmentObject private var favorites: FavoritesStore

    @AppStorage("codclimb.useMetric") private var useMetric: Bool = false
    @AppStorage("codclimb.username") private var username: String = ""

    @State private var showingNameEditor = false
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
                        Label("Reports posted", systemImage: "square.and.pencil")
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        Text("\(myReportCount)")
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .monospacedDigit()
                    }

                    HStack {
                        Label("Climber title", systemImage: "rosette")
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        Text(climberTitle)
                            .foregroundStyle(Theme.Palette.accent)
                            .fontWeight(.medium)
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
