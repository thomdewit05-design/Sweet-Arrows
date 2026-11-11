import AVFoundation
import Foundation

/// Short sound effects, synthesised by Tools/Sounds/make_sounds.py.
enum SoundEffect: String, CaseIterable, Sendable {
    case tap, squish, pop, bonk, crack, melt, win, lose, star, coin
}

@MainActor
protocol AudioService: AnyObject {
    var soundEnabled: Bool { get set }
    var musicEnabled: Bool { get set }
    func play(_ effect: SoundEffect)
    /// Rising xylophone tone for the n-th pop in a row (1-based).
    func playCombo(_ step: Int)
}

/// Plays preloaded effects through AVAudioPlayer. Uses the ambient session, so the
/// silent switch is respected and the player's own music keeps playing.
@MainActor
final class SoundEffectsService: AudioService {
    var soundEnabled = true
    var musicEnabled = true

    private static let comboCount = 8
    private static let voices = 3
    private var players: [String: [AVAudioPlayer]] = [:]
    private var nextVoice: [String: Int] = [:]

    init(bundle: Bundle = .main) {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        let names = SoundEffect.allCases.map(\.rawValue) + (1...Self.comboCount).map { "combo\($0)" }
        for name in names {
            guard let url = bundle.url(forResource: name, withExtension: "wav") else { continue }
            let voices = (0..<Self.voices).compactMap { _ in try? AVAudioPlayer(contentsOf: url) }
            voices.forEach { $0.prepareToPlay() }
            players[name] = voices
        }
    }

    func play(_ effect: SoundEffect) {
        play(named: effect.rawValue)
    }

    func playCombo(_ step: Int) {
        play(named: "combo\(min(max(step, 1), Self.comboCount))")
    }

    private func play(named name: String) {
        guard soundEnabled, let voices = players[name], !voices.isEmpty else { return }
        let index = nextVoice[name, default: 0]
        nextVoice[name] = (index + 1) % voices.count
        let player = voices[index]
        player.currentTime = 0
        player.play()
    }
}

/// Silent stand-in for tests and previews.
@MainActor
final class SilentAudioService: AudioService {
    var soundEnabled = true
    var musicEnabled = true
    func play(_ effect: SoundEffect) {}
    func playCombo(_ step: Int) {}
}
