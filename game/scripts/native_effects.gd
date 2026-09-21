extends Node3D
## Presentation-only effect director. Gameplay never reads particles or shader state.
const RING = preload("res://effects/pulse_ring.gdshader")
const DUST_PATH := "res://assets/generated/dust-puff.png"
const MAX_BURSTS := 20
const MAGNET_PURPLE := Color("#a486db")
const ENGINE_YELLOW := Color("#e9ad38")
const REPAIR_TEAL := Color("#58b7ac")
const COMEDY_RED := Color("#df604e")
var enabled := true
var vehicle: Node3D
var field: MeshInstance3D
var field_material: ShaderMaterial
var dust: Texture2D
var live: Array[Dictionary] = []
var age := 0.0
var serial := 0
var parcels: Array[Node3D] = []

func _ready() -> void:
	if ResourceLoader.exists(DUST_PATH):
		dust = load(DUST_PATH)
	field = _ring(Vector3.ZERO, 11.0, Color("#a77cdd"))
	field_material = field.material_override
	field.hide()
	field_material.set_shader_parameter("strength", 0.35)
	for _index in range(2):
		var parcel := _scrap_cube()
		add_child(parcel)
		parcel.hide()
		parcels.append(parcel)

func set_vehicle(value: Node3D) -> void:
	vehicle = value

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		for effect in live:
			effect.node.queue_free()
		live.clear()
		field.hide()
		for parcel in parcels:
			parcel.hide()

func get_status() -> Dictionary:
	return {"enabled": enabled, "live_effects": live.size(), "burst_limit": MAX_BURSTS,
		"particle_budget": MAX_BURSTS * 12, "dust_texture_loaded": dust != null}

func _process(delta: float) -> void:
	age += delta
	var packed_ids: Array = vehicle.get("packed_enemy_ids") if is_instance_valid(vehicle) else []
	for index in parcels.size():
		var parcel: Node3D = parcels[index]
		parcel.visible = enabled and is_instance_valid(vehicle) and index < packed_ids.size()
		if parcel.visible:
			var direction: Vector3 = vehicle.aim_direction.normalized()
			var sideways := Vector3(-direction.z, 0, direction.x)
			parcel.global_position = vehicle.global_position + direction * 1.8 + sideways * (float(index) - 0.5) * 0.85 + Vector3.UP * 0.65
			parcel.rotation.y = atan2(direction.x, direction.z)
	field.visible = enabled and is_instance_valid(vehicle) and vehicle.assembler != null and vehicle.assembler.has_module("magnet")
	if field.visible:
		field.global_position = Vector3(vehicle.global_position.x, 0.11, vehicle.global_position.z)
		field_material.set_shader_parameter("phase", age * -1.4)
	for index in range(live.size() - 1, -1, -1):
		var effect: Dictionary = live[index]
		effect.time = float(effect.time) - delta
		if effect.time <= 0.0:
			effect.node.queue_free()
			live.remove_at(index)
		elif effect.kind == "ring":
			var progress := 1.0 - float(effect.time) / float(effect.duration)
			effect.node.scale = Vector3.ONE * lerpf(0.3, 1.0, progress)
			effect.node.material_override.set_shader_parameter("strength", 1.0 - progress)
			effect.node.material_override.set_shader_parameter("phase", age)
		elif effect.kind == "beam":
			effect.node.scale.x = float(effect.time) / float(effect.duration)
			effect.node.scale.z = effect.node.scale.x
		elif effect.kind in ["pack", "parcel"]:
			var progress := 1.0 - float(effect.time) / float(effect.duration)
			effect.node.position = effect.origin.lerp(effect.destination, progress)
			effect.node.position.y += sin(progress * PI) * (2.5 if effect.kind == "parcel" else 0.55)
			effect.node.rotation.z = sin(progress * TAU) * 0.18
			if effect.kind == "pack":
				# The parcel visibly compresses as the jaws close. This is only
				# a prop animation; the packed target and damage are authoritative
				# in vehicle_controller.gd.
				effect.node.scale = Vector3(
					lerpf(1.1, 0.5, progress),
					lerpf(1.0, 0.72, progress),
					lerpf(1.1, 0.5, progress)
				)
				effect.node.rotation.y += delta * 5.0

