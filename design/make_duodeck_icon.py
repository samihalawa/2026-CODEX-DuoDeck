#!/usr/bin/env python3
"""Render DuoDeck's original opaque App Store icon. Requires Pillow."""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
dst = Path(__file__).resolve().parent.parent / "iOSClient/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
base = Image.new("RGB", (SIZE, SIZE))
pix = base.load()
for y in range(SIZE):
    for x in range(SIZE):
        t = (x / SIZE) * .27 + (y / SIZE) * .55
        glow = max(0.0, 1 - math.hypot((x - 260) / 950, (y - 190) / 850))
        pix[x, y] = (
            int(7 + 20 * t + 11 * glow),
            int(13 + 24 * t + 18 * glow),
            int(28 + 50 * t + 32 * glow),
        )

img = base.convert("RGBA")
glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
g = ImageDraw.Draw(glow)
g.ellipse((140, 125, 875, 825), fill=(50, 207, 255, 35))
g.ellipse((275, 480, 995, 1100), fill=(114, 97, 255, 65))
glow = glow.filter(ImageFilter.GaussianBlur(105))
img = Image.alpha_composite(img, glow)

shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle((175, 175, 850, 862), radius=72, fill=(0, 0, 0, 170))
shadow = shadow.filter(ImageFilter.GaussianBlur(47))
img = Image.alpha_composite(img, shadow)

d = ImageDraw.Draw(img)
# Upper display: the live Mac preview
d.rounded_rectangle((199, 170, 823, 482), radius=59, fill=(10, 27, 49), outline=(155, 234, 255), width=17)
d.rounded_rectangle((227, 199, 795, 454), radius=40, fill=(20, 48, 77))
d.rounded_rectangle((242, 214, 780, 439), radius=32, fill=(15, 39, 65))
d.line((290, 264, 552, 264), fill=(100, 180, 226), width=12, joint="curve")
d.line((290, 300, 470, 300), fill=(63, 125, 163), width=12, joint="curve")
d.line((290, 338, 600, 338), fill=(63, 125, 163), width=12, joint="curve")
# A bright mouse pointer announces the product's purpose
pointer = [(620, 248), (620, 389), (653, 361), (685, 415), (704, 405), (674, 350), (714, 349)]
d.polygon(pointer, fill=(243, 250, 255))
d.line(pointer + [pointer[0]], fill=(120, 218, 244), width=5, joint="curve")

# Hinge joins display and touch deck
d.rounded_rectangle((262, 497, 760, 528), radius=16, fill=(116, 221, 244))
d.rounded_rectangle((307, 503, 715, 521), radius=9, fill=(208, 248, 255))

# Lower programmable control surface
d.rounded_rectangle((199, 541, 823, 859), radius=62, fill=(14, 25, 51), outline=(145, 154, 255), width=17)
d.rounded_rectangle((228, 568, 794, 831), radius=43, fill=(18, 32, 62))
# Small floating touchpad on the left
d.rounded_rectangle((255, 596, 505, 801), radius=32, fill=(11, 43, 67), outline=(71, 221, 247), width=8)
for yy in range(630, 777, 33):
    for xx in range(290, 480, 34):
        d.ellipse((xx-3, yy-3, xx+3, yy+3), fill=(58, 120, 150))
# Six command keys right
colors = [(77, 141, 249), (96, 117, 239), (61, 196, 220),
          (100, 138, 252), (97, 121, 243), (62, 196, 217)]
for i in range(6):
    c, r = i % 2, i // 2
    x0, y0 = 536 + c * 120, 602 + r * 70
    d.rounded_rectangle((x0, y0, x0 + 102, y0 + 55), radius=15, fill=colors[i])
    d.rounded_rectangle((x0+15, y0+17, x0+44, y0+22), radius=3, fill=(238, 248, 255, 226))
    d.rounded_rectangle((x0+15, y0+30, x0+73, y0+35), radius=3, fill=(209, 229, 250, 185))
img.convert("RGB").save(dst, "PNG", optimize=True)
print(dst, dst.stat().st_size)
