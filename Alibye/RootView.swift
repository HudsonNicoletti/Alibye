import SwiftUI
import CoreLocation

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var locationService: LocationService

    private var requiresSetup: Bool {
        !appState.hasCompletedSetup || locationService.authorizationStatus != .authorizedAlways
    }

    var body: some View {
        Group {
            if requiresSetup {
                SetupView()
            } else {
                MainTabView()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(LocationService.shared)
}
