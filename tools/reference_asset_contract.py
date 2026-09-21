"""Read selected AssetRipper exports and record traceable, small structural facts.
No texture, mesh, or implementation body is copied into the game project.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path


def inspect_prefab(path):
    text = path.read_text(encoding="utf-8-sig")
    selected = []
    names = []
    for block in re.finditer(r"(?ms)^--- !u!1 &\d+\nGameObject:\n.*?(?=^---|\Z)", text):
        name = re.search(r"(?m)^  m_Name: (.+)$", block.group())
        active = re.search(r"(?m)^  m_IsActive: (\d+)$", block.group())
        if not name:
            continue
        value = name.group(1).strip()
        names.append(value)
        if re.search(r"Skin|S0_|T[0-5](?:[._ (]|$)|Upgrade|Cooldown|CoolDown|InstantiationPoint|VFX_|LegController|Drive|Feedback", value, re.I):
            selected.append({
                "name": value,
                "line": text.count("\n", 0, block.start() + name.start()) + 1,
                "active_in_export": active.group(1) == "1" if active else None,
            })
    return {
        "prefab": str(path),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "game_object_count": len(names),
        "mono_behaviour_reference_count": len(re.findall(r"m_Script:", text)),
        "selected_nodes": selected[:50],
        "confidence": "observed-serialized-structure",
        "not_proven": "runtime activation order, actual formulas, complete playable content count",
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("F:/WanderburgAssetRipperExport/ExportedProject"))
    parser.add_argument("--out", type=Path, default=Path("evidence/reference_asset_contract.json"))
    args = parser.parse_args()
    prefabs = args.root / "Assets/GameObject"
    names = ["Module2_FrontCannon", "Module2_BackDash", "Module2_TopMortar",
             "PV_Tank_Rank__0_", "PV_Tank_Rank__3_", "PV_Spider_0"]
    facts = [inspect_prefab(prefabs / (name + ".prefab")) for name in names]
    output = {
        "reference_export": str(args.root),
        "scope": "Small structural evidence for original asset production; no reference art included.",
        "prefabs": facts,
        "design_translation": [
            {"observation": "active/passive instantiation points", "original_contract": "Separate gameplay origin and visual emitter sockets"},
            {"observation": "T0-T5 and disabled hierarchy objects", "original_contract": "Author explicit model stages, activation predicates, and transition feedback"},
            {"observation": "cooldown, dash and driving VFX groups", "original_contract": "Per-state effect layers driven by confirmed gameplay events"},
            {"observation": "different player rank prefabs", "original_contract": "Measure silhouette, travel clearance and readable attachment topology per stage"},
        ],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"out": str(args.out), "prefabs": len(facts),
                      "nodes": [f["game_object_count"] for f in facts]}))


if __name__ == "__main__":
    main()
