import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if !appState.hasCompletedSetup {
                SetupView()
            } else {
                MainTabView()
            }
        }
    }
}
