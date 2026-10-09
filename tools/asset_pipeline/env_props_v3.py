# -*- coding: utf-8 -*-
"""Environment / world props v3: replace every code-built box in the arena with authored assets.

Stages (each resumable; finished outputs are skipped):
  concepts : TiMi multi-image edit [style anchor, W03 world-prop reference] + brief -> artifacts/weaver/inputs_v3/<ID>-v3.png
  textures : TiMi text-to-image seamless top-down ground tiles -> game/assets/textures/ground/<name>.png
  models   : weaver_v3_batch.run (360 -> 2D split -> joint mid -> texture -> Blender rig) -> game/assets/models/rigged/<slot>_rig.glb

Usage:
  python -u env_props_v3.py --stage concepts --workers 4
  python -u env_props_v3.py --stage textures
  python -u env_props_v3.py --stage models --workers 5
  python -u env_props_v3.py --stage all
"""
import argparse
import json
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, r"C:\Users\jasonlyan\.bg-agent\config-with-app\skills\timi-image\scripts")
import common as timi  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
ANCHOR = REPO / "docs" / "assets" / "style-anchor-industrial-folk-v1.png"
REF = REPO / "artifacts" / "weaver" / "inputs_v3" / "W03-v3.png"
V3 = REPO / "artifacts" / "weaver" / "inputs_v3"
RAW = REPO / "artifacts" / "weaver" / "inputs_v3_raw"
TEX_DIR = REPO / "game" / "assets" / "textures" / "ground"

