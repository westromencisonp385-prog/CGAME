# -*- coding: utf-8 -*-
"""Wanderburg level design research: WaveSpawner / EnemyWave / EnemyType / LocalSpawner / TimerBar / BiomeData / Agent stats.
Research evidence only. Output docs/research/wanderburg-levels.json
"""
import json
import sys
from collections import Counter
from pathlib import Path

import UnityPy
from UnityPy.helpers.TypeTreeGenerator import TypeTreeGenerator

sys.stdout.reconfigure(encoding="utf-8")
GAME = Path(r"F:\SteamLibrary\steamapps\common\Wanderburg Game\Wanderburg_Data")
DUMMY = Path(__file__).resolve().parents[3] / "wanderburg_re" / "il2cpp_dump" / "DummyDll"
OUT = Path(__file__).resolve().parents[2] / "docs" / "research" / "wanderburg-levels.json"
WANT = {"WaveSpawner", "LocalSpawner", "TimerBarWithEventsController", "BiomeData", "AgentUnit", "AgentVehicle", "Agent", "EventCompound", "QuestData"}
PATTERNS = ["surround", "randomDirection", "doubleOppositeSideRandom", "allDirections", "playerDrivingDirection", "groupSurround"]
RARITY = ["common", "uncommon", "rare"]


def rnd(x):
    if isinstance(x, float):
        return round(x, 3)
    return x


