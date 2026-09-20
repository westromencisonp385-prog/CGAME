class_name M0VehicleController
extends CharacterBody3D

const CombatResolverScript = preload("res://scripts/combat_resolver.gd")

signal feedback(message: String)
signal state_changed
signal disabled
signal harvested(amount: int)
signal action_effect(kind: String, origin: Vector3, end: Vector3)

var assembler: LoadoutAssembler
var camera: Camera3D
var aim_direction := Vector3(0, 0, -1)
var cargo := 0
var max_cargo := 3
var heat := 0.0
var health := 100.0
var max_speed := 7.0
var base_speed := 7.0
var primary_cooldown := 0.0
var throw_cooldown := 0.0
var dash_cooldown := 0.0
var charge := 0.0
var gameplay_enabled := true
var dash_pending := false
var dash_remaining := 0.0
var dash_hit_ids: Array[String] = []
var tool_anim_time := 0.0
var _last_position := Vector3.ZERO
var visual_root: Node3D
var bucket_visual: Node3D
var chassis_visual: Node3D
var boom_visual: Node3D
var cabin_visual: MeshInstance3D

func _ready() -> void:
	add_to_group("player_vehicle")
	_create_collision()
	_create_visuals()
	_last_position = global_position

func setup(module_assembler: LoadoutAssembler, gameplay_camera: Camera3D) -> void:
	assembler = module_assembler
	camera = gameplay_camera
	if not assembler.loadout_changed.is_connected(_on_loadout_changed):
		assembler.loadout_changed.connect(_on_loadout_changed)
	_on_loadout_changed(assembler.active_ids)

func _stats() -> Dictionary:
	if assembler != null and assembler.has_method("get_stats"):
		return assembler.get_stats()
	return {"power": 14.0, "reach": 3.0, "radius": 1.35, "speed": 7.0, "cargo_capacity": 3}

