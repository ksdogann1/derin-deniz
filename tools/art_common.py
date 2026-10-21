"""Piksel sanat üretimi için ortak yardımcılar."""
import math
import random

from PIL import Image

T = 16
CLEAR = (0, 0, 0, 0)


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def ramp(*hexes):
    return [hexc(h) for h in hexes]


def with_alpha(c, a):
    return (c[0], c[1], c[2], a)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


class Canvas:
    """Kenar kontrollü küçük bir piksel tuvali."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), CLEAR)
        self.px = self.img.load()

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            if len(c) == 4 and c[3] < 255 and c[3] > 0:
                base = self.px[x, y]
                if base[3] > 0:
                    a = c[3] / 255.0
                    c = (int(base[0] * (1 - a) + c[0] * a),
                         int(base[1] * (1 - a) + c[1] * a),
                         int(base[2] * (1 - a) + c[2] * a),
                         max(base[3], c[3]))
            self.px[x, y] = c

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return CLEAR

    def alpha(self, x, y):
        return self.get(x, y)[3]

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def outline(self, color, src=None):
        """Opak piksellerin çevresine 1px dış çizgi (ortogonal komşular)."""
        src = src or self
        pts = []
        for y in range(self.h):
            for x in range(self.w):
                if src.alpha(x, y) == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if src.alpha(x + dx, y + dy) > 0:
                            pts.append((x, y))
                            break
        for x, y in pts:
            self.set(x, y, color)

    def paste_into(self, sheet, ox, oy):
        sheet.paste(self.img, (ox, oy), self.img)


def wrap_noise(seed, size, period):
    """Kenarları birbirine uyan (döşenebilir) değer gürültüsü, 0..1."""
    rnd = random.Random(seed)
    n = size // period
    grid = [[rnd.random() for _ in range(n)] for _ in range(n)]

    def smooth(t):
        return t * t * (3 - 2 * t)

    out = [[0.0] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            gx, gy = x / period, y / period
            x0, y0 = int(gx) % n, int(gy) % n
            x1, y1 = (x0 + 1) % n, (y0 + 1) % n
            tx, ty = smooth(gx - int(gx)), smooth(gy - int(gy))
            a = grid[y0][x0] * (1 - tx) + grid[y0][x1] * tx
            b = grid[y1][x0] * (1 - tx) + grid[y1][x1] * tx
            out[y][x] = a * (1 - ty) + b * ty
    return out


def cobbles(seed, count, size=T):
    """Toroidal Voronoi: her piksel için (taş indeksi, d1, d2, dx, dy)."""
    rnd = random.Random(seed)
    pts = []
    # Biraz düzenli dağılım için ızgara + sarsıntı
    side = max(1, int(math.sqrt(count)))
    cell = size / side
    for gy in range(side):
        for gx in range(side):
            pts.append(((gx + 0.5) * cell + rnd.uniform(-cell * 0.3, cell * 0.3),
                        (gy + 0.5) * cell + rnd.uniform(-cell * 0.3, cell * 0.3)))
    while len(pts) < count:
        pts.append((rnd.uniform(0, size), rnd.uniform(0, size)))
    res = {}
    for y in range(size):
        for x in range(size):
            best = []
            for i, (px, py) in enumerate(pts):
                dx = (x + 0.5) - px
                dy = (y + 0.5) - py
                dx -= size * round(dx / size)
                dy -= size * round(dy / size)
                d = math.hypot(dx, dy)
                best.append((d, i, dx, dy))
            best.sort()
            res[(x, y)] = (best[0][1], best[0][0], best[1][0], best[0][2], best[0][3])
    return res, pts


def clampi(v, lo, hi):
    return max(lo, min(hi, v))


def disc(cv, cx, cy, r, shade_ramp, light=(-1, -1), base_idx=None, outline=None):
    """Işık yönüne göre gölgelenmiş dolu daire."""
    n = len(shade_ramp)
    base_idx = (n - 1) / 2 if base_idx is None else base_idx
    lx, ly = light
    ll = math.hypot(lx, ly) or 1
    lx, ly = lx / ll, ly / ll
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d <= r:
                lit = -(dx * lx + dy * ly) / max(r, 0.01)
                idx = clampi(int(round(base_idx + lit * (n / 2.2))), 0, n - 1)
                cv.put(x, y, shade_ramp[idx])
            elif outline is not None and d <= r + 0.9:
                cv.put(x, y, outline)
