import Foundation
import Combine

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published var logs: [String: DayLog] = [:]

    private init() {}

    func append(sample: LocationSample) {
        let key = dayKey(for: sample.timestamp)
        var log = logs[key] ?? DayLog(dateKey: key, samples: [], visits: [])
        log.samples.append(sample)
        logs[key] = log
    }

    func append(visit: VisitRecord, on date: Date) {
        let key = dayKey(for: date)
        var log = logs[key] ?? DayLog(dateKey: key, samples: [], visits: [])
        log.visits.append(visit)
        logs[key] = log
    }

    func samples(for date: Date) -> [LocationSample] {
        logs[dayKey(for: date)]?.samples ?? []
    }

    func visits(for date: Date) -> [VisitRecord] {
        logs[dayKey(for: date)]?.visits ?? []
    }

    func load() {
        // Intentionally left simple for now.
    }

    func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
