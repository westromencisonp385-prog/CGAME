# -*- coding: utf-8 -*-
"""Enemy roster v3: NEW minion / elite / boss designs, drawn directly in the RECLAIMER v3 style.

TiMi multi-image edit: [style anchor, tier reference (existing v3 enemy)] + design brief -> single-subject concept
at artifacts/weaver/inputs_v3/<ID>-v3.png, ready for weaver_v3_batch.py.

Tier language (readability in the top-down camera):
  minion : small, one silhouette = one verb, petrol blue + ochre, tomato-red eye lights
  elite  : bigger, bone-white armor plates with tomato-red trim, red rotating warning beacon on top
  boss   : biggest, layered silhouette, glowing greyish-violet core, ochre/red hazard accents

Usage:
  python -u enemy_roster_v3.py --only N05
  python -u enemy_roster_v3.py --workers 3
"""
import argparse
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, r"C:\Users\jasonlyan\.bg-agent\config-with-app\skills\timi-image\scripts")
import common as timi  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
ANCHOR = REPO / "docs" / "assets" / "style-anchor-industrial-folk-v1.png"
V3 = REPO / "artifacts" / "weaver" / "inputs_v3"
RAW = REPO / "artifacts" / "weaver" / "inputs_v3_raw"

TIER_REF = {"minion": V3 / "B02-v3.png", "elite": V3 / "B03-v3.png", "boss": V3 / "E02-v3.png"}
TIER_STYLE = {
    "minion": "Small enemy minion, compact readable silhouette, petrol blue body with ochre yellow joints, two glowing tomato-red eye lights.",
    "elite": "Elite enemy, noticeably bigger and heavier than a minion, bone-white armor plates with tomato-red trim, a red rotating warning beacon on top, petrol blue underframe.",
    "boss": "Boss enemy, huge and imposing, layered silhouette, one glowing greyish-violet core, ochre and tomato-red hazard accents, petrol blue heavy plating.",
}

# id: (tier, 中文名, design brief)
ROSTER = {
    "N05": ("minion", "铆钉跳蚤", "a tiny hopping robot flea made of a riveted round tin body, four springy bent legs, two long antennae; it jumps in swarms"),
    "N06": ("minion", "喷油桶章鱼", "a squat oil-drum robot octopus, a barrel body with a spray nozzle on top, four short hose tentacles as legs; it sprays oil from range"),
    "N07": ("minion", "吸尘蝙蝠", "a small flying robot bat with a vacuum-cleaner snout, two big folding mechanical wings, a dust bag belly"),
    "N08": ("minion", "齿轮刺猬", "a round chubby toy robot hedgehog whose back shell is covered with rows of rounded cog-wheel teeth, four stubby legs, a small cute snout; it curls up and rolls"),
    "N09": ("minion", "焊枪螳螂", "a slim robot praying mantis, two raised front arms ending in welding torches, four thin legs, a welding-mask head"),
    "EL1": ("elite", "压路犀牛·工头", "a heavy robot rhinoceros foreman, a big steamroller drum mounted in front of its chest, a jackhammer horn, four thick legs"),
    "EL2": ("elite", "变电鳗·监工", "an armored robot eel standing up on four short crawler legs, a tall transformer-coil back fin crackling with arcs, a lantern jaw"),
    "BS4": ("boss", "疏浚母舰·吞河蟾", "a gigantic dredging robot toad, an enormous scoop-bucket lower jaw, a crane with a grab on its back, two smokestacks, four squat powerful legs"),
}

PROMPT = (
    "Design a NEW original game enemy machine: {brief}. {tier} "
    "Render it in exactly the art style of the reference images: industrial fairy-tale low-poly toy, chunky faceted "
    "slabs, matte flat color blocks with simple three-step cel shading, one thin dark ink outline, very few hand-painted "
    "strokes. Strict palette only: petrol blue #23394A and #2F4B5C, bone cream #EFE3C8, tomato red #D9412B, ochre yellow "
    "#E3A52B, greyish violet #8C7BA8, rubber black #1B1B1D. Do NOT copy the reference subjects; only their style. "
    "Movable parts (legs, arms, wings, jaw, drum, fin) must be clearly separate chunky pieces with visible joints. "
    "No rust, grime, decals, tiny bolts, metal noise, reflections or gradients. Single subject, three-quarter front view, "
    "whole body fully visible with margin, soft even light, plain flat light grey background #D8D8D8, no ground shadow, "
    "no text, no frame, no other objects."
)

_lock = threading.Lock()


def log(m: str) -> None:
    with _lock:
        print(f"[{time.strftime('%H:%M:%S')}] {m}", flush=True)


def produce(eid: str, force: bool) -> dict:
    dst = V3 / f"{eid}-v3.png"
    if dst.exists() and not force:
        return {"id": eid, "skipped": True}
    tier, _name, brief = ROSTER[eid]
    prompt = PROMPT.format(brief=brief, tier=TIER_STYLE[tier])
    for attempt in range(1, 4):
        try:
            paths = timi.edit(prompt, [ANCHOR, TIER_REF[tier]], size="1024x1024", out_dir=RAW, stem=eid, timeout=600)
            dst.write_bytes(Path(paths[0]).read_bytes())
            log(f"OK {eid}")
            return {"id": eid, "file": str(dst)}
        except Exception as exc:  # noqa: BLE001
            log(f"{eid} attempt {attempt} failed: {str(exc)[:140]}")
            time.sleep(20 * attempt)
    return {"id": eid, "error": "failed"}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    ids = [s.strip().upper() for s in a.only.split(",") if s.strip()] or list(ROSTER)
    res = []
    with ThreadPoolExecutor(max_workers=a.workers) as pool:
        for f in as_completed([pool.submit(produce, i, a.force) for i in ids]):
            res.append(f.result())
    log(f"ROSTER SUMMARY ok={sum(1 for r in res if 'error' not in r)}/{len(res)} failed={[r['id'] for r in res if 'error' in r]}")


if __name__ == "__main__":
    main()
