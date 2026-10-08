class_name WanderburgAudio
extends Node

## C6：事件驱动音频节点。保持旧 play_feedback(message) API 兼容主干，
## 新增 play_event(event_name) 直接走 AudioEventTable；headless 下静默。

var voices: Array[AudioStreamPlayer] = []
var tones: Dictionary = {}
var baked_count := 0
var last_play := 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for event_name in AudioEventTable.EVENTS:
		var wav_path := "res://assets/generated/audio/%s.wav" % event_name
		if ResourceLoader.exists(wav_path):
			var stream := load(wav_path) as AudioStreamWAV
			if stream != null:
				tones[event_name] = stream
				baked_count += 1
				continue
		tones[event_name] = AudioEventTable.synth_stream(event_name)
	for _index in range(6):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15.0
		add_child(voice)
		voices.append(voice)

func play_event(event_name: String, volume_db := -12.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not tones.has(event_name):
		return
	for voice in voices:
		if not voice.playing:
			voice.stream = tones[event_name]
			voice.volume_db = volume_db
			voice.play()
			return

func play_feedback(message: String) -> void:
	if Time.get_ticks_msec() - last_play < 120:
		return
	last_play = Time.get_ticks_msec()
	var event_name := AudioEventTable.keyword_event(message)
	play_event(event_name if not event_name.is_empty() else "work_loop", -15.0)

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	tones.clear()
