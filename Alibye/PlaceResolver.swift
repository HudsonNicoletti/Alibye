import Foundation
import CoreLocation

@MainActor
final class PlaceResolver {
    static let shared = PlaceResolver()

    // MARK: - Internal State

    private let geocoder = CLGeocoder()
    private var cache: [String: String] = [:]

    private init() {}

    // MARK: - Public API

    func name(for coordinate: CLLocationCoordinate2D) async -> String {
        let key = cacheKey(for: coordinate)

        if let cached = cache[key] {
            return cached
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let name = try await reverseGeocodeName(for: location)
            cache[key] = name
            return name
        } catch {
            print("Reverse geocoding error: \(error.localizedDescription)")
            return "Visited Place"
        }
    }

    // MARK: - Private Helpers

    private func reverseGeocodeName(for location: CLLocation) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let placemark = placemarks?.first else {
                    continuation.resume(returning: "Visited Place")
                    return
                }

                let resolved =
                    placemark.name ??
                    placemark.locality ??
                    placemark.thoroughfare ??
                    placemark.administrativeArea ??
                    placemark.country ??
                    "Visited Place"

                continuation.resume(returning: resolved)
            }
        }
    }

    private func cacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        // Quantize to ~100m buckets to reduce duplicate reverse geocoding.
        let lat = (coordinate.latitude * 1000).rounded() / 1000
        let lon = (coordinate.longitude * 1000).rounded() / 1000
        return "\(lat),\(lon)"
    }
}
