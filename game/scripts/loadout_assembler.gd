class_name LoadoutAssembler
extends Node3D

const ModuleCatalogScript = preload("res://scripts/module_catalog.gd")
const ModuleVisualScript = preload("res://scripts/module_visual.gd")

signal loadout_changed(active_ids: Array[String])
signal preview_changed(module_id: String)

const SLOT_COUNT := 2
const DEFAULT_STATS := {"power": 14.0, "reach": 3.0, "radius": 1.35, "speed": 7.0, "cargo_capacity": 3}

var definitions: Dictionary = {}
var core_id: String = "basic_bucket"
var drive_id: String = ""
var active_ids: Array[String] = ["", ""]
var stage: int = 1
var preview_id: String = ""
var preview_slot: int = -1
var owner_vehicle: Node3D
var visual_root: Node3D
var preview_root: Node3D

func setup(vehicle: Node3D, module_definitions: Dictionary) -> void:
	owner_vehicle = vehicle
	definitions = module_definitions.duplicate()
	if not _definition_is_valid(core_id) or definitions[core_id].mount_kind != "core":
		core_id = _first_definition("core")
	if not core_id.is_empty() and not _definition_is_valid(core_id):
		core_id = ""
	visual_root = Node3D.new()
	visual_root.name = "ModuleVisuals"
	add_child(visual_root)
	preview_root = Node3D.new()
	preview_root.name = "LoadoutGhostPreview"
	preview_root.position = Vector3(0, 0, 5)
	add_child(preview_root)
	apply_visuals()

func get_active_definitions() -> Array[ModuleDefinition]:
	var result: Array[ModuleDefinition] = []
	for id in [core_id, drive_id, active_ids[0], active_ids[1]]:
		if not str(id).is_empty() and definitions.has(str(id)):
			result.append(definitions[str(id)] as ModuleDefinition)
	return result

func has_module(module_id: String) -> bool:
	return core_id == module_id or drive_id == module_id or active_ids.has(module_id)

func set_preview(module_id: String, slot_index: int = 0) -> bool:
	if not _definition_is_valid(module_id):
		return false
	var definition: ModuleDefinition = definitions[module_id]
	var target_slot := _target_slot_for(definition, slot_index)
	if target_slot == -2 or not _can_install(module_id, target_slot):
		return false
	preview_id = module_id
	preview_slot = target_slot
	_apply_preview_visual()
	preview_changed.emit(module_id)
	return true

func clear_preview() -> void:
	preview_id = ""
	preview_slot = -1
	_clear_preview_visual()
	preview_changed.emit("")

func confirm_preview(slot_index: int = -99) -> bool:
	if preview_id.is_empty() or not definitions.has(preview_id):
		return false
	var definition: ModuleDefinition = definitions[preview_id]
	var target_slot := _target_slot_for(definition, preview_slot if slot_index == -99 else slot_index)
	if target_slot == -2 or not _can_install(preview_id, target_slot):
		return false
	if target_slot == -1:
		core_id = preview_id
	elif target_slot == -3:
		drive_id = preview_id
	else:
		active_ids[target_slot] = preview_id
	_clear_preview_visual()
	preview_id = ""
	preview_slot = -1
	apply_visuals()
	loadout_changed.emit(active_ids.duplicate())
	preview_changed.emit("")
	return true

func snapshot() -> Dictionary:
	return {"version": 1, "core_id": core_id, "drive_id": drive_id, "active_ids": active_ids.duplicate(), "stage": stage}

func validate_snapshot(snapshot_data: Dictionary) -> bool:
	if snapshot_data.is_empty():
		return false
	var raw_version: Variant = snapshot_data.get("version")
	var raw_stage: Variant = snapshot_data.get("stage")
	var raw_core: Variant = snapshot_data.get("core_id")
	var raw_drive: Variant = snapshot_data.get("drive_id")
	var raw_active: Variant = snapshot_data.get("active_ids")
	if not _is_integer_number(raw_version) or int(raw_version) != 1 or not _is_integer_number(raw_stage):
		return false
	if raw_core is not String or raw_drive is not String or raw_active is not Array:
		return false
	if raw_active.size() != SLOT_COUNT or int(raw_stage) < 1 or int(raw_stage) > 2:
		return false
	if raw_active[0] is not String or raw_active[1] is not String:
		return false
	if not _definition_is_valid(raw_core) or definitions[raw_core].mount_kind != "core":
		return false
	if not raw_drive.is_empty() and (not _definition_is_valid(raw_drive) or definitions[raw_drive].mount_kind != "drive"):
		return false
	var used_ids: Array[String] = [raw_core]
	if not raw_drive.is_empty():
		used_ids.append(raw_drive)
	for id: String in raw_active:
		if id.is_empty():
			continue
		if used_ids.has(id) or not _definition_is_valid(id) or definitions[id].mount_kind != "function":
			return false
		used_ids.append(id)
	return true