# id: (slot, size_m, brief, split_prompt, parts)
# Every subject is ONE connected object (360 QC rejects multi-blob images): clusters sit on a small shared base.
PROPS = {
    "P01": ("prop_tree_round", 3.4, "a stylized round-crowned tree: a short thick faceted trunk, a big chunky low-poly crown made of three or four rounded faceted leaf masses, olive and sage green",
            "拆成两个部件：树冠、树干。", [("Body", "树干"), ("Crown", "树冠")]),
    "P02": ("prop_tree_poplar", 4.0, "a tall slim stylized poplar tree: a thin faceted trunk and a tall pointed teardrop crown of stacked faceted leaf slabs, sage green with olive shadows",
            "拆成两个部件：树冠、树干。", [("Body", "树干"), ("Crown", "树冠")]),
    "P03": ("prop_bush", 1.5, "a chunky round low-poly bush made of faceted olive and sage leaf clumps with a few small tomato-red berries",
            "拆成两个部件：灌木主体、浆果。", [("Body", "灌木"), ("Part", "浆果")]),
    "P04": ("prop_grass_tuft", 0.8, "a single tuft of tall chunky faceted grass blades growing out of a small dirt clod, sage and olive green blades with ochre tips",
            "拆成两个部件：草叶、土块。", [("Body", "土"), ("Blades", "草")]),
    "P05": ("prop_reeds", 1.4, "a clump of river reeds and cattails on a small muddy base, tall faceted stems, brown cattail heads, sage green",
            "拆成两个部件：芦苇、泥底座。", [("Body", "泥"), ("Blades", "芦苇")]),
    "P06": ("prop_flowers", 0.9, "a small patch of chunky stylized wildflowers on a little grass mound, bone-cream and ochre-yellow petals, sage leaves",
            "拆成两个部件：花朵、草丘。", [("Body", "草丘"), ("Part", "花")]),
    "P07": ("prop_rock_large", 1.9, "a large faceted boulder, chunky planar cuts, blue-grey stone #5D706D with lighter top faces and a patch of olive moss on top",
            "拆成两个部件：岩石、苔藓。", [("Body", "岩石"), ("Part", "苔藓")]),
    "P08": ("prop_rock_cluster", 1.1, "three small faceted river stones of different sizes pressed together into one cluster, blue-grey stone with lighter top faces",
            "拆成两个部件：大石块、小石块。", [("Body", "大石"), ("Part", "小石")]),
    "P09": ("prop_scrap_pile", 1.6, "a heap of salvage scrap: bent petrol-blue metal plates, an ochre gear, a broken pipe and a crushed bone-cream panel piled together, collectible junk",
            "拆成两个部件：废料堆主体、顶部齿轮。", [("Body", "废料"), ("Part", "齿轮")]),
    "P10": ("prop_cargo_crate", 1.3, "a sturdy wooden cargo crate with ochre planks, petrol-blue metal corner brackets and a bone-cream strap across the lid",
            "拆成两个部件：木箱、捆带。", [("Body", "箱"), ("Part", "带")]),
    "P11": ("prop_barrier", 1.6, "a heavy road barrier block: a petrol-blue concrete-like slab with tomato-red and bone-cream hazard stripes and a small amber lamp on top",
            "拆成两个部件：路障主体、警示灯。", [("Body", "路障"), ("Part", "灯")]),
    "P12": ("prop_stone_arch", 3.2, "a crooked old civic stone gate arch: two uneven faceted pillars and a bone-cream lintel slab with a tomato-red banner strip",
            "拆成两个部件：拱门、横幅。", [("Body", "拱"), ("Part", "横幅")]),
    "P13": ("prop_broken_wall", 4.2, "a short ruined wall segment of five uneven faceted stone blocks of different heights, blue-grey stone, olive moss on one block",
            "拆成两个部件：墙体、苔藓。", [("Body", "墙"), ("Part", "苔藓")]),
    "P14": ("prop_sign", 1.7, "a worksite notice board on a wooden post: a petrol-blue sign plate with a bone-cream wrench pictogram and an ochre frame",
            "拆成两个部件：牌子、木桩。", [("Body", "木桩"), ("Part", "牌")]),
    "P15": ("prop_pennant", 2.6, "a tall thin wooden pole with a triangular tomato-red pennant flag and an ochre finial, on a small stone footing",
            "拆成两个部件：旗杆、旗帜。", [("Body", "旗杆"), ("Flag", "旗")]),
    "P16": ("prop_bridge", 10.8, "a long low-poly worksite bridge deck: bone-cream planks, petrol-blue steel side girders, ochre railings, seen from three-quarter view, long and straight",
            "拆成两个部件：桥面、栏杆。", [("Body", "桥面"), ("Part", "栏杆")]),
    "P17": ("prop_bridge_stub", 3.4, "a broken bridge abutment: a chunky earth-and-stone bank block ending in snapped wooden planks and a bent petrol-blue girder",
            "拆成两个部件：桥墩、断木板。", [("Body", "桥墩"), ("Part", "木板")]),
    "P18": ("prop_pipe", 6.0, "a long horizontal industrial water pipe lying on the ground with two support saddles, petrol-blue pipe with bone-cream flange rings and an ochre valve, one cracked joint",
            "拆成两个部件：水管、阀门。", [("Body", "水管"), ("Part", "阀")]),
    "P19": ("prop_roadblock", 3.6, "a road-closed barricade fence: two ochre trestle legs holding a long tomato-red and bone-cream striped board with two amber warning lamps",
            "拆成两个部件：栏板、支架。", [("Body", "支架"), ("Part", "栏板")]),
    "P20": ("prop_fence", 4.0, "a straight segment of worksite fence: three petrol-blue posts connected by bone-cream rails and an ochre top rail, sturdy and chunky",
            "拆成两个部件：立柱、横栏。", [("Body", "立柱"), ("Part", "横栏")]),
    "P21": ("prop_coin", 0.5, "a single chunky thick silver salvage coin with a bone-cream rim and an embossed petrol-blue gear emblem, standing upright",
            "拆成两个部件：硬币、齿轮浮雕。", [("Body", "硬币"), ("Part", "齿轮")]),
    "P22": ("prop_repair_kit", 0.5, "a small chunky repair kit box, sage-green case with a bone-cream wrench cross emblem and an ochre handle",
            "拆成两个部件：箱体、把手。", [("Body", "箱"), ("Part", "把手")]),
    "P23": ("prop_lamp_post", 2.8, "a worksite lamp post: a petrol-blue pole with an ochre lamp head and a warm glowing bulb, on a stone footing",
            "拆成两个部件：灯杆、灯头。", [("Body", "杆"), ("Part", "灯")]),
    "P24": ("prop_oil_drums", 1.2, "two standing oil drums side by side touching, petrol-blue and tomato-red drums with bone-cream bands",
            "拆成两个部件：蓝色油桶、红色油桶。", [("Body", "蓝"), ("Part", "红")]),
    # 召唤物 / 钥匙 / 王冠（原为程序拼的方块）
    "P25": ("summon_turret", 1.4, "a deployable auto-turret: a squat petrol-blue tripod base and a rotating ochre turret head with one stubby twin-barrel gun and a red sensor eye",
            "拆成两个部件：三脚底座、炮塔头。", [("Body", "底座"), ("Barrel", "炮塔")], "turret"),
    "P26": ("summon_emp", 1.3, "a deployable EMP pulse beacon: a petrol-blue hexagonal base with a tall bone-cream coil mast topped by a glowing greyish-violet orb inside a ring",
            "拆成两个部件：底座与线圈、顶部光球环。", [("Body", "底座"), ("Ring_0", "环")], "static"),
    "P27": ("summon_camp", 1.8, "a small field repair camp: a sage-green canvas tent with a bone-cream wrench flag and an ochre toolbox in front",
            "拆成两个部件：帐篷、小旗。", [("Body", "帐篷"), ("Flag", "旗")], "static"),
    "P28": ("biome_key", 0.9, "a big chunky ornate key artifact: ochre gold bow shaped like a gear, a bone-cream shaft and tomato-red bit, a glowing greyish-violet gem in the bow",
            "拆成两个部件：钥匙柄、钥匙杆。", [("Body", "柄"), ("Part", "杆")], "static"),
    "P29": ("boss_crown", 1.0, "a chunky boss crown: an ochre gold band with five tall faceted points each tipped with a tomato-red gem, petrol-blue inner rim",
            "拆成两个部件：冠环、宝石。", [("Body", "冠"), ("Part", "宝石")], "static"),
}

