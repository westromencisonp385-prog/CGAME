class_name BiomeWeather
extends Node3D

## C7 群系环境视效（对齐 SandstormSpawner 语义重写）：纯粒子层。
## desert → 飘沙盘；swamp → 上升气泡；river → 无附加粒子。
## 环境雾/背景色调色由 arena_visual.apply_biome 负责（单一 WorldEnvironment 归属）。

var biome_id := "river"
var weather_root: Node3D

func _ready() -> void:
	_rebuild_particles()

func apply_biome(new_id: String) -> void:
	if not ["river", "desert", "swamp"].has(new_id):
		return
	biome_id = new_id
	_rebuild_particles()

func _rebuild_particles() -> void:
	if weather_root != null:
		weather_root.queue_free()
	weather_root = Node3D.new()
	weather_root.name = "WeatherParticles"
	add_child(weather_root)
	match biome_id:
		"desert":
			_build_sandstorm()
		"swamp":
			_build_bubbles()

func _build_sandstorm() -> void:
	for lane in range(3):
		var drift := MeshInstance3D.new()
		var drift_mesh := BoxMesh.new()
		drift_mesh.size = Vector3(34.0, 0.09, 1.4 + float(lane))
		drift.mesh = drift_mesh
		drift.position = Vector3(0, 0.5 + float(lane) * 0.9, -6.0 + float(lane) * 6.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(Color("#e0b36a"), 0.14 + float(lane) * 0.04)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drift.material_override = mat
		weather_root.add_child(drift)
		var tween := create_tween()
		tween.set_loops()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(drift, "position:x", 17.0, 2.6 + float(lane) * 0.7).from(-17.0)
		tween.tween_callback(func(): drift.position.x = -17.0)

func _build_bubbles() -> void:
	for index in range(12):
		var bubble := MeshInstance3D.new()
		var bubble_mesh := SphereMesh.new()
		bubble_mesh.radius = 0.08 + fmod(float(index) * 0.37, 0.14)
		bubble_mesh.height = bubble_mesh.radius * 2.0
		bubble_mesh.radial_segments = 8
		bubble_mesh.rings = 4
		bubble.mesh = bubble_mesh
		var start_x := -14.0 + fmod(float(index * 31), 28.0)
		var start_z := -13.0 + fmod(float(index * 17), 26.0)
		bubble.position = Vector3(start_x, 0.2, start_z)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(Color("#9fd6a8"), 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bubble.material_override = mat
		weather_root.add_child(bubble)
		var rise := create_tween()
		rise.set_loops()
		rise.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		rise.tween_property(bubble, "position:y", 1.6, 1.8 + fmod(float(index) * 0.23, 1.4)).from(0.1)
		rise.tween_callback(func(): bubble.position.y = 0.1)
