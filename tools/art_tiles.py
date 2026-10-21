"""Karo atlası: satır = blok id, sütun 0-3 = varyant ya da animasyon karesi,
sütun 4 = üstü açık (üstünde su olan) hali."""
import math
import random

from PIL import Image

from art_common import (T, CLEAR, Canvas, hexc, ramp, with_alpha, mix, wrap_noise,
                        cobbles, clampi, disc)

AIR, SAND, ROCK, CORAL, KELP, GLASS, PEARL_ORE, ABYSS, BEDROCK, LAMP, OXYGEN, \
    BRICK, PLANK, CHEST, GLOWSHROOM, AQUARIUM = range(16)
ROWS = 16
COLS = 5

SAND_R = ramp("#a8854f", "#c4a46c", "#d8c08a", "#e8d6a4", "#f5e9c4")
ROCK_R = ramp("#262d37", "#363f4b", "#47525f", "#5a6674", "#6f7c8a", "#8895a2")
ABYSS_R = ramp("#0a0812", "#140f22", "#1e1733", "#2a2048", "#3a2d63")
BED_R = ramp("#050407", "#0c0a10", "#14111a", "#1d1925", "#272231")
ALGAE_R = ramp("#1d5c34", "#2a7d45", "#3aa05a", "#5cc777")
BIO_R = ramp("#0f4f63", "#1a8aa6", "#35c6e0", "#8ff0ff")
WOOD_R = ramp("#2e1b0f", "#4a2e1a", "#6a4326", "#8a5a34", "#a97445")
GOLD_R = ramp("#5c3f0c", "#946a16", "#cf9f2c", "#f2cf5c", "#fff1b0")
BRICK_R = ramp("#22323a", "#334a55", "#486672", "#62838f", "#86a7b2")
STEEL_R = ramp("#262d36", "#3d4753", "#5a6672", "#7e8a96", "#a8b3bd", "#d4dbe1")
CORAL_RAMPS = [
    ramp("#6e1c3d", "#a3335b", "#d65778", "#f2879f", "#ffc2cf"),   # pembe
    ramp("#6e2e10", "#ad501c", "#e47c35", "#f6a75e", "#ffd29a"),   # turuncu
    ramp("#37205e", "#58338d", "#8256bd", "#ab84de", "#d7c3f5"),   # mor
    ramp("#174f50", "#24787a", "#38a79d", "#6dd2c2", "#b4efe4"),   # turkuaz
]


def new():
    return Canvas(T, T)


# ---------------------------------------------------------------- doğal bloklar

def sand(variant, top=False):
    cv = new()
    nz = wrap_noise(11, T, 8)
    rnd = random.Random(100 + variant)
    for y in range(T):
        for x in range(T):
            v = nz[y][x]
            idx = 1 + int(v * 2.6)
            band = (y + 1.3 * math.sin(2 * math.pi * x / 16 * 2)) % 8
            if band < 1.0:
                idx += 1
            elif band < 2.0:
                idx -= 1
            cv.set(x, y, SAND_R[clampi(idx, 0, 4)])
    for _ in range(14):
        x, y = rnd.randrange(T), rnd.randrange(T)
        cv.set(x, y, SAND_R[0] if rnd.random() < 0.5 else SAND_R[4])
    if variant == 1:      # deniz kabuğu
        sx, sy = rnd.randint(3, 10), rnd.randint(4, 11)
        shell = ramp("#c96e84", "#f0a3b2", "#ffe1e6")
        for i, (dx, dy) in enumerate([(0, 1), (1, 0), (2, 0), (3, 0), (4, 1), (1, 1), (2, 1), (3, 1), (2, 2)]):
            cv.set(sx + dx, sy + dy, shell[2 if dy == 0 else (1 if dy == 1 else 0)])
        cv.set(sx + 2, sy + 3, shell[0])
    elif variant == 2:    # çakıl taşları
        for _ in range(2):
            px, py = rnd.randint(2, 12), rnd.randint(3, 12)
            disc(cv, px + 1, py + 1, 1.3, ROCK_R[2:6])
    elif variant == 3:    # minik deniz yıldızı
        sx, sy = rnd.randint(4, 10), rnd.randint(5, 10)
        star = ramp("#b8481e", "#f07a3a", "#ffb37a")
        for dx, dy in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 1), (-2, 1), (1, 2), (-1, 2), (0, -2)]:
            cv.set(sx + dx, sy + dy, star[1])
        cv.set(sx, sy, star[2])
        cv.set(sx, sy - 1, star[2])
    if top:
        _wavy_top(cv, seed=7, rim=SAND_R[4], rim2=SAND_R[3], depth=1)
    return cv


