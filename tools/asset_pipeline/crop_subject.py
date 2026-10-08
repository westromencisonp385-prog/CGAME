# -*- coding: utf-8 -*-
"""Center-crop a concept image to raise subject ratio (fixes weaver 130400)."""
import sys
from pathlib import Path

from PIL import Image

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
target = float(sys.argv[3]) if len(sys.argv) > 3 else 0.72

img = Image.open(src).convert("RGB")
w, h = img.size
gray = img.convert("L")
small = gray.resize((160, 160))
px = small.load()
# background = dominant corner tone; foreground = pixels far from it
corners = [px[2, 2], px[157, 2], px[2, 157], px[157, 157]]
bg = sum(corners) // 4
xs, ys = [], []
for iy in range(160):
    for ix in range(160):
        if abs(px[ix, iy] - bg) > 28:
            xs.append(ix); ys.append(iy)
if not xs:
    raise SystemExit("no foreground detected")
x0, x1, y0, y1 = min(xs) / 160, max(xs) / 160, min(ys) / 160, max(ys) / 160
pad = 0.04
cx0 = max(0.0, x0 - pad); cx1 = min(1.0, x1 + pad)
cy0 = max(0.0, y0 - pad); cy1 = min(1.0, y1 + pad)
bw, bh = cx1 - cx0, cy1 - cy0
# enforce target aspect 4:3 like weaver-friendly input, expand shorter side
side = max(bw, bh, target)
ccx, ccy = (cx0 + cx1) / 2, (cy0 + cy1) / 2
nx0 = max(0.0, ccx - side / 2); nx1 = min(1.0, ccx + side / 2)
ny0 = max(0.0, ccy - side * 0.75 / 2); ny1 = min(1.0, ccy + side * 0.75 / 2)
box = (int(nx0 * w), int(ny0 * h), int(nx1 * w), int(ny1 * h))
crop = img.crop(box)
if crop.width > 2048:
    crop = crop.resize((2048, int(2048 * crop.height / crop.width)), Image.LANCZOS)
dst.parent.mkdir(parents=True, exist_ok=True)
crop.save(dst)
print(f"crop {box} -> {dst} ({crop.width}x{crop.height}, subject_ratio {bw:.2f}x{bh:.2f} -> {min(crop.width/crop.height, 1/bw and bw/bh or 1):.2f})")
