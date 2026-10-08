class_name FormalModelLibrary
extends RefCounted

## C10：正式模型目录。P2 Weaver 产物拷入 game/assets/models/formal_slice/ 后，
## 运行时按槽位自动挂载；文件缺失自动回落代码白模（不崩、不丢功能）。
## 命名约定：<slot>_formal.glb（fbx 由 Godot 导入器处理，运行时统一 load .glb/.fbx）。

const MODELS_DIR := "res://assets/models/formal_slice"

## 槽位 -> 文件名（P2 计划 slot 后缀 _formal.glb）
const SLOT_FILES := {
	"enemy_light": "enemy_light_formal.glb",
	"enemy_light_v1": "enemy_light_v1_formal.glb",
	"enemy_light_v2": "enemy_light_v2_formal.glb",
	"enemy_ranged": "enemy_ranged_formal.glb",
	"enemy_ranged_v1": "enemy_ranged_v1_formal.glb",
	"enemy_flyer": "enemy_flyer_v1_formal.glb",
	"enemy_heavy": "enemy_heavy_formal.glb",
	"boss_01_kanoning": "boss_01_kanoning_formal.glb",
	"boss_02": "boss_02_formal.glb",
	"boss_03": "boss_03_formal.glb",
	"player_stage02_whale": "player_stage02_whale_formal.glb",
	"module_umbrella_mole": "module_umbrella_mole_formal.glb",
	"module_rail_snail": "module_rail_snail_formal.glb",
	"module_folding_bastion": "module_folding_bastion_formal.glb",
	"module_scrap_crawler": "module_scrap_crawler_formal.glb",
	"module_spider_crane": "module_spider_crane_formal.glb",
	"module_road_croc": "module_road_croc_formal.glb",
	"module_repair_ark": "module_repair_ark_formal.glb",
	"module_demolition_pigeon": "module_demolition_pigeon_formal.glb",
	"biome_gate": "biome_gate_formal.glb",
	"camp_board": "camp_board_formal.glb",
	"wind_turbine": "wind_turbine_formal.glb",
	"mountain_air_pump": "mountain_air_pump_formal.glb",
}

static func model_path(slot: String) -> String:
	var file := str(SLOT_FILES.get(slot, ""))
	return "" if file.is_empty() else "%s/%s" % [MODELS_DIR, file]

## v2 模块 -> 模型槽位（12 模块共用 8 个设定稿模型，按功能语义分配）
const MODULE_SLOTS := {
	"mage_pyro": "module_demolition_pigeon",
	"mage_cryo": "module_umbrella_mole",
	"mage_storm": "module_spider_crane",
	"mage_void": "module_scrap_crawler",
	"crew_engineer": "module_repair_ark",
	"crew_sniper": "module_rail_snail",
	"crew_medic": "module_repair_ark",
	"crew_bomber": "module_demolition_pigeon",
	"turret_layer": "module_folding_bastion",
	"arms_dealer": "module_road_croc",
	"barracks": "module_folding_bastion",
	"top_cannon_tower": "module_spider_crane",
}

## Boss 花名册 -> 模型槽位（3 个设定稿 Boss 轮换覆盖 10 顺位）
const BOSS_SLOTS := ["boss_01_kanoning", "boss_02", "boss_03"]
const BOSS_SLOT_OVERRIDES := {"boss_kanoning": "boss_01_kanoning", "boss_dredge_toad": "boss_04_dredge_toad"}

static func boss_slot(boss_id: String) -> String:
	if BOSS_SLOT_OVERRIDES.has(boss_id):
		return str(BOSS_SLOT_OVERRIDES[boss_id])
	var ids: Array = ContentRoster.boss_ids()
	var index := ids.find(boss_id)
	return BOSS_SLOTS[maxi(index, 0) % BOSS_SLOTS.size()]

static func module_slot(module_id: String) -> String:
	if MODULE_SLOTS.has(module_id):
		return str(MODULE_SLOTS[module_id])
	# C17 新增 28 模块：按挂件组共用 8 个部件化模块模型
	return str(GROUP_SLOTS.get(ContentV2Catalog.group_of(module_id), ""))

const GROUP_SLOTS := {
	"mage": "module_spider_crane",
	"crew": "module_repair_ark",
	"turret": "module_folding_bastion",
	"front": "module_road_croc",
	"side": "module_rail_snail",
	"back": "module_scrap_crawler",
}

static func has_model(slot: String) -> bool:
	var path := model_path(slot)
	return not path.is_empty() and ResourceLoader.exists(path)

## 挂载正式模型；成功返回 true。
## P2 流水线（tools/asset_pipeline/blender_to_game_glb.py）导出的 GLB 已是 Y-up、底面中心为原点、
## 且按槽位目标尺寸归一化过，所以这里不旋转、不二次缩放。仅保留个别微调系数。
const SLOT_SCALES := {}

static func attach(parent: Node3D, slot: String, model_name := "FormalModel") -> Node3D:
	if parent == null or not has_model(slot):
		return null
	var packed := load(model_path(slot))
	if packed == null:
		return null
	var model := (packed as PackedScene).instantiate() as Node3D
	if model == null:
		return null
	model.name = model_name
	model.scale = Vector3.ONE * float(SLOT_SCALES.get(slot, 1.0))
	parent.add_child(model)
	return model
