import Foundation
import Observation
import SweetArrowsCore

/// The bit of iCloud key-value storage we use, behind a protocol so tests can fake it.
@MainActor
protocol CloudKeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudKeyValueStore {}

/// Stores progress as JSON in Application Support and syncs it through iCloud
/// (key-value storage), so a new iPhone picks up where the old one stopped.
/// Works fully offline; the copies are merged without losing anything earned.
@MainActor
@Observable
final class SaveService {
    static let cloudKey = "progress.v1"

    private(set) var progress: PlayerProgress
    private let url: URL?
    private let cloud: CloudKeyValueStore?
    @ObservationIgnored private var observer: NSObjectProtocol?

    /// - Parameters:
    ///   - url: file to use; nil keeps everything in memory (tests, previews).
    ///   - cloud: iCloud store; nil disables sync.
    init(url: URL? = SaveService.defaultURL, cloud: CloudKeyValueStore? = nil) {
        self.url = url
        self.cloud = cloud
        if let url, let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
            progress = saved
        } else {
            progress = PlayerProgress()
        }
        guard cloud != nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pullFromCloud() }
        }
        cloud?.synchronize()
        pullFromCloud()
    }

    static var defaultURL: URL? {
        guard let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        return folder.appendingPathComponent("progress.json")
    }

    // MARK: Changes

    func update(_ change: (inout PlayerProgress) -> Void) {
        change(&progress)
        progress.updatedAt = Date()
        persist()
        pushToCloud()
    }

    /// Uses a booster from stock or pays coins for it. Returns false if the player can't afford it.
    func spend(_ booster: Booster) -> Bool {
        var paid = false
        update { paid = $0.spend(booster) }
        return paid
    }

    // MARK: Disk & iCloud

    private func persist() {
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(progress)
            try data.write(to: url, options: [.atomic])
        } catch {
            assertionFailure("Could not save progress: \(error)")
        }
    }

    private func pushToCloud() {
        guard let cloud, let data = try? JSONEncoder().encode(progress) else { return }
        cloud.set(data, forKey: Self.cloudKey)
    }

    /// Merges the iCloud copy into ours. Public for tests.
    func pullFromCloud() {
        guard let cloud, let data = cloud.data(forKey: Self.cloudKey),
              let remote = try? JSONDecoder().decode(PlayerProgress.self, from: data)
        else { return }
        let merged = progress.merged(with: remote)
        guard merged != progress else { return }
        progress = merged
        persist()
        if merged != remote { pushToCloud() }
    }
}
