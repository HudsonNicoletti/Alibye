import SwiftUI

struct MainTabView: View {
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

            SettingsScreen()
                .tabItem {
                    Label("Saved", systemImage: "house.fill")
                }
        }
    }
}
