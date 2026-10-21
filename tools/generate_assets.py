"""Tüm görsel ve ses dosyalarını assets/ klasörüne üretir.

    python3 tools/generate_assets.py

Not: Bu betik assets/ içindeki PNG ve WAV dosyalarının üzerine yazar.
Görselleri elle düzenlediysen tekrar çalıştırmadan önce yedek al.
"""
import math
import os
import random
import struct
import sys
import wave

sys.path.insert(0, os.path.dirname(__file__))

import art_creatures  # noqa: E402
import art_sprites  # noqa: E402
import art_tiles  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
RATE = 22050


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        data = b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples)
        w.writeframes(data)


def env(i, n, attack=0.005, release=None):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    rel = (1 - i / n) if release is None else math.exp(-t / release)
    return a * rel


def lowpass(samples, k):
    out, y = [], 0.0
    for s in samples:
        y += k * (s - y)
        out.append(y)
    return out


def sfx_break():
    rnd = random.Random(1)
    n = int(RATE * 0.22)
    noise = lowpass([rnd.uniform(-1, 1) for _ in range(n)], 0.25)
    return [(noise[i] * 0.9 + 0.6 * math.sin(2 * math.pi * 110 * i / RATE * (1 - i / n * 0.5)))
            * env(i, n, release=0.05) for i in range(n)]


def sfx_place():
    n = int(RATE * 0.15)
    return [0.8 * math.sin(2 * math.pi * (180 - 80 * i / n) * i / RATE) * env(i, n, release=0.04)
            for i in range(n)]


def sfx_pickup():
    n = int(RATE * 0.12)
    return [0.35 * math.sin(2 * math.pi * (700 + 900 * i / n) * i / RATE) * env(i, n) for i in range(n)]


def sfx_craft():
    out = []
    for freq, dur in ((660, 0.09), (880, 0.09), (1320, 0.22)):
        n = int(RATE * dur)
        out += [0.35 * (math.sin(2 * math.pi * freq * i / RATE) + 0.3 * math.sin(4 * math.pi * freq * i / RATE))
                * env(i, n, release=dur * 0.6) for i in range(n)]
    return out


def sfx_treasure():
    out = []
    for freq in (523, 659, 784, 1047, 1319):
        n = int(RATE * 0.08)
        out += [0.3 * math.sin(2 * math.pi * freq * i / RATE) * env(i, n, release=0.06) for i in range(n)]
    n = int(RATE * 0.4)
    out += [0.25 * math.sin(2 * math.pi * 1568 * i / RATE) * env(i, n, release=0.15) for i in range(n)]
    return out


def sfx_chat():
    n = int(RATE * 0.08)
    return [0.3 * math.sin(2 * math.pi * (1000 + 400 * i / n) * i / RATE) * env(i, n) for i in range(n)]


def sfx_warn():
    out = []
    for _ in range(2):
        n = int(RATE * 0.12)
        out += [0.3 * (1 if math.sin(2 * math.pi * 440 * i / RATE) > 0 else -1) * env(i, n) * 0.5 for i in range(n)]
        out += [0.0] * int(RATE * 0.06)
    return out


def sfx_bubble():
    n = int(RATE * 0.09)
    return [0.4 * math.sin(2 * math.pi * (300 + 1400 * (i / n) ** 2) * i / RATE) * env(i, n, release=0.03)
            for i in range(n)]


def sfx_shock():
    rnd = random.Random(9)
    n = int(RATE * 0.35)
    out = []
    for i in range(n):
        buzz = 1 if math.sin(2 * math.pi * 90 * i / RATE) > 0 else -1
        crackle = rnd.uniform(-1, 1) if rnd.random() < 0.35 else 0
        out.append((0.35 * buzz + 0.5 * crackle) * env(i, n, release=0.12))
    return out


def sfx_catch():
    rnd = random.Random(3)
    n = int(RATE * 0.25)
    splash = lowpass([rnd.uniform(-1, 1) for _ in range(n)], 0.3)
    return [(0.6 * splash[i] * env(i, n, release=0.06)
             + 0.3 * math.sin(2 * math.pi * (520 + 700 * i / n) * i / RATE) * env(i, n)) for i in range(n)]


def ambience():
    """Döngüye uygun, kısık su altı uğultusu (8 sn)."""
    rnd = random.Random(5)
    n = RATE * 8
    raw = [rnd.uniform(-1, 1) for _ in range(n)]
    lp = lowpass(lowpass(raw, 0.02), 0.05)
    out = []
    for i in range(n):
        t = i / n
        swell = 0.6 + 0.4 * math.sin(2 * math.pi * t * 2)
        out.append(lp[i] * 6.0 * swell + 0.04 * math.sin(2 * math.pi * 55 * i / RATE))
    # uçları yumuşak birleştir
    fade = RATE // 2
    for i in range(fade):
        k = i / fade
        out[i] = out[i] * k + out[n - fade + i] * (1 - k)
    return out[: n - fade]


