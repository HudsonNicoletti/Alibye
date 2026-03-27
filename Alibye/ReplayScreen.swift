import SwiftUI
import CoreLocation

struct ReplayScreen: View {
    @EnvironmentObject var historyStore: HistoryStore

    // MARK: - UI State

    @State private var sliderValue: Double = 0
    @State private var isPlaying = false
    @State private var refreshToken = UUID()
    @State private var selectedVisit: VisitRecord?

    private enum Constants {
        static let replayTick: Duration = .milliseconds(250)
    }

    // MARK: - Derived Data

    private var samples: [LocationSample] {
        historyStore.samples(for: historyStore.selectedDate)
    }

    private var visits: [VisitRecord] {
        historyStore.visits(for: historyStore.selectedDate)
    }

    private var displayedCoordinates: [CLLocationCoordinate2D] {
        guard !samples.isEmpty else { return [] }
        let count = min(max(Int(sliderValue), 0), samples.count)
        return Array(samples.prefix(count)).map(\.coordinate)
    }

    // MARK: - UI

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                DatePicker(
                    "Day",
                    selection: $historyStore.selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding(.horizontal)

                RouteMapView(
                    coordinates: displayedCoordinates,
                    visits: visits,
                    refreshToken: refreshToken,
                    onVisitTapped: { selectedVisit = $0 }
                )

                VStack {
                    Slider(
                        value: $sliderValue,
                        in: 0...Double(max(samples.count, 1)),
                        step: 1
                    )
                    .onChange(of: sliderValue) { _, _ in
                        refreshToken = UUID()
                    }

                    HStack {
                        Button(isPlaying ? "Stop" : "Play") {
                            isPlaying ? stopReplay() : startReplay()
                        }
                        .buttonStyle(.borderedProminent)

                        Text("\(Int(sliderValue))/\(samples.count)")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Replay")
            .onChange(of: historyStore.selectedDate) { _, _ in
                stopReplay()
                sliderValue = 0
                refreshToken = UUID()
            }
        }
        .sheet(item: $selectedVisit) { visit in
            VisitDetailSheet(visit: visit)
        }
    }

    // MARK: - Replay Controls

    private func startReplay() {
        guard !samples.isEmpty else { return }
        isPlaying = true
        sliderValue = 0
        refreshToken = UUID()

        Task {
            for index in 1...samples.count {
                if !isPlaying { break }
                try? await Task.sleep(for: Constants.replayTick)
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
