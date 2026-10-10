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
	# 打击类：低频下扫 thump + 噪声爆点（noise = 噪声占比，drop = 频率下扫比例，负值为上扫）
	"bite": {"freq": 120.0, "dur": 0.14, "mechanical": true, "noise": 0.75, "drop": 0.55},
	"bite_hit": {"freq": 78.0, "dur": 0.24, "mechanical": true, "noise": 1.0, "drop": 0.6},
	"bite_heavy": {"freq": 58.0, "dur": 0.36, "mechanical": true, "noise": 1.0, "drop": 0.65},
	"throw_launch": {"freq": 210.0, "dur": 0.2, "mechanical": false, "noise": 0.55, "drop": -0.7},
	"throw_hit": {"freq": 62.0, "dur": 0.34, "mechanical": true, "noise": 0.95, "drop": 0.5},
	"deny": {"freq": 150.0, "dur": 0.1, "mechanical": true},
	# C24 升级：上扫（drop 为负）
	"xp_tick": {"freq": 900.0, "dur": 0.07, "mechanical": false, "noise": 0.05, "drop": -0.6},
	"card_pick": {"freq": 260.0, "dur": 0.22, "mechanical": false, "noise": 0.55, "drop": -0.6},
	"power_up": {"freq": 360.0, "dur": 0.45, "mechanical": false, "noise": 0.15, "drop": -1.0},
	"level_up": {"freq": 120.0, "dur": 0.7, "mechanical": false, "noise": 0.6, "drop": -2.5},
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
	var noise_amt := float(spec.get("noise", 0.0))
	var drop := float(spec.get("drop", 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(event_name)
	var phase := 0.0
	var lp := 0.0
	for index in range(length):
		var time := float(index) / result.mix_rate
		var envelope := pow(1.0 - float(index) / length, 2.0)
		var wave: float
		if noise_amt > 0.0:
			# 打击：频率随时间下扫的 thump（相位累加避免爆音）+ 快衰减的低通噪声
			var f := frequency * (1.0 - drop * time / duration)
			phase += TAU * maxf(f, 20.0) / result.mix_rate
			lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35)
			var punch := exp(-time * 38.0)
			wave = sin(phase) * 0.85 * pow(1.0 - float(index) / length, 1.2) + lp * noise_amt * (punch * 1.4 + envelope * 0.25)
			envelope = 1.0
		else:
			wave = sin(TAU * frequency * time) * 0.6 + sin(TAU * frequency * 1.5 * time) * 0.25
			if mechanical:
				wave += sin(TAU * 1357.0 * time) * sin(TAU * 657.0 * time) * 0.3
		data.encode_s16(index * 2, int(clampf(wave * envelope, -1.0, 1.0) * 16000))
	result.data = data
	return result
