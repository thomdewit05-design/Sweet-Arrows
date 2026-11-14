import AVFoundation
import Foundation

/// Short sound effects, synthesised by Tools/Sounds/make_sounds.py.
enum SoundEffect: String, CaseIterable, Sendable {
    case tap, squish, pop, bonk, crack, melt, win, lose, star, coin
}

/// Background music, synthesised by Tools/Sounds/make_music.py. The game tracks get livelier with the speed.
enum MusicTrack: String, CaseIterable, Sendable {
    case menu = "candy_shop_loop"
    case calm = "game_calm"
    case groove = "game_groove"
    case bright = "game_bright"
    case rush = "game_rush"

    /// The game track for a speed stage (0-based): changes every two stages.
    static func game(stage: Int) -> MusicTrack {
        switch stage {
        case ..<2: .calm
        case 2..<4: .groove
        case 4..<6: .bright
        default: .rush
        }
    }
}

@MainActor
protocol AudioService: AnyObject {
    var soundEnabled: Bool { get set }
    var musicEnabled: Bool { get set }
    func play(_ effect: SoundEffect)
    /// Rising xylophone tone for the n-th pop in a row (1-based).
    func playCombo(_ step: Int)
    /// Crossfades to another background track (does nothing if it is already playing).
    func playMusic(_ track: MusicTrack)
    /// Turns the sound back on after something took it away: the app becoming active (also the very
    /// first time), a call or Siri, a full-screen ad.
    func resume()
}

/// Plays preloaded effects through AVAudioPlayer. The game is heard even with the iPhone on silent
/// (owner's choice: many players keep their phone on silent), and music from other apps keeps
/// playing alongside it. Sound and music can each be turned off in Settings.
@MainActor
final class SoundEffectsService: AudioService {
    var soundEnabled = true
    var musicEnabled = true {
        didSet { updateMusic() }
    }

    /// Background loop, kept low as PLAN.md asks.
    private static let musicVolume: Float = 0.25
    private static let crossfade: TimeInterval = 1.2
    private var tracks: [MusicTrack: AVAudioPlayer] = [:]
    private var currentTrack: MusicTrack = .menu

    private static let comboCount = 8
    private static let voices = 3
    private var players: [String: [AVAudioPlayer]] = [:]
    private var nextVoice: [String: Int] = [:]

    private var observers: [NSObjectProtocol] = []

    init(bundle: Bundle = .main) {
        Self.configureSession()
        let names = SoundEffect.allCases.map(\.rawValue) + (1...Self.comboCount).map { "combo\($0)" }
        for name in names {
            guard let url = bundle.url(forResource: name, withExtension: "wav") else { continue }
            let voices = (0..<Self.voices).compactMap { _ in try? AVAudioPlayer(contentsOf: url) }
            voices.forEach { $0.prepareToPlay() }
            players[name] = voices
        }
        for track in MusicTrack.allCases {
            guard let url = bundle.url(forResource: track.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.numberOfLoops = -1
            player.volume = track == currentTrack ? Self.musicVolume : 0
            player.prepareToPlay()
            tracks[track] = player
        }
        // The music starts in resume(), once the app is active: iOS can refuse to play sound while the
        // app is still launching, and nothing would try again.
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .ended else { return }
            MainActor.assumeIsolated { self?.resume() }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
        })
    }

    func resume() {
        Self.configureSession()
        try? AVAudioSession.sharedInstance().setActive(true)
        updateMusic()
    }

    /// Playback (heard with the silent switch on) mixed with other apps' audio instead of stopping it.
    private static func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }

    func playMusic(_ track: MusicTrack) {
        guard track != currentTrack else { return }
        let old = tracks[currentTrack]
        currentTrack = track
        guard musicEnabled else { return }
        old?.setVolume(0, fadeDuration: Self.crossfade)
        if let old {
            // Pause the old track once it has faded out (unless it was picked again meanwhile).
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(Self.crossfade + 0.1))
                guard let self, self.tracks[self.currentTrack] !== old else { return }
                old.pause()
            }
        }
        guard let next = tracks[track] else { return }
        // Each new speed starts its track from the top, so the change is clearly heard.
        next.currentTime = 0
        next.volume = 0
        next.play()
        next.setVolume(Self.musicVolume, fadeDuration: Self.crossfade)
    }

    private func updateMusic() {
        guard let music = tracks[currentTrack] else { return }
        if musicEnabled {
            music.volume = Self.musicVolume
            if !music.isPlaying { music.play() }
        } else {
            for player in tracks.values where player.isPlaying { player.pause() }
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
    func playMusic(_ track: MusicTrack) {}
    func resume() {}
}
