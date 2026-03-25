import Foundation
import Combine
import SwiftUI

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

        if let index = log.visits.firstIndex(where: { $0.id == visit.id }) {
            log.visits[index] = visit
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

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
