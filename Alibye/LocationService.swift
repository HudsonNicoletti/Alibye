import Foundation
import CoreLocation
import Combine
import UIKit

@MainActor
final class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    // MARK: - Core Dependencies

    private let manager = CLLocationManager()
    private let visitDetector = VisitDetector()
    private weak var store: HistoryStore?
    private var lastAcceptedLocation: CLLocation?
    private var dayChangeObserver: NSObjectProtocol?
    private var significantTimeObserver: NSObjectProtocol?

    private enum Constants {
        static let desiredAccuracy = kCLLocationAccuracyBest
        static let distanceFilter: CLLocationDistance = 10
        static let maxAcceptedAccuracy: CLLocationAccuracy = 100
        static let maxTimestampSkew: TimeInterval = 30
        static let minDistanceDelta: CLLocationDistance = 5
        static let minTimeDelta: TimeInterval = 10
    }

    // MARK: - Published State

    @Published var route: [CLLocationCoordinate2D] = []
    @Published var activeVisit: VisitRecord?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = Constants.desiredAccuracy
        manager.distanceFilter = Constants.distanceFilter
        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Public API

    func bootstrap(store: HistoryStore) async {
        self.store = store
        authorizationStatus = manager.authorizationStatus
        reloadRoute(for: store.selectedDate)
        _ = SmartPlaceStore.shared
        installDayChangeObservers()

        if isTrackingAuthorized(authorizationStatus) {
            manager.startUpdatingLocation()
        }
    }

    func requestPermissions() {
        manager.requestAlwaysAuthorization()
    }

    func reloadRoute(for date: Date) {
        route = store?.samples(for: date).map(\.coordinate) ?? []
    }

    // MARK: - Date Boundary Handling

    private func installDayChangeObservers() {
        if dayChangeObserver == nil {
            dayChangeObserver = NotificationCenter.default.addObserver(
                forName: .NSCalendarDayChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleDayBoundary()
                }
            }
        }

        if significantTimeObserver == nil {
            significantTimeObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.significantTimeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleDayBoundary()
                }
            }
        }
    }

    private func handleDayBoundary() {
        guard let store else { return }
        let newDate = Date()
        store.selectedDate = newDate
        reloadRoute(for: newDate)
    }

    private func rolloverIfNeeded(using timestamp: Date) {
        guard let store else { return }
        let currentKey = store.dayKey(for: timestamp)
        let selectedKey = store.dayKey(for: store.selectedDate)
        if currentKey != selectedKey {
            store.selectedDate = timestamp
            reloadRoute(for: timestamp)
        }
    }

    // MARK: - Filtering and Processing

    private func shouldAccept(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy <= Constants.maxAcceptedAccuracy else { return false }
        guard abs(location.timestamp.timeIntervalSinceNow) < Constants.maxTimestampSkew else { return false }

        if let lastAcceptedLocation {
            let distance = location.distance(from: lastAcceptedLocation)
            let seconds = location.timestamp.timeIntervalSince(lastAcceptedLocation.timestamp)
            if distance < Constants.minDistanceDelta && seconds < Constants.minTimeDelta {
                return false
            }
        }

        return true
    }

    private func handle(_ location: CLLocation) {
        lastAcceptedLocation = location
        rolloverIfNeeded(using: location.timestamp)

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

    private func isTrackingAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedAlways || status == .authorizedWhenInUse
    }
}

extension LocationService: CLLocationManagerDelegate {
    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            let status = manager.authorizationStatus
            if isTrackingAuthorized(status) {
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
