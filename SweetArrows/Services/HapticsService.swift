import UIKit

/// Light, tasteful vibrations. Core Haptics patterns come in phase 4.
@MainActor
protocol HapticsService: AnyObject {
    var enabled: Bool { get set }
    func tap()
    func pop()
    func bonk()
    func success()
}

@MainActor
final class UIKitHapticsService: HapticsService {
    var enabled = true
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()

    func tap() {
        guard enabled else { return }
        light.impactOccurred()
    }

    func pop() {
        guard enabled else { return }
        soft.impactOccurred(intensity: 1)
    }

    func bonk() {
        guard enabled else { return }
        rigid.impactOccurred(intensity: 0.6)
    }

    func success() {
        guard enabled else { return }
        notification.notificationOccurred(.success)
    }
}
