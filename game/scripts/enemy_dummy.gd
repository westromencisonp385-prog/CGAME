class_name EnemyDummy
extends Node3D

signal defeated(enemy: EnemyDummy)
signal hit_player(amount: float)
signal action_effect(kind: String, origin: Vector3, end: Vector3)

@export var enemy_id: String = "crawler"
@export var health: float = 35.0
@export var speed: float = 1.2
@export var kind: String = "light" # light, heavy, ranged

var current_health: float = 35.0
var wet_time := 0.0
var dead := false
var player: Node3D
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var visual_root: Node3D
var shadow: MeshInstance3D
var attack_timer := 0.0
var _home_position := Vector3.ZERO
var _wobble_time := 0.0
var packed := false
var pack_used := false

func configure(new_id: String, enemy_kind: String, hp: float, move_speed: float, at: Vector3 = Vector3.ZERO) -> EnemyDummy:
	enemy_id = new_id
	kind = enemy_kind
	health = hp
	current_health = hp
	speed = move_speed
	position = at
	_home_position = at
	return self

func _ready() -> void:
	add_to_group("enemies")
	if current_health <= 0.0:
		current_health = health
	_home_position = position
	_build_visual()

func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "EnemyVisual"
	add_child(visual_root)
	shadow = _add_cylinder("ContactShadow", 0.58 if kind != "heavy" else 0.82, 0.025, Vector3(0, 0.025, 0), Color("#344542"))
	shadow.scale = Vector3(1.25, 1.0, 0.72)
	mesh_instance = MeshInstance3D.new()
	var mesh: Mesh
	var height := height_for_kind()
	if kind == "heavy":
		var heavy_mesh := BoxMesh.new()
		heavy_mesh.size = Vector3(1.5, height, 1.35)
		mesh = heavy_mesh
	else:
		var wedge := CylinderMesh.new()
		wedge.top_radius = 0.16
		wedge.bottom_radius = 0.58
		wedge.height = height
		wedge.radial_segments = 6
		mesh = wedge
	mesh_instance.mesh = mesh
	material = StandardMaterial3D.new()
	material.albedo_color = Color("#df604e") if kind != "heavy" else Color("#8c4b59")
	material.metallic = 0.2
	material.roughness = 0.68
	mesh_instance.material_override = material
	visual_root.add_child(mesh_instance)
	position.y = maxf(position.y, height * 0.5)
	_add_box("LeftTrack", Vector3(0.18, 0.22, 0.9 if kind != "heavy" else 1.1), Vector3(-0.42 if kind != "heavy" else -0.7, 0.12, 0), Color("#253d48"))
	_add_box("RightTrack", Vector3(0.18, 0.22, 0.9 if kind != "heavy" else 1.1), Vector3(0.42 if kind != "heavy" else 0.7, 0.12, 0), Color("#253d48"))
	for side in [-1.0, 1.0]:
		_add_cylinder("TrackHub", 0.11 if kind != "heavy" else 0.16, 0.08, Vector3(side * (0.52 if kind != "heavy" else 0.82), 0.14, 0), Color("#f2c85c"), Vector3(0, 0, 90))
	# The enemy's readable behaviour shape is a leaning wedge or a heavy block;
	# the small warning plate adds comedy without turning it into a face.
	_add_box("WarningPlate", Vector3(0.75 if kind != "heavy" else 1.0, 0.1, 0.12), Vector3(0, height * 0.62, -0.36), Color("#f2c85c"))
	_add_box("WarningStripe", Vector3(0.18, 0.11, 0.4), Vector3(-0.31 if kind != "heavy" else -0.42, height * 0.62, -0.36), Color("#253d48"))
	_add_box("WarningStripe", Vector3(0.18, 0.11, 0.4), Vector3(0.31 if kind != "heavy" else 0.42, height * 0.62, -0.36), Color("#253d48"))
	if kind == "heavy":
		_add_box("HeavyShoulder", Vector3(1.85, 0.18, 0.45), Vector3(0, 0.65, -0.52), Color("#df604e"))
		_add_cylinder("HeavyBeacon", 0.18, 0.22, Vector3(0, height + 0.12, 0), Color("#f2c85c"))
	else:
		_add_cylinder("WobbleAntenna", 0.07, 0.75, Vector3(0.12, height * 0.72, 0.06), Color("#eee3c7"))

func height_for_kind() -> float:
	return 1.4 if kind != "heavy" else 1.9

