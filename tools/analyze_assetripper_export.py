"""Inventory and extract high-level evidence from an AssetRipper export.

This deliberately records names, serialized hierarchy labels, component script
references, and exported method/field signatures. It does not copy the exported
assets into the Godot project and does not treat IL2CPP decompiled method bodies
as recovered implementation: the free export uses empty/stub method bodies.
"""
from __future__ import annotations

import argparse
import collections
import json
import re
from pathlib import Path


SCRIPT_REF = re.compile(r"m_Script: \{fileID: 11500000, guid: ([0-9a-f]+), type: 3\}")
NAME = re.compile(r"^  m_Name: (.*)$", re.MULTILINE)
CLASS = re.compile(r"^public (?:sealed )?(?:class|struct|enum) (\w+)", re.MULTILINE)
PUBLIC_DECL = re.compile(r"^\s*public (?!class |struct |enum |delegate |static class)([^\n]+)$", re.MULTILINE)
METHOD = re.compile(r"^\s*(?:public|private|protected|internal)\s+(?:static\s+)?(?:override\s+|virtual\s+|sealed\s+)?(?:async\s+)?(?:[\w<>\[\],.?]+)\s+(\w+)\s*\(([^)]*)\)", re.MULTILINE)


def rel(path: Path, root: Path) -> str:
    return str(path.relative_to(root)).replace("\\", "/")


def read_script_guid_map(root: Path) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for meta in root.rglob("*.cs.meta"):
        match = re.search(r"^guid: ([0-9a-f]+)$", meta.read_text(encoding="utf-8", errors="ignore"), re.MULTILINE)
        if match:
            mapping[match.group(1)] = rel(meta.with_suffix(""), root)
    return mapping


def prefab_summary(path: Path, root: Path, script_map: dict[str, str]) -> dict:
    text = path.read_text(encoding="utf-8", errors="ignore")
    names = NAME.findall(text)
    guids = SCRIPT_REF.findall(text)
    scripts = collections.Counter(script_map.get(guid, f"guid:{guid}") for guid in guids)
    return {
        "path": rel(path, root),
        "root_name": names[0] if names else path.stem,
        "game_object_name_count": len(names),
        "game_object_names": names[:240],
        "component_script_reference_count": len(guids),
        "component_scripts": dict(scripts),
    }


def script_summary(path: Path, root: Path) -> dict:
    text = path.read_text(encoding="utf-8", errors="ignore")
    methods = [m.group(1) for m in METHOD.finditer(text) if not m.group(1).startswith("_")]
    public_declarations = []
    for line in PUBLIC_DECL.findall(text):
        line = line.strip()
        if line.endswith(";") and not line.startswith("return "):
            public_declarations.append(line[:-1])
    return {
        "path": rel(path, root),
        "classes": CLASS.findall(text),
        "public_declarations": public_declarations[:400],
        "method_names": methods[:400],
        "contains_stub_returns": bool(re.search(r"return (?:null|false|0f|default);", text)),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", type=Path, default=Path("tmp/assetripper-export2/ExportedProject"))
    parser.add_argument("--output", type=Path, default=Path("evidence/assetripper_export_inventory.json"))
    args = parser.parse_args()
    root = args.export.resolve()
    assets = root / "Assets"
    script_map = read_script_guid_map(assets)
    files = [p for p in root.rglob("*") if p.is_file()]
    prefabs = list(assets.rglob("*.prefab"))
    scenes = list(assets.rglob("*.unity"))
    textures = [p for p in assets.rglob("*") if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".tga", ".exr"}]
    scripts = list(assets.rglob("*.cs"))
    names = [p.stem for p in prefabs]
    categories = {
        "player_vehicle_prefabs": sorted(n for n in names if re.search(r"^(PV_|Player|Tankbert)", n, re.I)),
        "module_prefabs": sorted(n for n in names if re.search(r"Module|Booster|Auxilliary|Module2", n, re.I)),
        "artifact_prefabs": sorted(n for n in names if re.search(r"Artifact|Bumper|Catalyst|Clover|Magma|Napalm|Repair Wrench|Upgrade Dice", n, re.I)),
        "enemy_vehicle_prefabs": sorted(n for n in names if re.search(r"Agent_Enemy_Vehicle|Enemy_Boss", n, re.I)),
        "biome_or_level_prefabs": sorted(n for n in names if re.search(r"Grass|Desert|Forest|Swamp|Village|Castle|Mountain|Lake|Mill", n, re.I)),
    }
    selected_patterns = [
        "PV_Tank_Rank__0_.prefab", "PV_Tank_Rank__3_.prefab", "PV_Spider_0.prefab",
        "PV_Spider_Rank__3_.prefab", "Module2_FrontCannon.prefab", "Module2_BackDash.prefab",
        "Module2_TopMortar.prefab", "TopModuleBooster.prefab", "FrontModuleBooster.prefab",
        "BackModulBooster.prefab", "SideModuleBooster.prefab", "Agent_Enemy_Vehicle_WalkerDrill.prefab",
    ]
    selected = []
    for pattern in selected_patterns:
        matches = [p for p in prefabs if p.name == pattern]
        if matches:
            selected.append(prefab_summary(matches[0], root, script_map))
    target_script_names = [
        "Module2.cs", "ModuleSelection.cs", "VM.cs", "VMBaseStats.cs", "AttackModuleV2.cs",
        "ArtifactSystem.cs", "SaveLoad.cs", "SaveGame.cs", "VehicleModuleTransfer.cs",
        "BonusVehicleStats.cs", "GM.cs", "AgentVehicle.cs", "WaveSpawner.cs",
    ]
    target_scripts = []
    for name in target_script_names:
        matches = [p for p in scripts if p.name == name and "Assembly-CSharp" in str(p)]
        if matches:
            target_scripts.append(script_summary(matches[0], root))
    report = {
        "scope": "AssetRipper 2.0.0 free export inventory; names and serialized structures only; no asset copied into the Godot project.",
        "export_root": str(root),
        "file_count": len(files),
        "total_bytes": sum(p.stat().st_size for p in files),
        "asset_counts": {"prefabs": len(prefabs), "scenes": len(scenes), "textures": len(textures), "scripts": len(scripts), "script_meta_guid_count": len(script_map)},
        "scenes": [rel(p, root) for p in scenes],
        "categories": categories,
        "selected_prefabs": selected,
        "selected_scripts": target_scripts,
        "caveats": [
            "The AssetRipper free IL2CPP export contains fields, signatures and stub/empty method bodies; it is not source-level implementation recovery.",
            "Exported assets are reference evidence and must not be shipped in the new game without independent rights review.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(args.output), "files": len(files), "bytes": report["total_bytes"], "prefabs": len(prefabs), "scenes": len(scenes), "textures": len(textures), "scripts": len(scripts)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
