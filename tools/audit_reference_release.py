"""Read-only inventory and symbol audit of a locally installed Unity IL2CPP release.

This reads names and table metadata; it does not recover method bodies, extract
art assets, patch the reference game, or claim to reconstruct an editor project.
Supports the observed IL2CPP metadata v31 layout only and validates its tables.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import struct
import xml.etree.ElementTree as ET


def read_metadata(path: Path) -> dict:
    blob = path.read_bytes()
    header = struct.unpack_from("<64I", blob)
    if header[:2] != (0xFAB11BAF, 31):
        raise ValueError("This audit supports only the observed IL2CPP metadata version 31")
    sections = [(header[i], header[i + 1]) for i in range(2, 64, 2)]
    for offset, size in sections:
        if offset + size > len(blob):
            raise ValueError("Invalid metadata section bounds")
    string_offset, string_size = sections[2]
    strings = blob[string_offset:string_offset + string_size]

    def string(index: int) -> str:
        if not 0 <= index < len(strings):
            raise ValueError(f"Invalid string offset {index}")
        end = strings.find(b"\0", index)
        if end < 0:
            raise ValueError("Unterminated metadata string")
        return strings[index:end].decode("utf-8")

    types_offset, types_size = sections[19]
    methods_offset, methods_size = sections[5]
    fields_offset, fields_size = sections[11]
    images_offset, images_size = sections[20]
    for size, stride in [(types_size, 88), (methods_size, 36), (fields_size, 12), (images_size, 40)]:
        if size % stride:
            raise ValueError("Unsupported metadata table layout")
    images = []
    application_types = []
    for cursor in range(images_offset, images_offset + images_size, 40):
        record = struct.unpack_from("<10i", blob, cursor)
        image_name = string(record[0])
        image = {"name": image_name, "type_start": record[2], "type_count": record[3]}
        images.append(image)
        if image_name != "Assembly-CSharp.dll":
            continue
        for index in range(record[2], record[2] + record[3]):
            row = struct.unpack_from("<16i8H2I", blob, types_offset + index * 88)
            if row[9] < -1 or row[8] < -1:
                raise ValueError("Invalid type table")
            methods = []
            for method_index in range(row[9], row[9] + row[16]):
                method = struct.unpack_from("<7i4H", blob, methods_offset + method_index * 36)
                methods.append({"name": string(method[0]), "parameter_count": method[-1]})
            fields = []
            for field_index in range(row[8], row[8] + row[18]):
                field = struct.unpack_from("<3i", blob, fields_offset + field_index * 12)
                fields.append(string(field[0]))
            application_types.append({
                "index": index,
                "name": string(row[0]),
                "namespace": string(row[1]),
                "declaring_type_reference": row[3],
                "methods": methods,
                "fields": fields,
            })
    paths = sorted(set(m.decode("ascii") for m in re.findall(rb"\\Assets\\[\x20-\x7e]*?\.cs", blob)))
    probable_game_paths = [p for p in paths if not any(segment in p for segment in ["\\Plugins\\", "\\Samples\\", "\\Input Rebinder\\", "\\FastIK\\", "\\Thick Sprite Mesh\\"])]
    return {
        "metadata_version": 31,
        "sha256": hashlib.sha256(blob).hexdigest(),
        "total_metadata_types": types_size // 88,
        "total_metadata_methods": methods_size // 36,
        "images": images,
        "application_assembly": "Assembly-CSharp.dll",
        "application_types": application_types,
        "source_path_names": paths,
        "probable_game_source_paths": probable_game_paths,
        "source_path_caveat": "Names embedded in the build, not source files; includes obsolete/test code and cannot prove runtime use.",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, default=Path(r"F:\SteamLibrary\steamapps\common\Wanderburg Game"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.reference.resolve()
    files = sorted(p for p in root.rglob("*") if p.is_file())
    data = root / "Wanderburg_Data"
    assemblies = json.loads((data / "ScriptingAssemblies.json").read_text(encoding="utf-8"))
    initializers = json.loads((data / "RuntimeInitializeOnLoads.json").read_text(encoding="utf-8"))
    addressables = json.loads((data / "StreamingAssets/aa/settings.json").read_text(encoding="utf-8"))
    xml = ET.parse(data / "StreamingAssets/aa/AddressablesLink/link.xml")
    with (data / "data.unity3d").open("rb") as bundle:
        bundle_header = bundle.read(128)
    versions = re.findall(rb"\d{4}\.\d+\.\d+[abfp]\d+", bundle_header)
    report = {
        "audited_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "reference_root": str(root),
        "scope": "Read-only release inventory and IL2CPP name-table audit. No implementation bodies or visual assets extracted.",
        "engine_version_from_bundle_header": [v.decode("ascii") for v in versions],
        "file_count": len(files),
        "total_bytes": sum(p.stat().st_size for p in files),
        "files": [{"path": str(p.relative_to(root)), "bytes": p.stat().st_size} for p in files],
        "source_project_markers": [str(p.relative_to(root)) for p in files if p.name in {"project.godot", "ProjectVersion.txt", "manifest.json"} or p.suffix in {".cs", ".gd", ".tscn", ".unity"}],
        "assembly_names": assemblies["names"],
        "runtime_initializers": initializers["root"],
        "addressables_settings": addressables,
        "addressables_preserved_types": [{"assembly": a.attrib.get("fullname"), "type": t.attrib.get("fullname"), "preserve": t.attrib.get("preserve")} for a in xml.getroot().findall("assembly") for t in a.findall("type")],
        "metadata": read_metadata(data / "il2cpp_data/Metadata/global-metadata.dat"),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(args.output), "engine": report["engine_version_from_bundle_header"], "file_count": report["file_count"], "total_bytes": report["total_bytes"], "application_type_records": len(report["metadata"]["application_types"]), "probable_game_source_paths": len(report["metadata"]["probable_game_source_paths"]), "project_markers": report["source_project_markers"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()


