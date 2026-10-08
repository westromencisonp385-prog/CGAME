# -*- coding: utf-8 -*-
"""Style v3: restyle every 3D input concept to the RECLAIMER key-art style before Weaver.

TiMi gpt-image-2.5 multi-image edit: [concept, style anchor] -> same design, key-art rendering.
Output: artifacts/weaver/inputs_v3/<ID>-v3.png  (single subject, flat light-grey background, 3/4 view)

Usage:
  python -u style_v3_concepts.py --only M08,E02,B02
  python -u style_v3_concepts.py --workers 2
"""
import argparse
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, r"C:\Users\jasonlyan\.bg-agent\config-with-app\skills\timi-image\scripts")
sys.path.insert(0, str(Path(__file__).parent))
import common as timi  # noqa: E402
import weaver_p2_v2 as p2  # noqa: E402

REPO = p2.REPO
ANCHOR = REPO / "docs" / "assets" / "style-anchor-industrial-folk-v1.png"
OUT = REPO / "artifacts" / "weaver" / "inputs_v3"
RAW = REPO / "artifacts" / "weaver" / "inputs_v3_raw"

# 3 件正式 G1 资产补进来，统一风格
EXTRA = {
    "A01": REPO / "artifacts" / "weaver" / "inputs" / "player_a01-clean-v2.png",
    "B01": REPO / "artifacts" / "weaver" / "inputs" / "enemy_b01-clean-v2.png",
    "C04": REPO / "artifacts" / "weaver" / "inputs" / "facility_c04-clean-v2.png",
}

STYLE = (
    "Redraw the machine from the FIRST image as a game 3D-model reference in the art style of the SECOND image. "
    "Keep exactly the same design, silhouette, proportions, pose, part layout and every functional part "
    "(legs, arms, jaws, wings, rings, tools, treads) of the first image; do not add or remove parts. "
    "Style: industrial fairy-tale low-poly toy, chunky faceted slabs, big readable shapes, matte flat color blocks "
    "with simple three-step cel shading, one thin dark ink outline, very few hand-painted strokes. "
    "Strict shared palette: petrol blue #23394A and #2F4B5C, bone cream #EFE3C8, tomato red #D9412B, "
    "ochre yellow #E3A52B, greyish violet #8C7BA8, rubber black #1B1B1D; at most five main colors; glow only on "
    "magnet rings. Remove all rust, grime, scratches, dirt, decals, tiny bolts, rivets, metal noise, reflections, "
    "specular highlights and gradients. Single subject only, three-quarter front view, whole object fully visible "
    "with margin, soft even light, plain flat light grey background #D8D8D8, no shadow on ground, no text, no "
    "frame, no other objects."
)

_lock = threading.Lock()


def log(m: str) -> None:
    with _lock:
        print(f"[{time.strftime('%H:%M:%S')}] {m}", flush=True)


def source_of(aid: str) -> Path:
    if aid in EXTRA:
        return EXTRA[aid]
    return p2.PLAN[aid]["concept"]


def produce(aid: str, quality: str, force: bool) -> dict:
    dst = OUT / f"{aid}-v3.png"
    if dst.exists() and not force:
        return {"id": aid, "skipped": True}
    src = source_of(aid)
    if not src.exists():
        return {"id": aid, "error": f"missing source {src}"}
    for attempt in range(1, 4):
        try:
            paths = timi.edit(STYLE, [src, ANCHOR], size="1024x1024", out_dir=RAW, stem=aid, timeout=600)
            OUT.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(Path(paths[0]).read_bytes())
            log(f"OK {aid}")
            return {"id": aid, "file": str(dst)}
        except Exception as exc:  # noqa: BLE001
            log(f"{aid} attempt {attempt} failed: {str(exc)[:160]}")
            time.sleep(20 * attempt)
    return {"id": aid, "error": "failed"}


def all_ids() -> list:
    return list(EXTRA) + list(p2.PLAN)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--quality", default="high")
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    ids = [s.strip().upper() for s in a.only.split(",") if s.strip()] or all_ids()
    log(f"restyle {len(ids)} quality={a.quality}")
    res = []
    with ThreadPoolExecutor(max_workers=a.workers) as pool:
        for f in as_completed([pool.submit(produce, i, a.quality, a.force) for i in ids]):
            res.append(f.result())
    bad = [r for r in res if "error" in r]
    log(f"RESTYLE SUMMARY ok={len(res) - len(bad)} failed={bad}")


if __name__ == "__main__":
    main()
