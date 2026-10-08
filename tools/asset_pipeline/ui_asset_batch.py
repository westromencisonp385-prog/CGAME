# -*- coding: utf-8 -*-
"""P5/Metaphor-style UI asset batch producer (TiMi gpt-image-2.5).

Each asset is generated alone on a flat magenta (#FF00FF) background, then keyed
to a transparent, trimmed PNG under game/assets/ui/p5/. Parallel with a small
worker pool (platform has QPM limits). Idempotent: existing outputs are skipped.

Usage:
  python -u ui_asset_batch.py --list
  python -u ui_asset_batch.py --quality medium --workers 4
  python -u ui_asset_batch.py --only panel_hud,btn_normal --force
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
RAW_DIR = REPO / "artifacts" / "ui_p5_raw"
OUT_DIR = REPO / "game" / "assets" / "ui" / "p5"
MANIFEST = OUT_DIR / "manifest.json"

STYLE = (
    "Persona 5 and Metaphor ReFantazio inspired game UI art: aggressive diagonal slashed shapes, "
    "jagged torn-paper and ransom-note cut edges, heavy black ink outline, halftone dot shading, "
    "subtle grunge print texture, construction hazard stripe motifs. "
    "Palette strictly: tomato red #D9412B, ink black #141414, bone cream #EFE3C8, ochre yellow #E3A52B accent, "
    "small petrol blue #2F4B5C. Flat graphic, crisp clean edges, game-ready UI element. "
    "The single element is centered and isolated on a perfectly flat solid pure magenta #FF00FF background, "
    "no magenta inside the element, no drop shadow onto the background, no scene, no mockup, no frame around the image."
)
NO_TEXT = " Absolutely no text, no letters, no numbers, no logos anywhere."

# id: (size, prompt, text_allowed)
ASSETS = {
    # ---- 面板 / 底板（九宫格用，内部留大块干净区域）----
    "panel_hud": ("1536x1024", "A wide horizontal HUD plate: slanted parallelogram shape tilted about 8 degrees, bone cream body with a thick ink black jagged border and a red slash stripe along the top edge, large empty clean interior area for text.", False),
    "panel_mission": ("1024x1536", "A tall mission card panel: torn paper rectangle slightly rotated, bone cream with a red tab on the top-left corner and a black tape strip, halftone shading at the bottom, large empty interior.", False),
    "panel_dialog": ("1536x1024", "A large modal dialog panel: ink black body with a jagged red outer offset layer behind it, sharp cut corners, a thin cream inner border line, large empty interior.", False),
    "panel_garage": ("1024x1536", "A tall build-workshop side panel: ink black body, cream diagonal header band at the top with hazard stripes, red shard accent on the left edge, large empty interior.", False),
    "panel_tooltip": ("1536x1024", "A small speech-bubble style tooltip plate: cream body, heavy black outline, sharp triangular tail at the bottom left, slanted shape.", False),
    "panel_banner_red": ("1536x1024", "A long horizontal banner strip: red skewed ribbon with torn ragged ends and a black offset shadow layer, empty center.", False),
    # ---- 按钮三态 ----
    "btn_normal": ("1536x1024", "A wide arrow-shaped slanted button plate pointing right: bone cream body, thick black outline, small chevron cut on the right end, empty center.", False),
    "btn_hover": ("1536x1024", "A wide arrow-shaped slanted button plate pointing right: ochre yellow body, thick black outline, red slash accent on the left, small chevron on the right end, empty center.", False),
    "btn_pressed": ("1536x1024", "A wide arrow-shaped slanted button plate pointing right: tomato red body, thick black outline, slightly compressed look, white sparkle burst on one corner, empty center.", False),
    "btn_disabled": ("1536x1024", "A wide arrow-shaped slanted button plate pointing right: dull dark gray body with faded halftone, thin black outline, empty center.", False),
    # ---- 选择卡（稀有度四档）----
    "card_common": ("1024x1536", "A vertical upgrade card frame: cream inner area, thick ink black frame with jagged cut corners, gray steel trim, empty illustration window at top, empty text area at bottom.", False),
    "card_uncommon": ("1024x1536", "A vertical upgrade card frame: cream inner area, thick ink black frame with jagged cut corners, green and black trim with small sparkle marks, empty illustration window at top, empty text area at bottom.", False),
    "card_rare": ("1024x1536", "A vertical upgrade card frame: cream inner area, thick ink black frame with jagged cut corners, petrol blue and electric cyan trim with halftone burst, empty illustration window at top, empty text area at bottom.", False),
    "card_epic": ("1024x1536", "A vertical upgrade card frame: cream inner area, thick ink black frame with jagged cut corners, ochre gold and red flame-like shard trim radiating out, starburst behind the frame, empty illustration window at top, empty text area at bottom.", False),
    # ---- 技能槽 / 状态条 ----
    "skill_slot": ("1024x1024", "A slanted square skill slot frame tilted 10 degrees: thick black border, red corner triangle, empty dark center.", False),
    "skill_slot_ready": ("1024x1024", "A slanted square skill slot frame tilted 10 degrees: thick black border with a bright ochre yellow glowing outline and radiating speed lines, empty dark center.", False),
    "bar_frame": ("1536x1024", "A long thin horizontal slanted health bar frame: black outline with jagged ends, empty hollow interior, red notch on the left end.", False),
    "bar_fill_red": ("1536x1024", "A long thin horizontal slanted bar fill: solid tomato red with halftone gradient and diagonal stripe pattern, jagged right end.", False),
    "bar_fill_ochre": ("1536x1024", "A long thin horizontal slanted bar fill: solid ochre yellow with halftone gradient and diagonal stripe pattern, jagged right end.", False),
    # ---- 装饰 / 特效 ----
    "deco_star_burst": ("1024x1024", "A spiky comic starburst explosion shape: red with black outline and cream inner star, halftone dots.", False),
    "deco_slash": ("1536x1024", "A single dramatic diagonal brush slash mark: red with black edge, ragged ink splatter ends.", False),
    "deco_tape": ("1536x1024", "A strip of black and ochre yellow hazard tape, slightly torn at both ends, slanted.", False),
    "deco_halftone_corner": ("1024x1024", "A corner decoration of large black halftone dots fading diagonally, with a red triangle shard.", False),
    "deco_selector_arrow": ("1024x1024", "A bold pointing hand-drawn arrow cursor: red with thick black outline and white highlight, pointing right.", False),
    # ---- 图标（玩法）----
    "icon_health": ("1024x1024", "Icon: a wrench crossed with a heart shape, cream and red, heavy black outline, slanted badge background.", False),
    "icon_cargo": ("1024x1024", "Icon: a full excavator bucket loaded with scrap chunks, cream and ochre, heavy black outline.", False),
    "icon_heat": ("1024x1024", "Icon: a flame inside a gear, red and ochre, heavy black outline.", False),
    "icon_silver": ("1024x1024", "Icon: a stack of silver coins with a sparkle, cream and gray, heavy black outline.", False),
    "icon_gold": ("1024x1024", "Icon: a single big gold coin stamped with a gear, ochre, heavy black outline.", False),
    "icon_quest": ("1024x1024", "Icon: a clipboard with a checkmark, cream and red, heavy black outline.", False),
    "icon_boss": ("1024x1024", "Icon: a menacing crowned mechanical skull mask, red and black, heavy outline.", False),
    "icon_artifact": ("1024x1024", "Icon: a glowing mysterious gem relic on a small pedestal, petrol blue and ochre, heavy black outline.", False),
    "icon_captain": ("1024x1024", "Icon: a captain hat with an anchor emblem, petrol blue and cream, heavy black outline.", False),
    "icon_key": ("1024x1024", "Icon: an ornate old key with a gear bow, ochre, heavy black outline.", False),
    "icon_module": ("1024x1024", "Icon: a mechanical module block with a plug, cream and red, heavy black outline.", False),
    "icon_reroll": ("1024x1024", "Icon: two circular arrows around a die, red and cream, heavy black outline.", False),
    # ---- 技能图标 ----
    "skill_dig": ("1024x1024", "Skill icon: excavator bucket smashing down with impact lines, red and cream, heavy black outline.", False),
    "skill_magnet": ("1024x1024", "Skill icon: horseshoe magnet pulling scrap with lightning arcs, red and petrol blue, heavy black outline.", False),
    "skill_water": ("1024x1024", "Skill icon: pressurized water jet burst from a nozzle, petrol blue and cream, heavy black outline.", False),
    "skill_arc": ("1024x1024", "Skill icon: electric arc chain lightning between two coils, ochre and black, heavy outline.", False),
    "skill_dash": ("1024x1024", "Skill icon: speed dash chevrons with flywheel, red and ochre, heavy black outline.", False),
    "skill_turret": ("1024x1024", "Skill icon: small deployable cannon turret, cream and red, heavy black outline.", False),
    "skill_emp": ("1024x1024", "Skill icon: expanding shockwave ring pulse, petrol blue and cream, heavy black outline.", False),
    "skill_camp": ("1024x1024", "Skill icon: small repair camp tent with a wrench flag, ochre and cream, heavy black outline.", False),
    # ---- 大字标题（允许文字）----
    "title_victory": ("1536x1024", "Huge bold ransom-note style title word 'CLEAR!' made of mismatched cut-out letter blocks on a red skewed banner with a black offset shadow.", True),
    "title_defeat": ("1536x1024", "Huge bold ransom-note style title word 'DOWN' made of mismatched cut-out letter blocks on a black skewed banner with a red offset shadow, cracked.", True),
    "title_boss": ("1536x1024", "Huge bold ransom-note style title word 'WARNING' made of mismatched cut-out letter blocks with hazard stripes, red and black, skewed.", True),
    "title_levelup": ("1536x1024", "Huge bold ransom-note style title word 'UPGRADE' made of mismatched cut-out letter blocks on an ochre skewed banner, sparkles.", True),
    "title_logo": ("1536x1024", "Game logo lettering 'RECLAIMER' in bold ransom-note cut-out style with an excavator bucket replacing the letter A, red cream and black, skewed and dynamic.", True),
}

_lock = threading.Lock()


def log(msg: str) -> None:
    with _lock:
        print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def key_magenta(src: Path, dst: Path) -> dict:
    """Magenta chroma key with despill, then trim to content bbox + small pad."""
    img = Image.open(src).convert("RGBA")
    a = np.asarray(img).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # magenta-ness: high R and B, low G
    mag = np.clip((np.minimum(r, b) - g) / 255.0, 0, 1)
    alpha = np.clip(1.0 - (mag - 0.25) / 0.35, 0, 1)
    # despill: pull magenta tint out of semi-transparent edge pixels
    spill = np.clip(np.minimum(r, b) - g, 0, None) * (1 - alpha)
    a[..., 0] = np.clip(r - spill, 0, 255)
    a[..., 2] = np.clip(b - spill, 0, 255)
    a[..., 3] = alpha * 255
    out = Image.fromarray(a.astype(np.uint8), "RGBA")
    bbox = out.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    if bbox:
        pad = 8
        bbox = (max(bbox[0] - pad, 0), max(bbox[1] - pad, 0), min(bbox[2] + pad, out.width), min(bbox[3] + pad, out.height))
        out = out.crop(bbox)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, optimize=True)
    opaque = float((np.asarray(out.getchannel("A")) > 200).mean())
    return {"w": out.width, "h": out.height, "opaque_ratio": round(opaque, 3)}


def produce(asset_id: str, quality: str, force: bool) -> dict:
    size, prompt, text_ok = ASSETS[asset_id]
    out = OUT_DIR / f"{asset_id}.png"
    if out.exists() and not force:
        return {"id": asset_id, "skipped": True}
    full = f"{prompt} {STYLE}" + ("" if text_ok else NO_TEXT)
    for attempt in range(1, 4):
        try:
            paths = timi.generate(full, size=size, quality=quality, out_dir=RAW_DIR, stem=asset_id, timeout=600)
            info = key_magenta(paths[0], out)
            log(f"OK {asset_id} {info}")
            return {"id": asset_id, "file": str(out.relative_to(REPO / 'game')).replace('\\', '/'), **info}
        except Exception as exc:  # noqa: BLE001
            log(f"{asset_id} attempt {attempt} failed: {str(exc)[:160]}")
            time.sleep(15 * attempt)
    return {"id": asset_id, "error": "failed after retries"}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--quality", default="medium")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    if args.list:
        for k, v in ASSETS.items():
            print(f"{k:24s} {v[0]}")
        print(f"total {len(ASSETS)}")
        return
    ids = [s.strip() for s in args.only.split(",") if s.strip()] or list(ASSETS)
    log(f"producing {len(ids)} assets, quality={args.quality}, workers={args.workers}")
    results = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = [pool.submit(produce, i, args.quality, args.force) for i in ids]
        for f in as_completed(futs):
            results.append(f.result())
    old = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    for r in results:
        if "file" in r:
            old[r["id"]] = r
    MANIFEST.write_text(json.dumps(old, ensure_ascii=False, indent=2), encoding="utf-8")
    ok = sum(1 for r in results if "file" in r)
    log(f"SUMMARY ok={ok} skipped={sum(1 for r in results if r.get('skipped'))} failed={sum(1 for r in results if 'error' in r)} manifest={len(old)}")


if __name__ == "__main__":
    main()
