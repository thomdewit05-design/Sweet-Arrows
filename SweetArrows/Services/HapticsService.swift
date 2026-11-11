import CoreHaptics
import UIKit

/// Tactile feedback. Core Haptics patterns where the device supports them, UIKit generators otherwise.
@MainActor
protocol HapticsService: AnyObject {
    var enabled: Bool { get set }
    func tap()
    func pop()
    func bonk()
    func success()
    /// Celebration that grows with the move: 1 (a small pop) to 5 (the board is empty).
    func burst(_ level: Int)
    /// Low rumble for a bomb blast.
    func rumble()
}

@MainActor
final class CoreHapticsService: HapticsService {
    var enabled = true
    private var engine: CHHapticEngine?
    private let fallback = UIKitHapticsService()

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.playsHapticsOnly = true
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            Task { @MainActor in try? self?.engine?.start() }
        }
    }

    func tap() {
        play([event(at: 0, intensity: 0.45, sharpness: 0.6)]) { fallback.tap() }
    }

    func pop() {
        play([
            event(at: 0, intensity: 0.9, sharpness: 0.8),
            event(at: 0.05, intensity: 0.45, sharpness: 0.3),
        ]) { fallback.pop() }
    }

    func bonk() {
        // Soft and low: a mistake should never feel harsh.
        play([
            event(at: 0, intensity: 0.6, sharpness: 0.1),
            event(at: 0.07, intensity: 0.3, sharpness: 0.1),
        ]) { fallback.bonk() }
    }

    func success() {
        play((0..<4).map { event(at: Double($0) * 0.09, intensity: 0.5 + Float($0) * 0.15, sharpness: 0.5) }) {
            fallback.success()
        }
    }

    func burst(_ level: Int) {
        let level = min(max(level, 1), 5)
        // A sharp pop, then one extra beat per level, each a little stronger.
        var events = [event(at: 0, intensity: 0.8, sharpness: 0.8)]
        for beat in 1..<level {
            events.append(event(at: Double(beat) * 0.07, intensity: min(0.55 + Float(beat) * 0.12, 1), sharpness: 0.55))
        }
        if level >= 4 {
            events.append(continuous(at: 0.05, duration: 0.25 + Double(level - 4) * 0.15, intensity: 0.6, sharpness: 0.3))
        }
        play(events) { fallback.burst(level) }
    }

    func rumble() {
        play([
            event(at: 0, intensity: 1, sharpness: 0.4),
            continuous(at: 0.02, duration: 0.35, intensity: 0.8, sharpness: 0.1),
        ]) { fallback.rumble() }
    }

    private func continuous(at time: TimeInterval, duration: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time,
            duration: duration
        )
    }

    private func event(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private func play(_ events: [CHHapticEvent], otherwise: () -> Void) {
        guard enabled else { return }
        guard let engine else {
            otherwise()
            return
        }
        do {
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            otherwise()
        }
    }
}

/// UIKit feedback generators: fallback for devices without Core Haptics.
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

    func burst(_ level: Int) {
        guard enabled else { return }
        if level >= 4 {
            notification.notificationOccurred(.success)
        } else {
            soft.impactOccurred(intensity: min(0.6 + CGFloat(level) * 0.13, 1))
        }
    }

    func rumble() {
        guard enabled else { return }
        rigid.impactOccurred(intensity: 1)
    }
}