def _wavy_top(cv, seed, rim, rim2, depth=1):
    """Üst kenarı dalgalı kesip açık renkli bir sırt çizer."""
    rnd = random.Random(seed)
    phase = rnd.uniform(0, 6.28)
    for x in range(T):
        h = int(round(depth * (0.5 + 0.5 * math.sin(2 * math.pi * x / 16 + phase))))
        for y in range(h):
            cv.set(x, y, CLEAR)
        cv.set(x, h, rim)
        cv.set(x, h + 1, rim2)


def stone_base(cv, ramp_, seed, count, crack_idx=0, base_lo=2, base_hi=3, rough=0.25):
    cells, pts = cobbles(seed, count)
    rnd = random.Random(seed * 7)
    base = [rnd.randint(base_lo, base_hi) for _ in pts]
    n = len(ramp_)
    for y in range(T):
        for x in range(T):
            i, d1, d2, dx, dy = cells[(x, y)]
            if d2 - d1 < 1.05:
                cv.set(x, y, ramp_[crack_idx])
                continue
            r = max(2.0, d2 * 0.9)
            lit = -(dx + dy) / (r * 1.3)
            idx = base[i] + lit * 1.6 + rnd.uniform(-rough, rough)
            cv.set(x, y, ramp_[clampi(int(round(idx)), crack_idx + 1, n - 1)])
    return cells


def rock(variant, top=False):
    cv = new()
    stone_base(cv, ROCK_R, seed=21, count=6)
    rnd = random.Random(200 + variant)
    if variant == 1:      # liken lekeleri
        lichen = ramp("#3d6b53", "#5b9a6c", "#8cc78e")
        for _ in range(2):
            cx, cy = rnd.randint(2, 13), rnd.randint(2, 13)
            for _ in range(5):
                cv.set(cx + rnd.randint(-1, 1), cy + rnd.randint(-1, 1), lichen[rnd.randint(0, 2)])
    elif variant == 2:    # fosil
        cx, cy = rnd.randint(4, 10), rnd.randint(4, 10)
        fos = hexc("#b7c0c7")
        for a in range(0, 330, 30):
            r = 0.6 + a / 160
            cv.set(int(round(cx + r * math.cos(math.radians(a)))),
                   int(round(cy + r * math.sin(math.radians(a)))), fos)
    elif variant == 3:    # parlak kuvars
        for _ in range(3):
            x, y = rnd.randint(1, 14), rnd.randint(1, 14)
            cv.set(x, y, hexc("#c9d6e2"))
            cv.set(x + 1, y, hexc("#9fb0c0"))
    if top:
        _algae_top(cv, ALGAE_R, seed=31)
    return cv


def _algae_top(cv, r, seed, dots=None):
    rnd = random.Random(seed)
    phase = rnd.uniform(0, 6.28)
    for x in range(T):
        h = int(round(0.5 + 0.5 * math.sin(2 * math.pi * x / 16 * 2 + phase)))
        for y in range(h):
            cv.set(x, y, CLEAR)
        depth = 2 + (1 if (x * 7 + 3) % 5 == 0 else 0) + (2 if (x * 13) % 11 == 0 else 0)
        for k in range(depth):
            y = h + k
            idx = 3 if k == 0 else (2 if k == 1 else 1)
            cv.set(x, y, r[idx])
        if dots and (x * 5) % 7 == 0:
            cv.set(x, h + depth, dots)


