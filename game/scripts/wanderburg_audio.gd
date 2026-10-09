class_name WanderburgAudio
extends Node

## C6：事件驱动音频节点。保持旧 play_feedback(message) API 兼容主干，
## 新增 play_event(event_name) 直接走 AudioEventTable；headless 下静默。

static var instance: WanderburgAudio
var voices: Array[AudioStreamPlayer] = []
var tones: Dictionary = {}
var baked_count := 0
var last_play := 0

## 供玩法直接调用的打击音：带少量音高随机，避免机枪感
static func hit(event_name: String, volume_db := -9.0, pitch_jitter := 0.08) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	instance.play_event(event_name, volume_db, 1.0 + randf_range(-pitch_jitter, pitch_jitter))

func _enter_tree() -> void:
	instance = self

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
	for _index in range(10):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15.0
		add_child(voice)
		voices.append(voice)

func play_event(event_name: String, volume_db := -12.0, pitch := 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not tones.has(event_name):
		return
	var chosen: AudioStreamPlayer = null
	for voice in voices:
		if not voice.playing:
			chosen = voice
			break
	if chosen == null and not voices.is_empty():
		chosen = voices[0]
		voices.push_back(voices.pop_front())
	if chosen == null:
		return
	chosen.stream = tones[event_name]
	chosen.volume_db = volume_db
	chosen.pitch_scale = pitch
	chosen.play()

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
