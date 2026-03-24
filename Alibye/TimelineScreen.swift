import SwiftUI

struct TimelineScreen: View {
    @EnvironmentObject var historyStore: HistoryStore

    var body: some View {
        NavigationView {
            List {
                ForEach(historyStore.logs.keys.sorted(), id: \.self) { key in
                    Text(key)
                }
            }
            .navigationTitle("Timeline")
        }
    }
}