def abyss(variant, top=False):
    cv = new()
    stone_base(cv, ABYSS_R, seed=41, count=5, base_lo=2, base_hi=3, rough=0.35)
    rnd = random.Random(400 + variant)
    crystal = ramp("#5b3fc4", "#8b6cff", "#d0c2ff")
    n = 2 + variant
    for _ in range(n):
        x, y = rnd.randint(1, 14), rnd.randint(1, 14)
        cv.set(x, y, crystal[1])
        if rnd.random() < 0.5:
            cv.set(x, y - 1, crystal[2])
            cv.set(x + 1, y, crystal[0])
    if top:
        _algae_top(cv, BIO_R, seed=43, dots=BIO_R[3])
    return cv


def bedrock(variant):
    cv = new()
    stone_base(cv, BED_R, seed=51 + variant, count=4, base_lo=1, base_hi=3, rough=0.5)
    rnd = random.Random(500 + variant)
    for _ in range(6):
        cv.set(rnd.randrange(T), rnd.randrange(T), BED_R[4])
    return cv


def coral(variant):
    cv = new()
    r = CORAL_RAMPS[variant]
    # taban dolgu
    for y in range(T):
        for x in range(T):
            cv.set(x, y, r[1] if (x + y) % 3 else r[0])
    if variant == 3:      # beyin mercanı: kıvrımlı çizgiler
        for y in range(T):
            for x in range(T):
                v = math.sin(x * 0.9 + math.sin(y * 0.7) * 2.2) + math.sin(y * 0.55 + x * 0.2)
                if v > 0.55:
                    cv.set(x, y, r[3])
                elif v > 0.1:
                    cv.set(x, y, r[2])
                elif v < -1.1:
                    cv.set(x, y, r[0])
    else:                 # polip tümsekleri
        rnd = random.Random(300 + variant)
        spots = []
        for gy in range(3):
            for gx in range(3):
                spots.append((gx * 5.5 + 2.6 + rnd.uniform(-0.8, 0.8) + (1.5 if gy % 2 else 0),
                              gy * 5.5 + 2.6 + rnd.uniform(-0.8, 0.8)))
        for (cx, cy) in spots:
            cx %= 16
            disc(cv, cx, cy, 2.6, r[1:], base_idx=1.6)
            cv.set(int(cx), int(cy), r[0])
            cv.set(int(cx) - 1, int(cy) - 2, r[4])
    # alt kenar gölgesi
    for x in range(T):
        cv.set(x, 15, mix(cv.get(x, 15), r[0], 0.6))
    return cv


