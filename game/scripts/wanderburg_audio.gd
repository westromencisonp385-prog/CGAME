class_name WanderburgAudio
extends Node

## C6：事件驱动音频节点。保持旧 play_feedback(message) API 兼容主干，
## 新增 play_event(event_name) 直接走 AudioEventTable；headless 下静默。
## 2026-10-11：事件优先用 Kenney CC0 采样（assets/audio/sfx/sfx_manifest.json，
## 由 tools/asset_pipeline/import_kenney_sfx.py 生成），每个事件多个变体随机轮换；
## 清单里没有的事件回落到原合成音 assets/generated/audio/<event>.wav。

const SFX_MANIFEST := "res://assets/audio/sfx/sfx_manifest.json"
const VOICE_COUNT := 16

static var instance: WanderburgAudio
var voices: Array[AudioStreamPlayer] = []
var tones: Dictionary = {}          # event -> Array[AudioStream]
var _last_variant: Dictionary = {}  # event -> 上次播放的变体下标
var baked_count := 0
var sample_count := 0
var last_play := 0

## 供玩法直接调用的打击音：带少量音高随机，避免机枪感
static func hit(event_name: String, volume_db := -9.0, pitch_jitter := 0.08) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	instance.play_event(event_name, volume_db, 1.0 + randf_range(-pitch_jitter, pitch_jitter))

static func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(SFX_MANIFEST):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(SFX_MANIFEST))
	return data.get("events", {}) if data is Dictionary else {}

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var samples := load_manifest()
	for event_name in AudioEventTable.EVENTS:
		var list: Array[AudioStream] = []
		for path in samples.get(event_name, []):
			if ResourceLoader.exists(str(path)):
				var s := load(str(path)) as AudioStream
				if s != null:
					list.append(s)
		if not list.is_empty():
			sample_count += list.size()
			tones[event_name] = list
			continue
		var wav_path := "res://assets/generated/audio/%s.wav" % event_name
		if ResourceLoader.exists(wav_path):
			var stream := load(wav_path) as AudioStreamWAV
			if stream != null:
				tones[event_name] = [stream]
				baked_count += 1
				continue
		tones[event_name] = [AudioEventTable.synth_stream(event_name)]
	for _index in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15.0
		add_child(voice)
		voices.append(voice)

## 随机挑一个变体，不与上一次相同
func _pick(event_name: String) -> AudioStream:
	var list: Array = tones[event_name]
	if list.size() == 1:
		return list[0]
	var i := randi() % list.size()
	if i == int(_last_variant.get(event_name, -1)):
		i = (i + 1) % list.size()
	_last_variant[event_name] = i
	return list[i]

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
	chosen.stream = _pick(event_name)
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
