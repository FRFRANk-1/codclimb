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
