class_name ModuleCatalog
extends RefCounted

const MODULE_PATHS: Array[String] = [
	"res://content/modules/basic_bucket.tres",
	"res://content/modules/wide_bucket.tres",
	"res://content/modules/water_cannon.tres",
	"res://content/modules/electric_arc.tres",
	"res://content/modules/magnet.tres",
	"res://content/modules/inertia_flywheel.tres",
]

# Contract-facing build identities live beside the module data so preview, GM
# presets and QA can refer to one canonical description of the intended slice.
const BUILD_SIGNATURES := {
	"magnetic_whale": {
		"core": "wide_bucket",
		"functions": ["magnet"],
		"verbs": ["聚拢", "压缩", "投送"],
		"counterplay": "重型护卫不能被吸入，必须用投送落点或基础铲击处理",
	},
	"storm_relay": {
		"core": "basic_bucket",
		"functions": ["water_cannon", "electric_arc"],
		"verbs": ["铺湿", "连锁"],
		"counterplay": "电弧先手伤害降低，需维持湿润窗口",
	},
}

static func create_definitions() -> Dictionary:
	var definitions: Dictionary = {}
	for path in MODULE_PATHS:
		var definition := load(path) as ModuleDefinition
		if definition != null and validate_definition(definition):
			definitions[definition.id] = definition
	return definitions

static func get_build_signature(id: String) -> Dictionary:
	return (BUILD_SIGNATURES.get(id, {}) as Dictionary).duplicate(true)

static func validate_definition(definition: ModuleDefinition) -> bool:
	if definition == null or definition.id.is_empty() or definition.display_name.is_empty():
		return false
	if definition.visual_scene_path.is_empty() or not ResourceLoader.exists(definition.visual_scene_path):
		return false
	if definition.family < ModuleDefinition.Family.TOOL or definition.family > ModuleDefinition.Family.MORPH:
		return false
	if definition.mount_kind not in ["core", "function", "drive"]:
		return false
	return true
