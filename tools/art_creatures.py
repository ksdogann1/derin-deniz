"""Gerçekçi (2x çözünürlüklü) deniz canlıları. Oyunda 0.5 ölçekle çizilir.

Balıkların çoğu ortak bir anatomi motoruyla üretilir: gövde profili, karşı
gölgeleme (sırt koyu, karın açık), pul dokusu, yanal çizgi, ışınlı yüzgeçler,
kuyruk tipi, göz ve solungaç kapağı. Kuyruk ve yüzgeçler karelerde salınır.
"""
import math
import random

from PIL import Image

from art_common import Canvas, CLEAR, hexc, mix, clampi

FRAMES = 4


def lerp(a, b, t):
    return a + (b - a) * t


def col(c, a=255):
    if isinstance(c, str):
        return hexc(c, a)
    return (c[0], c[1], c[2], a)


def shade(c, k):
    """k<1 koyulaştır, k>1 aç"""
    if k >= 1:
        return mix(c, (255, 255, 255, c[3]), min(1.0, k - 1))
    return mix(c, (0, 0, 0, c[3]), min(1.0, 1 - k))


# --------------------------------------------------------------------------
# Balık motoru
# --------------------------------------------------------------------------

def fish(spec, frame, W, H):
    """spec: gövde ve desen tanımı. Balık sağa bakar."""
    cv = Canvas(W, H)
    rnd = random.Random(spec.get("seed", 1))
    sway = [-1.0, 0.0, 1.0, 0.0][frame % 4]
    L = spec["length"]                 # gövde uzunluğu (kuyruk hariç)
    Hh = spec["height"]                # en yüksek yarı-yükseklik
    x0 = spec.get("x0", (W - L) * 0.62)   # gövdenin kuyruk tarafı
    cy = spec.get("cy", H / 2)
    peak = spec.get("peak", 0.6)       # en kalın yer (0 kuyruk .. 1 burun)
    belly = spec.get("belly", 1.0)
    hump = spec.get("hump", 1.0)
    snout = spec.get("snout", 0.5)     # burnun sivriliği (küçük = sivri)
    bend = spec.get("bend", 0.6) * sway

    def half(t):
        # t: 0 kuyruk sapı, 1 burun ucu
        if t <= peak:
            u = t / peak
            return Hh * (spec.get("stalk", 0.22) + (1 - spec.get("stalk", 0.22)) * math.sin(u * math.pi / 2) ** 1.2)
        u = (t - peak) / (1 - peak)
        return Hh * max(0.0, math.cos(u * math.pi / 2)) ** spec.get("nose", 0.75)

    def mid_y(t):
        return cy + bend * (1 - t) ** 2 * 2.0

    top, bot = {}, {}
    for xi in range(W):
        t = (xi + 0.5 - x0) / L
        if 0 <= t <= 1:
            h = half(t)
            m = mid_y(t)
            top[xi] = m - h * hump
            bot[xi] = m + h * belly

    brnd = random.Random(spec.get("seed", 1) * 31)
    blotches = [(brnd.uniform(x0 + L * 0.1, x0 + L * 0.85), brnd.uniform(cy - Hh * 0.8, cy + Hh * 0.8),
                 brnd.uniform(1.2, 3.2)) for _ in range(int(L * Hh / 18))]
    dorsal = col(spec["dorsal"])
    ventral = col(spec["ventral"])
    side = col(spec.get("side", mix(dorsal, ventral, 0.5)))
    fin_c = col(spec.get("fin", shade(dorsal, 0.9)), spec.get("fin_alpha", 210))

    # --- yüzgeçler (gövdenin arkasında)
    def fin_poly(pts, color, rays=True):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 2):
            for x in range(int(min(xs)), int(max(xs)) + 2):
                if _inside(pts, x + 0.5, y + 0.5):
                    c = color
                    if rays and (x + y) % 3 == 0:
                        c = shade(color, 1.18)
                    cv.put(x, y, c)

    # kuyruk
    tx = x0
    ty = mid_y(0)
    tail = spec.get("tail", "fork")
    ts = spec.get("tail_size", Hh * 1.3)
    sw = sway * ts * 0.25
    if tail == "fork":
        fin_poly([(tx + 2, ty - 1), (tx - ts * 0.9, ty - ts + sw), (tx - ts * 0.45, ty + sw * 0.5),
                  (tx - ts * 0.9, ty + ts + sw), (tx + 2, ty + 1)], fin_c)
    elif tail == "lunate":
        fin_poly([(tx + 2, ty - 1), (tx - ts * 0.7, ty - ts * 1.1 + sw), (tx - ts * 0.35, ty + sw * 0.5),
                  (tx - ts * 0.7, ty + ts * 1.1 + sw), (tx + 2, ty + 1)], fin_c)
    elif tail == "round":
        for a in range(-60, 61, 4):
            r = ts * 0.85
            px = tx - math.cos(math.radians(a)) * r
            py = ty + math.sin(math.radians(a)) * r + sw * (1 - abs(a) / 60)
            fin_poly([(tx + 1, ty - 2), (px, py - 2), (px - 1, py + 2), (tx + 1, ty + 2)], fin_c, rays=False)
    elif tail == "truncate":
        fin_poly([(tx + 2, ty - Hh * 0.9), (tx - ts * 0.35, ty - Hh * 1.1 + sw), (tx - ts * 0.35, ty + Hh * 1.1 + sw),
                  (tx + 2, ty + Hh * 0.9)], fin_c)
    elif tail == "shark":
        fin_poly([(tx + 3, ty - 2), (tx - ts * 0.6, ty - ts * 1.3 + sw), (tx - ts * 0.2, ty + sw * 0.3),
                  (tx - ts * 0.45, ty + ts * 0.6 + sw), (tx + 3, ty + 2)], fin_c, rays=False)

    # sırt yüzgeci
    for (a, b, hgt) in spec.get("dorsal_fins", [(0.35, 0.75, 0.6)]):
        xa, xb = x0 + a * L, x0 + b * L
        ya = top.get(int(xa), cy - Hh)
        yb = top.get(int(xb), cy - Hh)
        hh = Hh * hgt
        if spec.get("dorsal_spiky"):
            pts = [(xa, ya + 1)]
            n = 5
            for i in range(n + 1):
                xx = lerp(xa, xb, i / n)
                yy = top.get(int(xx), ya) - (hh if i % 2 == 0 else hh * 0.55)
                pts.append((xx, yy))
            pts.append((xb, yb + 1))
            fin_poly(pts, fin_c)
        else:
            fin_poly([(xa, ya + 1), (lerp(xa, xb, 0.25), ya - hh), (xb, yb - hh * 0.25), (xb, yb + 1)], fin_c)
    # karın (anal) yüzgeci
    for (a, b, hgt) in spec.get("anal_fins", [(0.2, 0.45, 0.4)]):
        xa, xb = x0 + a * L, x0 + b * L
        ya = bot.get(int(xa), cy + Hh)
        yb = bot.get(int(xb), cy + Hh)
        hh = Hh * hgt
        fin_poly([(xa, ya - 1), (lerp(xa, xb, 0.3), ya + hh), (xb, yb + hh * 0.2), (xb, yb - 1)], fin_c)

    # --- gövde
    for xi, yt in top.items():
        yb = bot[xi]
        t = (xi + 0.5 - x0) / L
        for yi in range(int(math.floor(yt)), int(math.ceil(yb)) + 1):
            fy = yi + 0.5
            if fy < yt or fy > yb:
                continue
            v = (fy - yt) / max(yb - yt, 0.01)          # 0 sırt .. 1 karın
            if v < 0.5:
                c = mix(dorsal, side, v / 0.5)
            else:
                c = mix(side, ventral, (v - 0.5) / 0.5)
            # yuvarlaklık: üstte ışık, altta gölge
            light = 1.0 + 0.18 * (1 - abs(v - 0.3) * 2.2) - 0.18 * max(0, v - 0.8) * 5
            c = shade(c, clampf(light, 0.6, 1.25))
            # pul dokusu: hafif, düzensiz noktalar
            if spec.get("scales", True) and 0.12 < v < 0.85 and (xi * 7 + yi * 13 + (xi // 3) * 5) % 9 == 0:
                c = shade(c, 0.9)
            elif spec.get("scales", True) and 0.12 < v < 0.85 and (xi * 5 + yi * 11) % 13 == 0:
                c = shade(c, 1.08)
            # desenler
            for st in spec.get("vstripes", []):
                cx_, w_, sc = st
                if abs(t - cx_) * L < w_ / 2:
                    edge = abs(t - cx_) * L > w_ / 2 - 1
                    c = col(sc) if not edge else shade(col(sc), 0.6)
            for hs in spec.get("hstripes", []):
                vv, w_, sc = hs[:3]
                t0, t1 = (hs[3], hs[4]) if len(hs) > 3 else (0.0, 1.0)
                if abs(v - vv) < w_ and t0 <= t <= t1:
                    c = mix(c, col(sc), 0.85)
            if spec.get("mottle"):
                for (bx, by, br) in blotches:
                    if (xi - bx) ** 2 + (yi - by) ** 2 < br * br:
                        c = mix(c, col(spec["mottle"]), 0.5)
                        break
            cv.put(xi, yi, c)
        # yanal çizgi
        if spec.get("lateral", True) and 0.1 < t < 0.85:
            ly = int(lerp(yt, yb, 0.38))
            cv.put(xi, ly, mix(cv.get(xi, ly), shade(side, 1.3), 0.5))
    # benekler
    for _ in range(spec.get("spots", 0)):
        xi = rnd.choice(list(top.keys()))
        t = (xi - x0) / L
        if not 0.15 < t < 0.85:
            continue
        yi = int(lerp(top[xi], bot[xi], rnd.uniform(0.15, 0.7)))
        cv.put(xi, yi, col(spec.get("spot_color", "#202020")))
        cv.put(xi + 1, yi, col(spec.get("spot_color", "#202020")))
    # göğüs yüzgeci (gövdenin önünde, salınır)
    px = x0 + L * spec.get("pec_at", 0.7)
    py = lerp(top.get(int(px), cy), bot.get(int(px), cy), 0.6)
    pl = Hh * spec.get("pec", 0.7)
    pa = math.radians(150 + sway * 15)
    fin_poly([(px, py - 1), (px + math.cos(pa) * pl, py + math.sin(pa) * pl * 0.5 - pl * 0.25),
              (px + math.cos(pa + 0.4) * pl * 0.8, py + math.sin(pa + 0.4) * pl * 0.7), (px, py + 1)],
             col(spec.get("pec_color", fin_c), 190))

    # solungaç kapağı
    gx = x0 + L * spec.get("gill", 0.78)
    if int(gx) in top:
        for yi in range(int(top[int(gx)] + 2), int(bot[int(gx)] - 1)):
            k = (yi - top[int(gx)]) / max(bot[int(gx)] - top[int(gx)], 1)
            xx = int(gx + math.sin(k * math.pi) * 1.5)
            cv.put(xx, yi, mix(cv.get(xx, yi), shade(dorsal, 0.55), 0.5))
    # göz
    ex = x0 + L * spec.get("eye_at", 0.88)
    ey = lerp(top.get(int(ex), cy), bot.get(int(ex), cy), spec.get("eye_v", 0.38))
    er = spec.get("eye", max(1.6, Hh * 0.2))
    for yi in range(int(ey - er - 1), int(ey + er + 2)):
        for xi in range(int(ex - er - 1), int(ex + er + 2)):
            d = math.hypot(xi + 0.5 - ex, yi + 0.5 - ey)
            if d <= er:
                c = col(spec.get("iris", "#f0e6c0"))
                if d < er * 0.62:
                    c = col("#0a0a0a")
                cv.set(xi, yi, c)
            elif d <= er + 0.8:
                cv.put(xi, yi, col(shade(dorsal, 0.45)))
    cv.set(int(ex - er * 0.3), int(ey - er * 0.35), col("#ffffff"))
    # ağız
    mx = x0 + L - 1
    my = lerp(top.get(int(mx - 1), cy), bot.get(int(mx - 1), cy), spec.get("mouth_v", 0.6))
    for i in range(int(spec.get("mouth", 3))):
        cv.put(int(mx - i), int(my), col(shade(dorsal, 0.4)))
    # dış çizgi
    _outline(cv, col(shade(dorsal, 0.35)))
    return cv


def clampf(v, a, b):
    return max(a, min(b, v))


def _inside(pts, x, y):
    n = len(pts)
    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-6) + xi):
            inside = not inside
        j = i
    return inside


