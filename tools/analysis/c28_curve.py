"""C28 强度曲线：把 telemetry.json 按 15 秒分桶打印，并生成 ECharts 配置（artifacts/qa/c28_level/curve_echarts.json）。"""
import json
import sys
from collections import defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parents[2]
name = sys.argv[1] if len(sys.argv) > 1 else "telemetry.json"
d = json.loads((ROOT / "artifacts/qa/c28_level" / name).read_text(encoding="utf-8"))
rows = d["samples"]
b = defaultdict(lambda: {"dmg": 0.0, "alive": 0, "thr": 0.0, "hpr": 1.0, "boss": False, "bhp": 0.0, "lv": 1})
for r in rows:
    k = (r["stage"], int(r["t"] // 15) * 15)
    x = b[k]
    x["dmg"] += r["dmg_taken"]
    x["alive"] = max(x["alive"], r["alive"])
    x["thr"] = max(x["thr"], r["threat"])
    x["hpr"] = min(x["hpr"], r["hp"] / max(r["max_hp"], 1))
    x["boss"] = x["boss"] or r["boss"]
    x["bhp"] = max(x["bhp"], r.get("boss_hp", 0))
    x["lv"] = r["level"]
for k in sorted(b):
    x = b[k]
    print(f"S{k[0]} {k[1]:4d}s dmg={x['dmg']:6.1f} alive={x['alive']:3d} threat={x['thr']:6.1f} hp%={x['hpr']*100:5.1f} {'BOSS' if x['boss'] else '    '} bhp={x['bhp']:6.0f} lv={x['lv']}")

# 整局时间轴（阶段首尾相接）
xs, thr, dmg, hpr, alive, marks = [], [], [], [], [], []
offset = 0.0
last_stage = 1
stage_starts = [0.0]
for r in rows:
    if r["stage"] != last_stage:
        offset = xs[-1] + 1 if xs else 0
        stage_starts.append(offset)
        last_stage = r["stage"]
    xs.append(round(offset + r["t"], 1))
    thr.append(r["threat"])
    dmg.append(r["dmg_taken"])
    hpr.append(round(r["hp"] / max(r["max_hp"], 1) * 100, 1))
    alive.append(r["alive"])


def smooth(a, w=8):
    out = []
    for i in range(len(a)):
        s = a[max(0, i - w + 1): i + 1]
        out.append(round(sum(s) / len(s), 2))
    return out


chart = {
    "title": {"text": "强度曲线（机器人整局采样，%s）" % ("不死模式" if d.get("immortal") else "正常模式")},
    "tooltip": {"trigger": "axis"},
    "legend": {"data": ["威胁值（25m 内）", "每秒受伤（8s 平滑）", "血量 %"]},
    "xAxis": {"type": "value", "name": "秒"},
    "yAxis": [{"type": "value", "name": "威胁 / 伤害"}, {"type": "value", "name": "血量 %", "max": 100}],
    "series": [
        {"name": "威胁值（25m 内）", "type": "line", "showSymbol": False, "data": [[x, y] for x, y in zip(xs, smooth(thr, 4))],
         "markLine": {"symbol": "none", "data": [{"xAxis": s, "label": {"formatter": "阶段 %d" % (i + 1)}} for i, s in enumerate(stage_starts)]}},
        {"name": "每秒受伤（8s 平滑）", "type": "line", "showSymbol": False, "data": [[x, y] for x, y in zip(xs, smooth(dmg))]},
        {"name": "血量 %", "type": "line", "yAxisIndex": 1, "showSymbol": False, "data": [[x, y] for x, y in zip(xs, hpr)]},
    ],
}
(ROOT / "artifacts/qa/c28_level/curve_echarts.json").write_text(json.dumps(chart, ensure_ascii=False), encoding="utf-8")
print("stage_starts", stage_starts, "samples", len(xs))
