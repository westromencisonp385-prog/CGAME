class_name ModuleDefinition
extends Resource

## Data-only definition used by the loadout seam.
enum Family { TOOL, DRIVE, REACTION, REPAIR, MORPH }

@export var id: String = ""
@export var display_name: String = ""
@export var family: Family = Family.TOOL
@export_enum("core", "function", "drive") var mount_kind: String = "function"
@export_multiline var description: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var power_bonus: float = 0.0
@export var range_bonus: float = 0.0
@export var radius_bonus: float = 0.0
@export var speed_bonus: float = 0.0
@export var cargo_bonus: int = 0
@export var heat_bonus: float = 0.0
@export var color: Color = Color.WHITE
@export var visual_scene_path: String = "res://scripts/module_visual.gd"

func configure(module_id: String, name_text: String, module_family: Family, description_text: String, module_tags: PackedStringArray, module_color: Color) -> ModuleDefinition:
	id = module_id
	display_name = name_text
	family = module_family
	mount_kind = "core" if module_family == Family.TOOL else ("drive" if module_family == Family.DRIVE else "function")
	description = description_text
	tags = module_tags
	color = module_color
	return self

func has_tag(tag: String) -> bool:
	return tags.has(tag)
