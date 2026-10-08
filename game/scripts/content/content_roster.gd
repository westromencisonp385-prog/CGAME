class_name ContentRoster
extends RefCounted

## C9 内容目录（对齐逆向花名册：神器 >=30 含 rare 双池、Boss 10、船长 15）。
## 纯逻辑目录：StaticXxx.new() 直接定义，无场景依赖，headless 可测。
## 数值全部标注 [roster]：可调占位，精确数值在原生码（GAP）。

# ---------- 神器（>=30，含 rare 池）----------

static func create_artifacts() -> Array:
	var list: Array = []
	var defs := [
		["art_magnet_core", "磁吸核心", "银币磁吸范围 +35%", false, 1.0, {"magnet": 0.35}],
		["art_gear_oil", "齿轮油", "作业伤害 +15%", false, 1.0, {"damage": 0.15}],
		["art_plated_frame", "加固车架", "受击伤害 -12%", false, 1.0, {"armor": 0.12}],
		["art_lucky_charm", "幸运符", "幸运 +2", false, 1.0, {"luck": 2.0}],
		["art_wide_funnel", "宽口漏斗", "收集半径 +20%", false, 1.0, {"collect_radius": 0.2}],
		["art_spare_bolt", "备用螺栓", "最大耐久 +25", false, 1.0, {"max_hp": 25.0}],
		["art_tuned_engine", "调校引擎", "移动速度 +10%", false, 1.0, {"speed": 0.10}],
		["art_double_cup", "双倍杯", "银币掉落 +20%", false, 1.2, {"silver_gain": 0.2}],
		["art_rust_plate", "防锈板", "受击伤害 -8%，最大耐久 +10", false, 1.0, {"armor": 0.08, "max_hp": 10.0}],
		["art_gyro_stab", "陀螺稳定器", "投送距离 +25%", false, 1.0, {"throw_range": 0.25}],
		["art_heat_sink", "散热片", "技能冷却 -15%", false, 1.2, {"cooldown": 0.15}],
		["art_gold_needle", "金针", "银币掉落 +10%，幸运 +1", false, 1.1, {"silver_gain": 0.10, "luck": 1.0}],
		["art_scrap_compass", "废料罗盘", "任务奖励银币 +25%", false, 1.0, {"quest_reward": 0.25}],
		["art_heavy_winch", "重型绞盘", "作业伤害 +10%，移动速度 -5%", false, 1.0, {"damage": 0.10, "speed": -0.05}],
		["art_repair_drone", "维修蜂", "每秒回复 1 耐久", false, 1.5, {"regen": 1.0}],
		["art_prism_lens", "棱镜透镜", "技能伤害 +20%", false, 1.2, {"ability_damage": 0.20}],
		["art_echo_sonar", "回声声呐", "收集半径 +15%，磁吸 +15%", false, 1.2, {"collect_radius": 0.15, "magnet": 0.15}],
		["art_cargo_net", "货网", "载货上限 +3", false, 1.0, {"cargo_cap": 3.0}],
		["art_bell_buoy", "钟浮标", "受击伤害 -15%", false, 1.3, {"armor": 0.15}],
		["art_sail_wind", "顺风帆", "移动速度 +18%", false, 1.3, {"speed": 0.18}],
		["art_dynamo", "发电机", "技能冷却 -25%", false, 1.5, {"cooldown": 0.25}],
		["art_whale_tooth", "鲸牙", "作业伤害 +25%", false, 1.5, {"damage": 0.25}],
		["art_pact_ink", "契约墨水", "任务奖励 +40%", false, 1.5, {"quest_reward": 0.40}],
		["art_gilded_hook", "镀金钩", "银币掉落 +35%", false, 1.6, {"silver_gain": 0.35}],
		["art_iron_hull", "铁壳", "受击伤害 -25%，最大耐久 +40", false, 1.8, {"armor": 0.25, "max_hp": 40.0}],
		["art_storm_vane", "风暴风向标", "幸运 +4，技能伤害 +10%", true, 2.0, {"luck": 4.0, "ability_damage": 0.10}],
		["art_kraken_heart", "海妖之心", "作业伤害 +40%，最大耐久 +60", true, 2.2, {"damage": 0.40, "max_hp": 60.0}],
		["art_crown_scale", "王冠鳞片", "技能冷却 -35%，技能伤害 +25%", true, 2.4, {"cooldown": 0.35, "ability_damage": 0.25}],
		["art_midas_gear", "点金齿轮", "银币掉落 +60%", true, 2.6, {"silver_gain": 0.60}],
		["art_abyss_pearl", "深渊之珠", "幸运 +8，收集半径 +30%", true, 2.8, {"luck": 8.0, "collect_radius": 0.30}],
	]
	for d in defs:
		var a := ArtifactDefinition.new()
		a.id = d[0]
		a.display_name = d[1]
		a.description = d[2]
		a.rare = d[3]
		a.factor = d[4]
		a.tags = PackedStringArray(["stat"])
		a.stat_modifiers = d[5]
		list.append(a)
	return list

