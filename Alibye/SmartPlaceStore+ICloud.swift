import Foundation
import Combine

extension SmartPlaceStore {
    func saveWithICloudSync() {
        save()
        ICloudSyncManager.shared.syncPlacesNow()
    }
}
