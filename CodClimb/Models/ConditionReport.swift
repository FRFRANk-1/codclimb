import Foundation

// MARK: - ConditionReport

struct ConditionReport: Identifiable, Codable {
    let id: String
    let cragID: String
    let author: String
    let date: Date
    var rockCondition: RockCondition
    var crowdLevel: CrowdLevel
    var bodyText: String
    var thumbsUp: Int

    init(
        id: String = UUID().uuidString,
        cragID: String,
        author: String,
        date: Date = .now,
        rockCondition: RockCondition,
        crowdLevel: CrowdLevel,
        bodyText: String = "",
        thumbsUp: Int = 0
    ) {
        self.id = id
        self.cragID = cragID
        self.author = author
        self.date = date
        self.rockCondition = rockCondition
        self.crowdLevel = crowdLevel
        self.bodyText = bodyText
        self.thumbsUp = thumbsUp
    }

    // MARK: - Relative time label

    var relativeTime: String {
        let diff = Date.now.timeIntervalSince(date)
        switch diff {
        case ..<60:           return "just now"
        case ..<3600:         return "\(Int(diff / 60))m ago"
        case ..<86400:        return "\(Int(diff / 3600))h ago"
        case ..<(7 * 86400):  return "\(Int(diff / 86400))d ago"
        default:
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return f.string(from: date)
        }
    }

    // MARK: - Rock Condition

    enum RockCondition: String, Codable, CaseIterable, Identifiable {
        case perfect = "Perfect"
        case good    = "Good"
        case damp    = "Damp"
        case wet     = "Wet"
        case seeping = "Seeping"
        case icy     = "Icy"

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .perfect:  return "✅"
            case .good:     return "🟢"
            case .damp:     return "🟡"
            case .wet:      return "🔵"
            case .seeping:  return "💧"
            case .icy:      return "❄️"
            }
        }

        var isClimbable: Bool {
            switch self {
            case .perfect, .good: return true
            default:              return false
            }
        }
    }

    // MARK: - Crowd Level

    enum CrowdLevel: String, Codable, CaseIterable, Identifiable {
        case empty    = "Empty"
        case light    = "Light"
        case moderate = "Moderate"
        case busy     = "Busy"
        case packed   = "Packed"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .empty:    return "person"
            case .light:    return "person.2"
            case .moderate: return "person.3"
            case .busy:     return "person.3.sequence"
            case .packed:   return "person.crop.circle.badge.exclamationmark"
            }
        }
    }
}

// MARK: - ConditionReportStore

import FirebaseFirestore

@MainActor
final class ConditionReportStore: ObservableObject {

    @Published private(set) var reportsByID: [String: ConditionReport] = [:]

    private let firebase = FirebaseService.shared
    private var listener: ListenerRegistration?

    init() {
        startListening()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Real-time listener

    private func startListening() {
        listener = firebase.listenToReports { [weak self] reports in
            guard let self else { return }
            self.reportsByID = Dictionary(uniqueKeysWithValues: reports.map { ($0.id, $0) })
        }
    }

    // MARK: - Accessors (unchanged public API)

    /// All reports for a specific crag, newest first
    func reports(for cragID: String) -> [ConditionReport] {
        reportsByID.values
            .filter { $0.cragID == cragID }
            .sorted { $0.date > $1.date }
    }

    /// Most recent reports across all crags (newest first, last 7 days)
    func recentReports(limit: Int = 40) -> [ConditionReport] {
        let cutoff = Date.now.addingTimeInterval(-7 * 24 * 3600)
        return reportsByID.values
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Mutations

    func add(_ report: ConditionReport) {
        // Optimistic local insert so UI updates instantly
        reportsByID[report.id] = report
        Task {
            do {
                try await firebase.addReport(report)
            } catch {
                // Roll back on failure
                reportsByID.removeValue(forKey: report.id)
                print("[ConditionReportStore] Add failed: \(error)")
            }
        }
    }

    func thumbsUp(report: ConditionReport) {
        // Optimistic update
        guard var r = reportsByID[report.id] else { return }
        r.thumbsUp += 1
        reportsByID[report.id] = r
        Task {
            do {
                try await firebase.thumbsUp(reportID: report.id)
            } catch {
                print("[ConditionReportStore] ThumbsUp failed: \(error)")
            }
        }
    }

    func remove(id: String) {
        let backup = reportsByID[id]
        reportsByID.removeValue(forKey: id)
        Task {
            do {
                try await firebase.removeReport(id: id)
            } catch {
                if let backup { reportsByID[id] = backup }
                print("[ConditionReportStore] Remove failed: \(error)")
            }
        }
    }
}
