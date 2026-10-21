"""Dalgıç ve deniz canlıları sprite sayfaları."""
import math

from PIL import Image

from art_common import Canvas, CLEAR, hexc, ramp, with_alpha, mix, clampi, disc

FW = 24   # dalgıç kare boyutu
OUTLINE = hexc("#0b1220")
SUIT = ramp("#3c3c3c", "#626262", "#8a8a8a", "#b4b4b4", "#dcdcdc", "#f4f4f4")   # renklendirilecek
TANK = ramp("#6b4a07", "#a87b12", "#e0b020", "#ffd95a", "#fff1b0")
GLASS = ramp("#0e4c6e", "#1e86b8", "#46c0ec", "#a6ecff")
DARK = ramp("#11151d", "#1d2330", "#2c3445")
FIN = ramp("#0f1a2c", "#1c3352", "#2f5f94", "#4f8fd0")
METAL = ramp("#4b5560", "#7e8a96", "#c3ccd4")


def ell(cv, cx, cy, rx, ry, r, base=None, light=(-1, -1)):
    n = len(r)
    base = (n - 1) * 0.55 if base is None else base
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                lit = -(dx * light[0] + dy * light[1]) * 0.75
                cv.set(x, y, r[clampi(int(round(base + lit * n / 2.4)), 0, n - 1)])


def line(cv, x0, y0, x1, y1, c, w=1):
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(steps + 1):
        t = i / steps
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        for k in range(w):
            cv.set(int(round(x)) , int(round(y + k)), c)


def compose(base, suit):
    """Dış çizgiyi iki katmanın birleşimine göre taban katmanına ekle,
    taban katmanının dolu olduğu yerlerde takım katmanını temizle."""
    union = Canvas(FW, FW)
    for y in range(FW):
        for x in range(FW):
            if base.alpha(x, y) or suit.alpha(x, y):
                union.set(x, y, (255, 255, 255, 255))
            if base.alpha(x, y):
                suit.set(x, y, CLEAR)
    base.outline(OUTLINE, src=union)


