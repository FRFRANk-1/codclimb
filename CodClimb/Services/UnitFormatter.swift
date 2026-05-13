// CodClimb/Services/UnitFormatter.swift
import Foundation

// MARK: - UnitFormatter
// A single place for all imperial ↔ metric conversions.
// Read `useMetric` from UserDefaults ("codclimb.useMetric") before formatting.

struct UnitFormatter {

    static var useMetric: Bool {
        UserDefaults.standard.bool(forKey: "codclimb.useMetric")
    }

    // MARK: - Temperature

    static func temperature(_ fahrenheit: Double) -> String {
        if useMetric {
            let c = (fahrenheit - 32) * 5 / 9
            return "\(Int(c.rounded()))°C"
        } else {
            return "\(Int(fahrenheit.rounded()))°F"
        }
    }

    static func tempShort(_ fahrenheit: Double) -> String {
        if useMetric {
            let c = (fahrenheit - 32) * 5 / 9
            return "\(Int(c.rounded()))°"
        } else {
            return "\(Int(fahrenheit.rounded()))°"
        }
    }

    // MARK: - Wind

    static func wind(_ mph: Double) -> String {
        if useMetric {
            let kmh = mph * 1.60934
            return "\(Int(kmh.rounded())) km/h"
        } else {
            return "\(Int(mph.rounded())) mph"
        }
    }

    static func windShort(_ mph: Double) -> String {
        if useMetric {
            let kmh = mph * 1.60934
            return "\(Int(kmh.rounded()))"
        } else {
            return "\(Int(mph.rounded()))"
        }
    }

    static var windUnit: String { useMetric ? "km/h" : "mph" }

    // MARK: - Precipitation

    static func precip(_ inches: Double) -> String {
        if useMetric {
            let mm = inches * 25.4
            return String(format: "%.1f mm", mm)
        } else {
            return String(format: "%.2f\"", inches)
        }
    }

    // MARK: - Temperature label only (for StatTile trailing)

    static var tempUnit: String { useMetric ? "C" : "F" }
    static var tempSymbol: String { useMetric ? "°C" : "°F" }
}
