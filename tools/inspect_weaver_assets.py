from __future__ import annotations
import json, struct, sys
from pathlib import Path

def glb_report(path: Path) -> dict:
    data = path.read_bytes()
    if data[:4] != b"glTF":
        return {"format": "invalid_glb_header", "bytes": len(data)}
    offset = 12; doc = None; bin_len = 0
    while offset + 8 <= len(data):
        length, kind = struct.unpack_from("<II", data, offset); offset += 8
        chunk = data[offset:offset+length]; offset += length
        if kind == 0x4E4F534A: doc = json.loads(chunk.decode("utf-8"))
        elif kind == 0x004E4942: bin_len = len(chunk)
    if not doc: return {"format": "glb_no_json", "bytes": len(data)}
    accessors = doc.get("accessors", []); meshes = doc.get("meshes", [])
    triangles = vertices = primitives = 0
    for mesh in meshes:
        for primitive in mesh.get("primitives", []):
            primitives += 1
            attrs = primitive.get("attributes", {})
            pos = accessors[attrs["POSITION"]]["count"] if "POSITION" in attrs else 0
            vertices += pos
            if "indices" in primitive:
                count = accessors[primitive["indices"]]["count"]
                triangles += count // 3 if primitive.get("mode", 4) == 4 else 0
            else: triangles += pos // 3
    return {
        "format": "glb", "bytes": len(data), "json_version": doc.get("asset", {}).get("version"),
        "nodes": len(doc.get("nodes", [])), "meshes": len(meshes), "primitives": primitives,
        "vertices": vertices, "triangles": triangles, "materials": len(doc.get("materials", [])),
        "images": len(doc.get("images", [])), "textures": len(doc.get("textures", [])),
        "skins": len(doc.get("skins", [])), "animations": len(doc.get("animations", [])),
        "has_uv": any("TEXCOORD_0" in p.get("attributes", {}) for m in meshes for p in m.get("primitives", [])),
    }

def fbx_report(path: Path) -> dict:
    raw = path.read_bytes(); text = raw.decode("ascii", errors="ignore")
    return {"format": "fbx_binary" if raw[:18].startswith(b"Kaydara FBX Binary") else "unknown", "bytes": len(raw), "mesh_blocks": text.count("Vertices"), "polygon_blocks": text.count("PolygonVertexIndex"), "animation_stacks": text.count("AnimationStack"), "deformer_blocks": text.count("Deformer"), "material_blocks": text.count("Material::")}

for value in sys.argv[1:]:
    path = Path(value)
    print(json.dumps({"path": str(path), "report": glb_report(path) if path.suffix.lower()==".glb" else fbx_report(path)}, ensure_ascii=False))
