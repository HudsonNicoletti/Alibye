import Foundation
import CoreLocation
import Combine

@MainActor
final class SmartPlaceStore: ObservableObject {
    static let shared = SmartPlaceStore()

    @Published var places: [SmartPlace] = []

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

    private init() {
        load()
    }

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

    func label(for coordinate: CLLocationCoordinate2D) -> String? {
        nearestPlace(to: coordinate)?.name
    }

    func nearestPlace(to coordinate: CLLocationCoordinate2D, within radius: CLLocationDistance = 100) -> SmartPlace? {
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

    func recordVisit(at coordinate: CLLocationCoordinate2D, arrival: Date, departure: Date?) {
        if let existing = nearestPlace(to: coordinate, within: 80),
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
        places[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? places[index].name : newName
        places[index].category = .custom
        save()
    }

    private func autoCategorize(index: Int, arrival: Date) {
        let hour = Calendar.current.component(.hour, from: arrival)
        let weekday = Calendar.current.component(.weekday, from: arrival)
        let isWeekday = (2...6).contains(weekday)

        if places[index].visitCount >= 3 {
            if (20...23).contains(hour) || (0...6).contains(hour) {
                places[index].category = .home
                places[index].name = places[index].name == "Visited Place" || places[index].name == "Other Frequent Place" ? "Home" : places[index].name
            } else if isWeekday && (8...18).contains(hour) {
                places[index].category = .work
                places[index].name = places[index].name == "Visited Place" || places[index].name == "Other Frequent Place" ? "Work" : places[index].name
            } else if places[index].category == .other {
                places[index].name = "Other Frequent Place"
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
        return "Visited Place"
    }

    private func storageURL() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return docs.appendingPathComponent("alibye_smart_places.json")
    }
}
