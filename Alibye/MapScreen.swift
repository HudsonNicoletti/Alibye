import SwiftUI
import MapKit

struct MapScreen: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var historyStore: HistoryStore

    @State private var refreshToken = UUID()
    @State private var showHeatmap = false

    private var samples: [LocationSample] {
        historyStore.samples(for: historyStore.selectedDate)
    }

    private var visits: [VisitRecord] {
        historyStore.visits(for: historyStore.selectedDate)
    }

    var body: some View {
        ZStack {
            RouteMapView(
                coordinates: samples.map(\.coordinate),
                visitCoordinates: visits.map(\.coordinate),
                refreshToken: refreshToken,
                movingCoordinate: nil,
                heatmapCoordinates: showHeatmap ? samples.map(\.coordinate) : []
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()

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
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }

                Spacer()

                bottomOverlay
            }
            .padding(.bottom, 12)
        }
        .navigationBarHidden(true)
        .onAppear {
            locationService.reloadRoute(for: historyStore.selectedDate)
        }
        .onChange(of: historyStore.selectedDate) { _, newValue in
            locationService.reloadRoute(for: newValue)
            refreshToken = UUID()
        }
    }

    private var bottomOverlay: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Day Summary")
                        .font(.headline)

                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                summaryPill(title: "Points", value: "\(samples.count)")
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
            return "No route data for this day yet."
        }
        if let first = samples.first?.timestamp, let last = samples.last?.timestamp {
            return "\(first.formatted(date: .omitted, time: .shortened)) to \(last.formatted(date: .omitted, time: .shortened))"
        }
        return "Tracking active."
    }

    private var routeDistanceText: String {
        guard samples.count > 1 else { return "0 km" }
        let coords = samples.map(\.coordinate)
        var total: CLLocationDistance = 0

        for index in 1..<coords.count {
            let a = CLLocation(latitude: coords[index - 1].latitude, longitude: coords[index - 1].longitude)
            let b = CLLocation(latitude: coords[index].latitude, longitude: coords[index].longitude)
            total += b.distance(from: a)
        }

        if total >= 1000 {
            return String(format: "%.1f km", total / 1000)
        } else {
            return String(format: "%.0f m", total)
        }
    }
}
