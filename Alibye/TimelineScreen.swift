import SwiftUI

struct TimelineScreen: View {
    @EnvironmentObject var historyStore: HistoryStore

    // MARK: - Derived Data

    private var days: [Date] {
        historyStore.groupedDates()
    }

    // MARK: - UI

    var body: some View {
        NavigationView {
            List {
                if days.isEmpty {
                    ContentUnavailableView(
                        "No timeline yet",
                        systemImage: "calendar",
                        description: Text("Use the app for a while and your tracked days will appear here.")
                    )
                } else {
                    ForEach(days, id: \.self) { day in
                        NavigationLink {
                            TimelineReplayDetailView(date: day)
                        } label: {
                            DayTimelineRow(
                                day: day,
                                pointCount: historyStore.samples(for: day).count,
                                visitCount: historyStore.visits(for: day).count
                            )
                        }
                    }
                }
            }
            .navigationTitle("Timeline")
        }
    }
}

private struct DayTimelineRow: View {
    let day: Date
    let pointCount: Int
    let visitCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.formatted(date: .complete, time: .omitted))
                .font(.headline)

            HStack(spacing: 12) {
                Label("\(pointCount) points", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                Label("\(visitCount) visits", systemImage: "mappin.and.ellipse")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