def _outline(cv, color):
    src = Canvas(cv.w, cv.h)
    for y in range(cv.h):
        for x in range(cv.w):
            if cv.alpha(x, y) > 40:
                src.set(x, y, (255, 255, 255, 255))
    cv.outline(color, src=src)


# --------------------------------------------------------------------------
# Tür tanımları (balık motoru)
# --------------------------------------------------------------------------

FISH_SPECS = {
    "sari_cerrah": dict(nose=0.6, W=48, H=36, length=34, height=13, peak=0.55, snout=0.35, dorsal="#e8b400",
                        side="#ffd21a", ventral="#ffe867", fin="#f0c000", tail="lunate", tail_size=10,
                        dorsal_fins=[(0.15, 0.85, 0.45)], anal_fins=[(0.15, 0.6, 0.45)], eye=2.4, mouth=2,
                        scales=False, lateral=False, hstripes=[(0.97, 0.03, "#fff6c0")], seed=1),
    "palyaco": dict(nose=0.6, W=40, H=26, length=28, height=9, peak=0.5, snout=0.5, dorsal="#e85a0c", side="#ff7a1c",
                    ventral="#ff9a40", fin="#e86010", tail="round", tail_size=8, dorsal_spiky=True,
                    dorsal_fins=[(0.3, 0.7, 0.5)], anal_fins=[(0.2, 0.45, 0.45)],
                    vstripes=[(0.82, 3.5, "#ffffff"), (0.5, 4.0, "#ffffff"), (0.12, 2.5, "#ffffff")],
                    eye=2.0, scales=False, lateral=False, seed=2),
    "mavi_kromis": dict(nose=0.85, W=40, H=24, length=28, height=8, peak=0.55, dorsal="#1450a8", side="#2b7de0",
                        ventral="#7cc0ff", fin="#2a6cc8", tail="fork", tail_size=8, eye=2.0, seed=3),
    "sardalya": dict(nose=1.0, W=44, H=20, length=34, height=6, peak=0.55, snout=0.45, dorsal="#2c5a86", side="#a8bccc",
                     ventral="#eef4f8", fin="#90a4b4", tail="fork", tail_size=7, dorsal_fins=[(0.45, 0.62, 0.7)],
                     anal_fins=[(0.15, 0.3, 0.3)], spots=6, spot_color="#1e3a56", eye=1.8, seed=4),
    "lufer": dict(nose=1.2, W=60, H=28, length=46, height=9, peak=0.5, snout=0.3, dorsal="#2f6a80", side="#7ea8b8",
                  ventral="#e6eef0", fin="#5a8a90", tail="fork", tail_size=10,
                  dorsal_fins=[(0.48, 0.62, 0.45), (0.2, 0.42, 0.55)], anal_fins=[(0.15, 0.38, 0.5)],
                  eye=2.2, mouth=5, mouth_v=0.55, seed=5),
    "cipura": dict(nose=0.8, W=52, H=36, length=38, height=13, peak=0.55, snout=0.4, hump=1.15, dorsal="#5a6e7a",
                   side="#b9c7cf", ventral="#eef2f4", fin="#7d8f9a", tail="fork", tail_size=11,
                   dorsal_fins=[(0.2, 0.75, 0.35)], anal_fins=[(0.18, 0.45, 0.35)], dorsal_spiky=True,
                   hstripes=[(0.42, 0.04, "#3c4a54", 0.15, 0.75)], vstripes=[(0.9, 2.0, "#e8c040")],
                   eye=2.6, seed=6),
    "barbunya": dict(nose=0.65, W=48, H=26, length=36, height=8, peak=0.55, snout=0.6, dorsal="#c03838", side="#ec7a6a",
                     ventral="#ffd6c8", fin="#e89080", tail="fork", tail_size=8,
                     dorsal_fins=[(0.55, 0.72, 0.8), (0.2, 0.38, 0.55)], anal_fins=[(0.18, 0.35, 0.4)],
                     hstripes=[(0.42, 0.05, "#f0c040", 0.1, 0.8)], eye=2.2, eye_v=0.32, mouth_v=0.75, seed=7),
    "orfoz": dict(nose=0.85, W=64, H=40, length=48, height=14, peak=0.55, snout=0.45, belly=1.05, dorsal="#4a3424",
                  side="#7a5a3c", ventral="#c8a880", fin="#5a4030", tail="round", tail_size=11,
                  dorsal_fins=[(0.2, 0.8, 0.4)], dorsal_spiky=True, anal_fins=[(0.2, 0.45, 0.45)],
                  mottle="#e8d8b0", eye=2.6, mouth=6, mouth_v=0.62, seed=8),
    "balon": dict(nose=0.45, W=40, H=32, length=28, height=11, peak=0.55, snout=0.7, dorsal="#7a6a30", side="#c8b878",
                  ventral="#f4ecd0", fin="#c8b070", tail="round", tail_size=7, dorsal_fins=[(0.15, 0.3, 0.6)],
                  anal_fins=[(0.15, 0.3, 0.5)], spots=14, spot_color="#3a3020", eye=2.6, scales=False,
                  lateral=False, seed=9),
    "kopekbaligi": dict(nose=1.5, W=96, H=40, length=72, height=10, peak=0.55, snout=0.25, dorsal="#2a4a7a",
                        side="#5a7aa8", ventral="#e8eef4", fin="#2a4a7a", fin_alpha=255, tail="shark",
                        tail_size=18, dorsal_fins=[(0.48, 0.6, 1.5), (0.18, 0.22, 0.5)],
                        anal_fins=[(0.2, 0.25, 0.5)], pec=1.6, pec_at=0.62, eye=1.8, eye_at=0.86,
                        gill=0.74, mouth=8, mouth_v=0.72, scales=False, lateral=False, seed=10),
    "kilic": dict(nose=1.6, W=96, H=36, length=58, height=9, x0=10, peak=0.5, snout=0.15, dorsal="#2a3a5a",
                  side="#5a6e8a", ventral="#d8e0ea", fin="#2a3a5a", tail="lunate", tail_size=14,
                  dorsal_fins=[(0.75, 0.86, 1.6)], anal_fins=[(0.1, 0.18, 0.6)], eye=2.2, scales=False, seed=11),
    "ay_baligi": dict(nose=0.5, W=64, H=72, length=44, height=26, peak=0.5, snout=0.6, dorsal="#6a7480", side="#a4aeb8",
                      ventral="#e0e6ea", fin="#7a848e", tail="truncate", tail_size=10, stalk=0.75,
                      dorsal_fins=[(0.1, 0.25, 1.1)], anal_fins=[(0.1, 0.25, 1.1)], eye=3.0, mottle="#c8d0d8",
                      scales=False, lateral=False, seed=12),
    "fener": dict(nose=0.35, W=48, H=40, length=34, height=13, peak=0.6, snout=0.9, belly=1.15, dorsal="#16121f",
                  side="#2a2240", ventral="#3a3058", fin="#241d33", tail="round", tail_size=8,
                  dorsal_fins=[(0.15, 0.35, 0.5)], anal_fins=[(0.15, 0.3, 0.4)], eye=1.6, eye_v=0.3,
                  iris="#fff3a0", mouth=10, mouth_v=0.62, scales=False, lateral=False, seed=13),
    "altin_fener": dict(nose=0.35, W=48, H=40, length=34, height=13, peak=0.6, snout=0.9, belly=1.15, dorsal="#8a5a08",
                        side="#d8a020", ventral="#ffd866", fin="#b88010", tail="round", tail_size=8,
                        dorsal_fins=[(0.15, 0.35, 0.5)], anal_fins=[(0.15, 0.3, 0.4)], eye=1.6, eye_v=0.3,
                        iris="#ffffff", mouth=10, mouth_v=0.62, scales=False, lateral=False, seed=14),
}


