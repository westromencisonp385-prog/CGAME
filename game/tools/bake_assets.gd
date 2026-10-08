extends SceneTree

## C8 资产烘焙器：把 ProceduralVisuals 的共享几何打包为 props/*.tscn，
## 把 AudioEventTable.synth_stream 的音色写为 audio/*.wav。
## 用法：godot --headless --path game --script res://tools/bake_assets.gd
## 幂等：重复运行覆盖旧文件。烘焙后建议再跑一次 --import 让 WAV 进入导入管线。

const PROPS_DIR := "res://assets/generated/props"
const AUDIO_DIR := "res://assets/generated/audio"
const VisualsLib = preload("res://scripts/systems/procedural_visuals.gd")
const AudioTable = preload("res://scripts/audio_event_table.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROPS_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUDIO_DIR))
	var scenes := 0
	scenes += _bake_scene("summon_turret.tscn", func(): return ProceduralVisuals.build_summon(Color("#f2c85c"), false, "自动炮塔"))
	scenes += _bake_scene("summon_emp.tscn", func(): return ProceduralVisuals.build_summon(Color("#9dc7d1"), true, "EMP 脉冲"))
	scenes += _bake_scene("summon_camp.tscn", func(): return ProceduralVisuals.build_summon(Color("#78d6a8"), false, "临时营地"))
	scenes += _bake_scene("biome_gate_desert.tscn", func(): return ProceduralVisuals.build_gate(Color("#d9a441"), "荒漠之门"))
	scenes += _bake_scene("biome_gate_swamp.tscn", func(): return ProceduralVisuals.build_gate(Color("#7a9d54"), "沼泽之门"))
	scenes += _bake_scene("biome_key_desert.tscn", func(): return ProceduralVisuals.build_key(Color("#f2c85c")))
	scenes += _bake_scene("biome_key_swamp.tscn", func(): return ProceduralVisuals.build_key(Color("#8fb573")))
	scenes += _bake_scene("boss_crown.tscn", func(): return ProceduralVisuals.build_crown())
	var audio := 0
	for event_name in AudioEventTable.EVENTS:
		if _write_wav("%s/%s.wav" % [AUDIO_DIR, event_name], AudioEventTable.synth_stream(event_name)):
			audio += 1
	print("BAKE PASS: %d scenes, %d wav" % [scenes, audio])
	quit(0 if scenes == 8 and audio == AudioEventTable.EVENTS.size() else 1)

func _bake_scene(file_name: String, builder: Callable) -> int:
	var node: Node3D = builder.call()
	node.name = file_name.get_basename()
	var packed: PackedScene = ProceduralVisuals.pack_to_scene(node)
	var err := ResourceSaver.save(packed, "%s/%s" % [PROPS_DIR, file_name])
	if err != OK:
		push_error("烘焙失败: %s (err %d)" % [file_name, err])
		return 0
	return 1

func _write_wav(path: String, stream: AudioStreamWAV) -> bool:
	if stream == null:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("WAV 写入失败: " + path)
		return false
	var data := stream.data
	file.store_32(0x46464952)
	file.store_32(36 + data.size())
	file.store_32(0x45564157)
	file.store_32(0x20746D66)
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(stream.mix_rate)
	file.store_32(stream.mix_rate * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_32(0x61746164)
	file.store_32(data.size())
	file.store_buffer(data)
	file.close()
	return true
