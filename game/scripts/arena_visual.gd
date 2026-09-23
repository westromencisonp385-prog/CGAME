extends Node3D
## G1 presentation layer: a readable, stylised river worksite.
##
## This node owns no gameplay state. Decorative meshes intentionally have no
## collision bodies; the existing arena bounds remain the authority for play.
const Effects = preload("res://scripts/native_effects.gd")
const RIVER = preload("res://effects/river_surface.gdshader")

const OLIVE := Color("#6f7f61")
const EARTH := Color("#b48658")
const EARTH_DARK := Color("#6e503d")
const WATER_DULL := Color("#356f79")
const WATER_LIVE := Color("#4caea7")
const NAVY := Color("#253d48")
const BONE := Color("#eee3c7")
const ALERT := Color("#df604e")
const REPAIR_GREEN := Color("#78d6a8")
const PIPE_METAL := Color("#718a88")

var green_zone: Node3D
var route_before: Node3D
var route_after: Node3D
var camera: Camera3D
var effects: Node3D
var river_material: ShaderMaterial
var shortcut_gate_mesh: MeshInstance3D
var flow_time := 0.0
var route_repaired := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_lighting()
	_build_camera()
	_build_ground()
	_build_river_worksite()
	_build_edge_landmarks()
	_build_shortcut_visual()
	_set_route_state(false)
	effects = Effects.new()
	add_child(effects)

func _build_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.name = "WarmWorklight"
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_color = Color("#ffe4be")
	light.light_energy = 1.45
	light.shadow_enabled = true
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.name = "CoolRimFill"
	fill.rotation_degrees = Vector3(-35, 150, 0)
	fill.light_color = Color("#9dc7d1")
	fill.light_energy = 0.3
	fill.shadow_enabled = false
	add_child(fill)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#152c37")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9dc7d1")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "WorksiteCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23.0
	# A 55-degree starting angle exposes the cab, tool head and bank shapes.
	camera.position = Vector3(0, 25, 17)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0))

func _build_ground() -> void:
	# One quiet low-frequency plane keeps the action readable at a glance.
	box(self, Vector3(36, 1, 32), Vector3(0, -0.55, 0), EARTH, true)
	for at in [Vector3(-18, 0.8, 0), Vector3(18, 0.8, 0), Vector3(0, 0.8, -16), Vector3(0, 0.8, 16)]:
		var size := Vector3(1, 2, 33) if absf(at.x) > 0 else Vector3(36, 2, 1)
		box(self, size, at, NAVY, true)
	# Large authored masses replace the old debug grid: two work lanes and soft
	# vegetation patches, all visual-only.
	_disk(self, "CentralDustYard", Vector3(0, 0.035, 0.5), Vector3(11.5, 0.035, 15.8), Color("#bd9565"), 14)
	_disk(self, "OliveBackPatch", Vector3(-7.0, 0.04, -4.5), Vector3(6.4, 0.035, 6.8), OLIVE, 9)
	_disk(self, "OliveRepairPatch", Vector3(6.8, 0.045, -7.2), Vector3(5.2, 0.035, 4.5), Color("#788b67"), 10)
	_disk(self, "WarmScrapPatch", Vector3(-5.0, 0.05, 6.2), Vector3(5.8, 0.035, 2.2), Color("#d0a66f"), 8)
	_disk(self, "WarmPumpPatch", Vector3(4.2, 0.052, 6.1), Vector3(6.0, 0.035, 2.0), Color("#c99a66"), 8)
	box(self, Vector3(0.15, 0.06, 2.7), Vector3(-8.0, 0.07, 5.3), BONE)
	box(self, Vector3(0.15, 0.06, 2.7), Vector3(-7.45, 0.07, 5.3), BONE)
	for z in [-10.8, -7.2, 7.5, 11.0]:
		var strip := box(self, Vector3(2.3, 0.05, 0.12), Vector3(-8.6, 0.085, z), Color("#8e6d4f"))
		strip.rotation_degrees.y = 8.0 if z < 0.0 else -7.0

