import Foundation

/// Crash-loop protection with a trail of start-up steps.
///
/// Every start writes the steps it reaches to a small file. A start that does not stay up for
/// 20 seconds counts as crashed: from then on, until the next app update, the app starts in safe mode
/// without the optional services (consent form, ads, Game Center, iCloud sync), and Settings shows
/// how far the crashed start got.
@MainActor
enum LaunchGuard {
    private static let runningKey = "launch.inProgress"
    private static let safeBuildKey = "launch.safeModeBuild"
    private static let crashedStepsKey = "launch.crashedSteps"

    private(set) static var isSafeMode = false
    private static var steps: [String] = []

    private static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    private static var file: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("launch-steps.txt")
    }

    /// Call first thing at start-up.
    static func begin() {
        // UI tests close the app on purpose; that is not a crash.
        guard !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: runningKey) {
            // The previous start never settled: keep its steps and start safely for this build.
            let previous = file.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
            defaults.set(previous, forKey: crashedStepsKey)
            defaults.set(build, forKey: safeBuildKey)
        }
        isSafeMode = defaults.string(forKey: safeBuildKey) == build
        defaults.set(true, forKey: runningKey)
        steps = []
        step(isSafeMode ? "start (safe mode, build \(build))" : "start (build \(build))")
    }

    /// Records a step; written to disk at once so it survives a crash right after.
    static func step(_ name: String) {
        steps.append(name)
        guard let file else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? steps.joined(separator: " → ").write(to: file, atomically: true, encoding: .utf8)
    }

    /// The app stayed up: this start went fine.
    static func settled() {
        step("settled")
        UserDefaults.standard.set(false, forKey: runningKey)
    }

    /// The steps of the last start that crashed, if any.
    static var crashedSteps: String? {
        UserDefaults.standard.string(forKey: crashedStepsKey).flatMap { $0.isEmpty ? nil : $0 }
    }
}