func _add_box(node_name: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	var plate := StandardMaterial3D.new()
	plate.albedo_color = color
	plate.roughness = 0.72
	instance.material_override = plate
	(visual_root if visual_root != null else self).add_child(instance)
	return instance

func _add_cylinder(node_name: String, radius: float, height: float, at: Vector3, color: Color, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = rotation
	var cap := StandardMaterial3D.new()
	cap.albedo_color = color
	cap.roughness = 0.7
	instance.material_override = cap
	(visual_root if visual_root != null else self).add_child(instance)
	return instance

func _process(delta: float) -> void:
	if dead:
		return
	_wobble_time += delta
	if visual_root != null:
		var wobble := sin(_wobble_time * (5.0 if kind != "heavy" else 2.2) + float(enemy_id.hash() % 13)) * (0.07 if kind != "heavy" else 0.025)
		visual_root.rotation.z = wobble
	if player != null and is_instance_valid(player) and bool(player.get("gameplay_enabled")):
		var offset := player.global_position - global_position
		offset.y = 0.0
		if offset.length() > 1.8:
			global_position += offset.normalized() * speed * delta
		attack_timer -= delta
		if offset.length() < 2.2 and attack_timer <= 0.0:
			attack_timer = 1.4
			hit_player.emit(4.0 if kind != "heavy" else 7.0)
	if wet_time > 0.0:
		wet_time = maxf(0.0, wet_time - delta)
		if wet_time <= 0.0 and material != null:
			material.albedo_color = Color("#d5574e") if kind != "heavy" else Color("#8c4b59")

func can_be_magnetized() -> bool:
	return not dead and not packed and not pack_used and kind == "light"

func pack_into_whale() -> bool:
	if not can_be_magnetized():
		return false
	packed = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	return true

func release_from_whale() -> bool:
	if not packed:
		return false
	packed = false
	pack_used = true
	visible = not dead
	process_mode = Node.PROCESS_MODE_PAUSABLE
	return true

func apply_wet(duration: float = 4.0) -> void:
	if dead:
		return
	wet_time = maxf(wet_time, duration)
	if material != null:
		material.albedo_color = Color("#63c8e4")

func is_wet() -> bool:
	return wet_time > 0.0

func try_engineering_hit(origin: Vector3, direction: Vector3, radius: float, reach: float, power: float, source: Dictionary = {}) -> Dictionary:
	if dead or packed:
		return {"hit": false, "dead": true, "wet_before": false, "target_id": enemy_id}
	var planar := global_position - origin
	planar.y = 0.0
	var distance := planar.length()
	var facing := direction.normalized().dot(planar.normalized()) if distance > 0.05 else 0.0
	if distance > reach + radius or distance < 0.05 or facing < 0.28:
		return {"hit": false, "dead": false, "wet_before": false, "target_id": enemy_id}
	var was_wet := is_wet()
	if bool(source.get("water", false)):
		apply_wet(float(source.get("wet_duration", 4.0)))
	var damage := power
	if kind == "heavy":
		damage *= 0.65
	if bool(source.get("electric", false)) and not was_wet:
		damage *= 0.45
	if bool(source.get("dash", false)):
		damage *= 1.8
	take_damage(damage)
	action_effect.emit("hit", origin, global_position)
	return {"hit": true, "dead": dead, "wet_before": was_wet, "chain_eligible": was_wet and not dead, "target_id": enemy_id}

func take_damage(amount: float) -> void:
	if dead or packed:
		return
	current_health = maxf(0.0, current_health - maxf(0.0, amount))
	if current_health <= 0.0:
		dead = true
		visible = false
		defeated.emit(self)

func pull_toward(point: Vector3, amount: float) -> bool:
	if not can_be_magnetized():
		return false
	var offset := point - global_position
	if offset.length() <= 0.1:
		return false
	global_position += offset.normalized() * minf(amount, offset.length())
	return true

func get_snapshot() -> Dictionary:
	return {"schema": 1, "enemy_id": enemy_id, "kind": kind, "position": [global_position.x, global_position.y, global_position.z], "current_health": current_health, "wet_time": wet_time, "dead": dead, "attack_timer": attack_timer, "packed": packed, "pack_used": pack_used}

func validate_snapshot(data: Dictionary) -> bool:
	if int(data.get("schema", 0)) != 1 or str(data.get("enemy_id", "")) != enemy_id or str(data.get("kind", "")) != kind:
		return false
	var saved_packed := bool(data.get("packed", false))
	var saved_dead := bool(data.get("dead", false))
	var saved_pack_used := bool(data.get("pack_used", false))
	if saved_packed and (saved_dead or saved_pack_used or kind != "light"):
		return false
	var p = data.get("position", null)
	var hp := float(data.get("current_health", -1.0))
	var wet := float(data.get("wet_time", -1.0))
	return ["light", "heavy", "ranged"].has(kind) and p is Array and p.size() == 3 and (typeof(p[0]) == TYPE_FLOAT or typeof(p[0]) == TYPE_INT) and (typeof(p[1]) == TYPE_FLOAT or typeof(p[1]) == TYPE_INT) and (typeof(p[2]) == TYPE_FLOAT or typeof(p[2]) == TYPE_INT) and is_finite(float(p[0])) and is_finite(float(p[1])) and is_finite(float(p[2])) and is_finite(hp) and hp >= 0.0 and hp <= health and is_finite(wet) and wet >= 0.0 and wet <= 60.0

func restore_snapshot(data: Dictionary) -> bool:
	if not validate_snapshot(data):
		return false
	var p: Array = data.get("position", [_home_position.x, _home_position.y, _home_position.z])
	if p.size() < 3:
		return false
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	current_health = clampf(float(data.get("current_health", health)), 0.0, health)
	wet_time = maxf(0.0, float(data.get("wet_time", 0.0)))
	dead = bool(data.get("dead", false))
	attack_timer = maxf(0.0, float(data.get("attack_timer", 0.0)))
	packed = bool(data.get("packed", false)) and not dead
	pack_used = bool(data.get("pack_used", false))
	visible = not dead and not packed
	process_mode = Node.PROCESS_MODE_DISABLED if packed else Node.PROCESS_MODE_PAUSABLE
	if dead:
		current_health = 0.0
	return true
