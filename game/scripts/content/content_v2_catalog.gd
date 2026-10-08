class_name ContentV2Catalog
extends RefCounted

## v2 内容目录：40 模块（对齐逆向花名册 40+：法师系 / 船员系 / 炮塔系 / 前后侧挂件系）。
## 每个模块的施放行为由 AbilityLibrary.SHAPES[module_id] 决定（33 种行为形状）；
## 数值为本项目自有的等价设计（不复制原作数值）。

const KIND_LABLES := "法师系/船员系/炮塔系/挂件系"

## [id, 名称, 描述, 稀有度权重(>=3 普通/>=2 罕见/>=1 稀有/<1 史诗), 伤害, 冷却, 射程, 槽位组]
const DEFS := [
	# ---- 法师系（REACTION）----
	["mage_pyro", "烈焰法师", "掷出火球，落点爆炸并点燃一片敌人。", 2.0, 14.0, 3.5, 14.0, "mage"],
	["mage_cryo", "霜寒法师", "前方扇形冰锥：减速并铺湿，电击伤害翻倍。", 2.0, 9.0, 4.0, 7.5, "mage"],
	["mage_storm", "风暴法师", "链式闪电在最多 5 个敌人间跳跃并短暂麻痹。", 3.0, 11.0, 5.0, 12.0, "mage"],
	["mage_void", "虚空法师", "一道贯穿长枪，穿透整排敌人，对重型 ×1.8。", 1.0, 26.0, 6.0, 13.0, "mage"],
	["mage_tide", "潮汐法师", "宽幅水浪把敌人推远并铺湿。", 3.0, 7.0, 5.0, 8.0, "mage"],
	["mage_gravity", "重力法师", "制造引力井，把周围敌人吸到一处后砸下。", 1.0, 22.0, 8.0, 9.0, "mage"],
	["mage_frost_nova", "霜爆法师", "以自身为中心冻结周围敌人 0.8 秒。", 2.0, 10.0, 7.0, 4.5, "mage"],
	# ---- 船员系（REPAIR）----
	["crew_engineer", "随车工程师", "立刻修复 22 耐久并清除负面状态。", 2.0, 0.0, 12.0, 0.0, "crew"],
	["crew_sniper", "随车狙击手", "锁定血量最高的敌人，打出一发重狙。", 2.0, 48.0, 6.0, 22.0, "crew"],
	["crew_medic", "随车医护", "低血量时爆发治疗，并获得 1 秒无敌。", 3.0, 0.0, 14.0, 0.0, "crew"],
	["crew_bomber", "随车投弹手", "向三处敌群投掷炸弹（地面预警后爆炸）。", 2.0, 20.0, 7.0, 14.0, "crew"],
	["crew_cook", "随车厨师", "热汤：恢复 12 耐久，并获得 6 秒 30 点护盾。", 3.0, 0.0, 16.0, 0.0, "crew"],
	["crew_scout", "随车侦察兵", "向前方扇形连射 5 支短弩。", 3.0, 8.0, 3.0, 14.0, "crew"],
	["crew_rigger", "随车装配工", "其他技能冷却 -60%，并获得 2 秒氮气。", 1.0, 0.0, 18.0, 0.0, "crew"],
	# ---- 炮塔系（MORPH）----
	["turret_layer", "炮塔布设", "原地布设一座自动炮塔。", 2.0, 4.0, 9.0, 16.0, "turret"],
	["arms_dealer", "军火商", "重置所有技能 60% 冷却，超频挖斗。", 3.0, 0.0, 15.0, 0.0, "turret"],
	["barracks", "兵营", "展开随车营地，持续治疗。", 1.0, 0.0, 16.0, 0.0, "turret"],
	["top_cannon_tower", "顶置炮塔", "360° 齐射 12 发炮弹。", 2.0, 9.0, 8.0, 14.0, "turret"],
	["turret_tesla", "特斯拉塔", "布设电磁塔，周期麻痹附近敌人。", 1.0, 3.0, 14.0, 6.0, "turret"],
	["top_mortar", "顶置迫击炮", "向瞄准方向连发三枚迫击炮弹。", 2.0, 24.0, 8.0, 16.0, "turret"],
	["top_archer", "顶置弩手", "扇形五连发，近距离全中伤害很高。", 3.0, 9.0, 3.5, 14.0, "turret"],
	# ---- 前挂件 ----
	["front_cannon", "前装主炮", "一发重炮：高伤害、大击退。", 3.0, 30.0, 4.0, 18.0, "front"],
	["ballista", "穿甲弩车", "穿透 4 个目标的弩箭。", 2.0, 22.0, 4.5, 20.0, "front"],
	["harpoon_gun", "鱼叉枪", "射出鱼叉，把命中的敌人拽到车前并麻痹。", 2.0, 14.0, 5.0, 14.0, "front"],
	["ramme", "破城撞角", "向前猛冲 9 米，沿途撞飞敌人（冲撞中无敌）。", 2.0, 28.0, 6.0, 9.0, "front"],
	["magnet_crane", "磁吸吊臂", "把 9 米内的敌人吸到车前。", 3.0, 6.0, 7.0, 9.0, "front"],
	["quake_hammer", "震地锤", "猛砸地面，冲击波震退周围敌人。", 2.0, 18.0, 7.0, 5.0, "front"],
	# ---- 侧挂件 ----
	["side_cannon", "舷侧炮", "左右两舷各齐射三发。", 3.0, 12.0, 4.5, 14.0, "side"],
	["side_flamethrower", "侧喷火器", "前方扇形火焰，点燃并持续灼烧。", 2.0, 8.0, 4.0, 6.5, "side"],
	["emp_coil", "电磁脉冲", "6 米内敌人全部麻痹 1.6 秒。", 1.0, 6.0, 12.0, 6.0, "side"],
	["shield_dome", "护盾穹顶", "展开 45 点护盾，持续 6 秒。", 2.0, 0.0, 14.0, 0.0, "side"],
	["scrap_cyclone", "废料旋风", "车身周围卷起废料旋风，连续绞伤 4 次。", 1.0, 9.0, 9.0, 3.6, "side"],
	["whale_roar", "鲸吼", "一声长吼：7 米内敌人恐惧逃散 2 秒。", 2.0, 4.0, 11.0, 7.0, "side"],
	# ---- 后挂件 ----
	["back_dash", "尾喷冲刺", "瞬间加速冲出，冲刺途中无敌。", 3.0, 14.0, 4.0, 7.0, "back"],
	["back_mine_layer", "布雷车斗", "车尾撒下 3 枚触发地雷。", 2.0, 26.0, 7.0, 0.0, "back"],
	["back_trail", "焦油尾迹", "车尾铺出一段焦油带，敌人踩上大幅减速。", 3.0, 3.0, 8.0, 0.0, "back"],
	["firewall_spreader", "火墙喷洒", "前方铺出一道持续 4 秒的火墙。", 2.0, 6.0, 9.0, 8.0, "back"],
	["teleporter", "相位跃迁", "瞬移 7 米，落点放出电磁冲击。", 1.0, 16.0, 7.0, 7.0, "back"],
	["overclock", "超频核心", "热量清零、氮气 3 秒、主作业冷却减半 5 秒。", 1.0, 0.0, 16.0, 0.0, "back"],
	["repair_drone", "维修无人机", "无人机飞出：每秒修复 4 耐久，持续 5 秒。", 2.0, 0.0, 15.0, 0.0, "back"],
]

