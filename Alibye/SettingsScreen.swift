import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink {
                    PlaceManagementView()
                } label: {
                    Label("Manage Saved Locations", systemImage: "mappin.circle")
                }
            }
            .navigationTitle("Saved Locations")
        }
    }
}
