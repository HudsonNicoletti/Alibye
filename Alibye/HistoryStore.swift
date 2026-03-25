import Foundation
import Combine
import CoreLocation

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published var logs: [String: DayLog] = [:]
    @Published var selectedDate: Date = .now

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {}

    func append(sample: LocationSample) {
        let key = dayKey(for: sample.timestamp)
        var log = logs[key] ?? DayLog(dateKey: key, samples: [], visits: [])
        log.samples.append(sample)
        logs[key] = log
        save()
    }

    func upsertVisit(_ visit: VisitRecord, on day: Date) {
        let key = dayKey(for: day)
        var log = logs[key] ?? DayLog(dateKey: key, samples: [], visits: [])

        if let exactIndex = log.visits.firstIndex(where: { $0.id == visit.id }) {
            log.visits[exactIndex] = visit
        } else if let mergeIndex = mergeCandidateIndex(for: visit, in: log.visits) {
            log.visits[mergeIndex] = mergedVisit(log.visits[mergeIndex], with: visit)
        } else {
            log.visits.append(visit)
        }

        log.visits.sort { $0.arrival < $1.arrival }
        logs[key] = log
        save()
    }

    func samples(for date: Date) -> [LocationSample] {
        logs[dayKey(for: date)]?.samples.sorted { $0.timestamp < $1.timestamp } ?? []
    }

    func visits(for date: Date) -> [VisitRecord] {
        logs[dayKey(for: date)]?.visits.sorted { $0.arrival < $1.arrival } ?? []
    }

    func groupedDates() -> [Date] {
        logs.keys.compactMap { Self.dayFormatter.date(from: $0) }.sorted(by: >)
    }

    func load() {
        do {
            let url = try storageURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            let items = try decoder.decode([DayLog].self, from: data)
            logs = Dictionary(uniqueKeysWithValues: items.map { ($0.dateKey, $0) })
        } catch {
            print("Load error: \(error.localizedDescription)")
        }
    }

    func save() {
        do {
            let url = try storageURL()
            let items = logs.values.sorted { $0.dateKey < $1.dateKey }
            let data = try encoder.encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Save error: \(error.localizedDescription)")
        }
    }

    func dayKey(for date: Date) -> String {
        Self.dayFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    private func storageURL() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return docs.appendingPathComponent("alibye_logs.json")
    }

    private func mergeCandidateIndex(for newVisit: VisitRecord, in visits: [VisitRecord]) -> Int? {
        let mergeRadius: CLLocationDistance = 120
        let mergeGap: TimeInterval = 20 * 60

        return visits.firstIndex { existing in
            let a = CLLocation(latitude: existing.latitude, longitude: existing.longitude)
            let b = CLLocation(latitude: newVisit.latitude, longitude: newVisit.longitude)
            let distance = a.distance(from: b)

            let existingEnd = existing.departure ?? existing.arrival
            let newEnd = newVisit.departure ?? newVisit.arrival

            let gap1 = abs(newVisit.arrival.timeIntervalSince(existingEnd))
            let gap2 = abs(existing.arrival.timeIntervalSince(newEnd))
            let smallestGap = min(gap1, gap2)

            return distance <= mergeRadius && smallestGap <= mergeGap
        }
    }

    private func mergedVisit(_ existing: VisitRecord, with newVisit: VisitRecord) -> VisitRecord {
        var merged = existing

        let existingEnd = existing.departure ?? existing.arrival
        let newEnd = newVisit.departure ?? newVisit.arrival

        merged.arrival = min(existing.arrival, newVisit.arrival)
        merged.departure = max(existingEnd, newEnd)

        // Average coordinates so repeated indoor updates stay centered on one place
        merged.latitude = (existing.latitude + newVisit.latitude) / 2
        merged.longitude = (existing.longitude + newVisit.longitude) / 2

        if isGeneric(existing.title) && !isGeneric(newVisit.title) {
            merged.title = newVisit.title
        }

        return merged
    }

    private func isGeneric(_ title: String) -> Bool {
        let lowered = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowered.isEmpty
            || lowered == "visited place"
            || lowered == "possible home"
            || lowered == "possible work"
            || lowered == "other frequent place"
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