func _is_integer_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func restore(snapshot_data: Dictionary) -> bool:
	if not validate_snapshot(snapshot_data):
		return false
	core_id = str(snapshot_data["core_id"])
	drive_id = str(snapshot_data.get("drive_id", ""))
	var raw_active: Array = snapshot_data["active_ids"]
	active_ids = [str(raw_active[0]), str(raw_active[1])]
	stage = int(snapshot_data["stage"])
	clear_preview()
	apply_visuals()
	loadout_changed.emit(active_ids.duplicate())
	return true

func modifier_sum(field_name: String) -> float:
	var result := 0.0
	for definition in get_active_definitions():
		result += float(definition.get(field_name))
	return result

func has_tag(tag: String) -> bool:
	for definition in get_active_definitions():
		if definition.has_tag(tag):
			return true
	return false

func get_stats() -> Dictionary:
	return _evaluate_stats(core_id, drive_id, active_ids, stage)

func _evaluate_stats(candidate_core: String, candidate_drive: String, candidate_active: Array[String], candidate_stage: int) -> Dictionary:
	var stats := DEFAULT_STATS.duplicate()
	for id: String in [candidate_core, candidate_drive, candidate_active[0], candidate_active[1]]:
		if id.is_empty() or not definitions.has(id):
			continue
		var definition: ModuleDefinition = definitions[id]
		stats.power = float(stats.power) + definition.power_bonus
		stats.reach = float(stats.reach) + definition.range_bonus
		stats.radius = float(stats.radius) + definition.radius_bonus
		stats.speed = float(stats.speed) + definition.speed_bonus
		stats.cargo_capacity = int(stats.cargo_capacity) + definition.cargo_bonus
	if candidate_stage >= 2:
		stats.reach = float(stats.reach) + 1.0
		stats.speed = float(stats.speed) - 0.8
	return stats

func set_stage(next_stage: int) -> bool:
	if next_stage < 1 or next_stage > 2:
		return false
	stage = next_stage
	apply_visuals()
	if not preview_id.is_empty():
		_apply_preview_visual()
	loadout_changed.emit(active_ids.duplicate())
	return true

func get_preview_summary() -> String:
	if preview_id.is_empty() or not definitions.has(preview_id):
		return "无预览"
	var candidate := _stats_with_preview()
	var current := get_stats()
	return "%s — %s\n功率 %+0.1f  范围 %+0.1f  扇面 %+0.2f  速度 %+0.1f  载荷 %+d\n代价：占用%s；二阶增程 +1.0 / 巡航 -0.8" % [definitions[preview_id].display_name, definitions[preview_id].description, float(candidate.power) - float(current.power), float(candidate.reach) - float(current.reach), float(candidate.radius) - float(current.radius), float(candidate.speed) - float(current.speed), int(candidate.cargo_capacity) - int(current.cargo_capacity), "核心位" if preview_slot == -1 else ("驱动位" if preview_slot == -3 else "功能位 %d" % (preview_slot + 1))]

func apply_visuals() -> void:
	if visual_root == null:
		return
	for child in visual_root.get_children():
		child.free()
	if not core_id.is_empty() and definitions.has(core_id):
		var core_visual := ModuleVisualScript.create(definitions[core_id], stage)
		core_visual.position = Vector3(0, 0, 0)
		visual_root.add_child(core_visual)
	if not drive_id.is_empty() and definitions.has(drive_id):
		var drive_visual := ModuleVisualScript.create(definitions[drive_id], stage)
		drive_visual.position = Vector3(0, 0, 0.4)
		visual_root.add_child(drive_visual)
	for index in range(SLOT_COUNT):
		var id := active_ids[index]
		if id.is_empty() or not definitions.has(id):
			continue
		var module_visual := ModuleVisualScript.create(definitions[id], stage)
		module_visual.position = Vector3(-0.9 if index == 0 else 0.9, 0, 0.2)
		visual_root.add_child(module_visual)
	if owner_vehicle != null and owner_vehicle.has_method("on_module_visuals_changed"):
		owner_vehicle.on_module_visuals_changed()

