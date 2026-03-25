import SwiftUI
import CoreLocation

struct TimelineReplayDetailView: View {
    @EnvironmentObject var historyStore: HistoryStore

    let date: Date

    @State private var sliderValue: Double = 0
    @State private var isPlaying = false
    @State private var refreshToken = UUID()

    private var allSamples: [LocationSample] {
        historyStore.samples(for: date)
    }

    private var allVisits: [VisitRecord] {
        historyStore.visits(for: date)
    }

    private var displayedCoordinates: [CLLocationCoordinate2D] {
        guard !allSamples.isEmpty else { return [] }
        let count = min(max(Int(sliderValue.rounded(.down)), 0), allSamples.count)
        return Array(allSamples.prefix(count)).map(\.coordinate)
    }

    private var fullCoordinates: [CLLocationCoordinate2D] {
        allSamples.map(\.coordinate)
    }

    private var currentMovingCoordinate: CLLocationCoordinate2D? {
        guard !allSamples.isEmpty else { return nil }
        guard allSamples.count > 1 else { return allSamples.first?.coordinate }

        let clamped = min(max(sliderValue, 1), Double(allSamples.count))
        let lowerIndex = max(0, min(Int(floor(clamped)) - 1, allSamples.count - 1))
        let upperIndex = min(lowerIndex + 1, allSamples.count - 1)

        let start = allSamples[lowerIndex].coordinate
        let end = allSamples[upperIndex].coordinate

        if lowerIndex == upperIndex { return start }

        let t = clamped - floor(clamped)
        return CLLocationCoordinate2D(
            latitude: start.latitude + (end.latitude - start.latitude) * t,
            longitude: start.longitude + (end.longitude - start.longitude) * t
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            RouteMapView(
                coordinates: isPlaying || sliderValue > 0 ? displayedCoordinates : fullCoordinates,
                visitCoordinates: allVisits.map(\.coordinate),
                refreshToken: refreshToken,
                followUser: false,
                movingCoordinate: (isPlaying || sliderValue > 0) ? currentMovingCoordinate : nil,
                heatmapCoordinates: []
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.title3.bold())

                    if let first = allSamples.first?.timestamp,
                       let last = allSamples.last?.timestamp {
                        Text("\(first.formatted(date: .omitted, time: .shortened)) - \(last.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(allSamples.count) route points • \(allVisits.count) visits")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !allSamples.isEmpty {
                    Slider(
                        value: $sliderValue,
                        in: 0...Double(max(allSamples.count, 1)),
                        step: 0.05
                    )
                    .onChange(of: sliderValue) { _, _ in
                        refreshToken = UUID()
                    }

                    HStack {
                        Button(isPlaying ? "Stop Replay" : "Play Replay") {
                            isPlaying ? stopReplay() : startReplay()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Show Full Path") {
                            stopReplay()
                            sliderValue = 0
                            refreshToken = UUID()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Text("\(Int(sliderValue.rounded(.down)))/\(allSamples.count)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView(
                        "No replay points",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                        description: Text("There were not enough route samples for this day.")
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle("Day Replay")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopReplay()
        }
    }

    private func startReplay() {
        guard !allSamples.isEmpty else { return }
        isPlaying = true
        sliderValue = 1
        refreshToken = UUID()

        Task {
            let target = Double(allSamples.count)
            while isPlaying && sliderValue < target {
                try? await Task.sleep(for: .milliseconds(28))
                await MainActor.run {
                    sliderValue = min(sliderValue + 0.12, target)
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
