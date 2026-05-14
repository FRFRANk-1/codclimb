import Foundation
import CoreLocation

// MARK: - Climbing style enum

enum CragStyle: String, CaseIterable, Identifiable, Codable, Hashable {
    case sport   = "Sport"
    case trad    = "Trad"
    case boulder = "Boulder"
    case mixed   = "Mixed"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sport:   return "bolt.circle"
        case .trad:    return "hexagon"
        case .boulder: return "square.stack.3d.up"
        case .mixed:   return "shuffle"
        }
    }
}

// MARK: - Sun exposure enum

enum SunExposure: String, CaseIterable, Identifiable, Codable, Hashable {
    case fullSun    = "Full Sun"
    case partialSun = "Partial"
    case shade      = "Shade"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fullSun:    return "sun.max"
        case .partialSun: return "cloud.sun"
        case .shade:      return "cloud"
        }
    }
}

// MARK: - Crag model

struct Crag: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let latitude: Double
    let longitude: Double
    let elevationFt: Int
    let rockType: String
    let aspect: String
    let subAreas: [String]
    let notes: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // MARK: - Inferred style from notes keywords
    var inferredStyle: CragStyle {
        let lower = notes.lowercased()
        if lower.contains("boulder") || lower.contains("bouldering") { return .boulder }
        if lower.contains("trad") || lower.contains("traditional")   { return .trad }
        if lower.contains("sport")                                    { return .sport }
        return .mixed
    }

    // MARK: - Sun exposure inferred from aspect
    var sunExposure: SunExposure {
        let a = aspect.lowercased()
        if a.contains("south") { return .fullSun }
        if a.contains("north") { return .shade }
        return .partialSun   // East, West, Southeast partial, etc.
    }
}
