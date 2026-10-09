class_name Tuning3C
extends RefCounted

## 3C 参数加载器：读 res://config/3c_tuning.json，缺字段回落到 DEFAULTS（与 json 同值）。
## Tuning3C.get_f("drive", "grip")；Tuning3C.reload() 热重载（F10）。

const PATH := "res://config/3c_tuning.json"
const DEFAULTS := {
	"camera": {"pitch_deg": 45.0, "distance": 60.0, "base_size": 19.0, "tier_scale": [1.0, 1.154, 1.436, 1.846],
		"tier_zoom_time": 0.9, "follow_k": 3.0, "lead_mult": 0.55, "lead_k": 2.0, "lead_max": 4.5,
		"arena_half": [18.0, 16.0], "edge_margin": 4.0, "boss_scale": 1.18, "boss_smooth_time": 1.0,
		"zoom_punch_per_fov": 0.01, "boss_intro": true, "boss_intro_move": 0.6, "boss_intro_hold": 1.25,
		"boss_intro_return": 0.75, "boss_intro_zoom": 0.7, "boss_intro_wobble": 0.35, "boss_intro_wobble_strength": 0.4},
	"drive": {"accel_time": 0.3, "brake_time": 0.22, "turn_rate_still": 420.0, "turn_rate_full": 280.0,
		"forward_share_min": 0.75, "uturn_angle": 135.0, "uturn_turn_mult": 1.6, "uturn_speed_share": 0.35,
		"grip": 14.0, "stick_deadzone": 0.18, "wall_bounce": 0.35, "wall_bounce_min_speed": 3.0},
	"character": {"pitch_max_deg": 8.0, "pitch_per_accel": 0.28, "roll_max_deg": 5.0, "roll_per_yawrate": 0.006,
		"lean_k": 10.0, "bite_head_turn_max_deg": 55.0, "bite_lunge": 0.35, "bite_spring_k": 18.0},
	"dash": {"power": 12.0, "power_flywheel": 18.0},
	"aim": {"reticle": true, "reticle_radius": 0.55},
}

static var _data: Dictionary = {}
static var version := 0

static func data() -> Dictionary:
	if _data.is_empty():
		reload()
	return _data

static func reload() -> bool:
	var merged := DEFAULTS.duplicate(true)
	var ok := false
	var path := PATH
	# 打包版：exe 同目录放一份 3c_tuning.json 即可覆盖包内参数（F10 热重载）
	if not OS.has_feature("editor"):
		var external := OS.get_executable_path().get_base_dir().path_join("3c_tuning.json")
		if FileAccess.file_exists(external):
			path = external
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			ok = true
			for section in parsed:
				if merged.has(section) and parsed[section] is Dictionary:
					for k in parsed[section]:
						merged[section][k] = parsed[section][k]
	_data = merged
	version += 1
	return ok

static func get_f(section: String, key: String) -> float:
	return float(data().get(section, {}).get(key, 0.0))

static func get_v(section: String, key: String) -> Variant:
	return data().get(section, {}).get(key)
