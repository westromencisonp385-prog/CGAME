# -*- coding: utf-8 -*-
"""UI v2 icon batch (TiMi gpt-image-2.5): flat faceted icons matching the RECLAIMER key art.

Frames/panels/buttons are NOT generated anymore (drawn procedurally in Godot, see p5_plate.gd).
Only icon content is generated: magenta background -> hard key -> premultiplied downscale to 256px.

Usage:
  python -u ui_icon_batch_v2.py --only icon_health --quality low     # trial
  python -u ui_icon_batch_v2.py --workers 2
"""
import argparse
import json
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, r"C:\Users\jasonlyan\.bg-agent\config-with-app\skills\timi-image\scripts")
import common as timi  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
RAW = REPO / "artifacts" / "ui_v2_raw"
OUT = REPO / "game" / "assets" / "ui" / "v2"
SIZE_PX = 256

STYLE = (
    "Single game UI icon in a clean flat faceted low-poly style, like crisp cut-paper polygons, "
    "matching an industrial fairy-tale excavator game. Perfectly straight hard edges, 2 to 3 flat matte colors "
    "with one darker facet for volume, one thin dark outline #1B1B1D, no texture, no gradient, no noise, no halftone, "
    "no glow, no drop shadow. Palette only: petrol blue #23394A, bone cream #EFE3C8, tomato red #D9412B, "
    "ochre yellow #E3A52B, greyish violet #8C7BA8. Bold readable silhouette that reads at 48 pixels, centered, "
    "filling about 70 percent of the canvas, on a perfectly flat solid pure magenta #FF00FF background, "
    "no magenta inside the icon. No text, no letters, no numbers."
)

ICONS = {
    "icon_health": "a sturdy faceted wrench crossed over a faceted heart",
    "icon_cargo": "a faceted excavator bucket full of chunky scrap blocks",
    "icon_heat": "a faceted flame shape over a small gear",
    "icon_silver": "a short stack of faceted silver coins",
    "icon_gold": "one large faceted gold coin with a gear emblem",
    "icon_quest": "a faceted clipboard with a bold check mark",
    "icon_boss": "a menacing faceted mechanical whale skull with a small crown",
    "icon_artifact": "a faceted glowing-looking gem relic on a small pedestal",
    "icon_captain": "a faceted captain hat with an anchor badge",
    "icon_key": "an ornate faceted key with a gear-shaped bow",
    "icon_module": "a faceted mechanical module block with a plug connector",
    "icon_reroll": "two faceted circular arrows chasing each other",
    "skill_dig": "a faceted excavator bucket slamming down with three sharp impact wedges",
    "skill_magnet": "a faceted horseshoe magnet with two short zigzag arcs",
    "skill_water": "a faceted nozzle shooting a bold wedge-shaped water jet",
    "skill_arc": "a faceted lightning bolt jumping between two small coils",
    "skill_dash": "three bold faceted chevrons pointing right",
    "skill_turret": "a small faceted deployable cannon turret on a tripod",
    "skill_emp": "a faceted burst ring shockwave around a small core",
    "skill_camp": "a faceted small repair tent with a wrench flag",
}

_lock = threading.Lock()


def log(m: str) -> None:
    with _lock:
        print(f"[{time.strftime('%H:%M:%S')}] {m}", flush=True)


def key_hard(src: Path, dst: Path) -> dict:
    a = np.asarray(Image.open(src).convert("RGBA")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = np.clip((np.minimum(r, b) - g) / 255.0, 0, 1)
    # steep key: flat graphics need hard edges, not a soft feathered halo
    alpha = np.clip(1.0 - (mag - 0.30) / 0.18, 0, 1)
    spill = np.clip(np.minimum(r, b) - g, 0, None) * (1.0 - alpha)
    a[..., 0] = np.clip(r - spill, 0, 255)
    a[..., 2] = np.clip(b - spill, 0, 255)
    a[..., 3] = alpha * 255
    img = Image.fromarray(a.astype(np.uint8), "RGBA")
    bbox = img.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox()
    if bbox:
        w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
        side = int(max(w, h) * 1.08)
        cx, cy = (bbox[0] + bbox[2]) // 2, (bbox[1] + bbox[3]) // 2
        img = img.crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side))
    # premultiplied downscale avoids dark/magenta fringes
    img = img.convert("RGBa").resize((SIZE_PX, SIZE_PX), Image.LANCZOS).convert("RGBA")
    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, optimize=True)
    al = np.asarray(img.getchannel("A"))
    semi = float(((al > 10) & (al < 245)).mean())
    return {"opaque": round(float((al > 200).mean()), 3), "semi_edge": round(semi, 4)}


def produce(iid: str, quality: str, force: bool) -> dict:
    out = OUT / f"{iid}.png"
    if out.exists() and not force:
        return {"id": iid, "skipped": True}
    for attempt in range(1, 4):
        try:
            paths = timi.generate(f"{ICONS[iid]}. {STYLE}", size="1024x1024", quality=quality,
                                  out_dir=RAW, stem=iid, timeout=600)
            info = key_hard(paths[0], out)
            log(f"OK {iid} {info}")
            return {"id": iid, "file": f"res://assets/ui/v2/{iid}.png", **info}
        except Exception as exc:  # noqa: BLE001
            log(f"{iid} attempt {attempt} failed: {str(exc)[:140]}")
            time.sleep(20 * attempt)
    return {"id": iid, "error": "failed"}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--quality", default="medium")
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    ids = [s.strip() for s in a.only.split(",") if s.strip()] or list(ICONS)
    log(f"icons {len(ids)} quality={a.quality} workers={a.workers}")
    res = []
    with ThreadPoolExecutor(max_workers=a.workers) as pool:
        for f in as_completed([pool.submit(produce, i, a.quality, a.force) for i in ids]):
            res.append(f.result())
    man = OUT / "manifest.json"
    old = json.loads(man.read_text(encoding="utf-8")) if man.exists() else {}
    for r in res:
        if "file" in r:
            old[r["id"]] = r
    man.write_text(json.dumps(old, ensure_ascii=False, indent=2), encoding="utf-8")
    missing = [i for i in ICONS if not (OUT / f"{i}.png").exists()]
    log(f"ICON SUMMARY ok={sum(1 for r in res if 'file' in r)} failed={sum(1 for r in res if 'error' in r)} missing={missing}")


if __name__ == "__main__":
    main()
