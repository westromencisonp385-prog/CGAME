class_name ModuleVisual
extends Node3D

const WHALE_MODEL := preload("res://assets/models/reclaimer_whale_jaw.glb")

var moving_jaws: Array[Node3D] = []
var wheel: Node3D
var elapsed := 0.0
var imported_whale := false

func _process(delta: float) -> void:
	elapsed += delta
	for jaw in moving_jaws:
		jaw.rotation.x = lerpf(-0.8, -0.18, minf(elapsed / 0.45, 1.0))
	if wheel != null:
		wheel.rotation.z += delta * 2.0

static func create(definition: ModuleDefinition, stage: int, ghost: bool = false) -> ModuleVisual:
	var visual := ModuleVisual.new()
	visual.name = ("Ghost_" if ghost else "Installed_") + definition.id
	visual._build(definition, stage, ghost)
	return visual

func _build(definition: ModuleDefinition, stage: int, ghost: bool) -> void:
	var tint := definition.color
	if ghost:
		tint.a = 0.42
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.35
	material.roughness = 0.58
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if ghost else BaseMaterial3D.TRANSPARENCY_DISABLED
	if ghost:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dark := material.duplicate() as StandardMaterial3D
	dark.albedo_color = Color(0.10, 0.16, 0.18, tint.a)
	var highlight := material.duplicate() as StandardMaterial3D
	highlight.albedo_color = Color(0.93, 0.84, 0.56, tint.a)

	match definition.id:
		"basic_bucket":
			if ghost:
				_add_box("Bucket", Vector3(1.7, 0.55, 1.2), Vector3(0, 0.12, -1.55), material)
				_add_box("BucketInside", Vector3(1.38, 0.11, 0.7), Vector3(0, 0.18, -1.75), dark)
				_add_box("Lip", Vector3(1.9, 0.12, 0.18), Vector3(0, -0.12, -2.08), highlight)
				for index in range(3):
					_add_box("BucketTooth%d" % index, Vector3(0.18, 0.18, 0.35), Vector3((index - 1) * 0.62, -0.18, -2.24), highlight)
		"wide_bucket":
			var width := 2.4 if stage >= 2 else 2.05
			if ghost or stage < 2:
				_add_box("WideBucketPreview" if ghost else "WideBucketSideFins", Vector3(width, 0.38, 0.62), Vector3(0, 0.16, -1.75), material)
				_add_box("WideLip", Vector3(width * 1.05, 0.12, 0.16), Vector3(0, -0.08, -2.26), highlight)
			if stage >= 2:
				if not ghost and _attach_whale_model():
					return
				# G1 whale mouth: keep a dark negative space between two jaws.
				# The mouth is presentation-only; the core hit shape remains unchanged.
				_add_box("MouthCavity", Vector3(2.35, 0.16, 1.05), Vector3(0, 0.5, -2.02), dark)
				var upper := _add_box("WhaleUpperJaw", Vector3(2.8, 0.28, 0.54), Vector3(0, 1.0, -2.0), highlight)
				upper.rotation_degrees.x = -14.0
				var lower := _add_box("WhaleLowerJaw", Vector3(2.55, 0.2, 0.44), Vector3(0, 0.15, -2.05), material)
				lower.rotation_degrees.x = 9.0
				_add_box("UpperDarkGum", Vector3(2.15, 0.13, 0.24), Vector3(0, 0.77, -2.18), dark)
				for index in range(3):
					var jaw := _add_box("JawPetal%d" % index, Vector3(0.18, 0.32, 0.9), Vector3((float(index) - 1.0) * 0.94, 0.38, -2.58), material)
					jaw.rotation_degrees.y = (float(index) - 1.0) * 12.0
				moving_jaws.append(upper)
				for index in range(5):
					_add_box("UpperTooth%d" % index, Vector3(0.16, 0.34, 0.26), Vector3((index - 2) * 0.46, 0.62, -2.36), highlight)
				for side in [-1.0, 1.0]:
					var strut := _add_box("JawLink", Vector3(0.22, 0.9, 0.3), Vector3(side * 1.32, 0.62, -1.55), dark)
					strut.rotation_degrees.z = side * 22.0
		"water_cannon":
			_add_cylinder("WaterTank", 0.48, 0.7, Vector3(0.0, 0.85, 0.18), material)
			_add_cylinder("WaterTankCap", 0.28, 0.08, Vector3(0.0, 1.23, 0.18), highlight)
			_add_cylinder("WaterBarrel", 0.16, 1.15, Vector3(0.0, 1.0, -0.65), dark, Vector3(90, 0, 0))
			_add_cylinder("WaterNozzle", 0.23, 0.22, Vector3(0.0, 1.0, -1.23), highlight, Vector3(90, 0, 0))
		"electric_arc":
			_add_torus("ArcCoil", 0.62, 0.12, Vector3(0, 0.95, 0.0), material)
			_add_torus("ArcInsulator", 0.43, 0.08, Vector3(0, 0.95, 0.0), dark)
			for index in range(3):
				_add_box("ArcRod%d" % index, Vector3(0.12, 0.7, 0.12), Vector3((float(index) - 1.0) * 0.42, 1.05, -0.18), highlight)
		"magnet":
			_add_torus("MagnetRing", 0.75, 0.18, Vector3(0, 0.62, 0), material, Vector3(90, 0, 0))
			_add_torus("MagnetInnerRing", 0.42, 0.08, Vector3(0, 0.62, 0), highlight, Vector3(90, 0, 0))
			_add_box("MagnetCore", Vector3(0.8, 0.22, 0.25), Vector3(0, 0.62, 0), dark)
		"inertia_flywheel":
			wheel = _add_cylinder("Flywheel", 0.72, 0.3, Vector3(0, 0.65, 0.2), material, Vector3(90, 0, 0))
			_add_cylinder("FlywheelHub", 0.22, 0.34, Vector3(0, 0.65, 0.2), highlight, Vector3(90, 0, 0))
			_add_box("FlywheelGuard", Vector3(1.7, 0.14, 0.18), Vector3(0, 1.12, 0.2), dark)

func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	add_child(instance)
	return instance

func _add_cylinder(node_name: String, radius: float, height: float, at: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = rotation
	instance.material_override = material
	add_child(instance)
	return instance

func _add_torus(node_name: String, inner_radius: float, outer_radius: float, at: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = inner_radius + outer_radius
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = rotation
	instance.material_override = material
	add_child(instance)
	return instance

func _attach_whale_model() -> bool:
	var model := WHALE_MODEL.instantiate()
	if model == null:
		return false
	model.name = "WhaleJawGLB_P05"
	# The Blender contract uses +Y as forward and +Z as up; gameplay points
	# down -Z with +Y as up, so rotate the authored asset around X.
	model.rotation_degrees.x = -90.0
	add_child(model)
	imported_whale = true

	# The GLB is a complete inspection asset. Keep only the detachable jaw
	# module here because the live vehicle chassis remains authoritative.
	var base := model.get_node_or_null("Reclaimer_BaseVehicle_P04")
	if base != null:
		base.visible = false
	var jaw_root := model.get_node_or_null("Reclaimer_WhaleJawModule_P05")
	if jaw_root == null:
		return true
	var upper := jaw_root.get_node_or_null("Jaw_Upper_Stage02")
	if upper != null:
		moving_jaws.append(upper)
		upper.rotation.x = -0.22
	var lower := jaw_root.get_node_or_null("Jaw_Lower_Stage02")
	if lower != null:
		lower.rotation.x = 0.08
	return true
