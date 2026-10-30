#!/usr/bin/env python3
"""Generate Media/logo.tga (64x64, 32-bit) -- violet crescent moon + gold star
on a dark disc. Run from the repo root: python3 tools/make_logo.py"""
from PIL import Image, ImageDraw, ImageFilter
import math, os

S = 256  # draw big, downsample for smooth edges
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.ellipse((8, 8, S - 8, S - 8), fill=(20, 15, 32, 255), outline=(62, 51, 82, 255), width=8)
# glow
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse((50, 44, 200, 194), fill=(184, 115, 255, 90))
glow = glow.filter(ImageFilter.GaussianBlur(18))
img = Image.alpha_composite(img, glow)
# crescent: full moon minus offset disc
moon = Image.new("L", (S, S), 0)
md = ImageDraw.Draw(moon)
md.ellipse((56, 48, 196, 188), fill=255)
md.ellipse((96, 30, 226, 160), fill=0)
violet = Image.new("RGBA", (S, S), (184, 115, 255, 255))
img.paste(violet, (0, 0), moon)
# star
def star(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts
d = ImageDraw.Draw(img)
d.polygon(star(170, 92, 34, 14), fill=(242, 199, 92, 255))
d.polygon(star(150, 168, 13, 5), fill=(242, 199, 92, 230))
out = img.resize((64, 64), Image.LANCZOS)
here = os.path.dirname(os.path.abspath(__file__))
media = os.path.join(here, "..", "LOMBCompanion", "Media")
out.save(os.path.join(media, "logo.tga"))
out.resize((128, 128), Image.LANCZOS).save(os.path.join(here, "..", "docs", "logo.png")) if os.path.isdir(os.path.join(here, "..", "docs")) else None
print("wrote", os.path.join(media, "logo.tga"))
