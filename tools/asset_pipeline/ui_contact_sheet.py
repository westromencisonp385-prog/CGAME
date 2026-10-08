# -*- coding: utf-8 -*-
"""Composite keyed UI PNGs onto a checkerboard contact sheet to inspect alpha quality."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

src_dir = Path(sys.argv[1])
out = Path(sys.argv[2])
ids = sys.argv[3].split(",") if len(sys.argv) > 3 and sys.argv[3] else None
files = sorted(src_dir.glob("*.png"))
if ids:
    files = [f for f in files if f.stem in ids]
cell = 300
cols = 6
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGBA", (cols * cell, rows * (cell + 24)), (60, 60, 60, 255))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    x, y = (i % cols) * cell, (i // cols) * (cell + 24)
    for cy in range(0, cell, 20):
        for cx in range(0, cell, 20):
            c = (90, 90, 90, 255) if (cx // 20 + cy // 20) % 2 else (140, 140, 140, 255)
            d.rectangle([x + cx, y + cy, x + cx + 19, y + cy + 19], fill=c)
    im = Image.open(f).convert("RGBA")
    im.thumbnail((cell - 16, cell - 16))
    sheet.alpha_composite(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2))
    d.text((x + 6, y + cell + 4), f.stem, fill=(255, 255, 255, 255))
sheet.convert("RGB").save(out)
print("sheet", out, len(files))
