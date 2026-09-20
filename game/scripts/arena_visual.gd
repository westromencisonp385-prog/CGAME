extends Node3D
## G1 presentation layer: a readable, stylised river worksite.
##
## This node owns no gameplay state. Decorative meshes intentionally have no
## collision bodies; the existing arena bounds remain the authority for play.
const Effects = preload("res://scripts/native_effects.gd")
const RIVER = preload("res://effects/river_surface.gdshader")

const OLIVE := Color("#687b62")
const EARTH := Color("#b18a5d")
const EARTH_DARK := Color("#765842")
const WATER_DULL := Color("#356f79")
const WATER_LIVE := Color("#4caea7")
const NAVY := Color("#253d48")
const BONE := Color("#eee3c7")

var green_zone: Node3D
var camera: Camera3D
var effects: Node3D
var river_material: ShaderMaterial
var flow_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_lighting()
	_build_camera()
	_build_ground()
	_build_river_worksite()
	_build_edge_landmarks()
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
	camera.size = 25.0
	# A 55-degree starting angle exposes the cab, tool head and bank shapes.
	camera.position = Vector3(0, 25, 17)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0))

func _build_ground() -> void:
	# One quiet low-frequency plane keeps the action readable at a glance.
	box(self, Vector3(36, 1, 32), Vector3(0, -0.55, 0), OLIVE, true)
	for at in [Vector3(-18, 0.8, 0), Vector3(18, 0.8, 0), Vector3(0, 0.8, -16), Vector3(0, 0.8, 16)]:
		var size := Vector3(1, 2, 33) if absf(at.x) > 0 else Vector3(36, 2, 1)
		box(self, size, at, NAVY, true)
	# Wide route blocks replace the old debug grid. They are visual only.
	box(self, Vector3(5.8, 0.035, 30), Vector3(-1.4, 0.03, 0), Color("#74886c"))
	box(self, Vector3(14.0, 0.035, 3.2), Vector3(-2.0, 0.035, 6.5), EARTH)
	box(self, Vector3(13.0, 0.035, 2.2), Vector3(2.0, 0.04, -7.2), Color("#927052"))
	box(self, Vector3(0.15, 0.04, 2.7), Vector3(-8.0, 0.05, 5.3), BONE)
	box(self, Vector3(0.15, 0.04, 2.7), Vector3(-7.45, 0.05, 5.3), BONE)
	for z in [-11.0, -7.0, 7.0, 11.0]:
		box(self, Vector3(2.2, 0.05, 0.12), Vector3(-8.7, 0.08, z), Color("#9c7b55"))

func _build_river_worksite() -> void:
	# The dry channel is visible before repair; green_zone is the stateful overlay
	# toggled by main.gd after the pump is repaired.
	var dry := Node3D.new()
	dry.name = "DryRiverAndBanks"
	add_child(dry)
	box(dry, Vector3(5.0, 0.06, 18), Vector3(9, 0.06, -2), WATER_DULL)
	box(dry, Vector3(0.7, 0.08, 18), Vector3(6.35, 0.08, -2), EARTH_DARK)
	box(dry, Vector3(0.7, 0.08, 18), Vector3(11.65, 0.08, -2), EARTH_DARK)
	for z in [-10.0, -6.0, -2.0, 2.0, 6.0]:
		_create_rock(dry, Vector3(8.0 + fmod(z, 3.0) * 0.15, 0.18, z), 0.55, Color("#526f70"))
		_create_rock(dry, Vector3(10.7 - fmod(z, 2.0) * 0.12, 0.19, z + 1.1), 0.4, Color("#617876"))

	green_zone = Node3D.new()
	green_zone.name = "RepairedRiverAndGrowth"
	add_child(green_zone)
	for index in range(18):
		var x := 7.0 + fmod(float(index * 17), 5.4)
		var z := -12.5 + fmod(float(index * 7), 16.0)
		_create_reed_cluster(green_zone, Vector3(x, 0.08, z), index % 2 == 0)
	var flowing_water := box(green_zone, Vector3(4.7, 0.045, 17.8), Vector3(9, 0.13, -2), WATER_LIVE)
	river_material = ShaderMaterial.new()
	river_material.shader = RIVER
	flowing_water.material_override = river_material
	green_zone.hide()

func _build_edge_landmarks() -> void:
	var landmarks := Node3D.new()
	landmarks.name = "EdgeLandmarks"
	add_child(landmarks)
	# A crooked civic arch and two warning pennants establish foreground/background
	# without turning the route into a collision maze.
	_create_arch(landmarks, Vector3(-13.0, 0.0, -10.5))
	_create_pennant(landmarks, Vector3(13.2, 0.0, 10.5), Color("#df604e"))
	_create_pennant(landmarks, Vector3(-12.5, 0.0, 10.0), Color("#e9ad38"))
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

func _process(delta: float) -> void:
	flow_time += delta
	if river_material != null:
		river_material.set_shader_parameter("flow_time", flow_time)

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