def angler_extras(cv, gold, frame):
    """Fener balığı: dişler ve fener sapı."""
    W, H = cv.w, cv.h
    # dişler (ağız hizasında)
    for x in range(int(W * 0.66), int(W * 0.9), 3):
        y = int(H * 0.56)
        cv.set(x, y, col("#f4f0e8"))
        cv.set(x, y + 1, col("#f4f0e8"))
        cv.set(x + 1, y + 4, col("#f4f0e8"))
    stalk = col("#d8a020" if gold else "#4a3d66")
    pts = [(W * 0.62, H * 0.22), (W * 0.68, H * 0.08), (W * 0.8, H * 0.04), (W * 0.9, H * 0.08)]
    for (a, b) in zip(pts, pts[1:]):
        for i in range(12):
            t = i / 11
            cv.set(int(lerp(a[0], b[0], t)), int(lerp(a[1], b[1], t)), stalk)
    gx, gy = W * 0.92, H * 0.14
    glow = ["#fff0b0", "#ffd060"] if gold else ["#d4fff4", "#5be0c8"]
    pulse = [1.0, 1.25, 1.0, 0.85][frame]
    for y in range(int(gy - 4), int(gy + 5)):
        for x in range(int(gx - 4), int(gx + 5)):
            d = math.hypot(x + 0.5 - gx, y + 0.5 - gy)
            if d < 2.2 * pulse:
                cv.set(x, y, col(glow[0]))
            elif d < 3.4 * pulse:
                cv.put(x, y, col(glow[1], 170))


