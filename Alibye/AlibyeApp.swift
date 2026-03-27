import SwiftUI

@main
struct AlibyeApp: App {
    // Shared app-wide state and services.
    @StateObject private var appState = AppState()
    @StateObject private var historyStore = HistoryStore.shared
    @StateObject private var locationService = LocationService.shared
    @StateObject private var smartPlaceStore = SmartPlaceStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(historyStore)
                .environmentObject(locationService)
                .environmentObject(smartPlaceStore)
                .task {
                    // Keep launch hydration in one place so startup order is easy to scan.
                    appState.restoreSettings()
                    historyStore.load()
                    smartPlaceStore.load()
                    await locationService.bootstrap(store: historyStore)
                    await ICloudSyncManager.shared.start(historyStore: historyStore, smartPlaceStore: smartPlaceStore)
                }
        }
    }
}
