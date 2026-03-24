import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var biometricEnabled: Bool = false
    @Published var requiresUnlock: Bool = false

    func restoreSettings() {
        biometricEnabled = UserDefaults.standard.bool(forKey: "biometricEnabled")
        requiresUnlock = false
    }
}
