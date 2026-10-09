# -*- coding: utf-8 -*-
"""Compose artifacts/qa/c20_anim/<slot>/*.png into one contact sheet per slot (single row strip, cropped center)."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "artifacts" / "qa" / "c20_anim"
CELL = 240

for d in sorted(p for p in ROOT.iterdir() if p.is_dir()):
    frames = sorted(d.glob("*.png"))
    if not frames:
        continue
    cols = 10
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * CELL, rows * (CELL + 18)), "#1b1b1d")
    draw = ImageDraw.Draw(sheet)
    for i, f in enumerate(frames):
        im = Image.open(f).convert("RGB")
        w, h = im.size
        s = min(w, h)
        im = im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2)).resize((CELL, CELL))
        x, y = (i % cols) * CELL, (i // cols) * (CELL + 18)
        sheet.paste(im, (x, y + 18))
        draw.text((x + 4, y + 3), f.stem, fill="#EFE3C8")
    out = ROOT / f"{d.name}_sheet.png"
    sheet.save(out)
    print("sheet", out)