func _build_river_worksite() -> void:
	# The dry channel is visible before repair; green_zone is the stateful overlay
	# toggled by main.gd after the pump is repaired.
	var dry := Node3D.new()
	dry.name = "DryRiverAndBanks"
	add_child(dry)
	_disk(dry, "DryChannel", Vector3(9.0, 0.06, -2.2), Vector3(5.3, 0.045, 18.2), WATER_DULL, 14)
	for z in [-10.0, -7.2, -4.3, -1.2, 2.0, 5.5, 8.2]:
		_create_rock(dry, Vector3(6.4 + fmod(z * 2.1, 1.0) * 0.3, 0.18, z), 0.5, Color("#526f70"))
		_create_rock(dry, Vector3(11.4 - fmod(z * 1.7, 1.0) * 0.35, 0.19, z + 0.9), 0.44, Color("#617876"))

	green_zone = Node3D.new()
	green_zone.name = "RepairedRiverAndGrowth"
	add_child(green_zone)
	for index in range(18):
		var x := 7.0 + fmod(float(index * 17), 5.4)
		var z := -12.5 + fmod(float(index * 7), 16.0)
		_create_reed_cluster(green_zone, Vector3(x, 0.08, z), index % 2 == 0)
	var flowing_water := _disk(green_zone, "FlowingWater", Vector3(9, 0.13, -2), Vector3(4.8, 0.045, 17.8), WATER_LIVE, 16)
	river_material = ShaderMaterial.new()
	river_material.shader = RIVER
	flowing_water.material_override = river_material
	green_zone.hide()
	_build_route_landmarks()

func _build_route_landmarks() -> void:
	# The route is a visual contract: before repair, the broken crossing and
	# leaking pipe explain the detour; after repair, the bridge and green guide
	# bands explain why the world has gained a shortcut. No child has collision.
	route_before = Node3D.new()
	route_before.name = "RouteBeforeRepair"
	add_child(route_before)
	_create_route_notice(route_before, Vector3(3.1, 0.0, -1.0), ALERT, "ROUTE CLOSED")
	box(route_before, Vector3(3.4, 0.28, 1.35), Vector3(5.4, 0.25, -1.0), EARTH_DARK)
	box(route_before, Vector3(3.4, 0.28, 1.35), Vector3(12.6, 0.25, -1.0), EARTH_DARK)
	for at in [Vector3(4.1, 0.58, -1.0), Vector3(13.9, 0.58, -1.0)]:
		box(route_before, Vector3(0.18, 0.8, 0.18), at, ALERT)
	_pipe(route_before, Vector3(9.0, 0.26, 1.2), 7.0, Color("#a87856"))
	_pipe(route_before, Vector3(9.0, 0.28, 2.0), 5.2, PIPE_METAL)
	_create_route_notice(route_before, Vector3(14.0, 0.0, -1.0), ALERT, "DETOUR")

	route_after = Node3D.new()
	route_after.name = "RouteAfterRepair"
	add_child(route_after)
	box(route_after, Vector3(10.8, 0.34, 1.7), Vector3(9.0, 0.34, -1.0), BONE)
	box(route_after, Vector3(10.8, 0.12, 0.38), Vector3(9.0, 0.56, -1.62), REPAIR_GREEN)
	box(route_after, Vector3(10.8, 0.12, 0.38), Vector3(9.0, 0.56, -0.38), REPAIR_GREEN)
	for x in [4.1, 6.0, 8.0, 10.0, 12.0, 13.9]:
		box(route_after, Vector3(0.16, 0.9, 0.16), Vector3(x, 0.76, -1.0), REPAIR_GREEN)
	_create_route_notice(route_after, Vector3(3.1, 0.0, -1.0), REPAIR_GREEN, "SHORTCUT OPEN")
	_create_route_notice(route_after, Vector3(14.0, 0.0, -1.0), REPAIR_GREEN, "PUMP PASSED")
	route_after.scale = Vector3.ZERO

