import SwiftUI
import CoreLocation

struct ReplayScreen: View {
    @EnvironmentObject var historyStore: HistoryStore

    @State private var sliderValue: Double = 0
    @State private var isPlaying = false

    private var samples: [LocationSample] {
        historyStore.samples(for: historyStore.selectedDate)
    }

    private var displayedCoordinates: [CLLocationCoordinate2D] {
        guard !samples.isEmpty else { return [] }
        let count = min(max(Int(sliderValue), 0), samples.count)
        return Array(samples.prefix(count)).map(\.coordinate)
    }

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
                    visitCoordinates: historyStore.visits(for: historyStore.selectedDate).map(\.coordinate),
                    refreshToken: UUID()
                )

                VStack {
                    Slider(
                        value: $sliderValue,
                        in: 0...Double(max(samples.count, 1)),
                        step: 1
                    )

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
            }
        }
    }

    private func startReplay() {
        guard !samples.isEmpty else { return }
        isPlaying = true
        sliderValue = 0

        Task {
            for index in 1...samples.count {
                if !isPlaying { break }
                try? await Task.sleep(for: .milliseconds(250))
                await MainActor.run {
                    sliderValue = Double(index)
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
