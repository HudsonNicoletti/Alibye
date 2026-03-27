import Foundation
import Combine
import CoreLocation

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    // MARK: - Published State

    @Published var logs: [String: DayLog] = [:]
    @Published var selectedDate: Date = .now

    // MARK: - Persistence

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

    private enum Constants {
        static let storageFileName = "alibye_logs.json"
        static let mergeRadius: CLLocationDistance = 120
        static let mergeGap: TimeInterval = 20 * 60
    }

    private init() {}

    // MARK: - Write API

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

    func renameVisits(near coordinate: CLLocationCoordinate2D, radius: CLLocationDistance = 120, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let keys = Array(logs.keys)

        for key in keys {
            guard var log = logs[key] else { continue }
            var changed = false

            for index in log.visits.indices {
                let visitLocation = CLLocation(latitude: log.visits[index].latitude, longitude: log.visits[index].longitude)
                if target.distance(from: visitLocation) <= radius {
                    log.visits[index].title = trimmed
                    changed = true
                }
            }

            if changed {
                logs[key] = log
            }
        }

        save()
    }

    // MARK: - Read API

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

    // MARK: - Private Helpers

    private func storageURL() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return docs.appendingPathComponent(Constants.storageFileName)
    }

    private func mergeCandidateIndex(for newVisit: VisitRecord, in visits: [VisitRecord]) -> Int? {
        // Merge fragmented visits when they are spatially close and nearly contiguous in time.
        return visits.firstIndex { existing in
            let a = CLLocation(latitude: existing.latitude, longitude: existing.longitude)
            let b = CLLocation(latitude: newVisit.latitude, longitude: newVisit.longitude)
            let distance = a.distance(from: b)

            let existingEnd = existing.departure ?? existing.arrival
            let newEnd = newVisit.departure ?? newVisit.arrival

            let gap1 = abs(newVisit.arrival.timeIntervalSince(existingEnd))
            let gap2 = abs(existing.arrival.timeIntervalSince(newEnd))
            let smallestGap = min(gap1, gap2)

            return distance <= Constants.mergeRadius && smallestGap <= Constants.mergeGap
        }
    }

    private func mergedVisit(_ existing: VisitRecord, with newVisit: VisitRecord) -> VisitRecord {
        var merged = existing

        let existingEnd = existing.departure ?? existing.arrival
        let newEnd = newVisit.departure ?? newVisit.arrival

        // Keep one canonical visit span that covers both intervals.
        merged.arrival = min(existing.arrival, newVisit.arrival)
        merged.departure = max(existingEnd, newEnd)

        // Average centers to smooth noisy clusters around one place.
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

    // MARK: - Static

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