func play(kind: String, from: Vector3, to: Vector3) -> void:
	if not enabled or live.size() >= MAX_BURSTS:
		return
	serial += 1
	if kind in ["whale_pack", "whale_release"]:
		var parcel := _scrap_cube()
		add_child(parcel)
		var origin := to if kind == "whale_pack" else from
		var destination := from + Vector3.UP if kind == "whale_pack" else to
		var duration := 0.3 if kind == "whale_pack" else 0.55
		live.append({"node": parcel, "kind": "pack" if kind == "whale_pack" else "parcel", "time": duration,
			"duration": duration, "origin": origin, "destination": destination})
		if kind == "whale_pack":
			# Three readable beats: target gathers dust, the stubborn parcel
			# snaps toward the mouth, then the yellow flag remains for a beat.
			_remember(_ring(to, 3.4, COMEDY_RED), "ring", 0.28)
			_burst(to, Color("#c6a274"), 7, 0.32)
			_remember(_ring(from, 2.7, MAGNET_PURPLE), "ring", 0.5)
			_burst(destination, ENGINE_YELLOW, 6, 0.42)
		else:
			# Release lands with a hard ring and a small delayed dust pop. The
			# delayed pop is decorative and never changes the hit result.
			_remember(_ring(to, 4.8, ENGINE_YELLOW), "ring", 0.52)
			_burst(to, Color("#e5c788"), 10, 0.48)
			_burst(to + Vector3(0.0, 0.15, 0.0), COMEDY_RED, 5, 0.7)
	elif "arc" in kind or "electric" in kind:
		_lightning(from + Vector3.UP, to + Vector3.UP)
		_burst(to, Color("#d7b7ff"), 9, 0.3)
	elif "water" in kind:
		_beam(from + Vector3.UP, to + Vector3.UP, Color("#79e6e7"), 0.07)
		_burst(to, Color("#6ecfd3"), 12, 0.4)
	elif kind == "repair":
		# Pump feedback has a readable rise, cough, and flow cue. It does not
		# delay the repaired signal or own any world state.
		_remember(_ring(to, 8.0, REPAIR_TEAL), "ring", 1.4)
		_remember(_ring(to, 3.0, ENGINE_YELLOW), "ring", 0.65)
		_beam(to + Vector3.UP * 0.25, to + Vector3.UP * 1.8, REPAIR_TEAL, 0.11)
		_burst(to + Vector3.UP * 0.75, Color("#aed975"), 12, 1.0)
		_burst(to, Color("#c7a46b"), 5, 0.35)
	elif kind == "dash_hit":
		_remember(_ring(to, 5.0, Color("#edbb61")), "ring", 0.5)
		_burst(to, Color("#edca8a"), 12, 0.55)
	else:
		_burst(to, Color("#c8b790"), 8, 0.65)

func _burst(at: Vector3, color: Color, amount: int, duration: float) -> void:
	if live.size() >= MAX_BURSTS:
		return
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = duration
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-5, -3, -5), Vector3(10, 8, 10))
	particles.position = at + Vector3.UP * 0.4
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 65.0
	motion.initial_velocity_min = 1.1
	motion.initial_velocity_max = 3.2
	motion.gravity = Vector3(0, -1.1, 0)
	motion.scale_min = 0.2
	motion.scale_max = 0.55
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	motion.color_ramp = ramp
	particles.process_material = motion
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	if dust != null:
		material.albedo_texture = dust
	else:
		quad.size = Vector2(0.1, 0.1)
	quad.material = material
	particles.draw_pass_1 = quad
	add_child(particles)
	particles.emitting = true
	_remember(particles, "particle", duration + 0.15)

func _ring(at: Vector3, size: float, color: Color) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	ring.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = RING
	material.set_shader_parameter("tint", color)
	ring.material_override = material
	ring.position = Vector3(at.x, 0.1, at.z)
	add_child(ring)
	return ring

func _lightning(from: Vector3, to: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = serial
	var previous := from
	for index in range(1, 5):
		var point := from.lerp(to, index / 4.0)
		if index < 4:
			point += Vector3(rng.randf_range(-0.25, 0.25), 0.12, rng.randf_range(-0.25, 0.25))
		_beam(previous, point, Color("#d9c3ff"), 0.045)
		previous = point

func _beam(from: Vector3, to: Vector3, color: Color, radius: float) -> void:
	if live.size() >= MAX_BURSTS:
		return
	var node := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = maxf(from.distance_to(to), 0.02)
	node.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	node.material_override = material
	node.position = (from + to) / 2.0
	if from.distance_to(to) > 0.001:
		node.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	add_child(node)
	_remember(node, "beam", 0.22)

func _remember(node: Node3D, kind: String, duration: float) -> void:
	live.append({"node": node, "kind": kind, "time": duration, "duration": duration})

func _scrap_cube() -> Node3D:
	# Original bounded geometry: a compressed scrap parcel with a stubborn flag.
	# This has no collision, target identity, or damage callback.
	var parcel := Node3D.new()
	for item in [
		[Vector3(0.7, 0.62, 0.7), Vector3.ZERO, Color("#64716c")],
		[Vector3(0.78, 0.09, 0.76), Vector3(0, 0.2, 0), Color("#e9ad38")],
		[Vector3(0.09, 0.72, 0.78), Vector3(0.18, 0, 0), Color("#253d48")],
		[Vector3(0.05, 0.7, 0.05), Vector3(-0.16, 0.62, 0), Color("#eee3c7")],
		[Vector3(0.4, 0.25, 0.04), Vector3(0.02, 0.82, 0), Color("#df604e")]
	]:
		var piece := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = item[0]
		piece.mesh = mesh
		piece.position = item[1]
		var material := StandardMaterial3D.new()
		material.albedo_color = item[2]
		material.roughness = 0.85
		piece.material_override = material
		parcel.add_child(piece)
	return parcel
