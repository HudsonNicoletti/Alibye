import Foundation
import CoreLocation

enum VisitEvent {
    case arrived(VisitRecord)
    case updated(VisitRecord)
    case departed(VisitRecord)
}

final class VisitDetector {
    private let dwellRadius: CLLocationDistance = 60
    private let departureRadius: CLLocationDistance = 100
    private let minimumDwell: TimeInterval = 4 * 60

    private var anchorLocation: CLLocation?
    private var dwellStart: Date?
    private var activeVisit: VisitRecord?

    func process(_ location: CLLocation) -> VisitEvent? {
        if var activeVisit {
            let visitLocation = CLLocation(latitude: activeVisit.latitude, longitude: activeVisit.longitude)
            let distance = location.distance(from: visitLocation)

            if distance > departureRadius {
                activeVisit.departure = location.timestamp
                self.activeVisit = nil
                anchorLocation = location
                dwellStart = location.timestamp
                return .departed(activeVisit)
            } else {
                activeVisit.departure = location.timestamp
                self.activeVisit = activeVisit
                return .updated(activeVisit)
            }
        }

        if let anchorLocation {
            let distance = location.distance(from: anchorLocation)

            if distance <= dwellRadius {
                if let dwellStart, location.timestamp.timeIntervalSince(dwellStart) >= minimumDwell {
                    let visit = VisitRecord(
                        title: "Visited Place",
                        latitude: anchorLocation.coordinate.latitude,
                        longitude: anchorLocation.coordinate.longitude,
                        arrival: dwellStart,
                        departure: location.timestamp
                    )
                    activeVisit = visit
                    return .arrived(visit)
                }
            } else {
                self.anchorLocation = location
                self.dwellStart = location.timestamp
            }
        } else {
            anchorLocation = location
            dwellStart = location.timestamp
        }

        return nil
    }
}
