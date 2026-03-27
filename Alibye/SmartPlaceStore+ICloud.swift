import Foundation

extension SmartPlaceStore {
    // Save locally and then mirror the updated file to iCloud.
    func saveWithICloudSync() {
        save()
        ICloudSyncManager.shared.syncPlacesNow()
    }
}
