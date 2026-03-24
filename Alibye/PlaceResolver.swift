import Foundation
import CoreLocation

@MainActor
final class PlaceResolver {
    static let shared = PlaceResolver()

    private let geocoder = CLGeocoder()
    private var cache: [String: String] = [:]

    private init() {}

    func name(for coordinate: CLLocationCoordinate2D) async -> String {
        let key = cacheKey(for: coordinate)

        if let cached = cache[key] {
            return cached
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let name = formattedName(from: placemark)
                cache[key] = name
                return name
            }
        } catch {
            return "Visited Place"
        }

        return "Visited Place"
    }

    private func formattedName(from placemark: CLPlacemark) -> String {
        if let name = placemark.name, !name.isEmpty {
            return name
        }
        if let locality = placemark.locality, let administrativeArea = placemark.administrativeArea {
            return "\(locality), \(administrativeArea)"
        }
        if let locality = placemark.locality {
            return locality
        }
        if let country = placemark.country {
            return country
        }
        return "Visited Place"
    }

    private func cacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        let lat = (coordinate.latitude * 1000).rounded() / 1000
        let lon = (coordinate.longitude * 1000).rounded() / 1000
        return "\(lat),\(lon)"
    }
}
