extends Node3D
var green_zone: Node3D
var camera: Camera3D

func _ready() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_color = Color("#ffe4be")
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#152c37")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9dc7d1")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30
	camera.position = Vector3(0, 23, 23)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	box(self, Vector3(36, 1, 32), Vector3(0, -0.55, 0), Color("#637c69"), true)
	for at in [Vector3(-18, 0.8, 0), Vector3(18, 0.8, 0), Vector3(0, 0.8, -16), Vector3(0, 0.8, 16)]:
		var size := Vector3(1, 2, 33) if absf(at.x) > 0 else Vector3(36, 2, 1)
		box(self, size, at, Color("#425756"), true)
	for x in range(-16, 17, 4):
		box(self, Vector3(0.035, 0.02, 30), Vector3(x, 0.01, 0), Color("#829681"))
	for z in range(-14, 15, 4):
		box(self, Vector3(34, 0.02, 0.035), Vector3(0, 0.012, z), Color("#829681"))
	box(self, Vector3(5, 0.04, 18), Vector3(9, 0.03, -2), Color("#395d64"))
	box(self, Vector3(5.5, 0.12, 4), Vector3(9, 0.06, 6), Color("#9a9475"))
	green_zone = Node3D.new()
	add_child(green_zone)
	for index in range(28):
		var x := 4.0 + fmod(float(index * 17), 11.0)
		var z := -13.0 + fmod(float(index * 7), 16.0)
		var bush := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.45 + fmod(float(index), 3.0) * 0.12
		shape.height = shape.radius * 1.5
		shape.radial_segments = 6
		shape.rings = 3
		bush.mesh = shape
		bush.position = Vector3(x, 0.35, z)
		bush.material_override = material(Color("#9dc96d") if index % 2 == 0 else Color("#5caa7a"))
		green_zone.add_child(bush)
	box(green_zone, Vector3(4.8, 0.045, 18), Vector3(9, 0.05, -2), Color("#4fbcbe"))
	green_zone.hide()

func present_effect(kind: String, from: Vector3, to: Vector3) -> void:
	if get_child_count() > 180:
		return
	var line := MeshInstance3D.new()
	var length := from.distance_to(to)
	var shape := CylinderMesh.new()
	shape.top_radius = 0.07
	shape.bottom_radius = 0.07
	shape.height = maxf(length, 0.1)
	line.mesh = shape
	line.position = (from + to) * 0.5 + Vector3.UP * 0.4
	var color := Color("#ffd87c")
	if "arc" in kind or "electric" in kind:
		color = Color("#dfbaff")
	elif "water" in kind or "wet" in kind:
		color = Color("#71e8f0")
	line.material_override = material(color)
	add_child(line)
	if length > 0.01:
		line.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	var tween := create_tween()
	tween.tween_property(line, "scale", Vector3(0.01, 1, 0.01), 0.22)
	tween.tween_callback(line.queue_free)

func box(parent: Node3D, extent: Vector3, at: Vector3, color: Color, solid := false) -> void:
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

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	return mat
