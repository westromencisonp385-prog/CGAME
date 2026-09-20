class_name ModuleVisual
extends Node3D

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
	material.roughness = 0.4
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if ghost else BaseMaterial3D.TRANSPARENCY_DISABLED
	if ghost:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	match definition.id:
		"basic_bucket":
			_add_box("Bucket", Vector3(1.7, 0.55, 1.2), Vector3(0, 0.12, -1.55), material)
			_add_box("Lip", Vector3(1.9, 0.12, 0.18), Vector3(0, -0.12, -2.08), material)
		"wide_bucket":
			var width := 2.4 if stage >= 2 else 2.05
			_add_box("WideBucket", Vector3(width, 0.6, 1.45), Vector3(0, 0.14, -1.58), material)
			_add_box("WideLip", Vector3(width * 1.1, 0.14, 0.2), Vector3(0, -0.14, -2.3), material)
			if stage >= 2:
				for index in range(3):
					var jaw := _add_box("JawPetal%d" % index, Vector3(0.16, 0.34, 0.9), Vector3((float(index) - 1.0) * 0.92, 0.18, -2.62), material)
					jaw.rotation_degrees.y = (float(index) - 1.0) * 14.0
		"water_cannon":
			_add_cylinder("WaterTank", 0.48, 0.7, Vector3(0.0, 0.85, 0.18), material)
			_add_cylinder("WaterBarrel", 0.16, 1.15, Vector3(0.0, 1.0, -0.65), material, Vector3(90, 0, 0))
		"electric_arc":
			_add_torus("ArcCoil", 0.62, 0.12, Vector3(0, 0.95, 0.0), material)
			for index in range(3):
				_add_box("ArcRod%d" % index, Vector3(0.12, 0.7, 0.12), Vector3((float(index) - 1.0) * 0.42, 1.05, -0.18), material)
		"magnet":
			_add_torus("MagnetRing", 0.75, 0.18, Vector3(0, 0.62, 0), material, Vector3(90, 0, 0))
			_add_box("MagnetCore", Vector3(0.8, 0.22, 0.25), Vector3(0, 0.62, 0), material)
		"inertia_flywheel":
			_add_cylinder("Flywheel", 0.72, 0.3, Vector3(0, 0.65, 0.2), material, Vector3(90, 0, 0))
			_add_box("FlywheelGuard", Vector3(1.7, 0.14, 0.18), Vector3(0, 1.12, 0.2), material)

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
