import Foundation

struct WeatherSnapshot: Hashable {
    let time: Date
    let temperatureF: Double
    let humidityPct: Double
    let precipitationIn: Double
    let windMph: Double
    let cloudCoverPct: Double
    let weatherCode: Int

    var conditionLabel: String {
        switch weatherCode {
        case 0: return "Clear"
        case 1, 2: return "Mostly clear"
        case 3: return "Cloudy"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Severe storm"
        default: return "—"
        }
    }

    var sfSymbolName: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77: return "snowflake"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

struct WeatherBundle {
    let current: WeatherSnapshot
    let hourly: [WeatherSnapshot]
    let pastHourly: [WeatherSnapshot]

    var hoursSinceLastPrecip: Double? {
        let merged = (pastHourly + hourly).filter { $0.time <= current.time }
        guard let lastWet = merged.last(where: { $0.precipitationIn >= 0.01 }) else {
            return nil
        }
        return current.time.timeIntervalSince(lastWet.time) / 3600.0
    }

    // MARK: - Rain forecast

    private static let wetCodes: Set<Int> = [
        51, 53, 55, 56, 57,          // drizzle / freezing drizzle
        61, 63, 65, 66, 67,          // rain / freezing rain
        80, 81, 82,                  // showers
        95, 96, 99                   // thunderstorms
    ]

    /// Hours until the next rain event within the next 24 hours, or nil if none forecast.
    var hoursUntilRain: Double? {
        let next24 = hourly.filter { $0.time > current.time }.prefix(24)
        guard let first = next24.first(where: {
            $0.precipitationIn >= 0.01 || Self.wetCodes.contains($0.weatherCode)
        }) else { return nil }
        return max(0, first.time.timeIntervalSince(current.time) / 3600.0)
    }

    /// Human-readable forecast rain warning, or nil if skies are clear for 24h.
    var rainWarning: RainWarning? {
        guard let h = hoursUntilRain else { return nil }
        switch h {
        case 0..<1:   return .init(urgency: .critical, hoursAway: h)
        case 1..<3:   return .init(urgency: .high,     hoursAway: h)
        case 3..<8:   return .init(urgency: .moderate, hoursAway: h)
        default:      return .init(urgency: .low,      hoursAway: h)
        }
    }

    struct RainWarning {
        enum Urgency { case critical, high, moderate, low }
        let urgency: Urgency
        let hoursAway: Double

        var title: String {
            switch urgency {
            case .critical: return "Rain arriving now"
            case .high:     return "Rain in ~\(Int(hoursAway.rounded()))h"
            case .moderate: return "Rain expected in \(Int(hoursAway.rounded()))h"
            case .low:      return "Rain later today (~\(Int(hoursAway.rounded()))h)"
            }
        }

        var advice: String {
            switch urgency {
            case .critical: return "Rock will be wet soon. Descend or move to a sheltered sector."
            case .high:     return "Start wrapping up. Wet rock arriving in under 3 hours."
            case .moderate: return "Plan your day around it — get your burns in now."
            case .low:      return "Rain tonight. Conditions good now; watch the sky."
            }
        }

        var iconName: String {
            switch urgency {
            case .critical: return "cloud.bolt.rain.fill"
            case .high:     return "cloud.heavyrain.fill"
            case .moderate: return "cloud.rain.fill"
            case .low:      return "cloud.drizzle.fill"
            }
        }
    }

    /// Groups future hourly snapshots by calendar day, returning up to 7 days.
    func dailySummaries(scorer: ScoringService) -> [DailySummary] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: hourly) { snap in
            cal.startOfDay(for: snap.time)
        }
        return grouped.keys.sorted().prefix(7).map { day in
            let hours = grouped[day] ?? []
            let highF = hours.map(\.temperatureF).max() ?? 0
            let lowF  = hours.map(\.temperatureF).min() ?? 0
            let totalPrecip = hours.map(\.precipitationIn).reduce(0, +)
            let avgHumidity = hours.isEmpty ? 0 : hours.map(\.humidityPct).reduce(0, +) / Double(hours.count)
            let avgWind     = hours.isEmpty ? 0 : hours.map(\.windMph).reduce(0, +) / Double(hours.count)
            // Representative weather code: use midday hour if available, else first
            let midday = hours.first(where: { cal.component(.hour, from: $0.time) == 12 }) ?? hours.first
            // Score the midday or first snapshot
            let snapToScore = midday ?? WeatherSnapshot(
                time: day, temperatureF: (highF + lowF) / 2,
                humidityPct: avgHumidity, precipitationIn: totalPrecip,
                windMph: avgWind, cloudCoverPct: 50, weatherCode: 0
            )
            // Build a minimal bundle for scoring (no past data for future days)
            let miniBundle = WeatherBundle(current: snapToScore, hourly: hours, pastHourly: [])
            let score = scorer.score(for: miniBundle)

            return DailySummary(
                date: day,
                highF: highF,
                lowF: lowF,
                totalPrecipIn: totalPrecip,
                representativeCode: midday?.weatherCode ?? 0,
                score: score
            )
        }
    }
}

/// A rolled-up summary of conditions for a single calendar day.
struct DailySummary: Identifiable {
    let date: Date
    let highF: Double
    let lowF: Double
    let totalPrecipIn: Double
    let representativeCode: Int
    let score: ClimbScore

    var id: Date { date }

    var sfSymbolName: String {
        switch representativeCode {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67: return "cloud.rain.fill"
        case 71...77: return "snowflake"
        case 80...82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(date)
    }
}