PROMPT = (
    "Design a game environment prop: {brief}. "
    "Render it in exactly the art style of the reference images: industrial fairy-tale low-poly toy diorama, chunky "
    "faceted slabs, matte flat color blocks with simple three-step cel shading, one thin dark ink outline, very few "
    "hand-painted strokes. Palette: petrol blue #23394A #2F4B5C, bone cream #EFE3C8, tomato red #D9412B, ochre yellow "
    "#E3A52B, greyish violet #8C7BA8, rubber black #1B1B1D, plus nature tones olive #6F7F61, sage #8FA06E, warm earth "
    "#B48658, dark earth #6E503D, stone #5D706D. Do NOT copy the reference subjects; only their style. "
    "One single connected object. No rust, grime, decals, tiny bolts, noise, reflections or gradients. "
    "Three-quarter top view, whole object fully visible with margin, soft even light, plain flat light grey background "
    "#D8D8D8, no ground shadow, no text, no frame, no other objects."
)

# Seamless top-down ground tiles (used by the terrain splat shader)
TEXTURES = {
    "grass": "lush stylized meadow grass seen straight from above, olive #6F7F61 and sage #8FA06E faceted grass clumps, a few tiny ochre flowers",
    "dirt": "dry packed worksite earth seen straight from above, warm earth #B48658 with darker #6E503D faceted clods and a few small flat pebbles",
    "path": "compacted sandy dirt road seen straight from above, pale tan #CFA874 with faint tire ruts and scattered tiny pebbles",
    "riverbed": "wet river-bank pebbles and mud seen straight from above, blue-grey stone #5D706D pebbles in dark earth #4E4A3E mud",
    "sand": "desert sand dunes seen straight from above, amber #D9A85C with soft faceted wind ripples",
    "mud": "swamp mud and moss seen straight from above, dark olive #4F6248 moss patches on brown mud #5A4A36",
}
TEX_PROMPT = (
    "Seamless tileable game ground texture, {brief}. Hand-painted stylized low-poly diorama look, matte flat color "
    "facets with gentle cel shading, low contrast so characters stay readable on top, evenly lit, no shadows from "
    "objects, no perspective, no horizon, no text, edges must tile seamlessly."
)

_lock = threading.Lock()


def log(m: str) -> None:
    with _lock:
        print(f"[{time.strftime('%H:%M:%S')}] {m}", flush=True)


