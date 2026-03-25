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
        ZStack {
            RouteMapView(
                coordinates: isPlaying || sliderValue > 0 ? displayedCoordinates : fullCoordinates,
                visitCoordinates: allVisits.map(\.coordinate),
                refreshToken: refreshToken,
                followUser: false,
                movingCoordinate: (isPlaying || sliderValue > 0) ? currentMovingCoordinate : nil,
                heatmapCoordinates: []
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                bottomOverlay
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .navigationTitle("Day Replay")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopReplay()
        }
    }

    private var bottomOverlay: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.headline)

                    if let first = allSamples.first?.timestamp,
                       let last = allSamples.last?.timestamp {
                        Text("\(first.formatted(date: .omitted, time: .shortened)) to \(last.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No route data for this day.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !allSamples.isEmpty {
                    replayStateBadge
                }
            }

            HStack(spacing: 10) {
                summaryPill(title: "Points", value: "\(allSamples.count)")
                summaryPill(title: "Visits", value: "\(allVisits.count)")
                summaryPill(title: "Shown", value: shownCountText)
            }

            if !allSamples.isEmpty {
                VStack(spacing: 10) {
                    Slider(
                        value: $sliderValue,
                        in: 0...Double(max(allSamples.count, 1)),
                        step: 0.05
                    )
                    .onChange(of: sliderValue) { _, _ in
                        refreshToken = UUID()
                    }

                    HStack(spacing: 10) {
                        Button {
                            isPlaying ? stopReplay() : startReplay()
                        } label: {
                            Label(isPlaying ? "Stop" : "Play Replay", systemImage: isPlaying ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            stopReplay()
                            sliderValue = 0
                            refreshToken = UUID()
                        } label: {
                            Label("Full Path", systemImage: "arrow.triangle.branch")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Text("There were not enough route samples for this day.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    private var replayStateBadge: some View {
        Text(isPlaying ? "Replaying" : "Ready")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((isPlaying ? Color.blue : Color.secondary).opacity(0.15))
            .foregroundStyle(isPlaying ? .blue : .secondary)
            .clipShape(Capsule())
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var shownCountText: String {
        if isPlaying || sliderValue > 0 {
            return "\(Int(sliderValue.rounded(.down)))"
        } else {
            return "All"
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
