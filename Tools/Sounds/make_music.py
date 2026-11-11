#!/usr/bin/env python3
"""Synthesises the Sweet Arrows background loop: a calm, playful ukulele-lounge tune.

Run:  python3 Tools/Sounds/make_music.py
Writes SweetArrows/Resources/Music/candy_shop_loop.wav (uncompressed, so the loop has no encoder gap).
Everything is generated here (Karplus-Strong ukulele, soft bass, glockenspiel, shaker),
so there is no licence to track. The loop is seamless: the tail is folded back into the start.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
BPM = 92
BEAT = 60 / BPM
BARS = 16
LENGTH = BARS * 4 * BEAT
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "SweetArrows", "Resources", "Music")
random.seed(42)


def freq(note):
    """'C4' style note name to Hz."""
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    name, octave = note[:-1], int(note[-1])
    midi = 12 * (octave + 1) + names[name]
    return 440 * 2 ** ((midi - 69) / 12)


# Ukulele voicings (re-entrant G C E A tuning).
CHORDS = {
    "C": ["G4", "C4", "E4", "C5"],
    "Am": ["A4", "C4", "E4", "A4"],
    "F": ["A4", "C4", "F4", "A4"],
    "G": ["G4", "D4", "G4", "B4"],
    "Em": ["G4", "E4", "G4", "B4"],
    "Dm": ["A4", "D4", "F4", "A4"],
}
BASS = {"C": "C2", "Am": "A1", "F": "F2", "G": "G2", "Em": "E2", "Dm": "D2"}
PROGRESSION = ["C", "Am", "F", "G", "C", "Am", "F", "G", "F", "G", "Em", "Am", "Dm", "G", "C", "C"]

track = [0.0] * int((LENGTH + 3) * RATE)


def add(samples, start_time, gain):
    start = int(start_time * RATE)
    for i, s in enumerate(samples):
        j = start + i
        if j < len(track):
            track[j] += s * gain


def pluck(f, duration=1.6, brightness=0.5):
    """Karplus-Strong plucked string."""
    period = max(2, int(RATE / f))
    buf = [random.uniform(-1, 1) for _ in range(period)]
    # Soften the excitation for a nylon-string sound.
    for _ in range(2):
        buf = [(buf[i] + buf[i - 1]) / 2 for i in range(period)]
    out = []
    idx = 0
    decay = 0.996
    for _ in range(int(duration * RATE)):
        a = buf[idx]
        b = buf[(idx + 1) % period]
        buf[idx] = decay * (brightness * a + (1 - brightness) * (a + b) / 2)
        out.append(a)
        idx = (idx + 1) % period
    return out


PLUCK_CACHE = {}


def cached_pluck(note):
    if note not in PLUCK_CACHE:
        PLUCK_CACHE[note] = pluck(freq(note))
    return PLUCK_CACHE[note]


def strum(chord, t, down=True, velocity=1.0):
    strings = CHORDS[chord] if down else list(reversed(CHORDS[chord]))
    for k, note in enumerate(strings):
        add(cached_pluck(note), t + k * 0.012, 0.16 * velocity)


def bass(note, t, duration):
    f = freq(note)
    n = int(duration * RATE)
    samples = []
    for i in range(n):
        x = i / RATE
        env = min(1, x / 0.01) * math.exp(-x / 0.5)
        samples.append(env * (math.sin(2 * math.pi * f * x) + 0.3 * math.sin(4 * math.pi * f * x)))
    add(samples, t, 0.28)


def glock(note, t):
    f = freq(note)
    n = int(1.2 * RATE)
    samples = []
    for i in range(n):
        x = i / RATE
        env = min(1, x / 0.003) * math.exp(-x / 0.35)
        samples.append(env * (math.sin(2 * math.pi * f * x) + 0.25 * math.sin(2 * math.pi * f * 2.76 * x) * math.exp(-x / 0.08)))
    add(samples, t, 0.09)


def shaker(t, accent):
    n = int(0.06 * RATE)
    prev = 0.0
    samples = []
    for i in range(n):
        noise = random.uniform(-1, 1)
        hp = noise - prev  # crude high-pass
        prev = noise
        samples.append(hp * math.exp(-i / RATE / 0.015))
    add(samples, t, 0.03 if accent else 0.018)


# Strum pattern per bar (in beats): D . D U . U D U
PATTERN = [(0.0, True, 1.0), (1.0, True, 0.8), (1.5, False, 0.6), (2.5, False, 0.6), (3.0, True, 0.8), (3.5, False, 0.55)]
# A sparse glockenspiel melody (bar, beat, note), C major pentatonic.
MELODY = [
    (0, 2, "E6"), (1, 0, "C6"), (1, 2.5, "A5"), (2, 1, "C6"), (3, 0, "D6"), (3, 2, "B5"),
    (5, 0, "G5"), (5, 2, "A5"), (6, 0, "C6"), (7, 1, "D6"), (7, 3, "E6"),
    (8, 0, "F6"), (8, 2, "E6"), (9, 0, "D6"), (10, 0, "G5"), (10, 2, "B5"), (11, 1, "C6"),
    (12, 0, "D6"), (12, 2, "F6"), (13, 1, "D6"), (13, 3, "B5"), (14, 0, "C6"), (14, 2, "E6"), (15, 1, "G6"),
]

for bar, chord in enumerate(PROGRESSION):
    t0 = bar * 4 * BEAT
    for beat, down, velocity in PATTERN:
        strum(chord, t0 + beat * BEAT, down, velocity)
    bass(BASS[chord], t0, 2 * BEAT)
    bass(BASS[chord], t0 + 2 * BEAT, 2 * BEAT)
    for eighth in range(8):
        shaker(t0 + eighth * BEAT / 2 + (0.03 if eighth % 2 else 0), eighth % 2 == 0)
for bar, beat, note in MELODY:
    glock(note, (bar * 4 + beat) * BEAT)

# Seamless loop: fold everything past the end back onto the start.
loop_len = int(LENGTH * RATE)
loop = track[:loop_len]
for i, s in enumerate(track[loop_len:]):
    loop[i % loop_len] += s

peak = max(abs(s) for s in loop) or 1
loop = [s / peak * 0.7 for s in loop]

os.makedirs(OUT_DIR, exist_ok=True)
target = os.path.join(OUT_DIR, "candy_shop_loop.wav")
with wave.open(target, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in loop))
print(f"{LENGTH:.1f}s loop -> {target}")
