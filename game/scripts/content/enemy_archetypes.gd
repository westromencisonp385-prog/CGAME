class_name EnemyArchetypes
extends RefCounted

## C16 敌人花名册 v3：小怪 / 精英 / Boss 三档。
## 每个原型 = 显示名 + 档位 + 行为 + 数值 + 模型槽位。EnemyDummy.configure_archetype() 读取它。
## 档位语言（与原画一致）：小怪 蓝+赭黄红眼；精英 骨白红边 + 顶部警示灯，体型 ×1.0（模型本身更大）+ 名牌；
## Boss 走 BossEntity（ContentRoster.BOSS_ROSTER），这里只登记模型槽位映射。
##
## behavior:
##   chase   贴身近战（默认）
##   hopper  间歇跳跃突进（每 1.6s 一次 2.2× 速度冲刺）
##   ranged  保持 5m 距离，远程喷射
##   flyer   绕玩家盘旋，俯冲啄击
##   roller  蜷缩滚动冲撞（受击 -30%，冲撞伤害高）
##   charger 精英：蓄力 0.8s 后直线冲锋
##   caster  精英：保持距离，周期电弧（范围伤害）

const TIERS := ["swarm", "minion", "elite", "boss", "neutral", "structure"]

## C28 提速（原作杂兵速度约为玩家的 0.25~0.7；原来我们只有 0.13~0.28，WASD 永远甩得掉，没有压迫感）
const ARCHETYPES := {
	"flea": {"name": "铆钉跳蚤", "tier": "minion", "behavior": "hopper", "hp": 22.0, "speed": 2.4, "damage": 5.0, "slot": "enemy_minion_flea", "kind": "light"},
	"oildrum": {"name": "喷油桶章鱼", "tier": "minion", "behavior": "ranged", "hp": 30.0, "speed": 1.5, "damage": 6.0, "slot": "enemy_minion_oildrum", "kind": "ranged"},
	"bat": {"name": "吸尘蝙蝠", "tier": "minion", "behavior": "flyer", "hp": 20.0, "speed": 2.8, "damage": 5.0, "slot": "enemy_minion_bat", "kind": "light"},
	"hedgehog": {"name": "齿轮刺猬", "tier": "minion", "behavior": "roller", "hp": 40.0, "speed": 1.9, "damage": 8.0, "slot": "enemy_minion_hedgehog", "kind": "light"},
	"mantis": {"name": "焊枪螳螂", "tier": "minion", "behavior": "chase", "hp": 34.0, "speed": 2.3, "damage": 8.0, "slot": "enemy_minion_mantis", "kind": "light"},
	"rhino": {"name": "压路犀牛·工头", "tier": "elite", "behavior": "charger", "hp": 180.0, "speed": 1.5, "damage": 18.0, "slot": "enemy_elite_rhino", "kind": "heavy"},
	"eel": {"name": "变电鳗·监工", "tier": "elite", "behavior": "caster", "hp": 150.0, "speed": 1.2, "damage": 14.0, "slot": "enemy_elite_eel", "kind": "heavy"},
	# C28 杂兵（对齐原作 Unit：5~30 血、一碰就死、成群出现）：小怪模型缩小，一口咬死
	"swarm_flea": {"name": "小跳蚤", "tier": "swarm", "behavior": "chase", "hp": 8.0, "speed": 3.0, "damage": 4.0, "slot": "enemy_minion_flea", "kind": "light", "scale": 0.6},
	"swarm_mantis": {"name": "幼螳", "tier": "swarm", "behavior": "chase", "hp": 10.0, "speed": 2.7, "damage": 4.5, "slot": "enemy_minion_mantis", "kind": "light", "scale": 0.62},
	"swarm_bat": {"name": "小蝙蝠", "tier": "swarm", "behavior": "flyer", "hp": 6.0, "speed": 3.2, "damage": 3.0, "slot": "enemy_minion_bat", "kind": "light", "scale": 0.6},
	# 加时清场者（对齐原作 Metzelman：高血、极快，逼玩家去打 Boss）
	"enforcer": {"name": "清场者", "tier": "elite", "behavior": "charger", "hp": 600.0, "speed": 3.4, "damage": 26.0, "slot": "enemy_elite_rhino", "kind": "heavy", "overtime": true, "scale": 1.15},
	# 中立（对齐原作 Neutral Treasure / Support(Health)）：逃跑，限时消失，追上有奖
	"treasure": {"name": "宝箱车", "tier": "neutral", "behavior": "flee", "hp": 60.0, "speed": 4.6, "damage": 0.0, "prop": "prop_cargo_crate", "kind": "light", "lifetime": 26.0, "ring": "#E9AD38"},
	"supply": {"name": "补给车", "tier": "neutral", "behavior": "flee", "hp": 50.0, "speed": 3.4, "damage": 0.0, "prop": "prop_oil_drums", "kind": "light", "lifetime": 30.0, "ring": "#8FD694"},
	# 敌巢（对齐原作 LocalSpawner：玩家靠近才出兵，有上限）：不动、不攻击，咬碎有大奖
	"nest": {"name": "敌巢", "tier": "structure", "behavior": "nest", "hp": 220.0, "speed": 0.0, "damage": 0.0, "prop": "prop_stone_arch", "kind": "heavy", "ring": "#D9412B"},
}

static func is_hostile(tier: String) -> bool:
	return tier in ["swarm", "minion", "elite", "boss"]

## 新 Boss 登记进花名册时使用的条目（同 BOSS_ROSTER 结构）
const NEW_BOSSES := {
	"boss_dredge_toad": {"title": "疏浚母舰·吞河蟾", "hp": 620.0, "phases": [0.8, 1.25, 1.7], "kind": "heavy", "scale": 1.0, "slot": "boss_04_dredge_toad"},
}

static func ids_of_tier(tier: String) -> Array:
	var out := []
	for id in ARCHETYPES:
		if ARCHETYPES[id]["tier"] == tier and not bool(ARCHETYPES[id].get("overtime", false)):
			out.append(id)
	return out

static func get_def(id: String) -> Dictionary:
	return ARCHETYPES.get(id, {})

## 掉落/奖励倍率：精英 ×4 银币 + 必掉一次升级选择
static func reward_scale(tier: String) -> float:
	match tier:
		"elite": return 4.0
		"boss": return 10.0
		"swarm": return 0.0
		"structure": return 6.0
		"neutral": return 3.0
	return 1.0