func _definition_is_valid(module_id: String) -> bool:
	return definitions.has(module_id) and ModuleCatalogScript.validate_definition(definitions[module_id] as ModuleDefinition)

func _first_definition(mount_kind: String) -> String:
	for id in definitions:
		if _definition_is_valid(id) and (definitions[id] as ModuleDefinition).mount_kind == mount_kind:
			return str(id)
	return ""

func _target_slot_for(definition: ModuleDefinition, requested_slot: int) -> int:
	if definition.mount_kind == "core":
		return -1
	if definition.mount_kind == "drive":
		return -3
	if requested_slot < 0 or requested_slot >= SLOT_COUNT:
		return -2
	return requested_slot

func _can_install(module_id: String, target_slot: int) -> bool:
	if target_slot == -2 or not _definition_is_valid(module_id):
		return false
	var definition: ModuleDefinition = definitions[module_id]
	if target_slot == -1:
		return definition.mount_kind == "core" and module_id != core_id
	if target_slot == -3:
		return definition.mount_kind == "drive" and module_id != drive_id
	if definition.mount_kind != "function":
		return false
	if active_ids.has(module_id) and active_ids[target_slot] != module_id:
		return false
	if module_id == core_id or module_id == drive_id:
		return false
	return true

func _apply_preview_visual() -> void:
	_clear_preview_visual()
	if preview_root == null or preview_id.is_empty() or not definitions.has(preview_id):
		return
	var ghost_body := Node3D.new()
	ghost_body.name = "GhostVehicle"
	preview_root.add_child(ghost_body)
	var ghost_material := StandardMaterial3D.new()
	ghost_material.albedo_color = Color(0.35, 0.8, 0.95, 0.24)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for part in [
		["Chassis", Vector3(2.6, 0.8, 2.2), Vector3.ZERO],
		["Cabin", Vector3(1.0, 0.75, 0.95), Vector3(0, 0.72, 0.3)],
		["TrackLeft", Vector3(0.4, 0.6, 2.7), Vector3(-1.3, -0.2, 0)],
		["TrackRight", Vector3(0.4, 0.6, 2.7), Vector3(1.3, -0.2, 0)],
	]:
		var mesh := BoxMesh.new()
		mesh.size = part[1]
		var instance := MeshInstance3D.new()
		instance.name = part[0]
		instance.mesh = mesh
		instance.position = part[2]
		instance.material_override = ghost_material
		ghost_body.add_child(instance)
	var candidate_ids: Array[String] = [core_id, drive_id, active_ids[0], active_ids[1]]
	var candidate_index := 0 if preview_slot == -1 else (1 if preview_slot == -3 else preview_slot + 2)
	candidate_ids[candidate_index] = preview_id
	for index in candidate_ids.size():
		var id := candidate_ids[index]
		if id.is_empty() or not definitions.has(id):
			continue
		var ghost_module := ModuleVisualScript.create(definitions[id], stage, true)
		if index == 1:
			ghost_module.position.z = 0.4
		elif index >= 2:
			ghost_module.position = Vector3(-0.9 if index == 2 else 0.9, 0, 0.2)
		ghost_body.add_child(ghost_module)
	var label := Label3D.new()
	label.name = "PreviewStats"
	label.text = get_preview_summary()
	label.font_size = 32
	label.outline_size = 8
	label.position = Vector3(0, 2.8, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	preview_root.add_child(label)

func _clear_preview_visual() -> void:
	if preview_root == null:
		return
	for child in preview_root.get_children():
		child.free()

func _stats_with_preview() -> Dictionary:
	var candidate_core := core_id
	var candidate_drive := drive_id
	var candidate_active := active_ids.duplicate()
	if preview_slot == -1:
		candidate_core = preview_id
	elif preview_slot == -3:
		candidate_drive = preview_id
	else:
		candidate_active[preview_slot] = preview_id
	return _evaluate_stats(candidate_core, candidate_drive, candidate_active, stage)
