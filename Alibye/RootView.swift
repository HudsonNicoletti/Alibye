import SwiftUI
import CoreLocation

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var locationService: LocationService

    var body: some View {
        Group {
            if !appState.hasCompletedSetup || locationService.authorizationStatus != .authorizedAlways {
                SetupView()
            } else {
                MainTabView()
            }
        }
    }
}

#Preview {
    SetupView()
}
