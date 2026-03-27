import SwiftUI

struct VisitDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var smartPlaceStore: SmartPlaceStore

    let visit: VisitRecord

    @State private var draftName: String = ""

    // MARK: - UI

    var body: some View {
        NavigationView {
            Form {
                Section("Location") {
                    TextField("Location name", text: $draftName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    Button("Save name") {
                        save()
                    }
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Visit") {
                    LabeledContent("Period", value: periodText)
                    LabeledContent("Time there", value: durationText)
                }
            }
            .navigationTitle(visit.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            draftName = visit.title
        }
    }

    // MARK: - Helpers

    private var periodText: String {
        "\(visit.arrival.formatted(date: .omitted, time: .shortened)) to \(visit.effectiveDeparture.formatted(date: .omitted, time: .shortened))"
    }

    private var durationText: String {
        Duration.seconds(visit.durationSeconds).formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }

    private func save() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        historyStore.renameVisits(near: visit.coordinate, newName: trimmed)
        smartPlaceStore.renamePlace(near: visit.coordinate, newName: trimmed)
        dismiss()
    }
}
