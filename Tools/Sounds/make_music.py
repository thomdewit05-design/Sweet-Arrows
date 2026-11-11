#!/usr/bin/env python3
"""Synthesises the Sweet Arrows music: a menu tune and four game tracks that get livelier as a run speeds up.

Run:  python3 Tools/Sounds/make_music.py        (needs numpy)
Writes SweetArrows/Resources/Music/*.wav (uncompressed, so the loops have no encoder gap):

  candy_shop_loop.wav  menu      92 BPM  C major  ukulele lounge, glockenspiel, shaker
  game_calm.wav        speed 1-2 96 BPM  F major  marimba arpeggios, soft pad, shaker
  game_groove.wav      speed 3-4 108 BPM G major  off-beat ukulele, funky bass, claps, bells
  game_bright.wav      speed 5-6 120 BPM D major  8-bit lead and arpeggios, bouncy bass, drums
  game_rush.wav        speed 7+  132 BPM A minor  fast arpeggios, driving bass, four-on-the-floor

Every track has an A and a B section with different melodies, so it takes a while before it repeats.
Everything is generated here, so there is no licence to track. Each loop is seamless: the tail is
folded back into the start.
"""
import os
import random
import wave

import numpy as np

RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "SweetArrows", "Resources", "Music")
NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(note):
    """'C4' style note name to a MIDI number."""
    return 12 * (int(note[-1]) + 1) + NOTE_INDEX[note[:-1]]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


class Track:
    def __init__(self, bpm, bars, seed):
        self.beat = 60 / bpm
        self.length = bars * 4 * self.beat
        self.buf = np.zeros(int((self.length + 4) * RATE))
        self.rng = random.Random(seed)
        self.np_rng = np.random.default_rng(seed)

    def t(self, bar, beat=0.0):
        return (bar * 4 + beat) * self.beat

    def add(self, samples, time, gain):
        start = int(time * RATE)
        end = min(start + len(samples), len(self.buf))
        if start < len(self.buf):
            self.buf[start:end] += samples[: end - start] * gain

    def render(self, name, loudness=0.13):
        n = int(self.length * RATE)
        loop = self.buf[:n].copy()
        tail = self.buf[n:]
        loop[: len(tail)] += tail[:n]
        rms = np.sqrt(np.mean(loop**2)) or 1
        loop *= loudness / rms
        peak = np.max(np.abs(loop))
        if peak > 0.85:
            loop *= 0.85 / peak  # keep headroom; nothing clips
        os.makedirs(OUT_DIR, exist_ok=True)
        path = os.path.join(OUT_DIR, name)
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((np.clip(loop, -1, 1) * 32767).astype("<i2").tobytes())
        print(f"{self.length:5.1f}s  {name}")


# ---------------------------------------------------------------- instruments

def env_time(duration):
    return np.arange(int(duration * RATE)) / RATE


_PLUCKS = {}


def pluck(m, duration=1.4, brightness=0.5, seed=0):
    """Karplus-Strong nylon string (cached per pitch)."""
    key = (m, duration, brightness)
    if key in _PLUCKS:
        return _PLUCKS[key]
    period = max(2, int(RATE / hz(m)))
    rng = np.random.default_rng(m * 31 + seed)
    buf = rng.uniform(-1, 1, period)
    buf = (buf + np.roll(buf, 1)) / 2
    buf = (buf + np.roll(buf, 1)) / 2
    out = np.empty(int(duration * RATE))
    decay = 0.996
    idx = 0
    buf = list(buf)
    for i in range(len(out)):
        a = buf[idx]
        b = buf[(idx + 1) % period]
        buf[idx] = decay * (brightness * a + (1 - brightness) * (a + b) / 2)
        out[i] = a
        idx = (idx + 1) % period
    _PLUCKS[key] = out
    return out


def marimba(m, duration=0.9):
    x = env_time(duration)
    f = hz(m)
    env = np.minimum(1, x / 0.002) * np.exp(-x / 0.28)
    return env * (np.sin(2 * np.pi * f * x) + 0.35 * np.sin(2 * np.pi * f * 4 * x) * np.exp(-x / 0.05))


