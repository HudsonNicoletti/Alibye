import SwiftUI

struct TimelineScreen: View {
    @EnvironmentObject var historyStore: HistoryStore

    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Day",
                    selection: $historyStore.selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding(.horizontal)

                List {
                    let visits = historyStore.visits(for: historyStore.selectedDate)

                    if visits.isEmpty {
                        Text("No visits logged yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(visits) { visit in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(visit.title)
                                    .font(.headline)

                                Text("Arrived: \(visit.arrival.formatted(date: .omitted, time: .shortened))")

                                if let departure = visit.departure {
                                    Text("Left: \(departure.formatted(date: .omitted, time: .shortened))")
                                    Text("Stay: \(formattedDuration(visit.durationSeconds))")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Left: Still here")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Timeline")
        }
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0m"
    }
}
