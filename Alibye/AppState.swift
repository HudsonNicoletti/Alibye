import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State

    @Published var biometricEnabled: Bool = false
    @Published var requiresUnlock: Bool = false
    @Published var hasCompletedSetup: Bool = false

    // MARK: - Storage Keys

    private enum Keys {
        static let setupCompleted = "hasCompletedSetup"
        static let biometricEnabled = "biometricEnabled"
    }

    init() {
        restoreSettings()
    }

    // MARK: - Public API

    func restoreSettings() {
        biometricEnabled = UserDefaults.standard.bool(forKey: Keys.biometricEnabled)
        requiresUnlock = false
        hasCompletedSetup = UserDefaults.standard.bool(forKey: Keys.setupCompleted)
    }

    func completeSetup() {
        hasCompletedSetup = true
        UserDefaults.standard.set(true, forKey: Keys.setupCompleted)
    }

    func resetSetup() {
        hasCompletedSetup = false
        UserDefaults.standard.set(false, forKey: Keys.setupCompleted)
    }
}