def concept(pid: str, force: bool) -> dict:
    dst = V3 / f"{pid}-v3.png"
    if dst.exists() and not force:
        return {"id": pid, "skipped": True}
    brief = PROPS[pid][2]
    for attempt in range(1, 4):
        try:
            paths = timi.edit(PROMPT.format(brief=brief), [ANCHOR, REF], size="1024x1024", out_dir=RAW, stem=pid, timeout=600)
            dst.write_bytes(Path(paths[0]).read_bytes())
            log(f"CONCEPT OK {pid}")
            return {"id": pid, "file": str(dst)}
        except Exception as exc:  # noqa: BLE001
            log(f"{pid} concept attempt {attempt} failed: {str(exc)[:140]}")
            time.sleep(15 * attempt)
    return {"id": pid, "error": "concept failed"}


def texture(name: str, force: bool) -> dict:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    dst = TEX_DIR / f"{name}.png"
    if dst.exists() and not force:
        return {"id": name, "skipped": True}
    for attempt in range(1, 4):
        try:
            paths = timi.generate(TEX_PROMPT.format(brief=TEXTURES[name]), size="1024x1024", out_dir=RAW, stem=f"tex_{name}", timeout=600)
            dst.write_bytes(Path(paths[0]).read_bytes())
            log(f"TEXTURE OK {name}")
            return {"id": name, "file": str(dst)}
        except Exception as exc:  # noqa: BLE001
            log(f"tex {name} attempt {attempt} failed: {str(exc)[:140]}")
            time.sleep(15 * attempt)
    return {"id": name, "error": "texture failed"}


def register_models() -> None:
    import weaver_v3_batch as vb
    import weaver_parts as wp
    for pid, spec in PROPS.items():
        slot, size, _b, split, parts = spec[:5]
        vb.EXTRA_SLOTS[pid] = slot
        vb.EXTRA_RIG[pid] = spec[5] if len(spec) > 5 else "static"
        vb.EXTRA_SIZE[pid] = size
        wp.PARTS[pid] = {"prompt": split, "parts": parts}
        vb.SYNONYMS.setdefault(parts[1][1], [parts[1][1]])


def models(ids: list, workers: int) -> list:
    import weaver_v3_batch as vb
    register_models()

    def safe(i):
        try:
            return vb.run(i)
        except Exception as exc:  # noqa: BLE001
            log(f"{i} MODEL FAILED: {str(exc)[:220]}")
            return {"asset": i, "error": str(exc)[:400]}

    res = []
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futs = {pool.submit(safe, i): i for i in ids}
        for f in as_completed(futs):
            r = f.result()
            res.append(r)
            if "stage_glb" in r:
                vb.install([r])  # install as soon as each finishes so the game picks it up incrementally
                log(f"INSTALLED {r['asset']} -> {r['slot']}")
    return res


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage", default="all", choices=["concepts", "textures", "models", "all"])
    ap.add_argument("--only", default="")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    ids = [s.strip().upper() for s in a.only.split(",") if s.strip()] or list(PROPS)
    summary = {}
    if a.stage in ("concepts", "all"):
        with ThreadPoolExecutor(max_workers=a.workers) as pool:
            r = [f.result() for f in as_completed([pool.submit(concept, i, a.force) for i in ids])]
        summary["concepts_failed"] = [x["id"] for x in r if "error" in x]
    if a.stage in ("textures", "all"):
        with ThreadPoolExecutor(max_workers=3) as pool:
            r = [f.result() for f in as_completed([pool.submit(texture, n, a.force) for n in TEXTURES])]
        summary["textures_failed"] = [x["id"] for x in r if "error" in x]
    if a.stage in ("models", "all"):
        ready = [i for i in ids if (V3 / f"{i}-v3.png").exists()]
        r = models(ready, a.workers)
        summary["models_ok"] = sorted(x["asset"] for x in r if "stage_glb" in x)
        summary["models_failed"] = sorted(x["asset"] for x in r if "error" in x)
    (HERE / "logs").mkdir(exist_ok=True)
    (HERE / "logs" / "env_props_last.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"ENV SUMMARY {json.dumps(summary, ensure_ascii=False)}")


if __name__ == "__main__":
    main()
