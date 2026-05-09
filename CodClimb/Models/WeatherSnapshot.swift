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
}
