extends SceneTree
## C8 资产完整性测试：烘焙产物必须在盘、可加载、且运行时确实走资产而非兜底。

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	_test_scene_assets()
	_test_audio_assets()
	_test_runtime_prefers_assets()
	if failures.is_empty():
		print("PASS asset_bake_flow: all checks")
	else:
		print("FAIL asset_bake_flow: %d checks" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _test_scene_assets() -> void:
	var props := ["summon_turret.tscn", "summon_camp.tscn", "summon_emp.tscn", "biome_gate_desert.tscn", "biome_gate_swamp.tscn", "biome_key_desert.tscn", "biome_key_swamp.tscn", "boss_crown.tscn"]
	for file_name in props:
		check(FileAccess.file_exists("res://assets/generated/props/" + file_name), "烘焙场景应在盘: " + file_name)

func _test_audio_assets() -> void:
	for event_name in AudioEventTable.EVENTS:
		check(FileAccess.file_exists("res://assets/generated/audio/%s.wav" % event_name), "烘焙音频应在盘: " + event_name)
	var wav := load("res://assets/generated/audio/boss_spawn.wav") as AudioStreamWAV
	check(wav != null, "boss_spawn.wav 应可加载为 AudioStreamWAV")

func _test_runtime_prefers_assets() -> void:
	var turret := ProceduralVisuals.load_visual("summon_turret.tscn", func(): return Node3D.new())
	var has_base := false
	for child in turret.get_children():
		if child.name == "SummonBase":
			has_base = true
	check(has_base, "炮塔实例应含 SummonBase（证明走资产而非兜底）")
	check(turret.get_child_count() >= 3, "炮塔资产应含 base/barrel/label 三件")
	turret.free()
	var gate := ProceduralVisuals.load_visual("biome_gate_desert.tscn", func(): return Node3D.new())
	var has_frame := false
	for child in gate.get_children():
		if child.name == "GateFrame":
			has_frame = true
	check(has_frame, "门实例应含 GateFrame（证明走资产而非兜底）")
	gate.free()