func _physics_process(delta: float) -> void:
	if not gameplay_enabled or health <= 0.0:
		return
	primary_cooldown = maxf(0.0, primary_cooldown - delta)
	throw_cooldown = maxf(0.0, throw_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	heat = maxf(0.0, heat - delta * 12.0)
	tool_anim_time = maxf(0.0, tool_anim_time - delta)
	if boom_visual != null:
		boom_visual.rotation.x = sin(tool_anim_time * 28.0) * 0.22 if tool_anim_time > 0.0 else move_toward(boom_visual.rotation.x, 0.0, delta * 4.0)
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir := Vector3(movement.x, 0.0, movement.y)
	var stats := _stats()
	max_speed = float(stats.get("speed", base_speed))
	velocity.x = move_toward(velocity.x, move_dir.x * max_speed, delta * 18.0)
	velocity.z = move_toward(velocity.z, move_dir.z * max_speed, delta * 18.0)
	if move_dir.length() < 0.1:
		velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
	var before := global_position
	move_and_slide()
	var displacement := global_position.distance_to(before)
	if displacement > 0.01:
		record_drive_displacement(displacement)
		chassis_visual.rotation.y = lerp_angle(chassis_visual.rotation.y, atan2(velocity.x, velocity.z), delta * 8.0)
		_update_aim_from_movement(move_dir)
	if dash_pending:
		dash_remaining = maxf(0.0, dash_remaining - delta)
		_resolve_dash_contacts(before, global_position)
		if dash_remaining <= 0.0:
			dash_pending = false
	if Input.is_action_pressed("primary"):
		perform_primary()
	if Input.is_action_just_pressed("throw_cargo"):
		throw_cargo()
	if Input.is_action_just_pressed("dash"):
		try_dash()
	if assembler != null and assembler.has_tag("magnet"):
		_pull_nearby_targets(delta)
	state_changed.emit()
	_last_position = global_position

func _update_aim_from_movement(move_dir: Vector3) -> void:
	var aim_input := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if aim_input.length() > 0.1:
		aim_direction = Vector3(aim_input.x, 0.0, aim_input.y).normalized()
	elif move_dir.length() > 0.1:
		aim_direction = move_dir.normalized()
	if camera == null:
		return
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return
	var ray_origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var ray_direction := camera.project_ray_normal(get_viewport().get_mouse_position())
	if absf(ray_direction.y) > 0.001:
		var distance := (global_position.y - ray_origin.y) / ray_direction.y
		var planar: Vector3 = ray_origin + ray_direction * distance - global_position
		planar.y = 0.0
		if planar.length() > 0.2:
			aim_direction = planar.normalized()

func perform_primary() -> Dictionary:
	if not gameplay_enabled or health <= 0.0 or primary_cooldown > 0.0:
		return {"performed": false, "hits": 0, "chain_hits": 0}
	primary_cooldown = 0.32
	tool_anim_time = 0.24
	heat = minf(100.0, heat + 8.0)
	var stats := _stats()
	var reach := float(stats.get("reach", 3.0))
	var radius := float(stats.get("radius", 1.35))
	var power := float(stats.get("power", 14.0))
	var source := {"dash": false, "water": assembler != null and assembler.has_module("water_cannon"), "electric": assembler != null and assembler.has_module("electric_arc"), "wet_duration": 4.0}
	var hit_count := 0
	var chain_hits := 0
	var struck_enemies: Array[Node] = []
	for node in get_tree().get_nodes_in_group("engineering_targets"):
		if node is EngineeringTarget:
			var result: Dictionary = node.try_engineering_hit(global_position, aim_direction, radius, reach, power, source)
			if bool(result.get("hit", false)):
				hit_count += 1
			var amount := int(result.get("harvested", 0))
			if amount > 0:
				cargo = mini(int(stats.get("cargo_capacity", max_cargo)), cargo + amount)
				harvested.emit(amount)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyDummy:
			var enemy_result: Dictionary = node.try_engineering_hit(global_position, aim_direction, radius, reach, power, source)
			if bool(enemy_result.get("hit", false)):
				hit_count += 1
				struck_enemies.append(node)
	if source.electric:
		for source_enemy in struck_enemies:
			if not is_instance_valid(source_enemy) or not source_enemy.is_wet():
				continue
			var chain_targets: Array[Node3D] = CombatResolverScript.select_chain_targets(source_enemy, get_tree().get_nodes_in_group("enemies"), 2, 4.5)
			for node in chain_targets:
				node.take_damage(power * 0.55)
				chain_hits += 1
				action_effect.emit("arc_chain", source_enemy.global_position, node.global_position)
	feedback.emit("挖斗命中 %d 个目标" % hit_count if hit_count > 0 else "挖斗落空")
	return {"performed": true, "hits": hit_count, "chain_hits": chain_hits, "cargo": cargo}

func throw_cargo() -> Dictionary:
	if not gameplay_enabled or throw_cooldown > 0.0 or cargo <= 0:
		return {"performed": false, "hit": false}
	throw_cooldown = 0.45
	cargo -= 1
	var damage := 24.0 + float(cargo) * 3.0 + (8.0 if assembler != null and assembler.has_module("wide_bucket") else 0.0)
	var best: Node = null
	var best_distance := 8.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is EnemyDummy or node.dead:
			continue
		var planar: Vector3 = node.global_position - global_position
		planar.y = 0.0
		if planar.length() < best_distance and aim_direction.dot(planar.normalized()) > 0.55:
			best = node
			best_distance = planar.length()
	if best != null:
		best.take_damage(damage)
		feedback.emit("废料投掷命中")
		return {"performed": true, "hit": true}
	feedback.emit("废料投掷")
	return {"performed": true, "hit": false}

func try_dash() -> bool:
	if not gameplay_enabled or dash_cooldown > 0.0:
		return false
	dash_cooldown = 1.8
	var dash_power := 18.0 if assembler != null and assembler.has_module("inertia_flywheel") else 12.0
	velocity += aim_direction * dash_power
	dash_pending = true
	dash_remaining = 0.35
	dash_hit_ids.clear()
	feedback.emit("液压冲刺")
	return true

func record_drive_displacement(distance: float) -> void:
	if distance <= 0.0:
		return
	charge = minf(100.0, charge + distance * (5.0 if assembler != null and assembler.has_module("inertia_flywheel") else 1.5))

func reset_vehicle(at: Vector3 = Vector3.ZERO) -> void:
	global_position = at
	health = 100.0
	cargo = 0
	heat = 0.0
	charge = 0.0
	primary_cooldown = 0.0
	throw_cooldown = 0.0
	dash_cooldown = 0.0
	dash_pending = false
	dash_remaining = 0.0
	dash_hit_ids.clear()
	velocity = Vector3.ZERO
	aim_direction = Vector3(0, 0, -1)
	gameplay_enabled = true

func _resolve_dash_contacts(from: Vector3, to: Vector3) -> void:
	if from.distance_to(to) < 0.04:
		return
	var multiplier := 1.8 if assembler != null and assembler.has_module("inertia_flywheel") and charge >= 20.0 else 1.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is EnemyDummy or node.dead:
			continue
		if node.global_position.distance_to(to) < 2.4 and not dash_hit_ids.has(node.enemy_id):
			node.take_damage(20.0 * multiplier)
			dash_hit_ids.append(node.enemy_id)
			if multiplier > 1.0:
				charge = 0.0
			action_effect.emit("dash_hit", from, node.global_position)

func receive_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - maxf(0.0, amount))
	feedback.emit("受到 %.0f 点伤害" % amount)
	if health <= 0.0:
		gameplay_enabled = false
		velocity = Vector3.ZERO
		disabled.emit()
		feedback.emit("工程车失效，按 F9 恢复快照")
		disabled.emit()

