import UserNotifications
import BackgroundTasks
import SwiftUI

// MARK: - Alert Preference (persisted per crag)

struct CragAlertPreference: Codable, Identifiable {
    let cragId: String
    let cragName: String
    var threshold: Int        // 0–100, fire when score >= this
    var enabledDays: Set<Int> // 0 = Sun … 6 = Sat; empty = all days
    var isEnabled: Bool

    var id: String { cragId }

    static let bgTaskIdentifier = "com.codclimb.conditioncheck"
}

// MARK: - NotificationService

@MainActor
final class NotificationService: ObservableObject {

    // MARK: Published state

    @Published private(set) var authStatus: UNAuthorizationStatus = .notDetermined
    @Published var preferences: [String: CragAlertPreference] = [:] {
        didSet { save() }
    }

    // MARK: Private

    private let center = UNUserNotificationCenter.current()
    private let storageKey = "codclimb.alertPreferences"

    init() {
        load()
        registerBackgroundTask()
        Task { await refreshAuthStatus() }
    }

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthStatus()
            return granted
        } catch {
            return false
        }
    }

    func refreshAuthStatus() async {
        let settings = await center.notificationSettings()
        authStatus = settings.authorizationStatus
    }

    // MARK: - Preference management

    func preference(for crag: Crag) -> CragAlertPreference? {
        preferences[crag.id]
    }

    func setPreference(_ pref: CragAlertPreference) {
        preferences[pref.cragId] = pref
    }

    func removePreference(for crag: Crag) {
        preferences.removeValue(forKey: crag.id)
        cancelPending(for: crag)
    }

    func toggleEnabled(for crag: Crag) {
        guard var pref = preferences[crag.id] else { return }
        pref.isEnabled.toggle()
        preferences[crag.id] = pref
    }

    // MARK: - Fire a notification

    /// Call this when a background check determines conditions are met.
    func fireAlert(for pref: CragAlertPreference, score: Int) async {
        guard pref.isEnabled, authStatus == .authorized else { return }

        // Don't spam — skip if we already sent one in the last 6 hours.
        let pendingIds = await center.pendingNotificationRequests().map(\.identifier)
        let sentKey = "lastAlert_\(pref.cragId)"
        if let last = UserDefaults.standard.object(forKey: sentKey) as? Date,
           Date().timeIntervalSince(last) < 6 * 3600 { return }

        let content = UNMutableNotificationContent()
        content.title = "🧗 \(pref.cragName) is looking good!"
        content.body = scoreBody(score: score, cragName: pref.cragName, threshold: pref.threshold)
        content.sound = .default
        content.userInfo = ["cragId": pref.cragId]

        // Deliver immediately
        let request = UNNotificationRequest(
            identifier: "alert_\(pref.cragId)_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
        UserDefaults.standard.set(Date(), forKey: sentKey)
    }

    // MARK: - Background task scheduling

    /// Register the background refresh task identifier in AppDelegate / app init.
    /// Call once at app launch.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: CragAlertPreference.bgTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleBackgroundCheck(task: task as! BGAppRefreshTask)
            }
        }
    }

    /// Schedule the next background check (call after each check completes).
    func scheduleBackgroundCheck() {
        let request = BGAppRefreshTaskRequest(
            identifier: CragAlertPreference.bgTaskIdentifier
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 min
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Background check handler

    private func handleBackgroundCheck(task: BGAppRefreshTask) async {
        scheduleBackgroundCheck() // Reschedule immediately

        let enabledPrefs = preferences.values.filter(\.isEnabled)
        guard !enabledPrefs.isEmpty else {
            task.setTaskCompleted(success: true)
            return
        }

        let client = OpenMeteoClient()
        let scorer = ScoringService()

        // Check each enabled crag
        for pref in enabledPrefs {
            guard let crag = try? CragRepository.loadAll().first(where: { $0.id == pref.cragId })
            else { continue }

            // Respect day-of-week filter
            let today = Calendar.current.component(.weekday, from: Date()) - 1 // 0-indexed
            if !pref.enabledDays.isEmpty && !pref.enabledDays.contains(today) { continue }

            do {
                let bundle = try await client.fetch(latitude: crag.latitude, longitude: crag.longitude)
                let score = scorer.score(for: bundle)
                if score.value >= pref.threshold {
                    await fireAlert(for: pref, score: score.value)
                }
            } catch {
                continue
            }
        }

        task.setTaskCompleted(success: true)
    }

    // MARK: - Helpers

    private func cancelPending(for crag: Crag) {
        center.removePendingNotificationRequests(
            withIdentifiers: ["alert_\(crag.id)"]
        )
    }

    private func scoreBody(score: Int, cragName: String, threshold: Int) -> String {
        switch score {
        case 80...: return "Score \(score)/100 — send conditions. Pack the tape."
        case 60..<80: return "Score \(score)/100 — solid day on the wall."
        default:     return "Score \(score)/100 — hit your alert threshold of \(threshold)."
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: CragAlertPreference].self, from: data)
        else { return }
        preferences = decoded
    }
}
