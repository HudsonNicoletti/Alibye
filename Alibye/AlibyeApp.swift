import SwiftUI

@main
struct AlibyeApp: App {
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
                    appState.restoreSettings()
                    historyStore.load()
                    smartPlaceStore.load()
                    await locationService.bootstrap(store: historyStore)
                    await ICloudSyncManager.shared.start(historyStore: historyStore, smartPlaceStore: smartPlaceStore)
                }
        }
    }
}
