import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private let visitDetector = VisitDetector()
    private weak var store: HistoryStore?
    private var lastAcceptedLocation: CLLocation?

    @Published var route: [CLLocationCoordinate2D] = []
    @Published var activeVisit: VisitRecord?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }

    func bootstrap(store: HistoryStore) async {
        self.store = store
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
        reloadRoute(for: store.selectedDate)
    }

    func reloadRoute(for date: Date) {
        route = store?.samples(for: date).map(\.coordinate) ?? []
    }

    private func shouldAccept(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy <= 100 else { return false }
        guard abs(location.timestamp.timeIntervalSinceNow) < 30 else { return false }

        if let lastAcceptedLocation {
            let distance = location.distance(from: lastAcceptedLocation)
            let seconds = location.timestamp.timeIntervalSince(lastAcceptedLocation.timestamp)
            if distance < 5 && seconds < 10 {
                return false
            }
        }

        return true
    }

    private func handle(_ location: CLLocation) {
        lastAcceptedLocation = location

        let sample = LocationSample(location: location)
        store?.append(sample: sample)

        if let store, store.dayKey(for: sample.timestamp) == store.dayKey(for: store.selectedDate) {
            route.append(sample.coordinate)
        }

        if let event = visitDetector.process(location) {
            switch event {
            case .arrived(let visit):
                activeVisit = visit
                store?.upsertVisit(visit, on: visit.arrival)
                Task { await refreshPlaceName(for: visit) }

            case .updated(let visit):
                activeVisit = visit
                store?.upsertVisit(visit, on: visit.arrival)
                if visit.title == "Visited Place" {
                    Task { await refreshPlaceName(for: visit) }
                }

            case .departed(let visit):
                activeVisit = nil
                store?.upsertVisit(visit, on: visit.arrival)
                if visit.title == "Visited Place" {
                    Task { await refreshPlaceName(for: visit) }
                }
            }
        }
    }

    private func refreshPlaceName(for visit: VisitRecord) async {
        let name = await PlaceResolver.shared.name(for: visit.coordinate)
        var updated = visit
        updated.title = name
        store?.upsertVisit(updated, on: updated.arrival)
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations where self.shouldAccept(location) {
                self.handle(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
