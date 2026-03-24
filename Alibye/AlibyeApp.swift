import SwiftUI

@main
struct AlibyeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var historyStore = HistoryStore.shared
    @StateObject private var locationService = LocationService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(historyStore)
                .environmentObject(locationService)
                .task {
                    appState.restoreSettings()
                    historyStore.load()
                    await locationService.bootstrap(store: historyStore)
                }
        }
    }
}