def kelp(frame):
    cv = new()
    stalk = ALGAE_R
    phase = frame * math.pi / 2

    def off(y):
        return int(round(1.6 * math.sin(2 * math.pi * y / 16 + phase)))
    for y in range(T):
        x = 7 + off(y)
        cv.set(x, y, stalk[1])
        cv.set(x + 1, y, stalk[2])
    for (ly, side) in ((3, -1), (11, 1)):
        bx = 7 + off(ly) + (0 if side < 0 else 1)
        for k in range(1, 6):
            yy = ly + (k // 2) - 1 + (1 if k == 5 else 0)
            xx = bx + side * k + int(round(math.sin(phase + k * 0.6) * 0.6))
            cv.set(xx, yy, stalk[2] if k < 4 else stalk[3])
            cv.set(xx, yy + 1, stalk[1] if k < 5 else CLEAR)
        cv.set(bx + side, ly - 1, hexc("#b9c94a"))     # hava kesesi
    return cv


def glass(variant):
    cv = new()
    fill = (170, 225, 245, 50)
    for y in range(T):
        for x in range(T):
            cv.set(x, y, fill)
    edge = (215, 245, 255, 220)
    edge2 = (120, 180, 205, 200)
    for i in range(T):
        cv.set(i, 0, edge)
        cv.set(0, i, edge)
        cv.set(i, 15, edge2)
        cv.set(15, i, edge2)
    shine = (255, 255, 255, 170)
    k = [2, 4, 3, 5][variant]
    for d in range(k + 2):
        cv.set(2 + d, 2 + k + 1 - d, shine)
    for d in range(2):
        cv.set(3 + k + d, 3 + k - d + 1, (255, 255, 255, 110))
    if variant == 2:
        cv.set(11, 11, (255, 255, 255, 120))
        cv.set(12, 12, (255, 255, 255, 80))
    return cv


def pearl_ore(variant):
    cv = new()
    stone_base(cv, ROCK_R, seed=21, count=6)
    rnd = random.Random(600 + variant)
    pearl = ramp("#8e86a6", "#c9c2e0", "#efeaff", "#ffffff")
    placed = []
    for _ in range(3):
        for _ in range(20):
            x, y = rnd.randint(3, 12), rnd.randint(3, 12)
            if all(abs(x - a) + abs(y - b) > 5 for a, b in placed):
                placed.append((x, y))
                break
    for (x, y) in placed:
        cv.set(x, y + 2, ROCK_R[0])
        cv.set(x + 1, y + 2, ROCK_R[0])
        disc(cv, x + 1, y + 1, 1.6, pearl)
        cv.set(x, y, pearl[3])
    return cv


def lamp(frame):
    cv = new()
    brass = GOLD_R
    glow = [0.75, 1.0, 0.85, 0.95][frame]
    core = mix(hexc("#ffb43a"), hexc("#fff8d6"), glow)
    halo = mix(hexc("#a8641a"), hexc("#ffd36a"), glow)
    # gövde camı
    for y in range(3, 13):
        for x in range(3, 13):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
            cv.set(x, y, core if d < 2.6 else (halo if d < 4.6 else mix(halo, hexc("#5a3a12"), 0.6)))
    # kafes
    for y in range(3, 13):
        for x in (3, 7, 8, 12):
            cv.set(x, y, brass[1] if x in (3, 12) else with_alpha(brass[2], 180))
    for x in range(2, 14):
        cv.set(x, 2, brass[3])
        cv.set(x, 13, brass[2])
    for x in range(4, 12):
        cv.set(x, 1, brass[2])
        cv.set(x, 14, brass[1])
    cv.set(7, 0, brass[1])
    cv.set(8, 0, brass[1])
    for x in range(5, 11):
        cv.set(x, 15, brass[0])
    cv.set(5, 4, (255, 255, 255, 200))
    return cv


def oxygen(frame):
    cv = new()
    s = STEEL_R
    for y in range(2, 16):
        for x in range(2, 14):
            t = (x - 2) / 11
            idx = int(round(4.2 - abs(t - 0.32) * 7))
            cv.set(x, y, s[clampi(idx, 0, 5)])
    for x in range(3, 13):
        cv.set(x, 1, s[3])
    for x in range(2, 14):
        cv.set(x, 15, s[0])
        cv.set(x, 14, s[1])
    # valf
    for x in range(6, 10):
        cv.set(x, 0, hexc("#d23a3a"))
    cv.set(7, 1, hexc("#8a1f1f"))
    # şerit
    for x in range(2, 14):
        cv.set(x, 12, hexc("#f2f2f2") if x % 2 else hexc("#3aa0d8"))
    # pencere ve kabarcıklar
    win = ramp("#0b3d57", "#145f86", "#1f8fc0", "#59c8f0")
    for y in range(4, 11):
        for x in range(5, 11):
            cv.set(x, y, win[1] if x > 6 else win[2])
    for x in range(5, 11):
        cv.set(x, 3, s[1])
        cv.set(x, 11, s[4])
    for y in range(4, 11):
        cv.set(4, y, s[1])
        cv.set(11, y, s[4])
    for i, bx in enumerate((6, 8, 9)):
        by = 10 - ((frame * 2 + i * 3) % 7)
        cv.set(bx, by, win[3])
        if by + 1 <= 10:
            cv.set(bx, by + 1, (220, 250, 255, 255) if i == 1 else win[3])
    return cv


def brick(variant):
    cv = new()
    r = BRICK_R
    mortar = hexc("#18232a")
    rnd = random.Random(700 + variant)
    for row in range(4):
        y0 = row * 4
        offset = 0 if row % 2 == 0 else 4
        for bi in range(-1, 3):
            x0 = bi * 8 + offset
            base = rnd.randint(2, 3)
            for y in range(y0, y0 + 4):
                for x in range(x0, x0 + 8):
                    if not (0 <= x < T):
                        continue
                    if y == y0 + 3 or x == x0 + 7:
                        cv.set(x, y, mortar)
                    elif y == y0:
                        cv.set(x, y, r[base + 1])
                    elif y == y0 + 2:
                        cv.set(x, y, r[base - 1])
                    else:
                        cv.set(x, y, r[base] if rnd.random() > 0.15 else r[base - 1])
    if variant == 1:      # midye/barnacle
        barn = ramp("#7f8a8e", "#c3ccd0", "#eef3f5")
        for _ in range(4):
            x, y = rnd.randint(1, 13), rnd.randint(1, 13)
            cv.set(x, y, barn[1])
            cv.set(x + 1, y, barn[2])
            cv.set(x, y + 1, barn[0])
    elif variant == 2:    # yosun
        for x in range(0, 9):
            cv.set(x, 12 + (x % 3 == 0), ALGAE_R[2])
            cv.set(x, 13, ALGAE_R[1])
    elif variant == 3:    # çatlak
        x, y = 9, 1
        for _ in range(9):
            cv.set(x, y, mortar)
            y += 1
            x += rnd.choice([-1, 0, 1])
    return cv


def plank(variant):
    cv = new()
    r = WOOD_R
    rnd = random.Random(800 + variant)
    for p in range(3):
        y0 = p * 5 + (1 if p else 0)
        shade = rnd.randint(2, 3)
        for y in range(y0, min(y0 + 5, T)):
            for x in range(T):
                if y == y0 + 4 or (p == 0 and y == 4):
                    cv.set(x, y, r[0])
                    continue
                grain = math.sin(x * 0.7 + y * 2.1 + p * 3) > 0.7
                idx = shade - (1 if grain else 0) + (1 if y == y0 else 0)
                cv.set(x, y, r[clampi(idx, 0, 4)])
        nail = hexc("#9aa3a8")
        cv.set(1, y0 + 2 if p else 2, nail)
        cv.set(14, y0 + 2 if p else 2, nail)
    for y in range(T):
        cv.set(15, y, mix(cv.get(15, y), r[0], 0.5))
    if variant in (1, 3):
        for _ in range(6 if variant == 1 else 3):
            x, y = rnd.randint(0, 15), rnd.randint(0, 15)
            cv.set(x, y, ALGAE_R[rnd.randint(1, 2)])
    if variant == 2:
        for x in range(5, 10):
            cv.set(x, 7, r[0])
    return cv


def chest(variant):
    cv = new()
    w, g = WOOD_R, GOLD_R
    for y in range(3, 15):
        for x in range(1, 15):
            if y <= 6:
                # yuvarlak kapak
                if (y == 3 and (x < 3 or x > 12)):
                    continue
                cv.set(x, y, w[3] if y == 3 else (w[2] if y < 6 else w[1]))
            else:
                cv.set(x, y, w[2] if y < 13 else w[1])
    for x in range(1, 15):
        cv.set(x, 7, w[0])
        cv.set(x, 14, w[0])
    for y in range(3, 15):
        for x in (3, 12):
            cv.set(x, y, g[2] if y not in (7,) else g[1])
            cv.set(x + 1, y, g[3] if y < 7 else g[2])
    # kilit
    for y in range(6, 11):
        for x in range(7, 9):
            cv.set(x, y, g[3])
    cv.set(7, 8, g[0])
    cv.set(8, 8, g[0])
    cv.set(7, 6, g[4])
    for x in range(2, 14):
        cv.set(x, 2, w[4] if 3 <= x <= 12 else CLEAR)
    cv.outline(hexc("#1c1009"))
    if variant == 1:
        for x, y in ((2, 12), (13, 11), (10, 13)):
            cv.set(x, y, ALGAE_R[2])
    return cv


def glowshroom(frame):
    cv = new()
    pulse = [0.55, 0.8, 1.0, 0.8][frame]
    stem = ramp("#7c8f99", "#b6c9d1", "#e1eef2")
    for (cx, base, h, rad) in ((5, 15, 7, 3.2), (11, 15, 4, 2.3), (8, 15, 2, 1.6)):
        for y in range(base - h + 1, base + 1):
            cv.set(cx, y, stem[1])
            cv.set(cx + 1, y, stem[2] if y % 3 else stem[0])
        cy = base - h
        for y in range(int(cy - rad), int(cy) + 1):
            for x in range(int(cx - rad), int(cx + rad) + 2):
                dx = x + 0.5 - (cx + 1)
                dy = (y + 0.5 - cy) * 1.6
                if math.hypot(dx, dy) <= rad + 0.4:
                    t = 0.35 + 0.65 * pulse
                    idx = clampi(int(round(1 + t * 2 - dy * 0.15)), 0, 3)
                    cv.set(x, y, BIO_R[idx])
        cv.set(int(cx), int(cy - rad * 0.6), mix(BIO_R[3], hexc("#ffffff"), pulse))
    return cv


def aquarium(variant):
    """Akvaryum: cam kutu, kum taban, su. Canlı oyunda kodla içine çizilir."""
    cv = new()
    water = [(60, 150, 210, 150), (80, 175, 230, 150)]
    for y in range(2, 14):
        for x in range(1, 15):
            cv.set(x, y, water[0] if y > 7 else water[1])
    for x in range(1, 15):
        cv.set(x, 13, SAND_R[2])
        cv.set(x, 12, SAND_R[3] if x % 3 else SAND_R[1])
    # minik yosun
    for (x, y) in ((3, 11), (3, 10), (4, 9), (12, 11), (12, 10)):
        cv.set(x, y, ALGAE_R[2])
    frame = STEEL_R
    for x in range(0, 16):
        cv.set(x, 0, frame[3])
        cv.set(x, 1, frame[2])
        cv.set(x, 14, frame[2])
        cv.set(x, 15, frame[1])
    for y in range(0, 16):
        cv.set(0, y, frame[2])
        cv.set(15, y, frame[1])
    cv.set(2, 3, (255, 255, 255, 180))
    cv.set(3, 3, (255, 255, 255, 120))
    cv.set(2, 4, (255, 255, 255, 120))
    return cv


# ---------------------------------------------------------------- atlas

def build():
    sheet = Image.new("RGBA", (T * COLS, T * ROWS), CLEAR)

    def put(row, col, cv):
        cv.paste_into(sheet, col * T, row * T)

    for v in range(4):
        put(SAND, v, sand(v))
        put(ROCK, v, rock(v))
        put(CORAL, v, coral(v))
        put(KELP, v, kelp(v))
        put(GLASS, v, glass(v))
        put(PEARL_ORE, v, pearl_ore(v))
        put(ABYSS, v, abyss(v))
        put(BEDROCK, v, bedrock(v))
        put(LAMP, v, lamp(v))
        put(OXYGEN, v, oxygen(v))
        put(BRICK, v, brick(v))
        put(PLANK, v, plank(v))
        put(CHEST, v, chest(v % 2))
        put(GLOWSHROOM, v, glowshroom(v))
        put(AQUARIUM, v, aquarium(v))
    put(SAND, 4, sand(0, top=True))
    put(ROCK, 4, rock(0, top=True))
    put(ABYSS, 4, abyss(0, top=True))
    return sheet


def build_icons():
    """HUD simgeleri: 0 inci, 1 tüp, 2 ağ, 3 palet, 4 fener kaskı, 5 büyük fileye."""
    sheet = Image.new("RGBA", (T * 8, T), CLEAR)
    cv = new()
    pearl = ramp("#6f6890", "#a59dc4", "#d8d2f0", "#f4f1ff", "#ffffff")
    disc(cv, 8, 8.5, 5.2, pearl, base_idx=2.2)
    cv.set(5, 5, pearl[4])
    cv.set(6, 5, pearl[4])
    cv.set(5, 6, pearl[4])
    cv.outline(hexc("#2a2440"))
    cv.paste_into(sheet, 0, 0)

    cv = new()
    tank = ramp("#6b4a07", "#a87b12", "#e0b020", "#ffd95a", "#fff1b0")
    for y in range(3, 15):
        for x in range(4, 11):
            t = (x - 4) / 6
            cv.set(x, y, tank[clampi(int(round(3.6 - abs(t - 0.3) * 5)), 0, 4)])
    for x in range(5, 10):
        cv.set(x, 2, tank[3])
    for x in range(6, 9):
        cv.set(x, 1, hexc("#7e8a96"))
    cv.set(7, 0, hexc("#5a6672"))
    plus = hexc("#4cf08a")
    for d in range(-2, 3):
        cv.set(12 + d, 5, plus)
        cv.set(12, 5 + d, plus)
    cv.outline(hexc("#1a1406"))
    cv.paste_into(sheet, T, 0)

    cv = new()     # ağ (kepçe)
    wood = ramp("#4a2e1a", "#8a5a34", "#b98552")
    for i in range(7):
        cv.set(1 + i, 14 - i, wood[1])
        cv.set(2 + i, 14 - i, wood[2])
    net = (220, 235, 240, 255)
    rim = hexc("#c9d2d8")
    cx, cy, r = 10.5, 5.0, 4.6
    for a in range(0, 360, 12):
        cv.set(int(round(cx + r * math.cos(math.radians(a)))), int(round(cy + r * math.sin(math.radians(a)))), rim)
    for y in range(1, 10):
        for x in range(6, 16):
            if math.hypot(x + 0.5 - cx, y + 0.5 - cy) < r - 0.6 and (x + y) % 2 == 0:
                cv.set(x, y, (net[0], net[1], net[2], 160))
    cv.outline(hexc("#1a1406"))
    cv.paste_into(sheet, T * 2, 0)

    cv = new()     # hızlı palet: iki palet
    fin = ramp("#0f1a2c", "#1c3352", "#2f5f94", "#4f8fd0", "#8cc6ff")
    for k, ox in enumerate((1, 8)):
        for y in range(3, 15):
            w = 2 + (y - 3) // 3
            for x in range(ox + 3 - w // 2, ox + 3 + (w + 1) // 2):
                cv.set(x, y, fin[2 + (1 if x == ox + 3 - w // 2 else 0)] if y > 4 else fin[1])
        for y in range(1, 4):
            cv.set(ox + 3, y, fin[0])
            cv.set(ox + 2, y, fin[1])
        cv.set(ox + 3, 13, fin[4])
    cv.outline(hexc("#05080f"))
    cv.paste_into(sheet, T * 3, 0)

    cv = new()     # güçlü fener: kask + ışık
    helm = ramp("#6b4a07", "#a87b12", "#e0b020", "#ffd95a")
    disc(cv, 7, 9, 5.5, helm, base_idx=2)
    for x in range(1, 14):
        cv.set(x, 13, helm[0])
        cv.set(x, 14, CLEAR)
        cv.set(x, 15, CLEAR)
    for y in range(13, 16):
        for x in range(0, 15):
            if y > 13:
                cv.set(x, y, CLEAR)
    disc(cv, 7, 7, 2.0, ramp("#fff1b0", "#ffffff", "#ffffff"))
    beam = (255, 245, 180, 150)
    for i in range(1, 5):
        for d in range(-i // 2, i // 2 + 1):
            cv.set(9 + i, 7 + d - 1, beam)
    cv.outline(hexc("#1a1406"))
    cv.paste_into(sheet, T * 4, 0)

    cv = new()     # büyük fileye: dolu file torba
    rope = hexc("#c9d2d8")
    for y in range(5, 15):
        half = 3 + (y - 5) // 2 if y < 12 else 7 - (y - 12)
        for x in range(8 - half, 8 + half):
            if (x + y) % 2 == 0:
                cv.set(x, y, (220, 235, 240, 220))
    disc(cv, 7, 10, 2.2, ramp("#9c3a08", "#e0641a", "#ff8c3a"))
    cv.set(9, 9, hexc("#ffffff"))
    for x in range(4, 12):
        cv.set(x, 4, rope)
    for (x, y) in ((6, 1), (7, 2), (8, 2), (9, 1), (5, 3), (10, 3)):
        cv.set(x, y, rope)
    plus = hexc("#4cf08a")
    for d in range(-2, 3):
        cv.set(13 + d, 3, plus)
        cv.set(13, 3 + d, plus)
    cv.outline(hexc("#1a1406"))
    cv.paste_into(sheet, T * 5, 0)
    return sheet


if __name__ == "__main__":
    build().save("/tmp/tiles_preview.png")