def bell(m, duration=1.2):
    x = env_time(duration)
    f = hz(m)
    env = np.minimum(1, x / 0.003) * np.exp(-x / 0.35)
    return env * (np.sin(2 * np.pi * f * x) + 0.25 * np.sin(2 * np.pi * f * 2.76 * x) * np.exp(-x / 0.08))


def pad(notes, duration):
    """Soft chord: slightly detuned sines with slow attack and release."""
    x = env_time(duration)
    attack, release = 0.25, 0.4
    env = np.minimum(1, x / attack) * np.minimum(1, np.maximum(0, (duration - x) / release))
    out = np.zeros_like(x)
    for m in notes:
        f = hz(m)
        for detune in (-0.12, 0.12):
            out += np.sin(2 * np.pi * f * (1 + detune / 100) * x)
        out += 0.2 * np.sin(2 * np.pi * f * 2 * x)
    return env * out / max(len(notes), 1)


def square(m, duration, duty=0.5, decay=0.25):
    """8-bit style pulse wave, softened with a sine so it is not harsh."""
    x = env_time(duration)
    f = hz(m)
    phase = (f * x) % 1
    pulse = np.where(phase < duty, 1.0, -1.0)
    env = np.minimum(1, x / 0.004) * np.exp(-x / decay)
    return env * (0.55 * pulse + 0.45 * np.sin(2 * np.pi * f * x))


def bass(m, duration, pluck_decay=0.45):
    x = env_time(duration)
    f = hz(m)
    env = np.minimum(1, x / 0.008) * np.exp(-x / pluck_decay)
    return env * (np.sin(2 * np.pi * f * x) + 0.35 * np.sin(4 * np.pi * f * x) + 0.1 * np.sin(6 * np.pi * f * x))


def kick():
    x = env_time(0.35)
    f = 120 * np.exp(-x / 0.05) + 45
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return np.sin(phase) * np.exp(-x / 0.12)


def noise_hit(rng, duration, decay, highpass=True):
    n = int(duration * RATE)
    noise = rng.uniform(-1, 1, n)
    if highpass:
        noise = np.diff(noise, prepend=0)
    return noise * np.exp(-np.arange(n) / RATE / decay)


def clap(rng):
    out = np.zeros(int(0.25 * RATE))
    for k in range(3):  # a clap is a few quick hits
        hit = noise_hit(rng, 0.2, 0.05 if k == 2 else 0.01, highpass=False)
        s = int(k * 0.011 * RATE)
        out[s:s + len(hit)] += hit[: len(out) - s]
    return out


def snare(rng):
    x = env_time(0.22)
    tone = np.sin(2 * np.pi * 190 * x) * np.exp(-x / 0.05)
    return 0.6 * tone + noise_hit(rng, 0.22, 0.06, highpass=True)


# ---------------------------------------------------------------- music helpers

