import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        NavigationView {
            PlaceManagementView()
                .navigationTitle("Saved Locations")
        }
    }
}
