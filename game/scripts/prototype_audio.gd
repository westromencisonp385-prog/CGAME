extends Node
## Original procedural placeholder audio with bounded concurrent voices.
var voices: Array[AudioStreamPlayer] = []
var tones: Dictionary = {}
var last_play := 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	tones["work"] = _tone(150.0, 0.09, true)
	tones["change"] = _tone(480.0, 0.19, false)
	tones["repair"] = _tone(660.0, 0.5, false)
	for _index in range(4):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15.0
		add_child(voice)
		voices.append(voice)

func play_feedback(message: String) -> void:
	if Time.get_ticks_msec() - last_play < 120:
		return
	last_play = Time.get_ticks_msec()
	var kind := "work"
	if "修复" in message or "启动" in message or "进化" in message:
		kind = "repair"
	elif "安装" in message or "保存" in message or "恢复" in message:
		kind = "change"
	for voice in voices:
		if not voice.playing:
			voice.stream = tones.get(kind)
			voice.play()
			return

func _tone(frequency: float, duration: float, mechanical: bool) -> AudioStreamWAV:
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = 22050
	var length := int(duration * result.mix_rate)
	var data := PackedByteArray()
	data.resize(length * 2)
	for index in range(length):
		var time := float(index) / result.mix_rate
		var envelope := pow(1.0 - float(index) / length, 2.0)
		var wave := sin(TAU * frequency * time) * 0.6 + sin(TAU * frequency * 1.5 * time) * 0.25
		if mechanical:
			wave += sin(TAU * 1357.0 * time) * sin(TAU * 657.0 * time) * 0.3
		data.encode_s16(index * 2, int(clampf(wave * envelope, -1.0, 1.0) * 16000))
	result.data = data
	return result

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	tones.clear()
