import Foundation
import CoreLocation

struct LocationSample: Codable, Identifiable, Hashable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let timestamp: Date

    init(location: CLLocation) {
        self.id = UUID()
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.horizontalAccuracy = location.horizontalAccuracy
        self.timestamp = location.timestamp
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct VisitRecord: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var subtitle: String?
    var latitude: Double
    var longitude: Double
    var arrival: Date
    var departure: Date?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        latitude: Double,
        longitude: Double,
        arrival: Date,
        departure: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
        self.arrival = arrival
        self.departure = departure
    }

    var durationSeconds: TimeInterval {
        (departure ?? arrival).timeIntervalSince(arrival)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct DayLog: Codable, Hashable {
    let dateKey: String
    var samples: [LocationSample]
    var visits: [VisitRecord]
}
