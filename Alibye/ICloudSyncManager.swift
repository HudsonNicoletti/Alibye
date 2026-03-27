import Foundation
import Combine

@MainActor
final class ICloudSyncManager: ObservableObject {
    static let shared = ICloudSyncManager()

    // MARK: - Published State

    @Published var isICloudAvailable = false
    @Published var lastSyncDate: Date?

    // MARK: - Internal State

    private weak var historyStore: HistoryStore?
    private weak var smartPlaceStore: SmartPlaceStore?
    private var metadataQuery: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []

    private enum Constants {
        static let historyFileName = "alibye_logs.json"
        static let placesFileName = "alibye_smart_places.json"
    }

    private init() {}

    // MARK: - Public API

    func start(historyStore: HistoryStore, smartPlaceStore: SmartPlaceStore) async {
        self.historyStore = historyStore
        self.smartPlaceStore = smartPlaceStore

        guard let _ = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            isICloudAvailable = false
            return
        }

        isICloudAvailable = true
        await pullFromICloudIfAvailable()
        startMetadataQuery()
    }

    func syncHistoryNow() {
        Task { await pushLocalFileToICloud(named: Constants.historyFileName) }
    }

    func syncPlacesNow() {
        Task { await pushLocalFileToICloud(named: Constants.placesFileName) }
    }

    func syncAllNow() {
        Task {
            await pushLocalFileToICloud(named: Constants.historyFileName)
            await pushLocalFileToICloud(named: Constants.placesFileName)
            lastSyncDate = .now
        }
    }

    func pullFromICloudIfAvailable() async {
        await pullICloudFileToLocal(named: Constants.historyFileName)
        await pullICloudFileToLocal(named: Constants.placesFileName)
        historyStore?.load()
        smartPlaceStore?.load()
        lastSyncDate = .now
    }

    // MARK: - Query Lifecycle

    private func startMetadataQuery() {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        let observer1 = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMetadataUpdate(query)
            }
        }

        let observer2 = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMetadataUpdate(query)
            }
        }

        observers.append(observer1)
        observers.append(observer2)
        metadataQuery = query
        query.start()
    }

    private func handleMetadataUpdate(_ query: NSMetadataQuery) async {
        _ = query
        // Pull latest snapshots whenever iCloud metadata indicates changes.
        await pullFromICloudIfAvailable()
    }

    // MARK: - File Locations

    private func localDocumentsURL() throws -> URL {
        try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    private func iCloudDocumentsURL() -> URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let docs = container.appendingPathComponent("Documents", isDirectory: true)

        if !FileManager.default.fileExists(atPath: docs.path) {
            try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        }

        return docs
    }

    // MARK: - Sync Operations

    private func pushLocalFileToICloud(named fileName: String) async {
        guard let cloudDocs = iCloudDocumentsURL() else { return }

        do {
            let local = try localDocumentsURL().appendingPathComponent(fileName)
            let cloud = cloudDocs.appendingPathComponent(fileName)

            guard FileManager.default.fileExists(atPath: local.path) else { return }

            if FileManager.default.fileExists(atPath: cloud.path) {
                try? FileManager.default.removeItem(at: cloud)
            }

            try FileManager.default.setUbiquitous(true, itemAt: local, destinationURL: cloud)
            lastSyncDate = .now
        } catch {
            print("iCloud push error for \(fileName): \(error.localizedDescription)")
        }
    }

    private func pullICloudFileToLocal(named fileName: String) async {
        guard let cloudDocs = iCloudDocumentsURL() else { return }

        do {
            let cloud = cloudDocs.appendingPathComponent(fileName)
            let local = try localDocumentsURL().appendingPathComponent(fileName)

            guard FileManager.default.fileExists(atPath: cloud.path) else { return }

            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?

            coordinator.coordinate(readingItemAt: cloud, options: [], error: &coordinationError) { url in
                do {
                    let data = try Data(contentsOf: url)
                    try data.write(to: local, options: .atomic)
                } catch {
                    print("Local write error for \(fileName): \(error.localizedDescription)")
                }
            }

            if let coordinationError {
                print("iCloud coordinate error for \(fileName): \(coordinationError.localizedDescription)")
            } else {
                lastSyncDate = .now
            }
        } catch {
            print("iCloud pull error for \(fileName): \(error.localizedDescription)")
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        metadataQuery?.stop()
    }
}