const GROUP_SLOTS := {
	"mage": [ModuleDefinitionV2.ModuleSlot.SIDE, ModuleDefinitionV2.ModuleSlot.TOP],
	"crew": [ModuleDefinitionV2.ModuleSlot.CREW],
	"turret": [ModuleDefinitionV2.ModuleSlot.TOP, ModuleDefinitionV2.ModuleSlot.BACK],
	"front": [ModuleDefinitionV2.ModuleSlot.FRONT],
	"side": [ModuleDefinitionV2.ModuleSlot.SIDE],
	"back": [ModuleDefinitionV2.ModuleSlot.BACK],
}

static func create_v2_definitions() -> Array:
	var modules: Array = []
	for d in DEFS:
		var m := ModuleDefinitionV2.new()
		m.module_id = d[0]
		m.module_name = d[1]
		m.module_description = d[2]
		m.rarity = d[3]
		m.active_base_damage = d[4]
		m.active_base_cooldown = d[5]
		m.active_range = d[6]
		var slots: Array = GROUP_SLOTS[d[7]]
		for s in slots:
			m.allowed_slots.append(s)
		m.auto_base_cooldown = float(d[5]) * 1.6
		m.passive_base_damage = float(d[4]) * 0.5
		modules.append(m)
	return modules

static func group_of(module_id: String) -> String:
	for d in DEFS:
		if d[0] == module_id:
			return str(d[7])
	return ""

