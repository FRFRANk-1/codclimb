import Foundation

// MARK: - Cloud sky preference (persisted in UserDefaults)

enum CloudPreference: String, CaseIterable {
    case sun    = "sun"    // ☀ I want blue sky
    case either = "either" // neutral — default
    case shade  = "shade"  // ☁ I prefer overcast (no sunburn, cool rock)

    static let key = "codclimb.cloudPref"

    var label: String {
        switch self {
        case .sun:    return "☀ Sun"
        case .either: return "Either"
        case .shade:  return "☁ Shade"
        }
    }

    var description: String {
        switch self {
        case .sun:    return "Clear skies score higher. Overcast is penalised."
        case .either: return "Cloud cover is scored neutrally."
        case .shade:  return "Overcast scores higher. Great for granite in summer."
        }
    }
}

// MARK: - Scoring weights

struct ScoringWeights {
    var temperature: Double = 0.30
    var dryness: Double = 0.25
    var humidity: Double = 0.20
    var wind: Double = 0.15
    var cloudCover: Double = 0.10
    var cloudPreference: CloudPreference = .either

    /// Reads the user's saved cloud preference from UserDefaults.
    /// Call this at score-time so the preference is always current.
    static var current: ScoringWeights {
        let raw = UserDefaults.standard.string(forKey: CloudPreference.key) ?? ""
        let pref = CloudPreference(rawValue: raw) ?? .either
        return ScoringWeights(cloudPreference: pref)
    }
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
                  detail: "\(Int(bundle.current.cloudCoverPct.rounded()))% · \(cloudBlurb(bundle.current.cloudCoverPct, tempF: bundle.current.temperatureF))")
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
        // Sweet spot: 55–68 °F (13–20 °C) — ideal friction + comfort
        // Scores fall off smoothly outside that range.
        switch f {
        case ..<28:        return 0.0
        case 28..<45:      return 0.10 + (f - 28) / 17 * 0.45   // 0.10 → 0.55
        case 45..<55:      return 0.55 + (f - 45) / 10 * 0.35   // 0.55 → 0.90
        case 55..<68:      return 1.00                            // perfect zone
        case 68..<78:      return 1.00 - (f - 68) / 10 * 0.30   // 1.00 → 0.70
        case 78..<90:      return 0.70 - (f - 78) / 12 * 0.40   // 0.70 → 0.30
        default:           return 0.10
        }
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
        switch weights.cloudPreference {

        case .sun:
            // Wants blue sky — penalise overcast strongly.
            // 0 % → 1.00 · 50 % → 0.69 · 100 % → 0.38
            if tempF > 75 { return min(1.0, 0.40 + pct / 200.0) } // hot: clouds still help a bit
            return max(0.0, 1.0 - (pct / 160.0))

        case .shade:
            // Wants overcast — cool rock, no sunburn.
            // Hot day already rewards clouds, so leave that alone.
            if tempF > 75 { return min(1.0, 0.55 + pct / 220.0) }
            if tempF < 40 { return max(0.0, 1.0 - pct / 100.0) }
            // Normal temp: flip the curve — 0 % → 0.62 · 100 % → 1.00
            return min(1.0, 0.62 + (pct / 267.0))

        case .either:
            // Neutral — moderate penalty for heavy overcast, real range 0–100.
            // 0 % → 1.00 · 50 % → 0.73 · 100 % → 0.46
            if tempF > 75 { return min(1.0, 0.55 + pct / 220.0) }
            if tempF < 40 { return max(0.0, 1.0 - pct / 100.0) }
            return max(0.0, 1.0 - (pct / 185.0))
        }
    }

    private func cloudBlurb(_ pct: Double, tempF: Double) -> String {
        let condition: String
        if tempF > 75 {
            condition = pct > 50 ? "Clouds keeping it cool" : "Clear sky, hot rock"
        } else {
            switch pct {
            case ..<20:   condition = "Clear skies"
            case 20..<50: condition = "Partly cloudy"
            case 50..<80: condition = "Mostly cloudy"
            default:      condition = "Overcast"
            }
        }
        // Append preference label so users see why their score may differ
        switch weights.cloudPreference {
        case .sun:   return "\(condition) · scored for ☀ sun preference"
        case .shade: return "\(condition) · scored for ☁ shade preference"
        case .either: return condition
        }
    }

    private func tempBlurb(_ f: Double) -> String {
        switch f {
        case ..<28:    return "Dangerous cold"
        case 28..<45:  return "Cold — gloves between burns"
        case 45..<55:  return "Chilly but climbable"
        case 55..<68:  return "Sweet spot — prime friction"
        case 68..<78:  return "Warm, friction softening"
        case 78..<88:  return "Hot — chalk fast"
        default:       return "Too hot to send hard"
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
