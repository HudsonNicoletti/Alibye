import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var biometricEnabled: Bool = false
    @Published var requiresUnlock: Bool = false
    @Published var hasCompletedSetup: Bool = false

    private let setupKey = "hasCompletedSetup"
    private let biometricKey = "biometricEnabled"

    init() {
        restoreSettings()
    }

    func restoreSettings() {
        biometricEnabled = UserDefaults.standard.bool(forKey: biometricKey)
        requiresUnlock = false
        hasCompletedSetup = UserDefaults.standard.bool(forKey: setupKey)
    }

    func completeSetup() {
        hasCompletedSetup = true
        UserDefaults.standard.set(true, forKey: setupKey)
    }

    func resetSetup() {
        hasCompletedSetup = false
        UserDefaults.standard.set(false, forKey: setupKey)
    }
}
