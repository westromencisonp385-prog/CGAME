class_name RunSystems
extends RefCounted

## 单局系统束（子智能体 C4）：双货币经济 + 任务系统 + 磁吸掉落 + 神器 Tag 修饰器。
## 纯逻辑层，headless 可测。

signal silver_changed(new_value: int)
signal quest_achieved(quest_id: String)
signal dropped(kind: String, amount: int)

# ---------- 经济（对齐 Silver/Gold 双货币）----------

var silver: int = 0
var gold: int = 0
## 收益流水（对齐 GoldScoreLegitimacyTracker：记录来源与数额，供合法性审计）
var ledger: Array = []

func earn_silver(amount: int, source: String) -> bool:
	if amount <= 0:
		return false
	silver += amount
	ledger.append({"res": "silver", "amount": amount, "source": source})
	silver_changed.emit(silver)
	return true

func spend_silver(amount: int, reason: String) -> bool:
	if amount <= 0 or silver < amount:
		return false
	silver -= amount
	ledger.append({"res": "silver", "amount": -amount, "source": reason})
	silver_changed.emit(silver)
	return true

## 合法性审计：流水净值 == 余额
func ledger_legit() -> bool:
	var net := 0
	for entry in ledger:
		net += int(entry["amount"])
	return net == silver

# ---------- 磁吸掉落（对齐 VehicleItemMagnetDrop + dropChance 走 ProbabilityList）----------

var drop_table: ProbabilityList

func _init() -> void:
	drop_table = ProbabilityList.new()
	drop_table.add("silver", 70.0)
	drop_table.add("nothing", 30.0)

func roll_drop(rng: RandomNumberGenerator, luck: float = 0.0) -> String:
	var item: Variant = drop_table.roll_item(rng)
	if item == null:
		return "nothing"
	# luck 提升银币倾向：重新 roll 一次 nothing 转 silver（GAP：精确公式在原生码）
	if item == "nothing" and luck > 0.0 and rng.randf() < minf(0.5, luck * 0.05):
		item = "silver"
	if item == "silver":
		var amount := int(round(float(rng.randi_range(2, 8)) * (1.0 + total_bonus("silver_gain"))))
		earn_silver(amount, "magnet_drop")
		dropped.emit("silver", amount)
	return str(item)

# ---------- 任务（对齐 QuestSystem：achieved_quests + quest_progress 字典）----------

var quest_progress: Dictionary = {}
var achieved_quests: Array = []

## quests: [{"id", "name", "metric", "target", "reward_silver"}]
## C17：24 个任务（对齐 QuestSystem 20+），覆盖回收 / 战斗 / 技能 / 闪避 / 拾取 / 探索 / 成长。
const QUESTS := [
	{"id": "q_first_harvest", "name": "第一铲", "metric": "harvested", "target": 3, "reward_silver": 20},
	{"id": "q_harvest_20", "name": "废料大户", "metric": "harvested", "target": 20, "reward_silver": 60},
	{"id": "q_pack_whale", "name": "鲸口打包", "metric": "packed", "target": 2, "reward_silver": 35},
	{"id": "q_absorb_rank", "name": "越吃越大", "metric": "absorbs", "target": 4, "reward_silver": 50},
	{"id": "q_kill_10", "name": "清场", "metric": "enemy_defeated", "target": 10, "reward_silver": 30},
	{"id": "q_kill_50", "name": "拆迁队", "metric": "enemy_defeated", "target": 50, "reward_silver": 90},
	{"id": "q_kill_150", "name": "钢铁洪流", "metric": "enemy_defeated", "target": 150, "reward_silver": 200},
	{"id": "q_elite_1", "name": "工头下岗", "metric": "elite_defeated", "target": 1, "reward_silver": 40},
	{"id": "q_elite_5", "name": "精英猎手", "metric": "elite_defeated", "target": 5, "reward_silver": 120},
	{"id": "q_boss_1", "name": "屠龙", "metric": "boss_defeated", "target": 1, "reward_silver": 100},
	{"id": "q_boss_3", "name": "三连冠", "metric": "boss_defeated", "target": 3, "reward_silver": 260},
	{"id": "q_cast_20", "name": "技能达人", "metric": "ability_cast", "target": 20, "reward_silver": 40},
	{"id": "q_cast_100", "name": "按键磨损", "metric": "ability_cast", "target": 100, "reward_silver": 120},
	{"id": "q_crit_25", "name": "要害专家", "metric": "crit", "target": 25, "reward_silver": 50},
	{"id": "q_dodge_5", "name": "擦边球", "metric": "perfect_dodge", "target": 5, "reward_silver": 60},
	{"id": "q_multikill", "name": "一网打尽", "metric": "multikill", "target": 3, "reward_silver": 70},
	{"id": "q_loot_100", "name": "吸金", "metric": "loot", "target": 100, "reward_silver": 50},
	{"id": "q_status_30", "name": "花式控场", "metric": "status_applied", "target": 30, "reward_silver": 45},
	{"id": "q_summon_5", "name": "包工头", "metric": "summon_used", "target": 5, "reward_silver": 40},
	{"id": "q_repair", "name": "河岸复苏", "metric": "repair", "target": 1, "reward_silver": 30},
	{"id": "q_biome_2", "name": "远行", "metric": "biome_switch", "target": 2, "reward_silver": 60},
	{"id": "q_key", "name": "钥匙在手", "metric": "biome_keys", "target": 1, "reward_silver": 50},
	{"id": "q_modules_6", "name": "满配", "metric": "module_taken", "target": 6, "reward_silver": 70},
	{"id": "q_artifacts_5", "name": "藏品家", "metric": "artifact_taken", "target": 5, "reward_silver": 80},
]

