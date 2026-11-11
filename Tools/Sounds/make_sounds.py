#!/usr/bin/env python3
"""Synthesises all Sweet Arrows sound effects from scratch (no samples, no licences needed).

Run:  python3 Tools/Sounds/make_sounds.py
Writes 16-bit mono WAV files to SweetArrows/Resources/Sounds/.
Soft and toy-like on purpose: squish, pop, a gentle bonk, xylophone tones, never a harsh error sound.
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "SweetArrows", "Resources", "Sounds")
random.seed(7)


def envelope(t, attack, decay):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def render(duration, fn, gain=0.6):
    n = int(duration * RATE)
    samples = [fn(i / RATE) for i in range(n)]
    peak = max(1e-9, max(abs(s) for s in samples))
    fade = int(0.004 * RATE)
    out = []
    for i, s in enumerate(samples):
        v = s / peak * gain
        if i > n - fade:
            v *= (n - i) / fade
        out.append(v)
    return out


def save(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


def sweep(f0, f1, duration):
    """Phase-continuous exponential pitch sweep."""
    k = math.log(f1 / f0) / duration
    def phase(t):
        return 2 * math.pi * f0 * (math.exp(k * t) - 1) / k
    return phase


def xylophone(freq, duration=0.5, gain=0.55):
    def fn(t):
        env = envelope(t, 0.002, 0.16)
        return env * (math.sin(2 * math.pi * freq * t)
                      + 0.35 * math.sin(2 * math.pi * freq * 3.93 * t) * math.exp(-t / 0.05)
                      + 0.15 * math.sin(2 * math.pi * freq * 9.2 * t) * math.exp(-t / 0.02))
    return render(duration, fn, gain)


def concat(*parts, gap=0.0):
    out = []
    for p in parts:
        out.extend(p)
        out.extend([0.0] * int(gap * RATE))
    return out


def mix_at(base, part, offset):
    start = int(offset * RATE)
    need = start + len(part)
    if len(base) < need:
        base = base + [0.0] * (need - len(base))
    for i, s in enumerate(part):
        base[start + i] += s
    return base


def main():
    os.makedirs(OUT, exist_ok=True)

    tap_phase = sweep(1100, 700, 0.05)
    save("tap", render(0.05, lambda t: envelope(t, 0.001, 0.012) * math.sin(tap_phase(t)), 0.35))

    squish_phase = sweep(520, 170, 0.16)
    save("squish", render(0.16, lambda t: envelope(t, 0.004, 0.05)
                          * (math.sin(squish_phase(t)) + 0.25 * (random.random() * 2 - 1) * math.exp(-t / 0.02)), 0.5))

    pop_phase = sweep(320, 1100, 0.09)
    save("pop", render(0.12, lambda t: envelope(t, 0.001, 0.03)
                       * (math.sin(pop_phase(t)) + 0.3 * math.sin(2 * pop_phase(t))), 0.6))

    bonk_phase = sweep(210, 150, 0.18)
    save("bonk", render(0.18, lambda t: envelope(t, 0.002, 0.045)
                        * (math.sin(bonk_phase(t)) + 0.4 * math.sin(2.7 * bonk_phase(t)) * math.exp(-t / 0.02)), 0.5))

    def crack(t):
        noise = random.random() * 2 - 1
        return envelope(t, 0.001, 0.025) * noise * (0.6 + 0.4 * math.sin(2 * math.pi * 2400 * t))
    save("crack", render(0.12, crack, 0.4))

    def melt(t):
        return envelope(t, 0.02, 0.12) * sum(math.sin(2 * math.pi * f * t) / (k + 1)
                                             for k, f in enumerate([1568, 2093, 2637]))
    save("melt", render(0.35, melt, 0.3))

    # Rising xylophone tones for successive pops (C major pentatonic).
    for index, freq in enumerate([523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.66, 1318.51], start=1):
        save(f"combo{index}", xylophone(freq))

    win = []
    for i, freq in enumerate([523.25, 659.25, 783.99, 1046.5]):
        win = mix_at(win, xylophone(freq, 0.6, 0.5), i * 0.11)
    win = mix_at(win, xylophone(1318.51, 0.9, 0.45), 0.5)
    save("win", render(len(win) / RATE, lambda t: win[min(int(t * RATE), len(win) - 1)], 0.6))

    lose = []
    lose = mix_at(lose, xylophone(659.25, 0.5, 0.4), 0)
    lose = mix_at(lose, xylophone(523.25, 0.5, 0.4), 0.18)
    lose = mix_at(lose, xylophone(392.0, 0.7, 0.4), 0.36)
    save("lose", render(len(lose) / RATE, lambda t: lose[min(int(t * RATE), len(lose) - 1)], 0.45))

    save("star", xylophone(1567.98, 0.45, 0.5))
    coin_a = xylophone(1975.53, 0.12, 0.4)
    coin = mix_at(coin_a, xylophone(2637.02, 0.35, 0.4), 0.06)
    save("coin", render(len(coin) / RATE, lambda t: coin[min(int(t * RATE), len(coin) - 1)], 0.4))


if __name__ == "__main__":
    main()