def main():
    env = UnityPy.load(str(GAME / "data.unity3d"))
    ver = next(iter(env.objects)).assets_file.unity_version
    idx = {}
    picks = []
    for o in env.objects:
        idx[(o.assets_file.name, o.path_id)] = o
        if o.type.name == "MonoBehaviour":
            try:
                cls = o.read(check_read=False).m_Script.read().m_ClassName
            except Exception:  # noqa: BLE001
                continue
            if cls in WANT:
                picks.append((cls, o))
    gen = TypeTreeGenerator(ver)
    gen.load_local_dll_folder(str(DUMMY))
    env.typetree_generator = gen

    go_name_cache = {}

    def go_name(file, pid):
        if not pid:
            return None
        k = (file, pid)
        if k in go_name_cache:
            return go_name_cache[k]
        o = idx.get(k)
        name = None
        if o is not None:
            try:
                tt = o.read_typetree()
                name = tt.get("m_Name")
            except Exception:  # noqa: BLE001
                name = None
        go_name_cache[k] = name
        return name

    def ref_name(o, ref):
        if not isinstance(ref, dict):
            return None
        fid = ref.get("m_FileID", 0)
        pid = ref.get("m_PathID", 0)
        if not pid:
            return None
        file = o.assets_file.name
        if fid:
            try:
                ext = o.assets_file.externals[fid - 1]
                file = Path(ext.path).name
            except Exception:  # noqa: BLE001
                pass
        n = go_name(file, pid)
        if n is None:
            for (f, p), _ in ((k, v) for k, v in idx.items() if k[1] == pid):
                n = go_name(f, p)
                if n:
                    break
        return n

    def curve(c):
        if not isinstance(c, dict):
            return None
        return [[round(k["time"], 3), round(k["value"], 3)] for k in c.get("m_Curve", [])]

    def wave(o, w):
        return {"t": rnd(w.get("spawnTime")), "n": w.get("agentCount"), "agent": ref_name(o, w.get("agentPrefab")),
                "pattern": PATTERNS[w["spawnPattern"]] if isinstance(w.get("spawnPattern"), int) and w["spawnPattern"] < 6 else w.get("spawnPattern"),
                "offset": rnd(w.get("spawnPositionOffset")), "overwrite": w.get("overwriteGlobalSpawning"), "overwrite_dur": rnd(w.get("overwriteDuration"))}

    def etype(o, e):
        return {"agent": ref_name(o, e.get("prefab")), "t_min": rnd(e.get("minimumSpawnTime")), "t_max": rnd(e.get("maximumSpawnTime")),
                "n_min": rnd(e.get("minimumSpawnCount")), "n_max": rnd(e.get("maximumSpawnCount")),
                "rarity": RARITY[e["spawnRarity"]] if isinstance(e.get("spawnRarity"), int) else e.get("spawnRarity"), "type": ["Unit", "Vehicle"][e.get("type", 0)] if isinstance(e.get("type"), int) else e.get("type")}

    res = {"wave_spawners": [], "local_spawners": [], "timer_bars": [], "biomes": [], "agents": [], "event_compounds": 0, "errors": Counter()}
    agent_keys = Counter()
    for cls, o in picks:
        try:
            tt = o.read_typetree()
        except Exception as e:  # noqa: BLE001
            res["errors"][cls + ":" + type(e).__name__] += 1
            continue
        owner = go_name(o.assets_file.name, tt.get("m_GameObject", {}).get("m_PathID", 0))
        if cls == "WaveSpawner":
            ws = {"owner": owner, "file": o.assets_file.name}
            for k in ("tier", "endlessPhaseSpawner", "waveSpawnDistance", "generalEnemyAggroDistance", "gameTime", "referenceStageTimeInSeconds",
                      "bossSpawnTime", "bossMinimumPlayerDistance", "overtimeStart", "healthMult", "speedMult", "damageMult", "projectileSpeedMult",
                      "circleSpawnDepth", "groupSurroundGroupSize", "maxSpawnTickUnitCount", "neutralPreProgrammedWaveSpawnDistance"):
                if k in tt:
                    ws[k] = rnd(tt[k])
            ws["boss"] = ref_name(o, tt.get("bossPrefab"))
            ws["strength_curve"] = curve(tt.get("troopSpawnStrengthOverTimeCurve"))
            ws["interval_curve"] = curve(tt.get("troopSpawnIntervalOverTimeCurve"))
            ws["overtime_interval_curve"] = curve(tt.get("overtimeSpawnIntervalCurve"))
            ws["pool"] = [etype(o, e) for e in tt.get("totalAgentPool", [])]
            ws["pool_neutral"] = [etype(o, e) for e in tt.get("totalAgentPoolNeutral", [])]
            ws["overtime_pool"] = [etype(o, e) for e in tt.get("overtimeAgentPool", [])]
            ws["pre_waves"] = [wave(o, w) for w in tt.get("preProgrammedWaves", [])]
            ws["neutral_waves"] = [wave(o, w) for w in tt.get("neutralPreProgrammedWaves", [])]
            ws["overtime_waves"] = [wave(o, w) for w in tt.get("overtimePreprogrammedWaves", [])]
            ws["swarm_waves"] = [wave(o, w) for w in tt.get("swarmEventWaves", [])]
            res["wave_spawners"].append(ws)
        elif cls == "LocalSpawner":
            res["local_spawners"].append({"owner": owner, "agent": ref_name(o, tt.get("agentPrefab")), **{k: rnd(tt[k]) for k in ("activeDistance", "spawningInterval", "maxNumberOfAgents", "agentsPerSpawnTick", "setAgentsToHomeBoundBehavior", "maxDistanceFromHome") if k in tt}})
        elif cls == "TimerBarWithEventsController":
            res["timer_bars"].append({"owner": owner, "fillTime": rnd(tt.get("fillTime")), "events": [{"name": e.get("eventName"), "t_min": rnd(e.get("minEventTime")), "t_max": rnd(e.get("maxEventTime")), "spawns": [ref_name(o, p) for p in e.get("prefabsToSpawn", [])]} for e in tt.get("events", [])]})
        elif cls == "BiomeData":
            res["biomes"].append({k: rnd(tt.get(k)) for k in ("m_Name", "biomeID", "biomeName", "difficulty", "silverFactor", "biomeDescription")} | {"quests": len(tt.get("myQuests", []))})
        elif cls == "EventCompound":
            res["event_compounds"] += 1
        elif cls in ("AgentUnit", "AgentVehicle", "Agent"):
            row = {"class": cls, "owner": owner}
            for k, v in tt.items():
                if isinstance(v, (int, float, bool)) and not k.startswith("m_"):
                    row[k] = rnd(v)
                    agent_keys[k] += 1
            res["agents"].append(row)
    res["errors"] = dict(res["errors"])
    res["agent_numeric_keys"] = [k for k, _ in agent_keys.most_common(80)]
    OUT.write_text(json.dumps(res, ensure_ascii=False, indent=1, default=str), encoding="utf-8")
    print("wave_spawners", len(res["wave_spawners"]), "local", len(res["local_spawners"]), "timer", len(res["timer_bars"]), "biomes", len(res["biomes"]), "agents", len(res["agents"]), "compounds", res["event_compounds"], "err", res["errors"])


if __name__ == "__main__":
    main()
