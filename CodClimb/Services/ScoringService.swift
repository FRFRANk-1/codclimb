import Foundation

struct ScoringWeights {
    var temperature: Double = 0.30
    var dryness: Double = 0.30
    var humidity: Double = 0.20
    var wind: Double = 0.15
    var cloudCover: Double = 0.05

    static let `default` = ScoringWeights()
}

struct ScoringService {
    let weights: ScoringWeights

    init(weights: ScoringWeights = .default) {
        self.weights = weights
    }

    func score(for bundle: WeatherBundle) -> ClimbScore {
        let tempScore = temperatureScore(bundle.current.temperatureF)
        let drynessScore = drynessScore(hours: bundle.hoursSinceLastPrecip)
        let humidityScore = humidityScore(bundle.current.humidityPct)
        let windScore = windScore(bundle.current.windMph)
        let cloudScore = cloudScore(bundle.current.cloudCoverPct, tempF: bundle.current.temperatureF)

        let factors: [ClimbScore.Factor] = [
            .init(name: "Temperature", score: tempScore, weight: weights.temperature,
                  detail: "\(Int(bundle.current.temperatureF.rounded()))°F · \(tempBlurb(bundle.current.temperatureF))"),
            .init(name: "Dryness", score: drynessScore, weight: weights.dryness,
                  detail: drynessBlurb(hours: bundle.hoursSinceLastPrecip)),
            .init(name: "Humidity", score: humidityScore, weight: weights.humidity,
                  detail: "\(Int(bundle.current.humidityPct.rounded()))% · \(humidityBlurb(bundle.current.humidityPct))"),
            .init(name: "Wind", score: windScore, weight: weights.wind,
                  detail: "\(Int(bundle.current.windMph.rounded())) mph · \(windBlurb(bundle.current.windMph))"),
            .init(name: "Cloud cover", score: cloudScore, weight: weights.cloudCover,
                  detail: "\(Int(bundle.current.cloudCoverPct.rounded()))%")
        ]

        let weighted = factors.reduce(0.0) { $0 + $1.score * $1.weight }
        let value = Int((weighted * 100).rounded())
        return ClimbScore(value: value, factors: factors, summary: summary(for: value, factors: factors))
    }

    func bestUpcomingWindow(in bundle: WeatherBundle, hoursAhead: Int = 48) -> WeatherSnapshot? {
        let upcoming = Array(bundle.hourly.prefix(hoursAhead))
        return upcoming.max { a, b in
            scoreFor(a, dryHours: bundle.hoursSinceLastPrecip) < scoreFor(b, dryHours: bundle.hoursSinceLastPrecip)
        }
    }

    private func scoreFor(_ snap: WeatherSnapshot, dryHours: Double?) -> Double {
        let t = temperatureScore(snap.temperatureF)
        let d = drynessScore(hours: dryHours)
        let h = humidityScore(snap.humidityPct)
        let w = windScore(snap.windMph)
        let c = cloudScore(snap.cloudCoverPct, tempF: snap.temperatureF)
        return t * weights.temperature + d * weights.dryness + h * weights.humidity + w * weights.wind + c * weights.cloudCover
    }

    private func temperatureScore(_ f: Double) -> Double {
        let ideal = 50.0
        let spread = 25.0
        let dx = (f - ideal) / spread
        return max(0, min(1, 1 - dx * dx))
    }

    private func drynessScore(hours: Double?) -> Double {
        guard let h = hours else { return 1.0 }
        if h >= 24 { return 1.0 }
        if h <= 2 { return 0.0 }
        return (h - 2) / 22.0
    }

    private func humidityScore(_ pct: Double) -> Double {
        if pct <= 50 { return 1.0 }
        if pct >= 90 { return 0.0 }
        return (90 - pct) / 40.0
    }

    private func windScore(_ mph: Double) -> Double {
        switch mph {
        case 0..<5: return 0.85
        case 5..<15: return 1.0
        case 15..<22: return 0.7
        case 22..<30: return 0.4
        default: return 0.1
        }
    }

    private func cloudScore(_ pct: Double, tempF: Double) -> Double {
        if tempF > 75 { return min(1, pct / 100 + 0.3) }
        if tempF < 35 { return max(0, 1 - pct / 200) }
        return 0.85
    }

    private func tempBlurb(_ f: Double) -> String {
        switch f {
        case ..<25: return "Bitter cold — fingers will hate you"
        case 25..<40: return "Crisp, sticky friction"
        case 40..<60: return "Prime conditions"
        case 60..<72: return "Comfortable"
        case 72..<82: return "Warm, watch the friction"
        default: return "Too hot to send hard"
        }
    }

    private func drynessBlurb(hours: Double?) -> String {
        guard let h = hours else { return "No recent rain in window" }
        let r = Int(h.rounded())
        switch h {
        case ..<3: return "Wet — \(r)h since rain"
        case 3..<12: return "Damp — \(r)h since rain"
        case 12..<24: return "Drying — \(r)h since rain"
        default: return "Dry — \(r)h+ since rain"
        }
    }

    private func humidityBlurb(_ pct: Double) -> String {
        switch pct {
        case ..<50: return "Crisp"
        case 50..<70: return "OK"
        case 70..<85: return "Sticky"
        default: return "Soup"
        }
    }

    private func windBlurb(_ mph: Double) -> String {
        switch mph {
        case ..<5: return "Calm"
        case 5..<15: return "Breezy — helps drying"
        case 15..<25: return "Gusty"
        default: return "Strong — be careful"
        }
    }

    private func summary(for value: Int, factors: [ClimbScore.Factor]) -> String {
        let weakest = factors.min { $0.score < $1.score }
        switch value {
        case 80...: return "Send conditions. Pack the tape."
        case 60..<80: return "Solid day on the wall."
        case 40..<60: return "Marginal — \(weakest?.name.lowercased() ?? "conditions") is the limiting factor."
        default: return "Probably not worth it today."
        }
    }
}
