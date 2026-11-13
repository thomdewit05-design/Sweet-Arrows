import Foundation

/// Runs `work` on the main actor, whichever thread an SDK callback arrives on.
///
/// Closures written inside main-actor code are checked at run time by Swift 6: if Google's, Apple's
/// or Game Center's SDK calls one on a background thread, the app stops. Callbacks are therefore
/// marked `@Sendable` (no hidden main-thread check) and hop to the main actor here.
func onMain(_ work: @escaping @MainActor @Sendable () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated(work)
    } else {
        Task { @MainActor in work() }
    }
}