func _build_shortcut_visual() -> void:
	shortcut_gate_mesh = box(self, Vector3(10.8, 1.7, 0.7), Vector3(9.0, 0.85, -1.0), ALERT)
	shortcut_gate_mesh.name = "ShortcutClosedVisual"

func _set_route_state(repaired: bool) -> void:
	if route_before == null or route_after == null:
		return
	route_repaired = repaired
	route_before.visible = not repaired
	route_after.visible = repaired
	if repaired:
		route_after.scale = Vector3(1.0, 0.12, 1.0)
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(route_after, "scale", Vector3.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		route_after.scale = Vector3.ZERO

func set_shortcut_open(open: bool) -> void:
	_set_route_state(open)
	if shortcut_gate_mesh != null:
		shortcut_gate_mesh.visible = not open

func is_shortcut_open() -> bool:
	return route_repaired

func _create_route_notice(parent: Node3D, at: Vector3, color: Color, _label: String) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	box(group, Vector3(0.12, 1.15, 0.12), Vector3(0, 0.58, 0), EARTH_DARK)
	box(group, Vector3(1.55, 0.56, 0.12), Vector3(0, 1.3, 0), color)
	box(group, Vector3(0.92, 0.08, 0.14), Vector3(0, 1.3, -0.08), BONE)
	# The short, high-contrast stripe is legible from the top-down camera even
	# without relying on tiny 3D text that would blur at gameplay scale.
	box(group, Vector3(0.14, 0.26, 0.14), Vector3(-0.45, 1.3, -0.09), color.darkened(0.35))
	box(group, Vector3(0.14, 0.26, 0.14), Vector3(0.45, 1.3, -0.09), color.darkened(0.35))

func _pipe(parent: Node3D, at: Vector3, length: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.13
	mesh.bottom_radius = 0.16
	mesh.height = length
	mesh.radial_segments = 8
	var pipe := MeshInstance3D.new()
	pipe.mesh = mesh
	pipe.position = at
	pipe.rotation_degrees.z = 90.0
	pipe.material_override = material(color)
	parent.add_child(pipe)

func _build_edge_landmarks() -> void:
	var landmarks := Node3D.new()
	landmarks.name = "EdgeLandmarks"
	add_child(landmarks)
	# A crooked civic arch and two warning pennants establish foreground/background
	# without turning the route into a collision maze.
	_create_arch(landmarks, Vector3(-13.0, 0.0, -10.5))
	_create_pennant(landmarks, Vector3(13.2, 0.0, 10.5), Color("#df604e"))
	_create_pennant(landmarks, Vector3(-12.5, 0.0, 10.0), Color("#e9ad38"))
	_create_tree_cluster(landmarks, Vector3(-12.6, 0.0, -3.0))
	_create_tree_cluster(landmarks, Vector3(13.1, 0.0, 4.2))
	_create_broken_wall(landmarks, Vector3(-10.8, 0.0, 11.0), -12.0)
	_create_rock(landmarks, Vector3(-13.0, 0.25, 1.0), 1.1, Color("#5d706d"))
	_create_rock(landmarks, Vector3(13.0, 0.23, -13.0), 0.9, Color("#6d7669"))
	_create_repair_sign(landmarks, Vector3(5.6, 0.0, -7.0))

func _create_arch(parent: Node3D, at: Vector3) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	box(group, Vector3(0.6, 3.0, 0.6), Vector3(-1.1, 1.35, 0), NAVY)
	box(group, Vector3(0.6, 2.3, 0.6), Vector3(1.1, 1.05, 0), NAVY)
	box(group, Vector3(2.8, 0.5, 0.6), Vector3(0, 2.55, 0), BONE)
	box(group, Vector3(2.0, 0.18, 0.12), Vector3(0, 2.55, -0.34), Color("#df604e"))

func _create_pennant(parent: Node3D, at: Vector3, flag_color: Color) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	box(group, Vector3(0.12, 2.4, 0.12), Vector3(0, 1.15, 0), EARTH_DARK)
	box(group, Vector3(0.9, 0.55, 0.08), Vector3(0.36, 2.0, 0), flag_color)

func _create_repair_sign(parent: Node3D, at: Vector3) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	box(group, Vector3(0.12, 1.7, 0.12), Vector3(0, 0.84, 0), EARTH_DARK)
	box(group, Vector3(1.15, 0.7, 0.12), Vector3(0.42, 1.52, 0), Color("#58b7ac"))
	box(group, Vector3(0.68, 0.12, 0.12), Vector3(0.42, 1.52, -0.08), BONE)
	box(group, Vector3(0.12, 0.48, 0.12), Vector3(0.42, 1.52, -0.08), BONE)

func _create_tree_cluster(parent: Node3D, at: Vector3) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	for item in [[0.0, 0.0, 1.05], [0.8, 0.35, 0.82], [-0.7, 0.45, 0.74], [0.2, -0.65, 0.7]]:
		var crown := SphereMesh.new()
		crown.radius = float(item[2])
		crown.height = float(item[2]) * 1.15
		crown.radial_segments = 8
		crown.rings = 4
		var instance := MeshInstance3D.new()
		instance.mesh = crown
		instance.position = Vector3(float(item[0]), 0.72, float(item[1]))
		instance.material_override = material(Color("#667a56"))
		group.add_child(instance)
	box(group, Vector3(0.34, 0.9, 0.34), Vector3(0, 0.38, 0), EARTH_DARK)

func _create_broken_wall(parent: Node3D, at: Vector3, yaw: float) -> void:
	var group := Node3D.new()
	group.position = at
	group.rotation_degrees.y = yaw
	parent.add_child(group)
	for index in range(5):
		var height := 0.8 + float(index % 2) * 0.32
		box(group, Vector3(0.95, height, 0.34), Vector3((index - 2) * 0.9, height * 0.5, 0), Color("#5f6f70"))

func _create_reed_cluster(parent: Node3D, at: Vector3, warm: bool) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	var stem_color := Color("#6b915b") if warm else Color("#4f7c63")
	for index in range(3):
		var stem := CylinderMesh.new()
		stem.top_radius = 0.07
		stem.bottom_radius = 0.11
		stem.height = 0.75 + index * 0.12
		stem.radial_segments = 5
		var blade := MeshInstance3D.new()
		blade.mesh = stem
		blade.position = Vector3((index - 1) * 0.16, 0.4, (index % 2) * 0.12)
		blade.rotation_degrees.z = -12.0 + index * 10.0
		blade.material_override = material(stem_color)
		group.add_child(blade)

func _create_rock(parent: Node3D, at: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = radius * 0.55
	mesh.radial_segments = 6
	var rock := MeshInstance3D.new()
	rock.mesh = mesh
	rock.position = at
	rock.rotation_degrees = Vector3(0, fmod(at.z * 17.0, 30.0), 0)
	rock.material_override = material(color)
	parent.add_child(rock)

func _disk(parent: Node3D, node_name: String, at: Vector3, scale_value: Vector3, color: Color, segments := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.scale = scale_value
	instance.material_override = material(color)
	parent.add_child(instance)
	return instance

func _process(delta: float) -> void:
	flow_time += delta
	if river_material != null:
		river_material.set_shader_parameter("flow_time", flow_time)
	if green_zone != null and green_zone.visible != route_repaired:
		_set_route_state(green_zone.visible)

func set_vehicle(vehicle: Node3D) -> void:
	effects.set_vehicle(vehicle)

func set_effects_enabled(enabled: bool) -> void:
	effects.set_enabled(enabled)

func present_effect(kind: String, from: Vector3, to: Vector3) -> void:
	effects.play(kind, from, to)

func box(parent: Node3D, extent: Vector3, at: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = extent
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = material(color)
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.position = at
		var collider := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = extent
		collider.shape = collision
		body.add_child(collider)
		parent.add_child(body)
	return mesh

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	return mat