func on_module_visuals_changed() -> void:
	if bucket_visual == null or assembler == null:
		return
	var wide := assembler.has_module("wide_bucket")
	bucket_visual.scale = Vector3(1.5, 0.8, 1.1) if wide else Vector3.ONE
	if bucket_visual.has_node("BucketMesh"):
		(bucket_visual.get_node("BucketMesh") as MeshInstance3D).material_override = _material(Color("#f2bd45") if wide else Color("#c68b31"))

func _on_loadout_changed(_active_ids: Array[String]) -> void:
	var stats := _stats()
	max_cargo = int(stats.get("cargo_capacity", 3))
	on_module_visuals_changed()

func _pull_nearby_targets(delta: float) -> void:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if count >= 4 or not node is EnemyDummy or not node.can_be_magnetized():
			continue
		if global_position.distance_to(node.global_position) < 5.5 and node.pull_toward(global_position, delta * 1.3):
			count += 1
	for node in get_tree().get_nodes_in_group("engineering_targets"):
		if count >= 4 or not node is EngineeringTarget or not node.can_be_magnetized():
			continue
		if global_position.distance_to(node.global_position) < 5.5 and node.pull_toward(global_position, delta * 0.7):
			count += 1

func _create_collision() -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.2, 2.0)
	collider.shape = shape
	collider.position.y = 0.6
	add_child(collider)