def puffer_inflated(frame):
    s = dict(FISH_SPECS["balon"])
    s.update(height=15, peak=0.5, snout=0.9, stalk=0.3)
    cv = fish(s, frame, s["W"], s["H"])
    # dikenler
    cx, cy = cv.w * 0.55, cv.h / 2
    for a in range(0, 360, 24):
        r0, r1 = 13.5, 16.5
        for r in (r0, r0 + 1, r0 + 2, r1):
            x = int(cx + math.cos(math.radians(a)) * r * 1.05)
            y = int(cy + math.sin(math.radians(a)) * r * 0.95)
            if cv.alpha(x, y) == 0:
                cv.set(x, y, col("#5a4a20"))
    return cv


def shark_extras(cv):
    W, H = cv.w, cv.h
    # solungaç yarıkları
    for k in range(4):
        x = int(W * 0.66) + k * 3
        for y in range(int(H * 0.45), int(H * 0.62)):
            cv.put(x, y, col("#2a3a56", 180))


def sword_extras(cv):
    W, H = cv.w, cv.h
    y = int(H / 2) - 1
    for x in range(int(W * 0.7), W - 1):
        cv.set(x, y, col("#3a4a66"))
        cv.set(x, y + 1, col("#8a9ab0") if x < W - 4 else CLEAR)


