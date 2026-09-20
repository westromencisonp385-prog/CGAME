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

static func create_definitions() -> Dictionary:
	var definitions: Dictionary = {}
	for path in MODULE_PATHS:
		var definition := load(path) as ModuleDefinition
		if definition != null and validate_definition(definition):
			definitions[definition.id] = definition
	return definitions

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
