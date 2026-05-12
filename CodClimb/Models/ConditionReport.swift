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

@MainActor
final class ConditionReportStore: ObservableObject {
    @Published private(set) var reportsByID: [String: ConditionReport] = [:]

    private let storageKey = "codclimb.conditionReports"

    init() { load() }

    // MARK: Accessors

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

    // MARK: Mutations

    func add(_ report: ConditionReport) {
        reportsByID[report.id] = report
        save()
    }

    func thumbsUp(report: ConditionReport) {
        guard var r = reportsByID[report.id] else { return }
        r.thumbsUp += 1
        reportsByID[report.id] = r
        save()
    }

    func remove(id: String) {
        reportsByID.removeValue(forKey: id)
        save()
    }

    // MARK: Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(reportsByID) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: ConditionReport].self, from: data)
        else { return }
        reportsByID = decoded
    }
}