static func build_artifact_pools(artifacts: Array) -> Dictionary:
	var normal := ProbabilityList.new()
	var rare := ProbabilityList.new()
	for a in artifacts:
		# 权重 = factor（越强越稀有越低权重）[roster]
		(rare if a.rare else normal).add(a, float(a.factor))
	return {"normal": normal, "rare": rare}

# ---------- Boss（10，阶段控制器语义对齐 CannonPhase/ClubKing/Davinci/Kanoningen/Mortar/Pyramid/TankSpinner/RammeMortar/Mouth/GraveCross）----------

const BOSS_ROSTER := {
	"boss_kanoning": {"title": "卡诺宁鲸王", "hp": 420.0, "phases": [0.9, 1.35, 1.75], "kind": "heavy", "scale": 1.7},
	"boss_dredge_toad": {"title": "疏浚母舰·吞河蟾", "hp": 620.0, "phases": [0.8, 1.25, 1.7], "kind": "heavy", "scale": 1.0},
	"boss_cannon_phase": {"title": "炮阵阶段蟹", "hp": 360.0, "phases": [1.0, 1.2, 1.6], "kind": "medium", "scale": 1.5},
	"boss_club_king": {"title": "棍棒王", "hp": 500.0, "phases": [0.8, 1.3, 1.9], "kind": "heavy", "scale": 1.8},
	"boss_davinci": {"title": "达芬奇机械", "hp": 380.0, "phases": [1.1, 1.4, 1.5], "kind": "medium", "scale": 1.5},
	"boss_mortar": {"title": "臼炮龟", "hp": 440.0, "phases": [0.7, 1.1, 1.7], "kind": "heavy", "scale": 1.6},
	"boss_pyramid": {"title": "金字塔像", "hp": 560.0, "phases": [0.6, 0.9, 1.4], "kind": "heavy", "scale": 1.9},
	"boss_tank_spinner": {"title": "旋坦", "hp": 480.0, "phases": [1.2, 1.6, 2.0], "kind": "medium", "scale": 1.5},
	"boss_ramme_mortar": {"title": "撞臼兽", "hp": 460.0, "phases": [0.9, 1.5, 2.1], "kind": "heavy", "scale": 1.7},
	"boss_mouth": {"title": "巨口吞器", "hp": 400.0, "phases": [1.0, 1.3, 1.8], "kind": "medium", "scale": 1.6},
	"boss_grave_cross": {"title": "墓十字", "hp": 520.0, "phases": [0.8, 1.2, 1.6], "kind": "heavy", "scale": 1.8},
}

static func boss_ids() -> Array:
	return BOSS_ROSTER.keys()

## Boss 依次轮换（对齐 Boss 进度序列）： defeated_count 决定下一个出场者
static func next_boss_id(defeated_count: int) -> String:
	var ids := boss_ids()
	return ids[clampi(defeated_count, 0, ids.size() - 1)]

# ---------- 船长（15，被动天赋载体）----------

static func create_captains() -> Array:
	var list: Array = []
	var defs := [
		["cap_barnacle", "老藤壶", "银币掉落 +8%", {"silver_gain": 0.08}],
		["cap_salt", "盐姐", "移动速度 +6%", {"speed": 0.06}],
		["cap_rivet", "铆钉", "作业伤害 +6%", {"damage": 0.06}],
		["cap_moss", "苔爷", "受击伤害 -6%", {"armor": 0.06}],
		["cap_fin", "小鳍", "收集半径 +6%", {"collect_radius": 0.06}],
		["cap_bolt", "螺丝", "技能冷却 -6%", {"cooldown": 0.06}],
		["cap_marlow", "马洛", "幸运 +1", {"luck": 1.0}],
		["cap_nets", "网叔", "载货上限 +1", {"cargo_cap": 1.0}],
		["cap_wicks", "灯芯", "投送距离 +8%", {"throw_range": 0.08}],
		["cap_reef", "礁姨", "最大耐久 +15", {"max_hp": 15.0}],
		["cap_tide", "潮哥", "磁吸 +8%", {"magnet": 0.08}],
		["cap_gully", "沟仔", "任务奖励 +10%", {"quest_reward": 0.10}],
		["cap_ember", "余烬", "技能伤害 +8%", {"ability_damage": 0.08}],
		["cap_drift", "漂流", "幸运 +1，磁吸 +4%", {"luck": 1.0, "magnet": 0.04}],
		["cap_marrow", "骨髓船长", "作业伤害 +8%，最大耐久 +10", {"damage": 0.08, "max_hp": 10.0}],
	]
	for d in defs:
		var c := CaptainDefinition.new()
		c.id = d[0]
		c.display_name = d[1]
		c.description = d[2]
		c.stat_modifiers = d[3]
		list.append(c)
	return list
