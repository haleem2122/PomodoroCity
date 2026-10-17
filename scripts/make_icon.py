#!/usr/bin/env python3
"""Generates Packaging/AppIcon.png (1024x1024): a small isometric cottage on sage."""
from PIL import Image, ImageDraw
S = 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
# rounded sage square with vertical gradient
g = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(g)
for y in range(S):
    t = y / S
    gd.line([(0, y), (S, y)], fill=(int(150 - 40 * t), int(178 - 38 * t), int(145 - 40 * t), 255))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([60, 60, S - 60, S - 60], radius=190, fill=255)
img.paste(g, (0, 0), mask)
d = ImageDraw.Draw(img)
cx, cy = S // 2, 600
def P(x, y, z=0): return (cx + (x - y) * 150, cy + (x + y) * 75 - z)
# ground diamond
d.polygon([P(-1.2, -1.2), P(1.2, -1.2), P(1.2, 1.2), P(-1.2, 1.2)], fill=(168, 198, 140, 255))
d.polygon([P(-1.2, 1.2), P(1.2, 1.2), P(1.2, 1.2, -40), P(-1.2, 1.2, -40)], fill=(154, 116, 82, 255))
d.polygon([P(1.2, 1.2), P(1.2, -1.2), P(1.2, -1.2, -40), P(1.2, 1.2, -40)], fill=(125, 93, 65, 255))
# cottage walls
w = 0.62
d.polygon([P(-w, w), P(w, w), P(w, w, 230), P(-w, w, 230)], fill=(244, 234, 212, 255))
d.polygon([P(w, w), P(w, -w), P(w, -w, 230), P(w, w, 230)], fill=(216, 200, 170, 255))
# gable roof (ridge along x)
o = 0.78
d.polygon([P(o, o, 230), P(o, -o, 230), P(o, 0, 420)], fill=(216, 200, 170, 255))
d.polygon([P(-o, o, 230), P(o, o, 230), P(o, 0, 420), P(-o, 0, 420)], fill=(207, 119, 82, 255))
# door + window
d.polygon([P(-0.15, w), P(0.2, w), P(0.2, w, 150), P(-0.15, w, 150)], fill=(122, 90, 60, 255))
d.polygon([P(w, 0.05), P(w, -0.35), P(w, -0.35, 170), P(w, 0.05, 170)], fill=(159, 195, 207, 255))
# tree
tx, ty = P(1.0, 0.9)
d.rectangle([tx - 10, ty - 120, tx + 10, ty], fill=(115, 86, 56, 255))
for ox, oy, r, col in [(14, -170, 80, (88, 132, 74, 255)), (-30, -150, 72, (111, 156, 92, 255)), (-8, -215, 62, (139, 184, 116, 255))]:
    d.ellipse([tx + ox - r, ty + oy - r, tx + ox + r, ty + oy + r], fill=col)
img.save("Packaging/AppIcon.png")
print("icon written")
