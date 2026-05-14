// CodClimb/Services/SolarCalculator.swift
//
// Pure-Swift astronomical sunrise/sunset calculator.
// Uses the NOAA solar calculation algorithm — no API needed.
// Accurate to within a minute for latitudes ±60°.

import Foundation

struct SolarCalculator {

    // MARK: - Public API

    struct SolarTimes {
        let sunrise: Date
        let sunset: Date
        let solarNoon: Date

        var isDaytime: Bool {
            let now = Date()
            return now >= sunrise && now <= sunset
        }

        /// Minutes until next sunrise (positive) or since last sunrise (negative)
        var minutesUntilSunrise: Double {
            Date().distance(to: sunrise) / 60
        }

        /// Hours until sunset from now
        var hoursUntilSunset: Double {
            Date().distance(to: sunset) / 3600
        }

        /// "Golden hour" window: 60 min before sunset
        var isGoldenHour: Bool {
            let now = Date()
            return now >= sunset.addingTimeInterval(-3600) && now < sunset
        }

        /// Best climbing window label
        var timeOfDayLabel: String {
            let now = Date()
            if now < sunrise { return "Pre-Dawn" }
            if now < sunrise.addingTimeInterval(7200) { return "Morning" }
            if isGoldenHour { return "Golden Hour" }
            if isDaytime { return "Daytime" }
            return "Night"
        }
    }

    /// Calculate solar times for a given lat/lon on today's date (local timezone).
    static func solarTimes(latitude: Double, longitude: Double, date: Date = Date()) -> SolarTimes {
        let tz = TimeZone.current
        let rise = sunriseOrSet(latitude: latitude, longitude: longitude, date: date, rising: true, timezone: tz)
        let set  = sunriseOrSet(latitude: latitude, longitude: longitude, date: date, rising: false, timezone: tz)
        let noon = midpoint(rise, set)
        return SolarTimes(sunrise: rise, sunset: set, solarNoon: noon)
    }

    // MARK: - NOAA Algorithm

    private static func midpoint(_ a: Date, _ b: Date) -> Date {
        Date(timeIntervalSince1970: (a.timeIntervalSince1970 + b.timeIntervalSince1970) / 2)
    }

    private static func sunriseOrSet(
        latitude: Double,
        longitude: Double,
        date: Date,
        rising: Bool,
        timezone: TimeZone
    ) -> Date {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)

        // Julian Day Number
        let jd = julianDay(year: year, month: month, day: day)

        // Time zone offset in hours
        let tzOffset = Double(timezone.secondsFromGMT(for: date)) / 3600.0

        // Solar declination + equation of time
        let n = jd - 2451545.0
        let L = (280.460 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let g = (357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360)
        let gRad = g * .pi / 180
        let lambda = L + 1.915 * sin(gRad) + 0.020 * sin(2 * gRad)
        let lambdaRad = lambda * .pi / 180
        let epsilon = 23.439 - 0.0000004 * n
        let epsilonRad = epsilon * .pi / 180
        let sinDec = sin(epsilonRad) * sin(lambdaRad)
        let dec = atan(sinDec / sqrt(-sinDec * sinDec + 1))

        // Equation of time (minutes)
        let RA = atan2(cos(epsilonRad) * sin(lambdaRad), cos(lambdaRad))
        let eot = (L * .pi / 180 - RA) * 229.18

        // Hour angle
        let lat = latitude * .pi / 180
        let cosH = (cos(90.833 * .pi / 180) - sin(lat) * sin(dec)) / (cos(lat) * cos(dec))
        let cosHClamped = min(1.0, max(-1.0, cosH)) // avoid NaN at extreme latitudes
        let H = acos(cosHClamped) * 180 / .pi

        // UTC time in decimal hours
        let utcHours: Double
        if rising {
            utcHours = 720 - 4 * (longitude + H) - eot
        } else {
            utcHours = 720 - 4 * (longitude - H) - eot
        }

        // Convert to local time
        let localHours = utcHours / 60 + tzOffset
        let startOfDay = cal.startOfDay(for: date)
        return startOfDay.addingTimeInterval(localHours * 3600)
    }

    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year, m = month
        if m <= 2 { y -= 1; m += 12 }
        let A = Int(y / 100)
        let B = 2 - A + Int(A / 4)
        return Double(Int(365.25 * Double(y + 4716))) +
               Double(Int(30.6001 * Double(m + 1))) +
               Double(day) + Double(B) - 1524.5
    }
}

// MARK: - Overnight messaging

extension SolarCalculator {

    struct OvernightMessage {
        let headline: String
        let subtext: String
        let icon: String      // SF Symbol name
    }

    /// Returns a contextual overnight message based on tonight's temperature.
    static func overnightMessage(tempF: Double) -> OvernightMessage {
        switch tempF {
        case ..<25:
            return OvernightMessage(
                headline: "Frigid tonight",
                subtext: "Below 25°F — protect your gear and fingers",
                icon: "snowflake"
            )
        case 25..<35:
            return OvernightMessage(
                headline: "Below freezing tonight",
                subtext: "Frost likely — warm sleeping bag essential",
                icon: "thermometer.snowflake"
            )
        case 35..<45:
            return OvernightMessage(
                headline: "Chilly night ahead",
                subtext: "Mid-\(Int(tempF))s — an extra layer goes a long way",
                icon: "moon.stars.fill"
            )
        case 45..<55:
            return OvernightMessage(
                headline: "Cool and crisp tonight",
                subtext: "\(Int(tempF))°F — perfect campfire weather",
                icon: "moon.fill"
            )
        case 55..<65:
            return OvernightMessage(
                headline: "Comfortable night",
                subtext: "\(Int(tempF))°F — light layer or sleeping bag liner",
                icon: "moon.circle.fill"
            )
        case 65..<75:
            return OvernightMessage(
                headline: "Warm evening",
                subtext: "\(Int(tempF))°F — no extra gear needed",
                icon: "moon"
            )
        default:
            return OvernightMessage(
                headline: "Hot and sweaty night",
                subtext: "Above \(Int(tempF))°F — stay hydrated and find shade",
                icon: "flame.fill"
            )
        }
    }
}
