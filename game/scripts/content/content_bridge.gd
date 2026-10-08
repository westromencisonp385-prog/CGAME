class_name ContentBridge
extends RefCounted

## S3 桥接层：ModuleDefinitionV2 → 旧版 ModuleDefinition（进 LoadoutAssembler 体系）。
## 数值语义分工：旧字段（power/range 等 bonus）保持 0，v2 数值走技能系统；
## 本桥只负责身份、槽位兼容与视觉路由。

const BRANCH_COLORS := {
	"mage_pyro": Color("#e2543a"), "mage_cryo": Color("#6fc8e8"),
	"mage_storm": Color("#f2d24c"), "mage_void": Color("#7a4fd0"),
	"crew_engineer": Color("#d9a13c"), "crew_sniper": Color("#9fd0c0"),
	"crew_medic": Color("#e8e2d0"), "crew_bomber": Color("#c97f4e"),
	"turret_layer": Color("#8fa3b8"), "arms_dealer": Color("#b8b06a"),
	"barracks": Color("#a0765a"), "top_cannon_tower": Color("#97a8c8"),
}
const DEFAULT_COLOR := Color(0.72, 0.75, 0.78)

static func to_legacy(module: ModuleDefinitionV2) -> ModuleDefinition:
	var legacy := ModuleDefinition.new()
	legacy.id = module.module_id
	legacy.display_name = module.module_name
	legacy.description = module.module_description
	legacy.family = _family_for(module.module_id)
	legacy.mount_kind = "function"
	legacy.tags = PackedStringArray([_branch_of(module.module_id), "v2"])
	legacy.color = BRANCH_COLORS.get(module.module_id, DEFAULT_COLOR)
	legacy.visual_scene_path = "res://scripts/module_visual.gd"
	return legacy

static func _family_for(module_id: String) -> ModuleDefinition.Family:
	if module_id.begins_with("mage_"):
		return ModuleDefinition.Family.REACTION
	if module_id.begins_with("crew_"):
		return ModuleDefinition.Family.REPAIR
	return ModuleDefinition.Family.MORPH

static func _branch_of(module_id: String) -> String:
	if module_id.begins_with("mage_"):
		return "mage"
	if module_id.begins_with("crew_"):
		return "crew"
	return "turret"