def chord_tones(root, quality):
    steps = {"maj": [0, 4, 7], "min": [0, 3, 7], "sus": [0, 5, 7], "maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10]}
    return [root + s for s in steps[quality]]


def melody(track, scale, progression, bars, start_bar, octave_root, density, seed_offset):
    """A singable random-walk melody: chord tones on strong beats, scale steps in between."""
    rng = random.Random(seed_offset)
    notes = []
    pos = len(scale) // 2
    for bar in range(bars):
        root, quality = progression[bar % len(progression)]
        tones = {t % 12 for t in chord_tones(root, quality)}
        beat = 0.0
        while beat < 4:
            strong = beat in (0.0, 2.0)
            if rng.random() < density or strong:
                step = rng.choice([-2, -1, -1, 0, 1, 1, 2])
                pos = max(0, min(len(scale) - 1, pos + step))
                if strong:  # land on the nearest chord tone
                    for d in (0, 1, -1, 2, -2):
                        k = max(0, min(len(scale) - 1, pos + d))
                        if scale[k] % 12 in tones:
                            pos = k
                            break
                length = rng.choice([0.5, 0.5, 1.0]) if not strong else rng.choice([1.0, 1.0, 1.5])
                notes.append((start_bar + bar, beat, octave_root + scale[pos], min(length, 4 - beat)))
                beat += length
            else:
                beat += 0.5
    return notes


def scale_notes(root, kind, octaves=2):
    pattern = {"major_penta": [0, 2, 4, 7, 9], "minor_penta": [0, 3, 5, 7, 10], "major": [0, 2, 4, 5, 7, 9, 11]}[kind]
    return [root + o * 12 + p for o in range(octaves) for p in pattern]


# ---------------------------------------------------------------- the tracks

def menu():
    """The calm ukulele-lounge loop from the first version (menus and the shop)."""
    tr = Track(92, 16, 42)
    chords = {
        "C": ["G4", "C4", "E4", "C5"], "Am": ["A4", "C4", "E4", "A4"], "F": ["A4", "C4", "F4", "A4"],
        "G": ["G4", "D4", "G4", "B4"], "Em": ["G4", "E4", "G4", "B4"], "Dm": ["A4", "D4", "F4", "A4"],
    }
    bass_notes = {"C": "C2", "Am": "A1", "F": "F2", "G": "G2", "Em": "E2", "Dm": "D2"}
    prog = ["C", "Am", "F", "G", "C", "Am", "F", "G", "F", "G", "Em", "Am", "Dm", "G", "C", "C"]
    pattern = [(0.0, True, 1.0), (1.0, True, 0.8), (1.5, False, 0.6), (2.5, False, 0.6), (3.0, True, 0.8), (3.5, False, 0.55)]
    for bar, chord in enumerate(prog):
        for beat, down, vel in pattern:
            strings = chords[chord] if down else list(reversed(chords[chord]))
            for k, n in enumerate(strings):
                tr.add(pluck(midi(n)), tr.t(bar, beat) + k * 0.012, 0.16 * vel)
        tr.add(bass(midi(bass_notes[chord]), 2 * tr.beat), tr.t(bar), 0.28)
        tr.add(bass(midi(bass_notes[chord]), 2 * tr.beat), tr.t(bar, 2), 0.28)
        for eighth in range(8):
            tr.add(noise_hit(tr.np_rng, 0.06, 0.015), tr.t(bar, eighth / 2) + (0.03 if eighth % 2 else 0),
                   0.03 if eighth % 2 == 0 else 0.018)
    tune = [
        (0, 2, "E6"), (1, 0, "C6"), (1, 2.5, "A5"), (2, 1, "C6"), (3, 0, "D6"), (3, 2, "B5"),
        (5, 0, "G5"), (5, 2, "A5"), (6, 0, "C6"), (7, 1, "D6"), (7, 3, "E6"),
        (8, 0, "F6"), (8, 2, "E6"), (9, 0, "D6"), (10, 0, "G5"), (10, 2, "B5"), (11, 1, "C6"),
        (12, 0, "D6"), (12, 2, "F6"), (13, 1, "D6"), (13, 3, "B5"), (14, 0, "C6"), (14, 2, "E6"), (15, 1, "G6"),
    ]
    for bar, beat, n in tune:
        tr.add(bell(midi(n)), tr.t(bar, beat), 0.09)
    tr.render("candy_shop_loop.wav", loudness=0.12)


def calm():
    """Speed 1-2: gentle marimba arpeggios over a soft pad."""
    tr = Track(96, 16, 7)
    F, Bb, C, Dm, Gm, Am = 53, 58, 60, 62, 55, 57  # roots around F3
    prog_a = [(F, "maj7"), (Dm, "min7"), (Bb, "maj7"), (C, "sus")]
    prog_b = [(Gm, "min7"), (C, "maj"), (Am, "min7"), (Dm, "min7"), (Bb, "maj"), (C, "maj"), (F, "maj"), (F, "maj7")]
    progression = prog_a * 2 + prog_b
    for bar, (root, q) in enumerate(progression):
        tones = chord_tones(root, q)
        tr.add(pad([t + 12 for t in tones], 4 * tr.beat + 0.3), tr.t(bar), 0.10)
        arp = tones + [tones[1] + 12, tones[0] + 12, tones[2]]
        for i in range(8):
            tr.add(marimba(arp[i % len(arp)] + 12), tr.t(bar, i * 0.5), 0.13 if i % 2 == 0 else 0.09)
        tr.add(bass(root - 12, 2.5 * tr.beat, 0.7), tr.t(bar), 0.26)
        tr.add(bass(tones[2] - 12, 1.5 * tr.beat, 0.5), tr.t(bar, 2.5), 0.18)
        for eighth in range(8):
            tr.add(noise_hit(tr.np_rng, 0.05, 0.012), tr.t(bar, eighth / 2), 0.02 if eighth % 2 else 0.012)
    scale = scale_notes(65, "major_penta")  # F major pentatonic from F4
    for section, start in ((0, 0), (1, 8)):
        prog = progression[start:start + 8]
        for bar, beat, m, length in melody(tr, scale, prog, 8, start, 12, 0.35, 100 + section):
            tr.add(bell(m, 1.0), tr.t(bar, beat), 0.08)
    tr.render("game_calm.wav", loudness=0.12)


def groove():
    """Speed 3-4: off-beat ukulele, funky octave bass, claps and bells."""
    tr = Track(108, 16, 11)
    G, C, D, Em, Am = 55, 60, 62, 52, 57
    prog_a = [(G, "maj"), (Em, "min"), (C, "maj"), (D, "maj")]
    prog_b = [(Am, "min"), (D, "maj"), (G, "maj"), (Em, "min"), (C, "maj"), (D, "maj"), (G, "maj"), (D, "sus")]
    progression = prog_a * 2 + prog_b
    for bar, (root, q) in enumerate(progression):
        tones = chord_tones(root, q)
        for beat in (0.5, 1.5, 2.5, 3.5):  # skank on the off-beats
            for k, m in enumerate(tones + [tones[0] + 12]):
                tr.add(pluck(m + 12, 0.5, 0.65), tr.t(bar, beat) + k * 0.008, 0.11)
        for i, (beat, octave) in enumerate([(0, 0), (0.75, 12), (1.5, 0), (2, 0), (2.75, 12), (3.5, 7)]):
            tr.add(bass(root - 24 + octave, 0.4 * tr.beat * 2, 0.18), tr.t(bar, beat), 0.30)
        tr.add(kick(), tr.t(bar, 0), 0.5)
        tr.add(kick(), tr.t(bar, 2.5), 0.35)
        tr.add(clap(tr.np_rng), tr.t(bar, 1), 0.18)
        tr.add(clap(tr.np_rng), tr.t(bar, 3), 0.18)
        for sixteenth in range(16):
            tr.add(noise_hit(tr.np_rng, 0.04, 0.008), tr.t(bar, sixteenth / 4), 0.025 if sixteenth % 2 == 0 else 0.012)
    scale = scale_notes(67, "major_penta")  # G major pentatonic from G4
    for section, start in ((0, 0), (1, 8)):
        prog = progression[start:start + 8]
        for bar, beat, m, length in melody(tr, scale, prog, 8, start, 12, 0.5, 200 + section):
            tr.add(bell(m, 0.8), tr.t(bar, beat), 0.09)
    tr.render("game_groove.wav", loudness=0.13)


def bright():
    """Speed 5-6: cheerful 8-bit lead and arpeggios, bouncy bass, drums."""
    tr = Track(120, 16, 23)
    D, G, A, Bm, Em = 62, 55, 57, 59, 52
    prog_a = [(D, "maj"), (A, "maj"), (Bm, "min"), (G, "maj")]
    prog_b = [(Em, "min"), (A, "maj"), (D, "maj"), (Bm, "min"), (G, "maj"), (A, "maj"), (D, "maj"), (A, "sus")]
    progression = prog_a * 2 + prog_b
    for bar, (root, q) in enumerate(progression):
        tones = chord_tones(root, q)
        arp = [tones[0], tones[1], tones[2], tones[1] + 12]
        for i in range(16):
            tr.add(square(arp[i % 4] + 12, 0.12, duty=0.25, decay=0.06), tr.t(bar, i / 4), 0.05)
        for beat in range(4):
            tr.add(bass(root - 12 + (7 if beat % 2 else 0), 0.45, 0.15), tr.t(bar, beat), 0.30)
            tr.add(kick(), tr.t(bar, beat), 0.45 if beat % 2 == 0 else 0.3)
        tr.add(snare(tr.np_rng), tr.t(bar, 1), 0.16)
        tr.add(snare(tr.np_rng), tr.t(bar, 3), 0.16)
        for eighth in range(8):
            tr.add(noise_hit(tr.np_rng, 0.05, 0.01), tr.t(bar, eighth / 2 + 0.25), 0.03)
    scale = scale_notes(62, "major")  # D major from D4
    for section, start in ((0, 0), (1, 8)):
        prog = progression[start:start + 8]
        for bar, beat, m, length in melody(tr, scale, prog, 8, start, 12, 0.6, 300 + section):
            tr.add(square(m, length * tr.beat, duty=0.5, decay=0.35), tr.t(bar, beat), 0.09)
    tr.render("game_bright.wav", loudness=0.13)


def rush():
    """Speed 7+: fast arpeggios, driving bass, four-on-the-floor, a bright lead."""
    tr = Track(132, 16, 31)
    Am, F, C, G, Dm, E = 57, 53, 60, 55, 62, 52
    prog_a = [(Am, "min"), (F, "maj"), (C, "maj"), (G, "maj")]
    prog_b = [(Dm, "min"), (Am, "min"), (F, "maj"), (G, "maj"), (Dm, "min"), (E, "maj"), (Am, "min"), (E, "maj")]
    progression = prog_a * 2 + prog_b
    for bar, (root, q) in enumerate(progression):
        tones = chord_tones(root, q)
        arp = [tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[0] + 24, tones[2] + 12, tones[1] + 12]
        for i in range(16):
            tr.add(square(arp[i % len(arp)], 0.1, duty=0.3, decay=0.05), tr.t(bar, i / 4), 0.05)
        for eighth in range(8):
            tr.add(bass(root - 12, 0.22, 0.09), tr.t(bar, eighth / 2), 0.28)
        for beat in range(4):
            tr.add(kick(), tr.t(bar, beat), 0.5)
        tr.add(snare(tr.np_rng), tr.t(bar, 1), 0.18)
        tr.add(snare(tr.np_rng), tr.t(bar, 3), 0.18)
        for eighth in range(8):
            open_hat = eighth % 2 == 1
            tr.add(noise_hit(tr.np_rng, 0.12 if open_hat else 0.04, 0.04 if open_hat else 0.008),
                   tr.t(bar, eighth / 2), 0.035 if open_hat else 0.02)
        if bar % 4 == 3:  # a little snare fill into the next phrase
            for k in range(4):
                tr.add(snare(tr.np_rng), tr.t(bar, 3 + k / 4), 0.08 + 0.02 * k)
    scale = scale_notes(57, "minor_penta")  # A minor pentatonic from A3
    for section, start in ((0, 0), (1, 8)):
        prog = progression[start:start + 8]
        for bar, beat, m, length in melody(tr, scale, prog, 8, start, 24, 0.65, 400 + section):
            tr.add(square(m, length * tr.beat, duty=0.5, decay=0.3), tr.t(bar, beat), 0.08)
            tr.add(bell(m, 0.6), tr.t(bar, beat), 0.04)
    tr.render("game_rush.wav", loudness=0.14)


if __name__ == "__main__":
    menu()
    calm()
    groove()
    bright()
    rush()
