#!/usr/bin/env python3
"""Draw the storybook theme's art in code: parchment, a starfield, a corner flourish,
a divider and the 13 sidebar tab icons. Everything is made here from shapes and noise
(no Blizzard or third-party art). Writes 32-bit TGAs to LOMBCompanion/Media/Storybook
(the addon tints the white ones) and PNG copies for the mock screenshots.
Run from the repo root: python3 tools/make_storybook.py [png_dir]"""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter

OUT = "LOMBCompanion/Media/Storybook"
PNG = sys.argv[1] if len(sys.argv) > 1 else None
os.makedirs(OUT, exist_ok=True)
if PNG: os.makedirs(PNG, exist_ok=True)
rnd = random.Random(4112026)   # fixed seed: same art every run


def save(img, name):
    img.save(os.path.join(OUT, name + ".tga"), rle=False)
    if PNG: img.save(os.path.join(PNG, name + ".png"))


def parchment(w=256, h=64):
    # warm cream, low-frequency blotches, fine fibres, darker toasted edges; tiles left-right
    base = Image.new("RGB", (w, h), (233, 214, 170))
    px = base.load()
    blot = Image.effect_noise((w // 8, h // 8), 40).resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(3))
    fine = Image.effect_noise((w, h), 18)
    b, f = blot.load(), fine.load()
    for y in range(h):
        for x in range(w):
            n = (b[x, y] - 128) / 128 * 14 + (f[x, y] - 128) / 128 * 6
            edge = min(y, h - 1 - y) / (h / 2)
            burn = (1 - min(1, edge * 2.2)) ** 2 * 46
            r, g, bb = px[x, y]
            px[x, y] = (int(max(0, r + n - burn)), int(max(0, g + n - burn * 1.15)), int(max(0, bb + n - burn * 1.4)))
    d = ImageDraw.Draw(base, "RGBA")
    for _ in range(60):   # fibres
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        a = rnd.uniform(-.3, .3); L = rnd.uniform(6, 22)
        d.line([(x, y), (x + L * math.cos(a), y + L * math.sin(a))], fill=(150, 118, 70, 26), width=1)
    return base.convert("RGBA")


def stars(n=256):
    img = Image.new("RGBA", (n * 2, n * 2), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    for _ in range(170):   # dust
        x, y = rnd.uniform(0, n * 2), rnd.uniform(0, n * 2); r = rnd.choice([1, 1, 1, 1.6, 2.2])
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, rnd.randint(60, 200)))
    for _ in range(9):     # four-point twinkles
        x, y = rnd.uniform(20, n * 2 - 20), rnd.uniform(20, n * 2 - 20); L = rnd.uniform(7, 13)
        d.polygon([(x, y - L), (x + 1.6, y - 1.6), (x + L, y), (x + 1.6, y + 1.6), (x, y + L), (x - 1.6, y + 1.6), (x - L, y), (x - 1.6, y - 1.6)],
                  fill=(255, 255, 255, 235))
    return img.resize((n, n), Image.LANCZOS)


def flourish(n=64):
    # a corner curl: a quarter-frame line that rolls into a spiral, with a leaf; white, tinted in game
    S = 4; N = n * S
    img = Image.new("RGBA", (N, N), (255, 255, 255, 0)); d = ImageDraw.Draw(img)
    W = int(2.2 * S)
    d.line([(4 * S, N - 2 * S), (4 * S, 22 * S)], fill="white", width=W)
    d.line([(N - 2 * S, 4 * S), (22 * S, 4 * S)], fill="white", width=W)
    def spiral(cx, cy, r0, turns, start):
        pts = []
        for i in range(160):
            t = i / 159; a = start + t * turns * 2 * math.pi; r = r0 * (1 - .82 * t)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        d.line(pts, fill="white", width=W, joint="curve")
    spiral(13 * S, 13 * S, 9 * S, 1.25, math.pi)
    d.ellipse([22 * S, 22 * S, 30 * S, 30 * S], outline="white", width=W)
    d.polygon([(30 * S, 14 * S), (42 * S, 10 * S), (34 * S, 18 * S)], fill="white")   # leaf
    d.polygon([(14 * S, 30 * S), (10 * S, 42 * S), (18 * S, 34 * S)], fill="white")
    return img.resize((n, n), Image.LANCZOS)


def divider(w=256, h=16):
    S = 4; img = Image.new("RGBA", (w * S, h * S), (255, 255, 255, 0)); d = ImageDraw.Draw(img)
    cy = h * S // 2
    for side in (-1, 1):
        x0 = w * S // 2 + side * 14 * S; x1 = w * S // 2 + side * (w * S // 2 - 6 * S)
        d.line([(x0, cy), (x1, cy)], fill=(255, 255, 255, 220), width=S)
        d.ellipse([x1 - 3 * S, cy - 3 * S, x1 + 3 * S, cy + 3 * S], fill="white")
    m = w * S // 2   # little moon in the middle
    d.ellipse([m - 7 * S, cy - 7 * S, m + 7 * S, cy + 7 * S], fill="white")
    d.ellipse([m - 3 * S, cy - 9 * S, m + 9 * S, cy + 5 * S], fill=(255, 255, 255, 0))
    return img.resize((w, h), Image.LANCZOS)


# ---- tab icons: 32x32 white glyphs drawn at 4x and scaled down
def icon(draw_fn):
    S = 4; N = 32 * S
    img = Image.new("RGBA", (N, N), (255, 255, 255, 0)); d = ImageDraw.Draw(img)
    draw_fn(d, S)
    return img.resize((32, 32), Image.LANCZOS)

def clear(d, box, shape="ellipse"):
    getattr(d, shape)(box, fill=(255, 255, 255, 0))

def i_roster(d, s):
    for cx, sc in ((11, .8), (21, 1)):
        d.ellipse([(cx - 4.5 * sc) * s, (12 - 4.5 * sc) * s, (cx + 4.5 * sc) * s, (12 + 4.5 * sc) * s], fill="white")
        d.pieslice([(cx - 8 * sc) * s, (19 - 1) * s, (cx + 8 * sc) * s, (35) * s], 180, 360, fill="white")
def i_me(d, s):
    d.ellipse([10 * s, 4 * s, 22 * s, 16 * s], fill="white")
    d.pieslice([5 * s, 18 * s, 27 * s, 40 * s], 180, 360, fill="white")
def i_crafters(d, s):   # hammer
    d.polygon([(7 * s, 9 * s), (19 * s, 4 * s), (23 * s, 12 * s), (11 * s, 17 * s)], fill="white")
    d.line([(15 * s, 13 * s), (26 * s, 28 * s)], fill="white", width=4 * s)
def i_news(d, s):       # scroll
    d.rounded_rectangle([7 * s, 6 * s, 25 * s, 26 * s], 2 * s, outline="white", width=2 * s)
    d.ellipse([4 * s, 4 * s, 10 * s, 10 * s], fill="white"); d.ellipse([22 * s, 22 * s, 28 * s, 28 * s], fill="white")
    for y in (11, 15, 19): d.line([(11 * s, y * s), (21 * s, y * s)], fill="white", width=2 * s)
def i_board(d, s):      # trophy
    d.pieslice([8 * s, -4 * s, 24 * s, 18 * s], 0, 180, fill="white")
    d.arc([3 * s, 4 * s, 12 * s, 13 * s], 90, 270, fill="white", width=2 * s); d.arc([20 * s, 4 * s, 29 * s, 13 * s], 270, 90, fill="white", width=2 * s)
    d.rectangle([14.5 * s, 17 * s, 17.5 * s, 23 * s], fill="white"); d.rectangle([10 * s, 23 * s, 22 * s, 27 * s], fill="white")
def i_bestiary(d, s):   # paw
    d.ellipse([10 * s, 15 * s, 22 * s, 26 * s], fill="white")
    for x, y in ((7, 11), (12.5, 6.5), (19.5, 6.5), (25, 11)): d.ellipse([(x - 3) * s, (y - 3.5) * s, (x + 3) * s, (y + 3.5) * s], fill="white")
def i_quests(d, s):     # open book
    d.polygon([(4 * s, 8 * s), (15 * s, 10 * s), (15 * s, 26 * s), (4 * s, 24 * s)], fill="white")
    d.polygon([(28 * s, 8 * s), (17 * s, 10 * s), (17 * s, 26 * s), (28 * s, 24 * s)], fill="white")
def i_ask(d, s):        # speech bubble with "?"
    d.rounded_rectangle([4 * s, 5 * s, 28 * s, 23 * s], 5 * s, fill="white"); d.polygon([(9 * s, 22 * s), (8 * s, 29 * s), (15 * s, 22 * s)], fill="white")
    d.arc([12.5 * s, 7.5 * s, 19.5 * s, 14.5 * s], 180, 90, fill=(255, 255, 255, 0), width=2 * s)
    d.line([(16 * s, 14.5 * s), (16 * s, 17 * s)], fill=(255, 255, 255, 0), width=2 * s); clear(d, [15 * s, 18.5 * s, 17 * s, 20.5 * s])
def i_events(d, s):     # calendar
    d.rounded_rectangle([5 * s, 7 * s, 27 * s, 27 * s], 2 * s, outline="white", width=2 * s); d.rectangle([5 * s, 7 * s, 27 * s, 12 * s], fill="white")
    d.line([(10 * s, 4 * s), (10 * s, 9 * s)], fill="white", width=2 * s); d.line([(22 * s, 4 * s), (22 * s, 9 * s)], fill="white", width=2 * s)
    for x in (10, 16, 22):
        for y in (17, 22): d.rectangle([(x - 1.5) * s, (y - 1.5) * s, (x + 1.5) * s, (y + 1.5) * s], fill="white")
def i_wishlist(d, s):   # five-point star
    pts = [(16 + (12 if k % 2 == 0 else 5) * math.sin(k * math.pi / 5), 17 - (12 if k % 2 == 0 else 5) * math.cos(k * math.pi / 5)) for k in range(10)]
    d.polygon([(x * s, y * s) for x, y in pts], fill="white")
def i_bank(d, s):       # chest
    d.rounded_rectangle([4 * s, 13 * s, 28 * s, 27 * s], 2 * s, fill="white"); d.pieslice([4 * s, 5 * s, 28 * s, 21 * s], 180, 360, fill="white")
    d.line([(4 * s, 14 * s), (28 * s, 14 * s)], fill=(255, 255, 255, 0), width=s); clear(d, [14 * s, 13 * s, 18 * s, 18 * s], "rectangle")
def i_settings(d, s):   # gear
    for k in range(8):
        a = k * math.pi / 4
        d.line([(16 * s, 16 * s), ((16 + 12 * math.cos(a)) * s, (16 + 12 * math.sin(a)) * s)], fill="white", width=5 * s)
    d.ellipse([7 * s, 7 * s, 25 * s, 25 * s], fill="white"); clear(d, [12.5 * s, 12.5 * s, 19.5 * s, 19.5 * s])
def i_credits(d, s):    # quill
    d.polygon([(26 * s, 3 * s), (12 * s, 13 * s), (7 * s, 25 * s), (19 * s, 19 * s)], fill="white")
    d.line([(7 * s, 25 * s), (4 * s, 29 * s)], fill="white", width=2 * s); d.line([(9 * s, 23 * s), (22 * s, 8 * s)], fill=(255, 255, 255, 0), width=s)

ICONS = dict(roster=i_roster, me=i_me, crafters=i_crafters, news=i_news, board=i_board, bestiary=i_bestiary, quests=i_quests,
             ask=i_ask, events=i_events, wishlist=i_wishlist, bank=i_bank, settings=i_settings, credits=i_credits)

if __name__ == "__main__":
    save(parchment(), "parchment"); save(stars(), "stars"); save(flourish(), "flourish"); save(divider(), "divider")
    for k, fn in ICONS.items(): save(icon(fn), "icon-" + k)
    print("wrote", 4 + len(ICONS), "textures to", OUT)
