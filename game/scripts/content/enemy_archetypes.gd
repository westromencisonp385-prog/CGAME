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

const TIERS := ["minion", "elite", "boss"]

const ARCHETYPES := {
	"flea": {"name": "铆钉跳蚤", "tier": "minion", "behavior": "hopper", "hp": 22.0, "speed": 1.6, "damage": 3.0, "slot": "enemy_minion_flea", "kind": "light"},
	"oildrum": {"name": "喷油桶章鱼", "tier": "minion", "behavior": "ranged", "hp": 30.0, "speed": 0.9, "damage": 4.0, "slot": "enemy_minion_oildrum", "kind": "ranged"},
	"bat": {"name": "吸尘蝙蝠", "tier": "minion", "behavior": "flyer", "hp": 20.0, "speed": 2.0, "damage": 3.0, "slot": "enemy_minion_bat", "kind": "light"},
	"hedgehog": {"name": "齿轮刺猬", "tier": "minion", "behavior": "roller", "hp": 40.0, "speed": 1.2, "damage": 5.0, "slot": "enemy_minion_hedgehog", "kind": "light"},
	"mantis": {"name": "焊枪螳螂", "tier": "minion", "behavior": "chase", "hp": 34.0, "speed": 1.4, "damage": 5.0, "slot": "enemy_minion_mantis", "kind": "light"},
	"rhino": {"name": "压路犀牛·工头", "tier": "elite", "behavior": "charger", "hp": 180.0, "speed": 0.9, "damage": 12.0, "slot": "enemy_elite_rhino", "kind": "heavy"},
	"eel": {"name": "变电鳗·监工", "tier": "elite", "behavior": "caster", "hp": 150.0, "speed": 0.8, "damage": 9.0, "slot": "enemy_elite_eel", "kind": "heavy"},
}

## 新 Boss 登记进花名册时使用的条目（同 BOSS_ROSTER 结构）
const NEW_BOSSES := {
	"boss_dredge_toad": {"title": "疏浚母舰·吞河蟾", "hp": 620.0, "phases": [0.8, 1.25, 1.7], "kind": "heavy", "scale": 1.0, "slot": "boss_04_dredge_toad"},
}

static func ids_of_tier(tier: String) -> Array:
	var out := []
	for id in ARCHETYPES:
		if ARCHETYPES[id]["tier"] == tier:
			out.append(id)
	return out

static func get_def(id: String) -> Dictionary:
	return ARCHETYPES.get(id, {})

## 掉落/奖励倍率：精英 ×4 银币 + 必掉一次升级选择
static func reward_scale(tier: String) -> float:
	return 4.0 if tier == "elite" else (10.0 if tier == "boss" else 1.0)
