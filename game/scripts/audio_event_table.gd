class_name AudioEventTable
extends RefCounted

## C6：语义音频事件表。语义名对齐 Wanderburg FMOD 事件树（69 条）的玩法子集；
## 当前为程序化合成底座（GAP：实机音频资产落地后按事件名替换真实采样）。

const EVENTS := {
	"work_loop": {"freq": 150.0, "dur": 0.09, "mechanical": true},
	"change": {"freq": 480.0, "dur": 0.19, "mechanical": false},
	"ui_open": {"freq": 320.0, "dur": 0.14, "mechanical": false},
	"ui_pick": {"freq": 520.0, "dur": 0.18, "mechanical": false},
	"reroll": {"freq": 240.0, "dur": 0.22, "mechanical": true},
	"module_install": {"freq": 440.0, "dur": 0.3, "mechanical": true},
	"quest_complete": {"freq": 660.0, "dur": 0.4, "mechanical": false},
	"silver_gain": {"freq": 880.0, "dur": 0.16, "mechanical": false},
	"ability_cast": {"freq": 380.0, "dur": 0.25, "mechanical": true},
	"absorb": {"freq": 180.0, "dur": 0.3, "mechanical": true},
	"tier_up": {"freq": 300.0, "dur": 0.5, "mechanical": false},
	"boss_spawn": {"freq": 90.0, "dur": 0.8, "mechanical": true},
	"boss_phase": {"freq": 130.0, "dur": 0.55, "mechanical": true},
	"boss_defeat": {"freq": 220.0, "dur": 0.9, "mechanical": false},
	"repair": {"freq": 660.0, "dur": 0.5, "mechanical": false},
	"pack": {"freq": 200.0, "dur": 0.28, "mechanical": true},
	"throw": {"freq": 420.0, "dur": 0.2, "mechanical": true},
	"victory": {"freq": 740.0, "dur": 0.7, "mechanical": false},
	"defeat": {"freq": 140.0, "dur": 0.7, "mechanical": false},
}

static func has_event(event_name: String) -> bool:
	return EVENTS.has(event_name)

static func get_event(event_name: String) -> Dictionary:
	return (EVENTS.get(event_name, {}) as Dictionary).duplicate()

static func keyword_event(message: String) -> String:
	if message.contains("任务达成"):
		return "quest_complete"
	if message.contains("吞噬"):
		return "absorb"
	if message.contains("进化"):
		return "tier_up"
	if message.contains("现身"):
		return "boss_spawn"
	if message.contains("阶段"):
		return "boss_phase"
	if message.contains("赏金") or message.contains("银币"):
		return "silver_gain"
	if message.contains("修复") or message.contains("启动"):
		return "repair"
	if message.contains("打包"):
		return "pack"
	if message.contains("投送"):
		return "throw"
	if message.contains("复苏") or message.contains("胜利"):
		return "victory"
	if message.contains("失败"):
		return "defeat"
	if message.contains("模块"):
		return "module_install"
	if message.contains("保存") or message.contains("恢复") or message.contains("检查点"):
		return "change"
	return ""

## 音色合成（静态共享）：烘焙器写 WAV、运行时兜底都用这一个实现
static func synth_stream(event_name: String) -> AudioStreamWAV:
	var spec := get_event(event_name)
	if spec.is_empty():
		return null
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = 22050
	var duration := float(spec["dur"])
	var mechanical := bool(spec["mechanical"])
	var frequency := float(spec["freq"])
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
