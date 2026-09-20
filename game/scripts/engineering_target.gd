class_name EngineeringTarget
extends Node3D

signal destroyed(target: EngineeringTarget)
signal repaired(target: EngineeringTarget)
signal harvested(amount: int)
signal action_effect(kind: String, origin: Vector3, end: Vector3)

@export var target_id: String = "target"
@export var target_kind: String = "soft"
@export var hit_points: float = 20.0

var current_hp: float = 20.0
var repaired_state := false
var dead := false
var wet_time := 0.0
var resource_remaining := 1
var _harvest_awarded := false
var mesh_instance: MeshInstance3D
var base_material: StandardMaterial3D
var _home_position := Vector3.ZERO
var collision_body: StaticBody3D

func configure(new_id: String, kind: String, hp: float, at: Vector3 = Vector3.ZERO) -> EngineeringTarget:
	target_id = new_id
	target_kind = kind
	hit_points = hp
	current_hp = hp
	position = at
	_home_position = at
	return self

func _ready() -> void:
	add_to_group("engineering_targets")
	if current_hp <= 0.0:
		current_hp = hit_points
	_home_position = position
	_build_visual()

func _build_visual() -> void:
	mesh_instance = MeshInstance3D.new()
	var mesh: Mesh
	if target_kind == "repair":
		var cylinder := CylinderMesh.new()
		cylinder.height = 1.5
		cylinder.top_radius = 0.7
		cylinder.bottom_radius = 0.8
		mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = Vector3(1.4, 1.2, 1.4)
		mesh = box
	mesh_instance.mesh = mesh
	base_material = StandardMaterial3D.new()
	base_material.roughness = 0.8
	base_material.albedo_color = _base_color()
	mesh_instance.material_override = base_material
	add_child(mesh_instance)
	position.y = maxf(position.y, 0.75 if target_kind == "repair" else 0.6)
	if target_kind != "light":
		collision_body = StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.35, 1.2, 1.35)
		collider.shape = shape
		collision_body.add_child(collider)
		add_child(collision_body)

func _base_color() -> Color:
	match target_kind:
		"hard": return Color("#596477")
		"light": return Color("#d2a04e")
		"repair": return Color("#2f8390")
		_: return Color("#7a6552")

func _process(delta: float) -> void:
	if wet_time > 0.0:
		wet_time = maxf(0.0, wet_time - delta)
		if wet_time <= 0.0 and not repaired_state and not dead and base_material != null:
			base_material.albedo_color = _base_color()

func can_be_magnetized() -> bool:
	return not dead and not repaired_state and target_kind == "light"

func apply_wet(duration: float = 4.0) -> void:
	if dead or repaired_state:
		return
	wet_time = maxf(wet_time, duration)
	if base_material != null:
		base_material.albedo_color = Color("#63c8e4")

func is_wet() -> bool:
	return wet_time > 0.0

func try_engineering_hit(origin: Vector3, direction: Vector3, radius: float, reach: float, power: float, source: Dictionary = {}) -> Dictionary:
	if dead or repaired_state:
		return {"hit": false, "dead": dead, "harvested": 0, "target_id": target_id}
	if target_kind == "repair":
		return {"hit": false, "dead": false, "harvested": 0, "target_id": target_id}
	var planar := global_position - origin
	planar.y = 0.0
	var distance := planar.length()
	var facing := direction.normalized().dot(planar.normalized()) if distance > 0.05 else 0.0
	if distance > reach + radius or distance < 0.05 or facing < 0.28:
		return {"hit": false, "dead": false, "harvested": 0, "target_id": target_id}
	var was_wet := is_wet()
	if bool(source.get("water", false)):
		apply_wet(float(source.get("wet_duration", 4.0)))
	var damage := power
	if target_kind == "hard":
		damage *= 0.65
	if bool(source.get("electric", false)) and not was_wet:
		damage *= 0.45
	current_hp = maxf(0.0, current_hp - damage)
	action_effect.emit("hit", origin, global_position)
	var result := {"hit": true, "dead": false, "harvested": 0, "wet_before": was_wet, "target_id": target_id}
	if current_hp <= 0.0:
		if target_kind == "repair":
			repair()
		else:
			result["dead"] = true
			result["harvested"] = _destroy_and_harvest()
	return result

