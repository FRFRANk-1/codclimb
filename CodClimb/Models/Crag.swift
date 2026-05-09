import Foundation
import CoreLocation

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
}
