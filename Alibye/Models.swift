import Foundation
import CoreLocation

struct LocationSample: Codable, Identifiable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let timestamp: Date

    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct VisitRecord: Codable, Identifiable {
    let id = UUID()
    var title: String
    var latitude: Double
    var longitude: Double
    var arrival: Date
    var departure: Date?
}

struct DayLog: Codable {
    let dateKey: String
    var samples: [LocationSample]
    var visits: [VisitRecord]
}