func pull_toward(point: Vector3, amount: float) -> bool:
	if not can_be_magnetized():
		return false
	var offset := point - global_position
	if offset.length() <= 0.1:
		return false
	var planar := offset
	planar.y = 0.0
	global_position += planar.normalized() * minf(amount, planar.length())
	return true

func interact_repair() -> bool:
	if target_kind != "repair" or dead or repaired_state:
		return false
	repair()
	return true

func repair() -> void:
	if dead or repaired_state or target_kind != "repair":
		return
	repaired_state = true
	current_hp = 0.0
	if mesh_instance != null:
		mesh_instance.material_override = _green_material()
	repaired.emit(self)
	action_effect.emit("repair", global_position, global_position)

func _destroy_and_harvest() -> int:
	if dead:
		return 0
	dead = true
	var amount := 0
	if not _harvest_awarded and resource_remaining > 0:
		amount = resource_remaining
		resource_remaining = 0
		_harvest_awarded = true
		harvested.emit(amount)
	destroyed.emit(self)
	queue_free()
	return amount

func destroy_target() -> void:
	_destroy_and_harvest()

func get_snapshot() -> Dictionary:
	return {"schema": 1, "target_id": target_id, "target_kind": target_kind, "position": [global_position.x, global_position.y, global_position.z], "current_hp": current_hp, "wet_time": wet_time, "repaired": repaired_state, "dead": dead, "resource_remaining": resource_remaining, "harvest_awarded": _harvest_awarded}

func validate_snapshot(data: Dictionary) -> bool:
	if int(data.get("schema", 0)) != 1 or str(data.get("target_id", "")) != target_id or str(data.get("target_kind", "")) != target_kind:
		return false
	if not ["soft", "hard", "light", "repair"].has(target_kind):
		return false
	var p = data.get("position", null)
	var hp := float(data.get("current_hp", -1.0))
	var wet := float(data.get("wet_time", -1.0))
	return p is Array and p.size() == 3 and (typeof(p[0]) == TYPE_FLOAT or typeof(p[0]) == TYPE_INT) and (typeof(p[1]) == TYPE_FLOAT or typeof(p[1]) == TYPE_INT) and (typeof(p[2]) == TYPE_FLOAT or typeof(p[2]) == TYPE_INT) and is_finite(float(p[0])) and is_finite(float(p[1])) and is_finite(float(p[2])) and is_finite(hp) and hp >= 0.0 and hp <= hit_points and is_finite(wet) and wet >= 0.0 and wet <= 60.0

func restore_snapshot(data: Dictionary) -> bool:
	if not validate_snapshot(data):
		return false
	var p: Array = data.get("position", [_home_position.x, _home_position.y, _home_position.z])
	if p.size() < 3:
		return false
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	current_hp = clampf(float(data.get("current_hp", hit_points)), 0.0, hit_points)
	wet_time = maxf(0.0, float(data.get("wet_time", 0.0)))
	repaired_state = bool(data.get("repaired", false))
	dead = bool(data.get("dead", false))
	resource_remaining = maxi(0, int(data.get("resource_remaining", 1)))
	_harvest_awarded = bool(data.get("harvest_awarded", resource_remaining == 0))
	if mesh_instance != null:
		if repaired_state:
			mesh_instance.material_override = _green_material()
		elif wet_time > 0.0:
			mesh_instance.material_override = base_material
			base_material.albedo_color = Color("#63c8e4")
		else:
			mesh_instance.material_override = base_material
			base_material.albedo_color = _base_color()
	return true

func _green_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#75d28a")
	material.emission_enabled = true
	material.emission = Color("#183c22")
	return material
