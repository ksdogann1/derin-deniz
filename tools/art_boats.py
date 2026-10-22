"""Tekne ve altın görselleri (piksel sanat, Pillow).
Her tekne iki katman: <ad>.png (gövde, ayrıntılar) ve <ad>_paint.png (boyanan bölüm, beyaz;
oyunda oyuncunun seçtiği renge boyanır). Su çizgisi resmin WL satırında.
Çıktı: assets/boats/, assets/coin.png"""
from PIL import Image, ImageDraw
import math, pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets"

OUTLINE = (22, 26, 34, 255)
WOOD_D = (92, 58, 34, 255)
WOOD = (132, 86, 50, 255)
WOOD_L = (170, 118, 70, 255)
METAL_D = (70, 80, 92, 255)
METAL = (120, 134, 148, 255)
METAL_L = (176, 190, 202, 255)
WHITE = (236, 242, 246, 255)
WHITE_D = (196, 208, 216, 255)
GLASS = (90, 170, 220, 255)
GLASS_L = (170, 225, 250, 255)
RED = (210, 70, 60, 255)
YELLOW = (240, 196, 70, 255)
ROPE = (196, 170, 120, 255)
BOTTOM = (60, 40, 40, 255)


def hull_poly(w, top, wl, depth, bow, stern):
    """Gövde çokgeni: güverte (top) ile omurga (wl+depth) arası; pruva sağda."""
    keel = wl + depth
    return [(stern, top), (w - 1, top - 2), (w - 1 - bow // 3, top + 2),
            (w - 1 - bow, keel), (stern + 4, keel), (1, top + 3)]


def shade_rows(img, mask, light, base, dark, y0, y1):
    px = img.load()
    m = mask.load()
    for y in range(img.height):
        for x in range(img.width):
            if m[x, y]:
                t = (y - y0) / max(1, (y1 - y0))
                c = light if t < 0.25 else (base if t < 0.7 else dark)
                px[x, y] = c


def outline(img):
    px = img.load()
    w, h = img.size
    src = img.copy().load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0 and src[nx, ny] != OUTLINE:
                        px[x, y] = OUTLINE
                        break


def make(name, w, h, wl, tier):
    base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    paint = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    dp = ImageDraw.Draw(paint)
    depth = {0: 7, 1: 10, 2: 12, 3: 15}[tier]
    top = wl - {0: 5, 1: 9, 2: 10, 3: 13}[tier]
    bow = {0: 10, 1: 16, 2: 22, 3: 24}[tier]
    poly = hull_poly(w, top, wl, depth, bow, 2)
    mask = Image.new("1", (w, h), 0)
    ImageDraw.Draw(mask).polygon(poly, fill=1)
    if tier == 0:
        shade_rows(base, mask, WOOD_L, WOOD, WOOD_D, top, wl + depth)
        # tahta çizgileri
        for yy in range(top + 3, wl + depth, 3):
            for x in range(w):
                if mask.getpixel((x, yy)) and (x + yy) % 9 != 0:
                    base.putpixel((x, yy), WOOD_D)
    else:
        shade_rows(base, mask, WHITE, WHITE_D, METAL, top, wl + depth)
        # su altı boyası
        for y in range(wl + 2, h):
            for x in range(w):
                if mask.getpixel((x, y)):
                    base.putpixel((x, y), BOTTOM)
    # boyanan şerit (gövde yan bandı)
    band_y0 = top + (2 if tier == 0 else 3)
    band_y1 = band_y0 + (2 if tier == 0 else 3 + tier)
    for y in range(band_y0, band_y1):
        for x in range(w):
            if mask.getpixel((x, y)):
                paint.putpixel((x, y), (255, 255, 255, 255))
    # lomboz / ayrıntılar
    if tier >= 1:
        for x in range(stern_x := 10, w - bow - 4, 9 + tier):
            cy = band_y1 + 2
            if cy < wl:
                d.ellipse([x, cy, x + 3, cy + 3], fill=GLASS, outline=METAL_D)
    # üst yapı
    if tier == 0:
        # kürek ve küçük motor
        d.line([(6, top - 6), (22, top + 3)], fill=WOOD_D, width=2)
        d.rectangle([1, top - 5, 6, top + 2], fill=METAL_D)
        d.rectangle([2, top - 4, 5, top - 1], fill=METAL)
    elif tier == 1:
        # balıkçı: kabin, vinç, ağ
        cx0, cx1 = 12, 44
        d.rectangle([cx0, top - 18, cx1, top], fill=WHITE_D, outline=OUTLINE)
        d.rectangle([cx0 + 1, top - 18, cx1 - 1, top - 15], fill=RED)
        for x in range(cx0 + 4, cx1 - 4, 9):
            d.rectangle([x, top - 12, x + 5, top - 7], fill=GLASS, outline=METAL_D)
            d.point((x + 1, top - 11), fill=GLASS_L)
        dp.rectangle([cx0 + 1, top - 18, cx1 - 1, top - 15], fill=(255, 255, 255, 255))
        # vinç direği
        d.line([(60, top), (60, top - 26)], fill=METAL_D, width=2)
        d.line([(60, top - 24), (80, top - 12)], fill=METAL, width=1)
        d.line([(80, top - 12), (80, top - 2)], fill=ROPE, width=1)
        # ağ yığını
        for i in range(5):
            d.arc([66 + i * 2, top - 6, 76 + i * 2, top + 2], 180, 360, fill=ROPE)
    elif tier == 2:
        # yat: iki katlı şık kabin, korkuluk
        d.polygon([(14, top), (14, top - 14), (54, top - 14), (70, top)], fill=WHITE, outline=OUTLINE)
        d.polygon([(22, top - 14), (22, top - 24), (46, top - 24), (56, top - 14)], fill=WHITE_D, outline=OUTLINE)
        d.polygon([(18, top - 11), (18, top - 5), (60, top - 5), (55, top - 11)], fill=GLASS)
        d.line([(19, top - 10), (54, top - 10)], fill=GLASS_L)
        d.polygon([(25, top - 22), (25, top - 17), (50, top - 17), (46, top - 22)], fill=GLASS)
        dp.polygon([(14, top - 2), (14, top - 4), (66, top - 4), (68, top - 2)], fill=(255, 255, 255, 255))
        for x in range(72, w - 8, 4):
            d.line([(x, top - 1), (x, top - 5)], fill=METAL_L)
        d.line([(72, top - 5), (w - 8, top - 6)], fill=METAL_L)
        d.line([(34, top - 24), (34, top - 34)], fill=METAL_D)
        d.polygon([(34, top - 34), (41, top - 31), (34, top - 29)], fill=RED)
    else:
        # araştırma gemisi: büyük köprü, radar, A-çerçeve vinç, denizaltı
        d.rectangle([22, top - 20, 76, top], fill=WHITE, outline=OUTLINE)
        d.rectangle([30, top - 34, 68, top - 20], fill=WHITE_D, outline=OUTLINE)
        for x in range(34, 64, 8):
            d.rectangle([x, top - 30, x + 5, top - 25], fill=GLASS, outline=METAL_D)
            d.point((x + 1, top - 29), fill=GLASS_L)
        for x in range(26, 72, 7):
            d.ellipse([x, top - 14, x + 3, top - 11], fill=GLASS, outline=METAL_D)
        dp.rectangle([23, top - 20, 75, top - 17], fill=(255, 255, 255, 255))
        # radar direği
        d.line([(49, top - 34), (49, top - 50)], fill=METAL_D, width=2)
        d.line([(42, top - 46), (56, top - 46)], fill=METAL, width=2)
        d.ellipse([46, top - 54, 52, top - 48], fill=WHITE, outline=METAL_D)
        d.point((49, top - 56), fill=RED)
        # A-çerçeve vinç
        d.line([(8, top), (14, top - 22)], fill=YELLOW, width=2)
        d.line([(20, top), (14, top - 22)], fill=YELLOW, width=2)
        d.line([(14, top - 22), (4, top - 14)], fill=YELLOW, width=1)
        d.line([(4, top - 14), (4, top - 6)], fill=ROPE)
        # küçük sarı denizaltı
        d.ellipse([86, top - 10, 104, top], fill=YELLOW, outline=OUTLINE)
        d.rectangle([92, top - 14, 97, top - 9], fill=YELLOW, outline=OUTLINE)
        d.ellipse([88, top - 7, 92, top - 3], fill=GLASS, outline=METAL_D)
        # baca
        d.rectangle([62, top - 28, 70, top - 20], fill=METAL_D, outline=OUTLINE)
        dp.rectangle([63, top - 27, 69, top - 24], fill=(255, 255, 255, 255))
    # bayrak (kıçta)
    d.line([(3, top + 1), (3, top - 10 - tier * 2)], fill=METAL_D)
    d.rectangle([4, top - 10 - tier * 2, 10, top - 6 - tier * 2], fill=RED)
    outline(base)
    (OUT / "boats").mkdir(parents=True, exist_ok=True)
    base.save(OUT / "boats" / f"{name}.png")
    paint.save(OUT / "boats" / f"{name}_paint.png")
    return base


def coin():
    s = 32
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2, 3, 29, 30], fill=(150, 98, 20, 255))
    d.ellipse([2, 1, 29, 28], fill=(240, 186, 52, 255), outline=(150, 98, 20, 255), width=2)
    d.ellipse([7, 6, 24, 23], outline=(196, 140, 34, 255), width=2)
    d.arc([8, 5, 20, 15], 200, 300, fill=(255, 240, 170, 255), width=2)
    d.line([(15, 10), (15, 19)], fill=(150, 98, 20, 255), width=3)
    img.save(OUT / "coin.png")


# ad, genişlik, yükseklik, su çizgisi satırı, kademe
BOATS = [("sandal", 72, 40, 30, 0), ("balikci", 104, 56, 40, 1), ("yat", 124, 64, 46, 2),
         ("arastirma", 152, 88, 66, 3)]

if __name__ == "__main__":
    for b in BOATS:
        make(*b)
    coin()
    print("tekneler ve altın hazır")
