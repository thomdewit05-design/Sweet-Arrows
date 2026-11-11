# Sound effects

All sound effects in `SweetArrows/Resources/Sounds/` are synthesised from scratch by
`Tools/Sounds/make_sounds.py` (sine waves, sweeps and noise). No samples or third-party
recordings are used, so there is no licence to track. Regenerate with:

    python3 Tools/Sounds/make_sounds.py

The background loop `SweetArrows/Resources/Music/candy_shop_loop.wav` (41.7 s, ukulele-lounge,
92 BPM) is generated the same way by `Tools/Sounds/make_music.py`: Karplus-Strong ukulele, soft
bass, glockenspiel and shaker. No samples, no licence. Regenerate with:

    python3 Tools/Sounds/make_music.py
