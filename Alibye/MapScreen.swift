import SwiftUI
import MapKit

struct MapScreen: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var historyStore: HistoryStore

    @State private var refreshToken = UUID()

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
                refreshToken: refreshToken
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topOverlay
                Spacer()
                bottomOverlay
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
            .padding(.horizontal, 16)
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

    private var topOverlay: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alibye")
                        .font(.headline)
                    Text(historyStore.selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    historyStore.selectedDate = .now
                    locationService.reloadRoute(for: .now)
                    refreshToken = UUID()
                } label: {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(MapCircleButtonStyle())

                Button {
                    refreshToken = UUID()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(MapCircleButtonStyle())
            }

            HStack {
                DatePicker(
                    "",
                    selection: $historyStore.selectedDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(.primary)
                Spacer()
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
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

private struct MapCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