func _create_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VehicleVisuals"
	add_child(visual_root)
	chassis_visual = MeshInstance3D.new()
	var chassis_mesh := BoxMesh.new()
	chassis_mesh.size = Vector3(2.6, 0.8, 2.2)
	chassis_visual.mesh = chassis_mesh
	chassis_visual.material_override = _material(Color("#394b55"))
	visual_root.add_child(chassis_visual)
	for x in [-1.0, 1.0]:
		var track := MeshInstance3D.new()
		var track_mesh := BoxMesh.new()
		track_mesh.size = Vector3(0.45, 0.45, 2.4)
		track.mesh = track_mesh
		track.position = Vector3(x, -0.25, 0.0)
		track.material_override = _material(Color("#171d22"))
		visual_root.add_child(track)
	cabin_visual = MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.2, 0.9, 1.2)
	cabin_visual.mesh = cabin_mesh
	cabin_visual.position = Vector3(0, 0.85, 0.3)
	cabin_visual.material_override = _material(Color("#427080"))
	visual_root.add_child(cabin_visual)
	boom_visual = Node3D.new()
	boom_visual.name = "TwoStageBoom"
	visual_root.add_child(boom_visual)
	for i in 2:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.38, 0.38, 1.9)
		arm.mesh = arm_mesh
		arm.position = Vector3(0, 0.8 - i * 0.1, -0.8 - i * 0.9)
		arm.rotation_degrees.x = -20.0 if i == 0 else 18.0
		arm.material_override = _material(Color("#c68b31"))
		boom_visual.add_child(arm)
	bucket_visual = Node3D.new()
	bucket_visual.name = "BucketVisual"
	boom_visual.add_child(bucket_visual)
	var bucket := MeshInstance3D.new()
	bucket.name = "BucketMesh"
	var bucket_mesh := BoxMesh.new()
	bucket_mesh.size = Vector3(1.7, 0.55, 1.2)
	bucket.mesh = bucket_mesh
	bucket.position = Vector3(0, 0.1, -1.7)
	bucket.material_override = _material(Color("#c68b31"))
	bucket_visual.add_child(bucket)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	material.roughness = 0.55
	return material

func get_snapshot() -> Dictionary:
	return {"schema": 1, "position": [global_position.x, global_position.y, global_position.z], "health": health, "cargo": cargo, "heat": heat, "aim": [aim_direction.x, aim_direction.y, aim_direction.z], "primary_cooldown": primary_cooldown, "throw_cooldown": throw_cooldown, "dash_cooldown": dash_cooldown, "charge": charge, "dash_pending": dash_pending, "dash_remaining": dash_remaining, "dash_hit_ids": dash_hit_ids.duplicate()}

func validate_snapshot(data: Dictionary) -> bool:
	if int(data.get("schema", 0)) != 1:
		return false
	var p = data.get("position", null)
	var a = data.get("aim", null)
	if not (p is Array and p.size() == 3 and a is Array and a.size() == 3):
		return false
	for value in p:
		if not (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) or not is_finite(float(value)):
			return false
	for value in a:
		if not (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) or not is_finite(float(value)):
			return false
	var saved_health := float(data.get("health", -1.0))
	var saved_cargo := int(data.get("cargo", -1))
	var saved_charge := float(data.get("charge", -1.0))
	var primary := float(data.get("primary_cooldown", -1.0))
	var throwing := float(data.get("throw_cooldown", -1.0))
	var dash := float(data.get("dash_cooldown", -1.0))
	return is_finite(saved_health) and saved_health >= 0.0 and saved_health <= 100.0 and saved_cargo >= 0 and saved_cargo <= 64 and is_finite(saved_charge) and saved_charge >= 0.0 and saved_charge <= 100.0 and is_finite(primary) and primary >= 0.0 and primary <= 30.0 and is_finite(throwing) and throwing >= 0.0 and throwing <= 30.0 and is_finite(dash) and dash >= 0.0 and dash <= 30.0

func restore_snapshot(data: Dictionary) -> bool:
	if not validate_snapshot(data):
		return false
	var p: Array = data["position"]
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	health = float(data.get("health", 100.0))
	cargo = int(data.get("cargo", 0))
	heat = float(data.get("heat", 0.0))
	var a: Array = data["aim"]
	aim_direction = Vector3(float(a[0]), float(a[1]), float(a[2]))
	primary_cooldown = float(data.get("primary_cooldown", 0.0))
	throw_cooldown = float(data.get("throw_cooldown", 0.0))
	dash_cooldown = float(data.get("dash_cooldown", 0.0))
	charge = float(data.get("charge", 0.0))
	dash_pending = bool(data.get("dash_pending", false))
	dash_remaining = maxf(0.0, float(data.get("dash_remaining", 0.0)))
	dash_hit_ids.clear()
	for hit_id in data.get("dash_hit_ids", []):
		dash_hit_ids.append(str(hit_id))
	gameplay_enabled = health > 0.0
	velocity = Vector3.ZERO
	return true
