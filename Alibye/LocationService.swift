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
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }

    func bootstrap(store: HistoryStore) async {
        self.store = store
        authorizationStatus = manager.authorizationStatus
        reloadRoute(for: store.selectedDate)
        _ = SmartPlaceStore.shared

        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func requestPermissions() {
        manager.requestAlwaysAuthorization()
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
                let labeled = labeledVisit(from: visit)
                activeVisit = labeled
                store?.upsertVisit(labeled, on: labeled.arrival)
                SmartPlaceStore.shared.recordVisit(at: labeled.coordinate, arrival: labeled.arrival, departure: labeled.departure)

            case .updated(let visit):
                let labeled = labeledVisit(from: visit)
                activeVisit = labeled
                store?.upsertVisit(labeled, on: labeled.arrival)

            case .departed(let visit):
                let labeled = labeledVisit(from: visit)
                activeVisit = nil
                store?.upsertVisit(labeled, on: labeled.arrival)
                SmartPlaceStore.shared.recordVisit(at: labeled.coordinate, arrival: labeled.arrival, departure: labeled.departure)
            }
        }
    }

    private func labeledVisit(from visit: VisitRecord) -> VisitRecord {
        var updated = visit
        if let smartName = SmartPlaceStore.shared.label(for: visit.coordinate) {
            updated.title = smartName
        }
        return updated
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
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
