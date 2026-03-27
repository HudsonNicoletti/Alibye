import SwiftUI

struct PlaceManagementView: View {
    @StateObject private var smartPlaceStore = SmartPlaceStore.shared
    @State private var editingPlaceID: UUID?
    @State private var draftName = ""

    // MARK: - UI

    var body: some View {
        List {
            if smartPlaceStore.places.isEmpty {
                ContentUnavailableView(
                    "No smart places yet",
                    systemImage: "mappin.slash",
                    description: Text("Use the app for a while and your frequent places will appear here.")
                )
            } else {
                ForEach(smartPlaceStore.places) { place in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(place.name, systemImage: iconName(for: place.category))
                                .font(.headline)
                            Spacer()
                            Text(place.category.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("Visits: \(place.visitCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if editingPlaceID == place.id {
                            HStack {
                                TextField("Rename place", text: $draftName)
                                    .textFieldStyle(.roundedBorder)

                                Button("Save") {
                                    smartPlaceStore.renamePlace(id: place.id, newName: draftName)
                                    editingPlaceID = nil
                                    draftName = ""
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            Button("Rename") {
                                editingPlaceID = place.id
                                draftName = place.name
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Smart Places")
    }

    // MARK: - Helpers

    private func iconName(for category: SmartPlaceCategory) -> String {
        switch category {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .custom: return "pencil.circle.fill"
        case .other: return "mappin.and.ellipse"
        }
    }
}