# --------------------------------------------------------------------------
# Özel biçimli canlılar
# --------------------------------------------------------------------------

def ell(cv, cx, cy, rx, ry, c_top, c_bot, alpha=255, light=0.25):
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                v = (dy + 1) / 2
                c = mix(col(c_top, alpha), col(c_bot, alpha), v)
                c = shade(c, 1 + light * (1 - math.hypot(dx + 0.35, dy + 0.45)))
                cv.put(x, y, c)


def jelly(frame, glow=False):
    W, H = 32, 44
    cv = Canvas(W, H)
    rx = [12.0, 10.8, 9.6, 10.8][frame]
    ry = [8.0, 9.0, 10.0, 9.0][frame]
    top, bot = ("#ff9ad8", "#c04898") if not glow else ("#b8c8ff", "#5a62e0")
    # dokunaçlar
    for i, tx in enumerate((9, 12, 15, 18, 21, 24)):
        for y in range(int(10 + ry * 0.5), H - 1):
            off = math.sin(y * 0.35 + frame * 1.4 + i) * 1.6
            a = int(220 - (y - 14) * 7)
            if a > 20:
                cv.put(int(tx + off), y, col(bot, a))
    # ağız kolları
    for i, tx in enumerate((13, 19)):
        for y in range(int(10 + ry * 0.4), int(H * 0.72)):
            off = math.sin(y * 0.25 + frame + i * 2) * 2.4
            cv.put(int(tx + off), y, col(top, 200))
            cv.put(int(tx + off + 1), y, col(bot, 200))
    ell(cv, 16, 11, rx, ry, top, bot, alpha=215, light=0.35)
    # şemsiye iç deseni (gonad halkaları)
    for a in range(0, 360, 90):
        x = int(16 + math.cos(math.radians(a + frame * 10)) * rx * 0.35)
        y = int(11 + math.sin(math.radians(a)) * ry * 0.2)
        cv.put(x, y, col("#ffffff", 150))
    for x in range(int(16 - rx), int(16 + rx) + 1):
        cv.put(x, int(11 + ry * 0.6), col("#ffffff", 120))
    return cv


