import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            MapScreen().tabItem { Label("Map", systemImage: "map") }
            TimelineScreen().tabItem { Label("Timeline", systemImage: "list.bullet") }
        }
    }
}