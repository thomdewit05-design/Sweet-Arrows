import Foundation

/// Sound effects and music. Real sounds arrive with the game-feel pass (phase 4).
enum SoundEffect: String, Sendable {
    case tap, squish, pop, bonk, crack, win, lose
}

@MainActor
protocol AudioService: AnyObject {
    var soundEnabled: Bool { get set }
    var musicEnabled: Bool { get set }
    func play(_ effect: SoundEffect)
}

@MainActor
final class PlaceholderAudioService: AudioService {
    var soundEnabled = true
    var musicEnabled = true
    func play(_ effect: SoundEffect) {}
}