def seahorse(frame):
    W, H = 24, 40
    cv = Canvas(W, H)
    body = ["#a86408", "#e89a28", "#ffd27a"]
    bob = [0, 0.5, 1, 0.5][frame]
    # gövde segmentleri (S kıvrımı)
    path = [(13, 9), (12.5, 12), (11.6, 15), (11, 18), (11.2, 21), (12, 24), (13, 27), (13.4, 30),
            (12.6, 33), (10.6, 35), (8.8, 34.4), (8.6, 32.6), (10, 32)]
    for i, (x, y) in enumerate(path):
        r = 4.6 - i * 0.32 if i < 9 else 1.4
        ell(cv, x, y + bob, max(r, 1.2), max(r * 0.9, 1.2), body[2], body[0], light=0.3)
        if i < 9 and i % 1 == 0:
            cv.put(int(x - r + 1), int(y + bob), col(body[0]))
    # baş ve burun
    ell(cv, 14, 6 + bob, 4.0, 3.4, body[2], body[1], light=0.35)
    for x in range(17, 23):
        cv.set(x, int(6.5 + bob), col(body[1]))
        cv.set(x, int(7.5 + bob), col(body[0]))
    cv.set(14, int(5 + bob), col("#101010"))
    cv.set(13, int(4 + bob), col("#ffffff"))
    # taç
    for x in (12, 13, 14):
        cv.set(x, int(2 + bob), col(body[1]))
    # sırt yüzgeci (titreşir)
    for y in range(15, 22):
        cv.put(int(8 - (frame % 2)), int(y + bob), col("#fff0c0", 170))
    # karın halkaları
    for y in range(13, 28, 2):
        cv.put(14, int(y + bob), col(body[2]))
    _outline(cv, col("#4a2a04"))
    return cv


def octopus(frame):
    W, H = 40, 36
    cv = Canvas(W, H)
    sq = [0.0, 0.5, 1.0, 0.5][frame]
    top, bot = "#e0607e", "#8a2448"
    for i in range(8):
        base = 9 + i * 3.1
        for k in range(18):
            y = 16 + k
            spread = (base - 20) * (0.12 + sq * 0.08) * k
            x = base + spread + math.sin(k * 0.55 + frame * 1.3 + i) * 1.4
            th = 2.2 - k * 0.1
            for d in range(int(-th), int(th) + 1):
                c = col(top) if d < 0 else col(bot)
                cv.put(int(x + d), y, c)
            if k % 3 == 1 and k < 15:
                cv.put(int(x + th), y, col("#ffd0dc"))     # vantuz
    ell(cv, 20, 10 + sq, 11 - sq, 9 + sq * 0.6, "#f58ea4", bot, light=0.4)
    # gözler
    for ex in (15, 25):
        ell(cv, ex, 14 + sq, 2.4, 2.0, "#fff4c0", "#e8d890")
        cv.set(ex, int(14 + sq), col("#101010"))
        cv.set(ex + 1, int(14 + sq), col("#101010"))
    # benekler
    rnd = random.Random(4)
    for _ in range(10):
        x, y = rnd.randint(12, 28), rnd.randint(4, 12)
        cv.put(x, int(y + sq), col("#b83a5a"))
    _outline(cv, col("#3a0a1a"))
    return cv


