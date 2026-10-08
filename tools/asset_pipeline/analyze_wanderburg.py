# -*- coding: utf-8 -*-
"""Wanderburg 逆向分析：字符串常量分类统计 + 资源清单"""
import json, re, os, sys
from collections import Counter, defaultdict

BASE = r"D:\工作\InverseGame\WaWa\wanderburg_re"
OUT = os.path.join(BASE, "analysis")
os.makedirs(OUT, exist_ok=True)

# ---------- 1. 字符串常量分类 ----------
with open(os.path.join(BASE, "il2cpp_dump", "stringliteral.json"), encoding="utf-8") as f:
    literals = json.load(f)

values = [l.get("value", "") for l in literals]
print(f"total literals: {len(values)}")

cats = defaultdict(list)
def classify(v: str):
    if not v:
        return None
    if re.fullmatch(r"[a-z]+://.*", v):
        return "uri"
    if v.startswith("event:/") or v.startswith("bank:/") or "snapshot:/" in v:
        return "fmod"
    if re.fullmatch(r"[\w.]+\.(png|jpg|jpeg|tga|psd|wav|ogg|mp3|fbx|obj|ttf|otf|json|csv|asset|prefab|unity|mat|controller|anim|renderTexture|spriteatlas|shader)", v, re.I):
        return "asset_path"
    if re.fullmatch(r"[A-Za-z_][\w.]*", v) and ("_" in v or v[0].islower()) and len(v) < 60:
        return "ident_key"
    if v.startswith("Assets/"):
        return "unity_path"
    if re.fullmatch(r"[\w\-. ]{1,40}", v) and not re.search(r"[^\x00-\xff]", v):
        # 短英文词，可能是 UI 文本或键
        return "short_text"
    return "text"

for v in values:
    c = classify(v)
    if c:
        cats[c].append(v)

report = {k: len(v) for k, v in sorted(cats.items(), key=lambda kv: -len(kv[1]))}
print(json.dumps(report, indent=2))

# 高价值内容：较长的可读文本（描述、教程、成就等）
long_text = sorted({v for v in values if len(v) > 12 and re.search(r"[a-zA-Z]{3}", v) and not v.startswith("Unity") and "/" not in v[:3]})[:4000]

# FMOD 事件清单
fmod_events = sorted({v for v in cats.get("fmod", [])})

# PlayerPrefs / 配置键（可读字符串里形如 key 的）
pref_keys = sorted({v for v in values if re.fullmatch(r"(Option|Setting|Pref|Save|Stat)[\w]*", v)})

with open(os.path.join(OUT, "strings_report.json"), "w", encoding="utf-8") as f:
    json.dump({
        "total": len(values),
        "categories": report,
        "fmod_events": fmod_events,
        "pref_like_keys": pref_keys,
        "long_texts_sample": long_text[:800],
    }, f, ensure_ascii=False, indent=2)

# ---------- 2. Unity 资源统计 ----------
import UnityPy

data_path = r"F:\SteamLibrary\steamapps\common\Wanderburg Game\Wanderburg_Data\data.unity3d"
env = UnityPy.load(data_path)

type_counter = Counter()
name_by_type = defaultdict(list)
for obj in env.objects:
    t = obj.type.name
    type_counter[t] += 1
    if len(name_by_type[t]) < 400000:
        try:
            d = obj.read()
            nm = getattr(d, "m_Name", None) or getattr(d, "name", "")
            if nm:
                name_by_type[t].append(nm)
        except Exception:
            name_by_type[t].append("<unreadable>")

res = {"type_counts": dict(type_counter.most_common())}
for t in ("Texture2D", "Sprite", "AudioClip", "Mesh", "TextAsset", "Shader", "Material", "GameObject", "AnimationClip"):
    names = sorted(set(name_by_type.get(t, [])))
    res[f"{t}_names"] = names
    res[f"{t}_count_unique_names"] = len(names)

with open(os.path.join(OUT, "asset_inventory.json"), "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=2)

print("type counts:", json.dumps(dict(type_counter.most_common(25)), indent=2))
print("DONE")
