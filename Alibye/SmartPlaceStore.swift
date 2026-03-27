import Foundation
import CoreLocation
import Combine

@MainActor
final class SmartPlaceStore: ObservableObject {
    static let shared = SmartPlaceStore()

    // MARK: - Published State

    @Published var places: [SmartPlace] = []

    // MARK: - Persistence

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private enum Constants {
        static let storageFileName = "alibye_smart_places.json"
        static let labelRadius: CLLocationDistance = 100
        static let recordVisitRadius: CLLocationDistance = 80
        static let renameRadius: CLLocationDistance = 120
        static let frequentVisitThreshold = 3
        static let genericVisitedName = "Visited Place"
        static let genericOtherName = "Other Frequent Place"
    }

    private init() {
        load()
    }

    // MARK: - Persistence API

    func load() {
        do {
            let url = try storageURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            places = try decoder.decode([SmartPlace].self, from: data)
        } catch {
            print("Smart place load error: \(error.localizedDescription)")
        }
    }

    func save() {
        do {
            let url = try storageURL()
            let data = try encoder.encode(places)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Smart place save error: \(error.localizedDescription)")
        }
    }

    // MARK: - Lookup API

    func label(for coordinate: CLLocationCoordinate2D) -> String? {
        nearestPlace(to: coordinate)?.name
    }

    func nearestPlace(to coordinate: CLLocationCoordinate2D, within radius: CLLocationDistance = Constants.labelRadius) -> SmartPlace? {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return places
            .compactMap { place -> (SmartPlace, CLLocationDistance)? in
                let loc = CLLocation(latitude: place.latitude, longitude: place.longitude)
                let d = target.distance(from: loc)
                return d <= radius ? (place, d) : nil
            }
            .sorted { $0.1 < $1.1 }
            .first?.0
    }

    // MARK: - Mutation API

    func recordVisit(at coordinate: CLLocationCoordinate2D, arrival: Date, departure: Date?) {
        if let existing = nearestPlace(to: coordinate, within: Constants.recordVisitRadius),
           let index = places.firstIndex(where: { $0.id == existing.id }) {
            places[index].visitCount += 1
            places[index].lastSeen = departure ?? arrival
            autoCategorize(index: index, arrival: arrival)
            save()
            return
        }

        let inferredName = inferInitialName(for: coordinate, arrival: arrival)
        let place = SmartPlace(
            name: inferredName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            category: .other,
            visitCount: 1,
            lastSeen: departure ?? arrival
        )
        places.append(place)
        if let index = places.indices.last {
            autoCategorize(index: index, arrival: arrival)
        }
        save()
    }

    func renamePlace(id: UUID, newName: String) {
        guard let index = places.firstIndex(where: { $0.id == id }) else { return }
        renamePlace(at: index, newName: newName)
    }

    func renamePlace(near coordinate: CLLocationCoordinate2D, within radius: CLLocationDistance = Constants.renameRadius, newName: String) {
        if let existing = nearestPlace(to: coordinate, within: radius),
           let index = places.firstIndex(where: { $0.id == existing.id }) {
            renamePlace(at: index, newName: newName)
            return
        }

        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let place = SmartPlace(
            name: trimmed,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            category: .custom,
            visitCount: 1,
            lastSeen: .now
        )
        places.append(place)
        save()
    }

    private func renamePlace(at index: Int, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        places[index].name = trimmed
        places[index].category = .custom
        save()
    }

    // MARK: - Classification

    private func autoCategorize(index: Int, arrival: Date) {
        let hour = Calendar.current.component(.hour, from: arrival)
        let weekday = Calendar.current.component(.weekday, from: arrival)
        let isWeekday = (2...6).contains(weekday)

        if places[index].visitCount >= Constants.frequentVisitThreshold {
            if (20...23).contains(hour) || (0...6).contains(hour) {
                places[index].category = .home
                places[index].name = isGenericSuggestedName(places[index].name) ? "Home" : places[index].name
            } else if isWeekday && (8...18).contains(hour) {
                places[index].category = .work
                places[index].name = isGenericSuggestedName(places[index].name) ? "Work" : places[index].name
            } else if places[index].category == .other {
                places[index].name = Constants.genericOtherName
            }
        }
    }

    private func inferInitialName(for coordinate: CLLocationCoordinate2D, arrival: Date) -> String {
        let hour = Calendar.current.component(.hour, from: arrival)
        let weekday = Calendar.current.component(.weekday, from: arrival)
        let isWeekday = (2...6).contains(weekday)

        if (20...23).contains(hour) || (0...6).contains(hour) {
            return "Possible Home"
        }
        if isWeekday && (8...18).contains(hour) {
            return "Possible Work"
        }
        return Constants.genericVisitedName
    }

    private func isGenericSuggestedName(_ name: String) -> Bool {
        name == Constants.genericVisitedName || name == Constants.genericOtherName
    }

    private func storageURL() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return docs.appendingPathComponent(Constants.storageFileName)
    }
}