def diver_upright(f):
    base, suit = Canvas(FW, FW), Canvas(FW, FW)
    kick = [0, 1, 0, -1][f]
    # tüp (sırtta)
    for y in range(9, 18):
        for x in range(6, 9):
            base.set(x, y, TANK[[2, 3, 1][x - 6]])
    base.set(7, 8, METAL[1])
    base.set(7, 7, METAL[2])
    base.set(6, 17, TANK[0])
    base.set(8, 17, TANK[0])
    # bacaklar
    for y in range(16, 21):
        bx = 9 + (kick if y > 17 else 0)
        fx = 12 - (kick if y > 17 else 0)
        suit.set(bx, y, SUIT[1])
        suit.set(bx + 1, y, SUIT[2])
        suit.set(fx, y, SUIT[2])
        suit.set(fx + 1, y, SUIT[3])
    # paletler
    for leg, (lx, sgn) in enumerate(((9 + kick, 1), (12 - kick, -1))):
        for k in range(4):
            y = 21 + (k // 2)
            for x in range(lx - 1 + k, lx + 2 + k):
                base.set(x, y, FIN[1 if leg == 0 else 2])
        base.set(lx + 4, 22, FIN[3] if leg else FIN[2])
    # gövde
    ell(suit, 11.6, 13.2, 3.1, 3.8, SUIT)
    for x in range(9, 15):
        base.set(x, 16, DARK[1])
    base.set(12, 16, METAL[2])
    # kol
    for i, (x, y) in enumerate(((13, 11), (14, 12), (14, 13), (15, 14))):
        suit.set(x, y, SUIT[3])
        suit.set(x - 1, y + 1, SUIT[2])
    base.set(15, 15, DARK[2])
    base.set(16, 15, DARK[1])
    # başlık
    ell(suit, 12.8, 6.6, 3.4, 3.6, SUIT, base=3.2)
    # maske
    for x in range(13, 17):
        base.set(x, 4, DARK[1])
        base.set(x, 8, DARK[1])
    for y in range(5, 8):
        base.set(13, y, DARK[1])
        for x in range(14, 17):
            base.set(x, y, GLASS[2] if y < 7 else GLASS[1])
    base.set(14, 5, GLASS[3])
    base.set(17, 6, DARK[0])
    # regülatör ve hortum
    base.set(16, 9, METAL[1])
    base.set(17, 9, METAL[0])
    for (x, y) in ((15, 10), (14, 10), (13, 10), (12, 9), (11, 9), (10, 9), (9, 9)):
        base.set(x, y, DARK[2])
    compose(base, suit)
    return base, suit


def diver_swim(f):
    base, suit = Canvas(FW, FW), Canvas(FW, FW)
    kick = [0.0, 1.0, 0.0, -1.0][f]
    # iki bacak: kalçadan geriye, zıt yönde çırpar
    for (hy, sgn, shade) in ((9.6, 1, 3), (11.6, -1, 2)):
        ay = hy + sgn * kick * 1.6
        for i in range(6):
            t = i / 5
            x = 8 - i
            y = hy + (ay - hy) * t
            suit.set(x, int(round(y)), SUIT[shade])
            suit.set(x, int(round(y)) + 1, SUIT[shade - 1])
        # palet: ayak bileğinden geriye 4 piksel, açılı
        fy = ay + sgn * kick * 0.8
        for k in range(5):
            x = 2 - k + 1
            y = ay + (fy - ay) * (k / 4)
            c = FIN[2] if shade == 3 else FIN[1]
            base.set(x, int(round(y)), c)
            base.set(x, int(round(y)) + 1, FIN[0])
        base.set(-1 + 1, int(round(fy)), FIN[3])
    # gövde
    ell(suit, 12.0, 10.8, 4.8, 2.7, SUIT, light=(-0.3, -1))
    for y in range(9, 14):
        base.set(8, y, DARK[1])
    base.set(8, 11, METAL[2])
    # tüp (üstte)
    for x in range(8, 16):
        base.set(x, 6, TANK[3])
        base.set(x, 7, TANK[2])
        base.set(x, 8, TANK[1])
    base.set(16, 7, METAL[1])
    base.set(17, 7, METAL[2])
    base.set(7, 7, TANK[0])
    # kol öne uzanır
    for i, (x, y) in enumerate(((16, 12), (17, 13), (18, 13), (19, 14))):
        suit.set(x, y, SUIT[3])
        suit.set(x, y + 1, SUIT[1])
    base.set(20, 14, DARK[2])
    base.set(21, 14, DARK[1])
    # baş
    ell(suit, 18.4, 9.6, 3.2, 3.2, SUIT, base=3.2)
    for y in range(8, 12):
        base.set(21, y, DARK[1])
    for y in range(8, 11):
        base.set(22, y, GLASS[2] if y < 10 else GLASS[1])
    base.set(22, 8, GLASS[3])
    base.set(23, 9, DARK[0])
    base.set(21, 12, METAL[1])
    compose(base, suit)
    return base, suit


def build_diver():
    base_sheet = Image.new("RGBA", (FW * 8, FW), CLEAR)
    suit_sheet = Image.new("RGBA", (FW * 8, FW), CLEAR)
    for f in range(4):
        b, s = diver_upright(f)
        b.paste_into(base_sheet, f * FW, 0)
        s.paste_into(suit_sheet, f * FW, 0)
        b, s = diver_swim(f)
        b.paste_into(base_sheet, (4 + f) * FW, 0)
        s.paste_into(suit_sheet, (4 + f) * FW, 0)
    return base_sheet, suit_sheet


# ---------------------------------------------------------------- canlılar

FISH_VARIANTS = [
    dict(body=ramp("#a8780c", "#e0b21a", "#ffd83d", "#fff08a"), fin=hexc("#e0a010"), stripe=None),
    dict(body=ramp("#9c3a08", "#e0641a", "#ff8c3a", "#ffb978"), fin=hexc("#e0641a"), stripe=hexc("#ffffff")),
    dict(body=ramp("#123c7a", "#1f63b8", "#3a8fe6", "#8cc6ff"), fin=hexc("#1f63b8"), stripe=None),
    dict(body=ramp("#5a6876", "#8a9aa8", "#c3ced8", "#eef3f7"), fin=hexc("#6f8090"), stripe=hexc("#2e5a8a")),
]


def fish(variant, frame):
    cv = Canvas(12, 8)
    v = FISH_VARIANTS[variant]
    ell(cv, 6.6, 4.0, 4.4, 2.6, v["body"], base=2.0, light=(0, -1))
    spread = [1, 2][frame]
    for k in range(3):
        x = 2 - k
        for y in range(4 - k * spread // 2 - 1, 4 + k * spread // 2 + 1):
            cv.set(x, y, v["fin"])
    cv.set(6, 1, v["fin"])
    cv.set(7, 1, v["fin"])
    if v["stripe"] is not None:
        if variant == 1:
            for sx in (5, 8):
                for y in range(2, 7):
                    if cv.alpha(sx, y):
                        cv.set(sx, y, v["stripe"])
                        if cv.alpha(sx - 1, y):
                            cv.set(sx - 1, y, hexc("#1a1a1a"))
        else:
            for x in range(4, 10):
                cv.set(x, 3, v["stripe"])
    cv.set(9, 3, hexc("#ffffff"))
    cv.set(10, 3, hexc("#101010"))
    cv.outline(with_alpha(v["body"][0], 255))
    return cv


def jelly(frame):
    cv = Canvas(14, 18)
    rx = [5.6, 5.0, 4.4, 5.0][frame]
    ry = [3.6, 4.0, 4.5, 4.0][frame]
    body = [(220, 90, 190, 205), (245, 130, 215, 220), (255, 180, 232, 235), (255, 230, 250, 245)]
    ell(cv, 7.0, 5.0, rx, ry, body, base=1.6, light=(0, -1))
    for x in range(int(7 - rx), int(7 + rx) + 1):
        cv.set(x, int(5 + ry * 0.55), (255, 220, 255, 220))
    for i, tx in enumerate((4, 6, 8, 10)):
        for y in range(int(5 + ry * 0.6), 17):
            off = int(round(math.sin(y * 0.7 + frame * 1.5 + i) * 0.9))
            a = int(170 - (y - 8) * 12)
            if a > 20:
                cv.set(tx + off, y, (250, 150, 225, min(255, a + 40)))
    cv.set(5, 3, (255, 255, 255, 230))
    return cv


def angler(frame, gold=False):
    cv = Canvas(20, 16)
    body = ramp("#16121f", "#241d33", "#352b4a", "#4a3d66")
    if gold:
        body = ramp("#5c3a08", "#a06a12", "#e0a82a", "#ffd866")
    ell(cv, 9.0, 9.0, 6.0, 5.0, body, base=1.6)
    for k in range(4):
        for y in range(9 - k, 10 + k):
            cv.set(2 - k + 1, y, body[1])
    for x in range(10, 16):
        cv.set(x, 11, hexc("#0a0710"))
    for x in (11, 13, 15):
        cv.set(x, 10, hexc("#e8e8e8"))
        cv.set(x - 1, 12, hexc("#e8e8e8"))
    cv.set(12, 7, hexc("#fff3a0"))
    cv.set(13, 7, hexc("#101010"))
    pts = [(9, 4), (10, 2), (12, 1), (14, 1), (16, 2)]
    for a, b in zip(pts, pts[1:]):
        line(cv, a[0], a[1], b[0], b[1], body[3])
    glow = [ramp("#2a8a7a", "#5be0c8", "#d4fff4"), ramp("#3aa892", "#8ff5df", "#ffffff")][frame]
    if gold:
        glow = [ramp("#c06010", "#ffb030", "#fff0b0"), ramp("#e08020", "#ffd060", "#ffffff")][frame]
    disc(cv, 17, 3.4, 1.6, glow, base_idx=1.5)
    cv.outline(hexc("#07050c") if not gold else hexc("#2a1804"))
    return cv


def turtle(frame):
    cv = Canvas(24, 16)
    shell = ramp("#2b3a1a", "#456028", "#628a35", "#86b04a", "#a8cf6a")
    skin = ramp("#4a5a3a", "#6f8858", "#9ab57a")
    fl = [(-1, 1), (1, -1)][frame]
    # yüzgeçler (kabuğun altından çıkar)
    front = [(15, 10), (17, 12), (19, 13 + fl[0])]
    back = [(7, 10), (5, 12), (3, 13 + fl[1])]
    for pts in (front, back):
        for a, b in zip(pts, pts[1:]):
            line(cv, a[0], a[1], b[0], b[1], skin[1], w=2)
        cv.set(pts[-1][0], pts[-1][1], skin[2])
    ell(cv, 11.0, 8.0, 7.2, 4.2, shell, base=2.2)
    for (cx, cy) in ((8, 7), (11, 6), (14, 7), (11, 9), (8, 9.5), (14, 9.5)):
        cv.set(int(cx), int(cy), shell[1])
        cv.set(int(cx) + 1, int(cy), shell[1])
    ell(cv, 19.8, 7.4, 2.6, 2.0, skin, base=1.4)
    cv.set(21, 7, hexc("#101010"))
    cv.outline(hexc("#16200d"))
    return cv


def seahorse(frame):
    cv = Canvas(12, 16)
    body = ramp("#7a4a08", "#c07a12", "#f2a93a", "#ffd27a")
    bob = [0, 1][frame]
    # kafa ve burun
    ell(cv, 7.0, 3.2 + bob * 0.3, 2.3, 2.0, body, base=2.0)
    for x in range(9, 12):
        cv.set(x, 3 + bob // 2, body[1])
    cv.set(7, 2, hexc("#101010"))
    # gövde: kavisli
    for i, (cx, cy, r) in enumerate(((6.4, 6.0, 2.4), (5.6, 8.3, 2.6), (6.0, 10.6, 2.2), (6.8, 12.6, 1.6))):
        ell(cv, cx, cy + bob * 0.2, r, r * 0.9, body, base=2.2)
    # karın çizgileri
    for y in range(6, 12, 2):
        cv.set(7, y, body[3])
    # kuyruk kıvrımı
    for (x, y) in ((7, 14), (6, 15), (5, 15), (4, 14), (4, 13), (5, 13)):
        cv.set(x, y, body[1])
    # sırt yüzgeci (titreşir)
    fin = (255, 230, 170, 200)
    for y in range(6, 10):
        cv.set(3 - frame, y, fin)
    cv.outline(hexc("#3a2204"))
    return cv


def octopus(frame):
    cv = Canvas(18, 16)
    body = ramp("#5a1630", "#8e2448", "#c4406a", "#ef7898")
    squash = [0.0, 0.6, 1.0, 0.6][frame]
    ell(cv, 9.0, 5.0 + squash * 0.5, 5.2 - squash * 0.4, 4.4 + squash * 0.3, body, base=2.0)
    cv.set(7, 6, hexc("#fff4c0"))
    cv.set(11, 6, hexc("#fff4c0"))
    cv.set(7, 7, hexc("#101010"))
    cv.set(11, 7, hexc("#101010"))
    # 6 kol, dalgalı
    for i, bx in enumerate((4, 6, 8, 10, 12, 14)):
        for k in range(7):
            y = 9 + k
            spread = (bx - 9) * (0.15 + squash * 0.12) * k
            x = int(round(bx + spread + math.sin(k * 0.9 + frame * 1.4 + i) * 0.8))
            cv.set(x, y, body[1] if k < 5 else body[0])
            if k % 2 == 0 and k < 5:
                cv.set(x, y, body[2])
    cv.outline(hexc("#2a0814"))
    return cv


def squid(frame):
    """Hayalet kalamar: yarı saydam, parlayan."""
    cv = Canvas(12, 22)
    body = [(110, 230, 255, 150), (150, 240, 255, 175), (200, 250, 255, 200), (240, 255, 255, 230)]
    stretch = [0.0, 0.5, 1.0, 0.5][frame]
    ell(cv, 6.0, 7.0, 3.4 - stretch * 0.5, 6.0 + stretch * 0.8, body, base=1.6, light=(0, -1))
    # yüzgeçler
    for (x, y) in ((1, 2), (2, 3), (10, 2), (9, 3)):
        cv.set(x, y + int(stretch), body[1])
    cv.set(5, 10, (20, 40, 60, 255))
    cv.set(7, 10, (20, 40, 60, 255))
    for i, bx in enumerate((4, 5, 7, 8)):
        for k in range(8 - int(stretch * 2)):
            y = 13 + int(stretch) + k
            x = bx + int(round(math.sin(k * 0.8 + frame + i) * 0.7))
            cv.set(x, y, (160, 240, 255, 190 - k * 15))
    for (x, y) in ((6, 4), (5, 7), (7, 6)):
        cv.set(x, y, (255, 255, 255, 255))
    return cv


def eel(frame):
    """Elektrikli yılanbalığı: uzun, dalgalanan, sarı lekeli."""
    cv = Canvas(30, 12)
    body = ramp("#14240f", "#25401c", "#3a5f2a", "#5a8a3c")
    spot = hexc("#e6e04a")
    pts = []
    for x in range(1, 26):
        y = 6 + math.sin(x * 0.42 + frame * math.pi / 2) * 2.2 * (x / 26 + 0.3)
        pts.append((x, y))
    for i, (x, y) in enumerate(pts):
        thick = 1.4 + 1.2 * math.sin(math.pi * min(1, (i + 3) / 28))
        for dy in range(-2, 3):
            if abs(dy) <= thick:
                idx = 3 if dy < 0 else (2 if dy == 0 else 1)
                cv.set(x, int(round(y + dy)), body[idx])
        if i % 4 == 2:
            cv.set(x, int(round(y)), spot)
    # baş
    hx, hy = pts[-1]
    ell(cv, hx + 1.5, hy, 2.6, 2.1, body, base=2.0)
    cv.set(int(hx) + 2, int(round(hy)) - 1, hexc("#ff4040"))
    cv.outline(hexc("#070d05"))
    return cv


def build_creatures():
    sheets = {}
    s = Image.new("RGBA", (12 * 2, 8 * 4), CLEAR)
    for v in range(4):
        for f in range(2):
            fish(v, f).paste_into(s, f * 12, v * 8)
    sheets["fish"] = s
    s = Image.new("RGBA", (14 * 4, 18), CLEAR)
    for f in range(4):
        jelly(f).paste_into(s, f * 14, 0)
    sheets["jelly"] = s
    s = Image.new("RGBA", (20 * 2, 32), CLEAR)
    for f in range(2):
        angler(f).paste_into(s, f * 20, 0)
        angler(f, gold=True).paste_into(s, f * 20, 16)
    sheets["angler"] = s
    s = Image.new("RGBA", (24 * 2, 16), CLEAR)
    for f in range(2):
        turtle(f).paste_into(s, f * 24, 0)
    sheets["turtle"] = s
    for name, fn, w, h, frames in (("seahorse", seahorse, 12, 16, 2), ("octopus", octopus, 18, 16, 4),
                                   ("squid", squid, 12, 22, 4), ("eel", eel, 30, 12, 4)):
        s = Image.new("RGBA", (w * frames, h), CLEAR)
        for f in range(frames):
            fn(f).paste_into(s, f * w, 0)
        sheets[name] = s
    return sheets