static func default_quests() -> Array:
	return QUESTS

static func quest_name(qid: String) -> String:
	for q in QUESTS:
		if q["id"] == qid:
			return str(q["name"])
	return qid

static func quest_def(qid: String) -> Dictionary:
	for q in QUESTS:
		if q["id"] == qid:
			return q
	return {}

## 追踪面板：返回最多 n 条未完成、进度最高的任务
func tracked_quests(n := 3) -> Array:
	var rows := []
	for q in QUESTS:
		if achieved_quests.has(q["id"]):
			continue
		var prog := int(quest_progress.get(q["id"], 0))
		rows.append({"id": q["id"], "name": q["name"], "progress": prog, "target": int(q["target"]), "ratio": float(prog) / float(q["target"])})
	rows.sort_custom(func(a, b): return a["ratio"] > b["ratio"])
	return rows.slice(0, n)

func report(metric: String, amount: int = 1, quests: Array = default_quests()) -> Array:
	var newly_achieved: Array = []
	for q in quests:
		if achieved_quests.has(q["id"]):
			continue
		if str(q["metric"]) != metric:
			continue
		quest_progress[q["id"]] = int(quest_progress.get(q["id"], 0)) + amount
		if int(quest_progress[q["id"]]) >= int(q["target"]):
			achieved_quests.append(q["id"])
			earn_silver(int(q["reward_silver"]), "quest_" + str(q["id"]))
			newly_achieved.append(q["id"])
			quest_achieved.emit(q["id"])
	return newly_achieved

# ---------- 神器 Tag 修饰器（对齐 ArtifactTag 体系：additive 修饰 stat）----------

var owned_artifacts: Array = []
## C9：船长天赋（雇佣后常驻，与神器同构聚合）
var hired_captain: CaptainDefinition = null
## C9：Boss 击杀进度（驱动 BOSS_ROSTER 序列轮换）
var bosses_defeated: int = 0

func equip_artifact(artifact: ArtifactDefinition) -> bool:
	if artifact == null or artifact.id.is_empty():
		return false
	owned_artifacts.append(artifact)
	return true

func hire_captain(captain: CaptainDefinition) -> bool:
	if captain == null or captain.id.is_empty():
		return false
	hired_captain = captain
	return true

## 聚合所有神器的某项修饰：additive 求和 × factor
func artifact_bonus(stat_name: String) -> float:
	var total := 0.0
	for a in owned_artifacts:
		total += a.get_modifier(stat_name) * a.factor
	return total

## C9：神器+船长总修饰（聚合口径：神器 additive×factor + 船长 additive）
func total_bonus(stat_name: String) -> float:
	return artifact_bonus(stat_name) + (hired_captain.get_modifier(stat_name) if hired_captain != null else 0.0)

func has_artifact_tag(tag: String) -> bool:
	for a in owned_artifacts:
		if a.has_tag(tag):
			return true
	return false

## 载具有效属性 = 基础 + 神器修饰（luck/armor/collect_radius/magnet）
func effective_luck(base_luck: float) -> float:
	return base_luck + artifact_bonus("luck")

# ---------- 快照 ----------

func get_snapshot() -> Dictionary:
	return {"silver": silver, "quest_progress": quest_progress.duplicate(), "achieved_quests": achieved_quests.duplicate(), "artifact_ids": owned_artifacts.map(func(a): return a.id), "bosses_defeated": bosses_defeated, "hired_captain": hired_captain.id if hired_captain != null else ""}

func restore_snapshot(data: Dictionary) -> bool:
	if not data is Dictionary:
		return false
	silver = int(data.get("silver", 0))
	quest_progress = (data.get("quest_progress", {}) as Dictionary).duplicate()
	achieved_quests = (data.get("achieved_quests", []) as Array).duplicate()
	bosses_defeated = int(data.get("bosses_defeated", 0))
	hired_captain = null
	return silver >= 0
