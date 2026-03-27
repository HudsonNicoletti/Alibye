import SwiftUI

struct MainTabView: View {
    // MARK: - UI

    var body: some View {
        TabView {
            MapScreen()
                .tabItem {
                    Label("Live", systemImage: "location.fill")
                }

            TimelineScreen()
                .tabItem {
                    Label("Timeline", systemImage: "list.bullet")
                }
        }
    }
}
