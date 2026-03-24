import SwiftUI

struct MapScreen: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var historyStore: HistoryStore

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                DatePicker(
                    "Day",
                    selection: $historyStore.selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding(.horizontal)

                RouteMapView(
                    coordinates: historyStore.samples(for: historyStore.selectedDate).map(\.coordinate),
                    visitCoordinates: historyStore.visits(for: historyStore.selectedDate).map(\.coordinate)
                )
            }
            .navigationTitle("Map")
            .onAppear {
                locationService.reloadRoute(for: historyStore.selectedDate)
            }
            .onChange(of: historyStore.selectedDate) { _, newValue in
                locationService.reloadRoute(for: newValue)
            }
        }
    }
}
