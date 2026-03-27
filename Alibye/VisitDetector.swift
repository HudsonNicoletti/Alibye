import Foundation
import CoreLocation

enum VisitEvent {
    case arrived(VisitRecord)
    case updated(VisitRecord)
    case departed(VisitRecord)
}

final class VisitDetector {
    // MARK: - Detection Thresholds

    // Bigger radius to avoid apartment/indoor jitter creating many places
    private let stayRadius: CLLocationDistance = 90
    private let departureRadius: CLLocationDistance = 140

    // Require a longer dwell before creating a place
    private let minimumDwell: TimeInterval = 3 * 60

    // Must be outside the place for a bit before we consider it departed
    private let minimumAwayTime: TimeInterval = 2 * 60

    private var anchorLocation: CLLocation?
    private var dwellStart: Date?
    private var activeVisit: VisitRecord?

    private var awayStart: Date?
    private var runningLatitude: Double = 0
    private var runningLongitude: Double = 0
    private var runningCount: Int = 0

    // MARK: - Public API

    func process(_ location: CLLocation) -> VisitEvent? {
        if var activeVisit {
            let visitLocation = CLLocation(latitude: activeVisit.latitude, longitude: activeVisit.longitude)
            let distance = location.distance(from: visitLocation)

            if distance > departureRadius {
                if awayStart == nil {
                    awayStart = location.timestamp
                    return .updated(activeVisit)
                }

                if let awayStart,
                   location.timestamp.timeIntervalSince(awayStart) >= minimumAwayTime {
                    activeVisit.departure = location.timestamp
                    self.activeVisit = nil
                    self.awayStart = nil

                    // Start watching for the next place from here
                    anchorLocation = location
                    dwellStart = location.timestamp
                    resetRunningAverage(with: location)

                    return .departed(activeVisit)
                } else {
                    return .updated(activeVisit)
                }
            } else {
                awayStart = nil

                // Smooth the place center while the user is still there.
                updateRunningAverage(with: location)
                activeVisit.latitude = runningLatitude
                activeVisit.longitude = runningLongitude
                activeVisit.departure = location.timestamp
                self.activeVisit = activeVisit
                return .updated(activeVisit)
            }
        }

        if let anchorLocation {
            let distance = location.distance(from: anchorLocation)

            if distance <= stayRadius {
                updateRunningAverage(with: location)

                if let dwellStart,
                   location.timestamp.timeIntervalSince(dwellStart) >= minimumDwell {
                    let visit = VisitRecord(
                        title: "Visited Place",
                        latitude: runningLatitude,
                        longitude: runningLongitude,
                        arrival: dwellStart,
                        departure: location.timestamp
                    )
                    activeVisit = visit
                    awayStart = nil
                    return .arrived(visit)
                }
            } else {
                self.anchorLocation = location
                self.dwellStart = location.timestamp
                resetRunningAverage(with: location)
            }
        } else {
            anchorLocation = location
            dwellStart = location.timestamp
            resetRunningAverage(with: location)
        }

        return nil
    }

    // MARK: - Running Average

    private func resetRunningAverage(with location: CLLocation) {
        runningLatitude = location.coordinate.latitude
        runningLongitude = location.coordinate.longitude
        runningCount = 1
    }

    private func updateRunningAverage(with location: CLLocation) {
        if runningCount == 0 {
            resetRunningAverage(with: location)
            return
        }

        runningCount += 1
        runningLatitude += (location.coordinate.latitude - runningLatitude) / Double(runningCount)
        runningLongitude += (location.coordinate.longitude - runningLongitude) / Double(runningCount)
    }
}