def squid(frame, giant=False):
    W, H = (28, 52) if not giant else (64, 120)
    cv = Canvas(W, H)
    k = 1.0 if not giant else 2.3
    st = [0.0, 0.5, 1.0, 0.5][frame]
    if giant:
        top, bot, a = "#c04030", "#6a1a12", 255
    else:
        top, bot, a = "#c8f4ff", "#5ab8d8", 190
    cx = W / 2
    # manto (yukarı bakan, ucu sivri uzun gövde)
    for y in range(int(2 * k), int(26 * k + st * 2)):
        t = (y - 2 * k) / (24 * k)
        rx = (0.6 + 6.4 * min(1.0, max(0.0, t) / 0.55) ** 0.8) * k * (1 - st * 0.08)
        for x in range(int(cx - rx), int(cx + rx) + 1):
            v = abs(x + 0.5 - cx) / max(rx, 1)
            c = mix(col(top, a), col(bot, a), v)
            cv.put(x, y, c)
    # yan yüzgeçler: mantonun ucunda baklava biçimi
    span = 9 * k
    for y in range(int(2 * k), int(2 * k + span)):
        u = (y - 2 * k) / span
        body = (0.6 + 6.4 * min(1.0, max(0.0, (y - 2 * k) / (24 * k)) / 0.55) ** 0.8) * k
        w = math.sin(u * math.pi) * 4.5 * k
        for s in (-1, 1):
            for d in range(int(w)):
                cv.put(int(cx + s * (body + d)), y, col(bot if d > w * 0.6 else top, int(a * 0.85)))
    # gözler
    for s in (-1, 1):
        ex, ey = cx + s * 4.2 * k, 25 * k
        er = 1.8 * k
        for y in range(int(ey - er), int(ey + er) + 1):
            for x in range(int(ex - er), int(ex + er) + 1):
                if math.hypot(x + 0.5 - ex, y + 0.5 - ey) < er:
                    cv.set(x, y, col("#101820") if not giant else col("#f8e070"))
    # kollar
    n = 8 if not giant else 10
    for i in range(n):
        bx = cx - 6 * k + i * (12 * k / (n - 1))
        length = (16 if i not in (2, n - 3) else 24) * k
        for j in range(int(length)):
            y = 27 * k + j
            x = bx + math.sin(j * 0.22 / k + frame * 1.2 + i) * (1.5 + j * 0.06) * k
            cv.put(int(x), int(y), col(bot, max(40, a - j * 4)))
            if giant:
                cv.put(int(x) + 1, int(y), col(top, max(40, a - j * 4)))
    if giant:
        _outline(cv, col("#2a0804"))
    return cv


def eel(frame):
    W, H = 64, 24
    cv = Canvas(W, H)
    dark, mid, light = col("#14240f"), col("#2f5022"), col("#5a8a3c")
    pts = []
    for x in range(2, 54):
        y = 12 + math.sin(x * 0.2 + frame * math.pi / 2) * 4.0 * (x / 54 + 0.3)
        pts.append((x, y))
    for i, (x, y) in enumerate(pts):
        th = 2.0 + 2.6 * math.sin(math.pi * min(1, (i + 4) / 58))
        for dy in range(int(-th), int(th) + 1):
            v = (dy + th) / (2 * th)
            c = mix(light, dark, v) if v > 0.4 else mix(light, mid, 1 - v / 0.4)
            cv.put(int(x), int(round(y + dy)), c)
        if i % 6 == 3:
            cv.put(int(x), int(round(y - 1)), col("#e6e04a"))
            cv.put(int(x) + 1, int(round(y)), col("#c8c030"))
    hx, hy = pts[-1]
    ell(cv, hx + 3, hy, 5.0, 3.6, "#5a8a3c", "#14240f")
    cv.set(int(hx) + 5, int(hy) - 1, col("#ff4040"))
    for x in range(int(hx) + 3, int(hx) + 8):
        cv.put(x, int(hy) + 1, col("#0a1408"))
    _outline(cv, col("#060c04"))
    return cv


def turtle(frame):
    W, H = 52, 32
    cv = Canvas(W, H)
    fl = [(-2, 2), (0, 0), (2, -2), (0, 0)][frame]
    skin = ("#9ab57a", "#4a5a3a")
    # yüzgeçler
    for (bx, by, ang, ln) in ((33, 20, 30 + fl[0] * 12, 15), (15, 21, 150 + fl[1] * 10, 9)):
        for i in range(ln):
            t = i / ln
            x = bx + math.cos(math.radians(ang)) * i
            y = by + math.sin(math.radians(ang)) * i * 0.6
            w = 3.0 * (1 - t * 0.6)
            for d in range(int(-w), int(w) + 1):
                cv.put(int(x), int(y + d), col(skin[0] if d < 0 else skin[1]))
    # kabuk
    ell(cv, 24, 15, 15, 9, "#86b04a", "#2b3a1a", light=0.35)
    # kabuk plakaları
    for (cx, cy) in ((18, 12), (24, 10), (30, 12), (21, 16), (27, 16), (15, 16), (33, 16)):
        for a in range(0, 360, 30):
            cv.put(int(cx + math.cos(math.radians(a)) * 3), int(cy + math.sin(math.radians(a)) * 2),
                   col("#3a5020", 200))
    # baş
    ell(cv, 42, 12, 5.2, 3.8, skin[0], skin[1])
    cv.set(44, 11, col("#101010"))
    cv.set(46, 13, col("#2a3a1a"))
    _outline(cv, col("#16200d"))
    return cv


