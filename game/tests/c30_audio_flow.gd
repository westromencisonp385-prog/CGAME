extends SceneTree

## C30 音效验收：Kenney CC0 采样接入
## 1. 清单覆盖代码里实际用到的全部事件，每个文件都能载入，时长合理
## 2. 真窗口下播放器全部事件都走采样（不是合成音兜底），变体轮换不连续重复
## 3. 许可证文件在
var failures: Array[String] = []

const USED := ["bite", "bite_hit", "bite_heavy", "throw_launch", "throw_hit", "deny", "auto_shot", "auto_boom", "auto_zap",
	"ability_cast", "boss_spawn", "boss_phase", "boss_defeat", "quest_complete", "change", "silver_gain", "xp_tick",
	"power_up", "tier_up", "level_up", "card_pick", "work_loop", "absorb", "repair", "pack", "throw", "victory", "defeat", "module_install"]

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)

func _run() -> void:
	var m := WanderburgAudio.load_manifest()
	check(not m.is_empty(), "音效清单存在（%s）" % WanderburgAudio.SFX_MANIFEST)
	var missing := []
	for e in USED:
		if not m.has(e) or (m[e] as Array).is_empty():
			missing.append(e)
	check(missing.is_empty(), "代码用到的 %d 个事件都有采样（缺 %s）" % [USED.size(), ", ".join(missing)])
	var bad := []
	var too_long := []
	var total := 0
	for e in m:
		for path in m[e]:
			total += 1
			var s := load(str(path)) as AudioStream
			if s == null:
				bad.append(path)
				continue
			var limit := 2.1 if ["victory", "boss_spawn", "defeat"].has(e) else 1.3
			if s.get_length() > limit or s.get_length() < 0.005:
				too_long.append("%s %.2fs" % [path.get_file(), s.get_length()])
	check(bad.is_empty(), "全部 %d 个采样能载入（坏 %s）" % [total, ", ".join(bad)])
	check(too_long.is_empty(), "采样时长合理（%s）" % ", ".join(too_long))
	var freq_ok := true
	for e in ["auto_shot", "bite_hit", "xp_tick"]:
		for path in m.get(e, []):
			var s2 := load(str(path)) as AudioStream
			if s2 != null and s2.get_length() > 0.4:
				freq_ok = false
	check(freq_ok, "高频事件（自动攻击 / 咬中 / 能量）的采样都 ≤ 0.4 秒，不会糊成一片")
	check(FileAccess.file_exists("res://assets/audio/sfx/LICENSE_Kenney.txt"), "CC0 许可证随素材入库")

	if DisplayServer.get_name() != "headless":
		var audio := WanderburgAudio.new()
		root.add_child(audio)
		await process_frame
		var synth_fallback := []
		for e in USED:
			var list: Array = audio.tones.get(e, [])
			if list.is_empty() or list[0] is AudioStreamWAV:
				synth_fallback.append(e)
		check(synth_fallback.is_empty(), "运行时全部事件走 Kenney 采样（仍是合成音：%s）" % ", ".join(synth_fallback))
		check(audio.sample_count == total, "载入采样数 %d = 清单 %d" % [audio.sample_count, total])
		var repeats := 0
		var prev: AudioStream = null
		for i in 40:
			var s3 := audio._pick("bite_hit")
			if s3 == prev:
				repeats += 1
			prev = s3
		check(repeats == 0, "同一事件连续播放不会重复同一变体（重复 %d 次）" % repeats)
		for e in USED:
			audio.play_event(e, -40.0)
		await process_frame
		var playing := 0
		for v in audio.voices:
			if v.playing:
				playing += 1
		check(playing >= 10, "一帧内大量触发也能同时发声（%d 个声部在响）" % playing)
		audio.queue_free()
	print("C30 AUDIO %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