def _render_loop(seconds, events, pads, drone=None, echo=(0.375, 0.45, 3), lp=0.25):
    """Döngüye uygun müzik: olaylar ve yankılar dairesel tampona yazılır."""
    n = int(RATE * seconds)
    buf = [0.0] * n

    def add(start, samples):
        for i, v in enumerate(samples):
            buf[(start + i) % n] += v

    for (t0, freq, dur, vol, kind) in events:
        m = int(RATE * dur)
        out = []
        for i in range(m):
            t = i / RATE
            e = min(1.0, t / 0.01) * math.exp(-t / (dur * 0.35))
            if kind == "bell":
                v = math.sin(2 * math.pi * freq * t) + 0.35 * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-t * 3)
            else:
                ph = (freq * t) % 1.0
                v = math.sin(2 * math.pi * freq * t) * 0.8 + (4 * abs(ph - 0.5) - 1) * 0.25
            out.append(v * e * vol)
        start = int(RATE * t0)
        add(start, out)
        d, fb, taps = echo
        for k in range(1, taps + 1):
            add(start + int(RATE * d * k), [x * (fb ** k) for x in out])
    for (t0, freqs, dur, vol) in pads:
        m = int(RATE * dur)
        start = int(RATE * t0)
        out = []
        for i in range(m):
            t = i / RATE
            a = min(1.0, t / (dur * 0.3), (dur - t) / (dur * 0.3))
            v = sum(math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 1.003 * t) for f in freqs)
            out.append(v / len(freqs) * a * vol)
        add(start, out)
    if drone:
        f, vol = drone
        for i in range(n):
            t = i / RATE
            buf[i] += vol * (math.sin(2 * math.pi * f * t) + 0.4 * math.sin(2 * math.pi * f * 1.5 * t)) \
                * (0.7 + 0.3 * math.sin(2 * math.pi * t / seconds * 2))
    # hafif alçak geçiren, dairesel (döngü dikişsiz)
    y = buf[-1]
    for _ in range(2):
        for i in range(n):
            y += lp * (buf[i] - y)
            buf[i] = y
    peak = max(abs(v) for v in buf) or 1.0
    return [v / peak * 0.6 for v in buf]


def note(name):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semis = names[name[0]] + (1 if "#" in name else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((semis - 9) / 12 + (octave - 4))


def music_surface():
    rnd = random.Random(21)
    beat = 60 / 76
    chords = [["C3", "E3", "G3", "B3"], ["A2", "C3", "E3", "G3"], ["F2", "A2", "C3", "E3"], ["G2", "B2", "D3", "E3"]]
    scale = ["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6"]
    bars = 16
    events, pads = [], []
    for b in range(bars):
        ch = chords[b % 4]
        pads.append((b * 4 * beat, [note(x) for x in ch], 4 * beat + 0.6, 0.5))
        for s16 in range(8):
            if rnd.random() < (0.55 if s16 % 2 == 0 else 0.25):
                nm = rnd.choice(scale[:5] if b % 4 != 3 else scale[2:])
                events.append((b * 4 * beat + s16 * beat / 2, note(nm), 1.4, 0.32, "bell"))
    return _render_loop(bars * 4 * beat, events, pads, drone=(note("C2"), 0.12), echo=(beat * 0.75, 0.4, 3))


def music_deep():
    rnd = random.Random(33)
    beat = 60 / 56
    chords = [["D2", "F2", "A2"], ["A#1", "D2", "F2"], ["G1", "A#1", "D2"], ["A1", "C#2", "E2"]]
    scale = ["D5", "F5", "A5", "C6", "D6"]
    bars = 12
    events, pads = [], []
    for b in range(bars):
        pads.append((b * 4 * beat, [note(x) for x in chords[b % 4]], 4 * beat + 1.0, 0.7))
        if rnd.random() < 0.7:
            events.append((b * 4 * beat + rnd.choice([0, 1, 2]) * beat, note(rnd.choice(scale)), 3.0, 0.25, "bell"))
    return _render_loop(bars * 4 * beat, events, pads, drone=(note("D1"), 0.25), echo=(beat, 0.5, 4), lp=0.15)


def main():
    os.makedirs(ROOT, exist_ok=True)
    os.makedirs(os.path.join(ROOT, "sfx"), exist_ok=True)
    art_tiles.build().save(os.path.join(ROOT, "tiles.png"))
    art_tiles.build_icons().save(os.path.join(ROOT, "icons.png"))
    base, suit = art_sprites.build_diver()
    base.save(os.path.join(ROOT, "diver_base.png"))
    suit.save(os.path.join(ROOT, "diver_suit.png"))
    os.makedirs(os.path.join(ROOT, "creatures"), exist_ok=True)
    for name, img in art_creatures.build_all().items():
        img.save(os.path.join(ROOT, "creatures", f"{name}.png"))
    sounds = dict(br=sfx_break, place=sfx_place, pickup=sfx_pickup, craft=sfx_craft,
                  treasure=sfx_treasure, chat=sfx_chat, warn=sfx_warn, bubble=sfx_bubble,
                  shock=sfx_shock, catch=sfx_catch,
                  ambience=ambience)
    for name, fn in sounds.items():
        fname = "break" if name == "br" else name
        write_wav(os.path.join(ROOT, "sfx", f"{fname}.wav"), fn())
    os.makedirs(os.path.join(ROOT, "music"), exist_ok=True)
    write_wav(os.path.join(ROOT, "music", "surface.wav"), music_surface())
    write_wav(os.path.join(ROOT, "music", "deep.wav"), music_deep())
    print("Varlıklar üretildi:", os.path.abspath(ROOT))


if __name__ == "__main__":
    main()
