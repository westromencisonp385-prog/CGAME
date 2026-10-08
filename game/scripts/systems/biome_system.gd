class_name BiomeSystem
extends RefCounted

## C7 群系锁钥（语义对齐 BiomeData/BiomeLock/DesertKey/SwampKey 确证签名）：
## BiomeData：biomeID/biomeName/difficulty/silverFactor；
## BiomeLock：checkForDesertKey/checkForSwampKey → Unlock()（有钥匙即放行）；
## DesertKey/SwampKey：RequireComponent(Artifact) → 钥匙是神器，拾取即生效并长期解锁。
## 纯逻辑层：不依赖场景树，headless 可测；世界物（门/钥匙/天气）由 main 接线。

signal biome_changed(biome_id: String)
signal key_acquired(key_id: String)

const KEY_DESERT := "key_desert"
const KEY_SWAMP := "key_swamp"
const VALID_KEYS := [KEY_DESERT, KEY_SWAMP]

static func define_biomes() -> Dictionary:
	var river := {"id": "river", "name": "复苏河谷", "description": "起始作业河谷，水流复原后一片生机", "difficulty": 1, "silver_factor": 1.0, "required_key": ""}
	var desert := {"id": "desert", "name": "流金荒漠", "description": "沙暴肆虐的贫瘠沙海，底盘行动迟缓", "difficulty": 2, "silver_factor": 1.5, "required_key": KEY_DESERT}
	var swamp := {"id": "swamp", "name": "雾瘴沼泽", "description": "泥沼拖拽履带，深处藏着更重的赏金", "difficulty": 3, "silver_factor": 1.8, "required_key": KEY_SWAMP}
	return {"river": river, "desert": desert, "swamp": swamp}

var biomes: Dictionary = {}
## 对齐 SaveGame v7 的 unlocked_biome_ids：解锁即长期记录
var unlocked_biome_ids: Array = ["river"]
var keys: Dictionary = {}
var current_id := "river"

func _init() -> void:
	biomes = define_biomes()

func biome(biome_id: String) -> Dictionary:
	return biomes.get(biome_id, {}) as Dictionary

func current_biome() -> Dictionary:
	return biome(current_id)

func is_unlocked(biome_id: String) -> bool:
	return unlocked_biome_ids.has(biome_id)

## 对齐 BiomeLock.OnTriggerEnter → checkFor*Key → Unlock：已解锁或持有对应钥匙即放行
func can_enter(biome_id: String) -> bool:
	if not biomes.has(biome_id):
		return false
	if is_unlocked(biome_id):
		return true
	return int(keys.get(str(biome(biome_id)["required_key"]), 0)) > 0

## 对齐 DesertKey/SwampKey.TryApplyKey：钥匙神器生效 → 群系永久解锁（一次性持有）
func grant_key(key_id: String) -> Dictionary:
	if not VALID_KEYS.has(key_id):
		return {"granted": false, "reason": "unknown_key"}
	if int(keys.get(key_id, 0)) > 0:
		return {"granted": false, "reason": "already_holding"}
	keys[key_id] = 1
	key_acquired.emit(key_id)
	for id in biomes:
		if str(biomes[id]["required_key"]) == key_id and not unlocked_biome_ids.has(id):
			unlocked_biome_ids.append(id)
	return {"granted": true, "key": key_id, "unlocked": unlocked_biome_ids.duplicate()}

func switch_to(biome_id: String) -> Dictionary:
	if not biomes.has(biome_id):
		return {"switched": false, "reason": "unknown_biome"}
	if biome_id == current_id:
		return {"switched": false, "reason": "already_there"}
	if not can_enter(biome_id):
		return {"switched": false, "reason": "locked"}
	current_id = biome_id
	biome_changed.emit(biome_id)
	return {"switched": true, "biome": biome_id}

## 对齐 BiomeData.silverFactor + 环境事件（SandstormSpawner 语义）
func environment_effect(biome_id: String = "") -> Dictionary:
	var id := biome_id if not biome_id.is_empty() else current_id
	match id:
		"desert":
			return {"speed_factor": 0.82, "weather": "sandstorm"}
		"swamp":
			return {"speed_factor": 0.7, "weather": "bubbles"}
	return {"speed_factor": 1.0, "weather": ""}

func silver_factor() -> float:
	return float(current_biome().get("silver_factor", 1.0))

func locked_biome_ids() -> Array:
	var out: Array = []
	for id in biomes:
		if not is_unlocked(str(id)):
			out.append(id)
	return out

func reset_state() -> void:
	keys = {}
	unlocked_biome_ids = ["river"]
	current_id = "river"

# ---------- 快照（对齐 SaveGame v7 的 unlocked_biome_ids 持久化语义）----------

func get_snapshot() -> Dictionary:
	return {"schema": 1, "keys": keys.duplicate(), "unlocked": unlocked_biome_ids.duplicate(), "current": current_id}

func restore_snapshot(data: Dictionary) -> bool:
	if not data is Dictionary or int(data.get("schema", 0)) != 1:
		return false
	var raw_keys: Variant = data.get("keys", {})
	var unlocked: Variant = data.get("unlocked", [])
	var current: Variant = data.get("current", "")
	if not raw_keys is Dictionary or not unlocked is Array or not current is String:
		return false
	var clean_keys := {}
	for k in raw_keys:
		if not k is String or not VALID_KEYS.has(str(k)):
			return false
		clean_keys[str(k)] = clampi(int(raw_keys[k]), 0, 1)
	for id in unlocked:
		if not id is String or not biomes.has(str(id)):
			return false
	if not biomes.has(str(current)):
		return false
	# 钥匙与解锁必须自洽：持有钥匙的群系必须已解锁（grant_key 即解锁）
	for k in clean_keys:
		var consistent := false
		for id in biomes:
			if str(biomes[id]["required_key"]) == str(k) and unlocked.has(id):
				consistent = true
		if not consistent and int(clean_keys[k]) > 0:
			return false
	keys = clean_keys
	unlocked_biome_ids = ["river"]
	for id in unlocked:
		if not unlocked_biome_ids.has(str(id)):
			unlocked_biome_ids.append(str(id))
	current_id = str(current)
	return true
