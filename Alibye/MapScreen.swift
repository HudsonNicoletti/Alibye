import SwiftUI
import MapKit

struct MapScreen: View {
    @EnvironmentObject var historyStore: HistoryStore

    // MARK: - UI State

    @State private var refreshToken = UUID()
    @State private var showHeatmap = false
    @State private var showSavedLocations = false
    @State private var selectedVisit: VisitRecord?

    // MARK: - Derived Data

    private var samples: [LocationSample] {
        historyStore.samples(for: historyStore.selectedDate)
    }

    private var visits: [VisitRecord] {
        historyStore.visits(for: historyStore.selectedDate)
    }

    // MARK: - UI

    var body: some View {
        ZStack {
            RouteMapView(
                coordinates: samples.map(\.coordinate),
                visits: visits,
                refreshToken: refreshToken,
                followUser: true,
                movingCoordinate: nil,
                heatmapCoordinates: showHeatmap ? visits.map(\.coordinate) : [],
                onVisitTapped: { selectedVisit = $0 }
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()

                    VStack(spacing: 10) {
                        Button {
                            showHeatmap.toggle()
                            refreshToken = UUID()
                        } label: {
                            Image(systemName: showHeatmap ? "flame.fill" : "flame")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(showHeatmap ? .orange : .primary)
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                        }

                        Button {
                            showSavedLocations = true
                        } label: {
                            Image(systemName: "house.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }

                Spacer()

                bottomOverlay
            }
            .padding(.bottom, 12)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSavedLocations) {
            SettingsScreen()
        }
        .sheet(item: $selectedVisit) { visit in
            VisitDetailSheet(visit: visit)
        }
    }

    // MARK: - Helpers

    private var bottomOverlay: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Summary")
                        .font(.headline)

                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                summaryPill(title: "Visits", value: "\(visits.count)")
                summaryPill(title: "Route", value: routeDistanceText)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
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

    private var summaryText: String {
        if samples.isEmpty {
            return "No route data yet."
        }
        if let first = samples.first?.timestamp, let last = samples.last?.timestamp {
            return "\(first.formatted(date: .omitted, time: .shortened)) to \(last.formatted(date: .omitted, time: .shortened))"
        }
        return "Tracking active."
    }

    private var routeDistanceText: String {
        guard samples.count > 1 else { return "0 km" }
        var total: CLLocationDistance = 0
        let coords = samples.map(\.coordinate)

        // Sum segment distances along the sampled path.
        for index in 1..<coords.count {
            let a = CLLocation(latitude: coords[index - 1].latitude, longitude: coords[index - 1].longitude)
            let b = CLLocation(latitude: coords[index].latitude, longitude: coords[index].longitude)
            total += b.distance(from: a)
        }

        return total >= 1000 ? String(format: "%.1f km", total / 1000) : String(format: "%.0f m", total)
    }
}
