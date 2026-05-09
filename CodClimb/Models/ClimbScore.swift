import Foundation

struct ClimbScore: Hashable {
    let value: Int
    let factors: [Factor]
    let summary: String

    struct Factor: Hashable, Identifiable {
        let id = UUID()
        let name: String
        let score: Double
        let weight: Double
        let detail: String

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    var verdict: Verdict {
        switch value {
        case 80...: return .send
        case 60..<80: return .good
        case 40..<60: return .marginal
        default: return .nogo
        }
    }

    enum Verdict: String {
        case send = "Send"
        case good = "Good"
        case marginal = "Marginal"
        case nogo = "climbing experience might be not suitable"
    }
}
