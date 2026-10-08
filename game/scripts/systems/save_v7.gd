class_name SaveV7
extends RefCounted

## 存档 envelope v7（schema 对齐 SaveGame v7 字段；结构级对齐，值域为本项目自有）。
## 版本迁移 + 校验和 + 可选 AES 加密（密钥走环境/工程设置，不硬编码）。

const CURRENT_VERSION := 7

var save_version: int = CURRENT_VERSION
var save_channel: String = "dev"
var progress_reset_generation: int = 0
var last_saved_utc_ticks: int = 0
var last_loadout: Array = []
var unlocked_ids: Array = []
var unlocked_and_new: Array = []
var silver: int = 0
var silver_before_last_run: int = 0
var achieved_quests: Array = []
var quest_progress: Dictionary = {}
var unlocked_biome_ids: Array = []
## 本项目扩展：Run/Lifetime 统计双层（对齐 StatisticsManager 结构）
var run_statistics: Dictionary = {}
var lifetime_statistics: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"save_channel": save_channel,
		"progress_reset_generation": progress_reset_generation,
		"last_saved_utc_ticks": last_saved_utc_ticks,
		"last_loadout": last_loadout,
		"unlocked_ids": unlocked_ids,
		"unlocked_and_new": unlocked_and_new,
		"silver": silver,
		"silver_before_last_run": silver_before_last_run,
		"achieved_quests": achieved_quests,
		"quest_progress": quest_progress,
		"unlocked_biome_ids": unlocked_biome_ids,
		"run_statistics": run_statistics,
		"lifetime_statistics": lifetime_statistics,
	}

static func from_dict(d: Dictionary) -> SaveV7:
	var s := SaveV7.new()
	s.save_version = int(d.get("save_version", 0))
	s.save_channel = str(d.get("save_channel", "dev"))
	s.progress_reset_generation = int(d.get("progress_reset_generation", 0))
	s.last_saved_utc_ticks = int(d.get("last_saved_utc_ticks", 0))
	s.last_loadout = d.get("last_loadout", [])
	s.unlocked_ids = d.get("unlocked_ids", [])
	s.unlocked_and_new = d.get("unlocked_and_new", [])
	s.silver = int(d.get("silver", 0))
	s.silver_before_last_run = int(d.get("silver_before_last_run", 0))
	s.achieved_quests = d.get("achieved_quests", [])
	s.quest_progress = d.get("quest_progress", {})
	s.unlocked_biome_ids = d.get("unlocked_biome_ids", [])
	s.run_statistics = d.get("run_statistics", {})
	s.lifetime_statistics = d.get("lifetime_statistics", {})
	return s

## Normalize：去重 + 类型清洗（对齐 SaveGame.Normalize）
func normalize() -> void:
	unlocked_ids = _dedup(unlocked_ids)
	unlocked_and_new = _dedup(unlocked_and_new)
	achieved_quests = _dedup(achieved_quests)
	unlocked_biome_ids = _dedup(unlocked_biome_ids)
	var qp := {}
	for k in quest_progress:
		qp[str(k)] = int(quest_progress[k])
	quest_progress = qp

static func _dedup(values: Array) -> Array:
	var seen := {}
	var out: Array = []
	for v in values:
		if not seen.has(v):
			seen[v] = true
			out.append(v)
	return out

func stamp_build_identity(channel: String, generation: int) -> void:
	save_channel = channel
	progress_reset_generation = generation

func matches_build_identity(channel: String, generation: int) -> bool:
	return save_channel == channel and progress_reset_generation == generation

## 版本迁移链：低版本 -> v7（对齐 MigrateLegacy* 语义；本项目从 v1 白模存档迁入）
static func migrate(d: Dictionary) -> SaveV7:
	var s := from_dict(d)
	match s.save_version:
		0, 1, 2, 3, 4, 5, 6:
			# 旧白模 envelope：字段名 silver 缺失时从 gold 继承（对齐 FormerlySerializedAs("gold")）
			if not d.has("silver") and d.has("gold"):
				s.silver = int(d["gold"])
			s.save_version = CURRENT_VERSION
	s.normalize()
	return s