def crab(frame):
    W, H = 36, 24
    cv = Canvas(W, H)
    top, bot = "#4a8ad8", "#1a3a7a"
    step = [0, 1, 0, -1][frame]
    # bacaklar
    for i, bx in enumerate((10, 13, 23, 26)):
        s = -1 if bx < 18 else 1
        k = step * (1 if i % 2 else -1)
        for j in range(7):
            x = bx + s * (j // 2) + (k if j > 3 else 0)
            y = 14 + j
            cv.put(int(x), y, col(bot))
    # kıskaçlar
    for s in (-1, 1):
        ax = 18 + s * 11
        ell(cv, ax, 9 + step * 0.5, 3.6, 2.6, "#5aa0ff", "#1a4a9a")
        cv.set(int(ax + s * 3), int(7 + step * 0.5), col("#e0e8ff"))
        for j in range(4):
            cv.put(int(18 + s * (6 + j)), 12, col(bot))
    ell(cv, 18, 13, 9, 5.5, top, bot, light=0.35)
    for ex in (15, 21):
        cv.set(ex, 6, col("#101010"))
        cv.set(ex, 7, col(bot))
        cv.set(ex, 8, col(bot))
    _outline(cv, col("#0a1a3a"))
    return cv


def stingray(frame):
    W, H = 64, 32
    cv = Canvas(W, H)
    wave = [0.0, 1.0, 0.0, -1.0][frame]
    top, bot = "#7a6a58", "#3a3024"
    # kuyruk
    for x in range(2, 24):
        y = 17 + math.sin(x * 0.3 + frame) * 1.2
        cv.put(x, int(y), col(bot))
    cv.put(10, 16, col("#d8c8a0"))
    # kanat (üstten hafif açılı görünüm)
    cx, cy = 40, 16
    for y in range(4, 30):
        for x in range(18, 62):
            dx = (x + 0.5 - cx) / 21
            dy = (y + 0.5 - cy - math.sin((x - 18) * 0.25) * wave) / (10 - abs(dx) * 3)
            if abs(dx) + abs(dy) * 0.9 <= 1.0:
                v = (dy + 1) / 2
                c = mix(col(top), col(bot), v * 0.9)
                if (x * 3 + y * 7) % 11 == 0:
                    c = shade(c, 1.2)
                cv.put(x, y, c)
    cv.set(50, 13, col("#101010"))
    cv.set(50, 19, col("#101010"))
    _outline(cv, col("#1a140c"))
    return cv


# --------------------------------------------------------------------------
# Sayfalar
# --------------------------------------------------------------------------

def sheet(frames_cv):
    w, h = frames_cv[0].w, frames_cv[0].h
    img = Image.new("RGBA", (w * len(frames_cv), h), CLEAR)
    for i, cv in enumerate(frames_cv):
        cv.paste_into(img, i * w, 0)
    return img


def build_all():
    out = {}
    for name, spec in FISH_SPECS.items():
        frames = []
        for f in range(FRAMES):
            cv = fish(spec, f, spec["W"], spec["H"])
            if name in ("fener", "altin_fener"):
                angler_extras(cv, name == "altin_fener", f)
            elif name == "kopekbaligi":
                shark_extras(cv)
            elif name == "kilic":
                sword_extras(cv)
            frames.append(cv)
        if name == "balon":
            frames = frames[:2] + [puffer_inflated(0), puffer_inflated(1)]
        out[name] = sheet(frames)
    out["denizanasi"] = sheet([jelly(f) for f in range(4)])
    out["isikli_denizanasi"] = sheet([jelly(f, glow=True) for f in range(4)])
    out["denizati"] = sheet([seahorse(f) for f in range(4)])
    out["ahtapot"] = sheet([octopus(f) for f in range(4)])
    out["kalamar"] = sheet([squid(f) for f in range(4)])
    out["dev_kalamar"] = sheet([squid(f, giant=True) for f in range(4)])
    out["yilanbaligi"] = sheet([eel(f) for f in range(4)])
    out["kaplumbaga"] = sheet([turtle(f) for f in range(4)])
    out["yengec"] = sheet([crab(f) for f in range(4)])
    out["vatoz"] = sheet([stingray(f) for f in range(4)])
    return out