static func validate_v2(definition: ModuleDefinitionV2) -> bool:
	if definition == null or definition.module_id.is_empty() or definition.module_name.is_empty():
		return false
	if definition.rarity <= 0.0:
		return false
	if definition.allowed_slots.is_empty():
		return false
	if definition.active_base_cooldown <= 0.0 and definition.auto_base_cooldown <= 0.0:
		return false
	return true

## 组装 SelectionEngine 的四档模块池（按 rarity_weight 分档：>=3 普通 / >=2 罕见 / >=1 稀有 / 其余史诗）。
static func build_module_pools(modules: Array) -> Array:
	var pools: Array = []
	for i in LuckEngine.RARITY_COUNT:
		pools.append(ProbabilityList.new())
	for m in modules:
		var tier := 0
		if m.rarity >= 3.0:
			tier = 0
		elif m.rarity >= 2.0:
			tier = 1
		elif m.rarity >= 1.0:
			tier = 2
		else:
			tier = 3
		pools[tier].add(m, 1.0)
	return pools

## 模块升级池（UpgradeDefinition，四档）：伤害 / 冷却 / 范围 / 充能 + 传奇分支
static func build_upgrade_pools() -> Array:
	var pools: Array = []
	for i in LuckEngine.RARITY_COUNT:
		pools.append(ProbabilityList.new())
	var defs := [
		[0, "dmg_1", "强化 I", "技能伤害 +20%", UpgradeDefinition.UpgradeType.PASSIVE, {"damage": 0.2}],
		[0, "cd_1", "冷却 I", "冷却 -12%", UpgradeDefinition.UpgradeType.COOLDOWN, {"cooldown": 0.12}],
		[0, "size_1", "扩径 I", "范围 +15%", UpgradeDefinition.UpgradeType.SIZE, {"range": 0.15}],
		[1, "dmg_2", "强化 II", "技能伤害 +35%", UpgradeDefinition.UpgradeType.PASSIVE, {"damage": 0.35}],
		[1, "cd_2", "冷却 II", "冷却 -20%", UpgradeDefinition.UpgradeType.COOLDOWN, {"cooldown": 0.2}],
		[1, "size_2", "扩径 II", "范围 +25%", UpgradeDefinition.UpgradeType.SIZE, {"range": 0.25}],
		[2, "ult_1", "过载", "伤害 +50%，冷却 +10%", UpgradeDefinition.UpgradeType.ULT, {"damage": 0.5, "cooldown": -0.1}],
		[2, "crit_1", "要害", "该技能必定暴击", UpgradeDefinition.UpgradeType.SPECIAL_0A, {"crit": 1.0}],
		[2, "echo_1", "回响", "施放后 0.4 秒再触发一次（50% 伤害）", UpgradeDefinition.UpgradeType.SPECIAL_0B, {"echo": 0.5}],
		[3, "leg_a", "传奇 · 双生", "伤害 +60%，施放两次", UpgradeDefinition.UpgradeType.LEGENDARY_A, {"damage": 0.6, "echo": 1.0}],
		[3, "leg_b", "传奇 · 永动", "冷却 -40%，范围 +30%", UpgradeDefinition.UpgradeType.LEGENDARY_B, {"cooldown": 0.4, "range": 0.3}],
	]
	for d in defs:
		var u := UpgradeDefinition.new()
		u.rarity_index = d[0]
		u.id = d[1]
		u.display_name = d[2]
		u.description = d[3]
		u.type = d[4]
		u.stat_gains = d[5]
		pools[int(d[0])].add(u, 1.0)
	return pools
