import SwiftUI
import CoreLocation

struct TimelineReplayDetailView: View {
    @EnvironmentObject var historyStore: HistoryStore

    let selectedVisit: VisitRecord
    let date: Date

    @State private var sliderValue: Double = 0
    @State private var isPlaying = false
    @State private var refreshToken = UUID()

    private var allSamples: [LocationSample] {
        historyStore.samples(for: date)
    }

    private var replaySamples: [LocationSample] {
        let start = selectedVisit.arrival.addingTimeInterval(-300)
        let end = (selectedVisit.departure ?? selectedVisit.arrival).addingTimeInterval(300)
        return allSamples.filter { $0.timestamp >= start && $0.timestamp <= end }
    }

    private var displayedCoordinates: [CLLocationCoordinate2D] {
        guard !replaySamples.isEmpty else { return [] }
        let count = min(max(Int(sliderValue), 0), replaySamples.count)
        return Array(replaySamples.prefix(count)).map(\.coordinate)
    }

    private var currentMovingCoordinate: CLLocationCoordinate2D? {
        guard !replaySamples.isEmpty else { return nil }
        let count = min(max(Int(sliderValue), 1), replaySamples.count)
        return replaySamples[count - 1].coordinate
    }

    var body: some View {
        VStack(spacing: 0) {
            RouteMapView(
                coordinates: displayedCoordinates,
                visitCoordinates: [selectedVisit.coordinate],
                refreshToken: refreshToken,
                movingCoordinate: currentMovingCoordinate
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedVisit.title)
                        .font(.title3.bold())

                    HStack(spacing: 12) {
                        Label(AppFormatters.timeLabel.string(from: selectedVisit.arrival), systemImage: "arrow.down.circle")
                        Label(selectedVisit.departure.map { AppFormatters.timeLabel.string(from: $0) } ?? "Still here", systemImage: "arrow.up.circle")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text("Stay: \(AppFormatters.duration(selectedVisit.durationSeconds))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    Slider(
                        value: $sliderValue,
                        in: 0...Double(max(replaySamples.count, 1)),
                        step: 1
                    )
                    .onChange(of: sliderValue) { _, _ in
                        refreshToken = UUID()
                    }

                    HStack {
                        Button(isPlaying ? "Stop Replay" : "Play Replay") {
                            isPlaying ? stopReplay() : startReplay()
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Text("\(Int(sliderValue))/\(replaySamples.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                if replaySamples.isEmpty {
                    ContentUnavailableView(
                        "No replay points",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                        description: Text("There were not enough route samples around this visit to build a replay.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Replay window")
                            .font(.headline)

                        Text("\(replaySamples.first?.timestamp.formatted(date: .omitted, time: .shortened) ?? "-") to \(replaySamples.last?.timestamp.formatted(date: .omitted, time: .shortened) ?? "-")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle("Visit Replay")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopReplay()
        }
    }

    private func startReplay() {
        guard !replaySamples.isEmpty else { return }
        isPlaying = true
        sliderValue = 0
        refreshToken = UUID()

        Task {
            for index in 1...replaySamples.count {
                if !isPlaying { break }
                try? await Task.sleep(for: .milliseconds(220))
                await MainActor.run {
                    sliderValue = Double(index)
                    refreshToken = UUID()
                }
            }
            await MainActor.run {
                isPlaying = false
            }
        }
    }

    private func stopReplay() {
        isPlaying = false
    }
}
