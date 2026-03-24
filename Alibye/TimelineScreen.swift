import SwiftUI

struct TimelineScreen: View {
    @EnvironmentObject var historyStore: HistoryStore

    private var visits: [VisitRecord] {
        historyStore.visits(for: historyStore.selectedDate)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    DatePicker(
                        "Day",
                        selection: $historyStore.selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .padding(.horizontal)

                    if visits.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                            Text("No visits logged yet")
                                .font(.headline)
                            Text("Walk around for a few minutes, then come back here.")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                    } else {
                        ForEach(visits) { visit in
                            NavigationLink {
                                TimelineReplayDetailView(
                                    selectedVisit: visit,
                                    date: historyStore.selectedDate
                                )
                            } label: {
                                VisitCardView(visit: visit)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(AppFormatters.dayLabel.string(from: historyStore.selectedDate))
        }
    }
}

struct VisitCardView: View {
    let visit: VisitRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(iconColor)
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(iconColor.opacity(0.25))
                    .frame(width: 2)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(visit.title, systemImage: iconName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.blue)
                }

                if let subtitle = visit.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Label(AppFormatters.timeLabel.string(from: visit.arrival), systemImage: "arrow.down.circle")
                    Label(visit.departure.map { AppFormatters.timeLabel.string(from: $0) } ?? "Still here", systemImage: "arrow.up.circle")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text("Stay: \(AppFormatters.duration(visit.durationSeconds))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private var iconName: String {
        switch visit.title.lowercased() {
        case "home": return "house.fill"
        case "work": return "briefcase.fill"
        default: return "mappin.and.ellipse"
        }
    }

    private var iconColor: Color {
        switch visit.title.lowercased() {
        case "home": return .green
        case "work": return .orange
        default: return .blue
        }
    }
}
