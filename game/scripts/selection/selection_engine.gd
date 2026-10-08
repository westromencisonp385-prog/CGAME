class_name SelectionEngine
extends RefCounted

## 四套升级选择的纯逻辑层（语义对齐 ModuleSelection 四套生成/选择/重掷流）。
## 1 新模块 3 选 1 / 2 模块升级 3 选 1 / 3 神器 3 选 1（双池+保底）/ 4 载具升级 2 选 1。
## 不含 UI；UI 层订阅 signals 渲染。

signal selection_generated(kind: String, options: Array)
signal selection_committed(kind: String, chosen: Variant)

var rng := RandomNumberGenerator.new()
## luck 由载具/神器聚合而来（对齐 VM 与 Artifact 的 luck 汇聚语义）
var luck: float = 0.0
var positive_luck_ramp: float = 1.0

## 池子由内容层注入
var new_module_pools: Array = []          # Array[ProbabilityList] x4（按稀有度）
var upgrade_pools: Array = []             # Array[ProbabilityList] x4
var artifact_pool: ProbabilityList        # 普通池
var rare_artifact_pool: ProbabilityList   # rare 池
var artifact_fallbacks: Array = []        # 普通保底
var rare_artifact_fallbacks: Array = []   # rare 保底（对齐 rareArtifactFallbacks）
var vehicle_tiers: Array = []             # Array[VehicleStats]，Tier 链
var installed_modules: Array = []         # 已装 ModuleDefinitionV2（升级选项来源）

## reroll 计数（对齐 TryRerollCurrent*Selection；未解锁模块数参与缩放的确证语义用 luck 缩放近似）
var reroll_count: int = 0

func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

# ---------- 1) 新模块 3 选 1 ----------

func generate_new_modules(exclude_ids: Array = []) -> Array:
	var picks: Array = []
	var picked_ids := {}
	for e in exclude_ids:
		picked_ids[e] = true
	for i in 3:
		var item = LuckEngine.roll_from_pools(luck, new_module_pools, rng, positive_luck_ramp)
		if item == null:
			continue
		if picked_ids.has(item.module_id):
			item = LuckEngine.roll_from_pools(luck, new_module_pools, rng, positive_luck_ramp)
		if item != null:
			picks.append(item)
			picked_ids[item.module_id] = true
	selection_generated.emit("new_module", picks)
	return picks

# ---------- 2) 模块升级 3 选 1 ----------

## internal_rarity_weights：对齐 defaultInternalRarity（ProbabilityList<int>）
func generate_upgrades() -> Array:
	var picks: Array = []
	if installed_modules.is_empty():
		return picks
	for i in 3:
		var target: ModuleDefinitionV2 = installed_modules[rng.randi_range(0, installed_modules.size() - 1)]
		var item = LuckEngine.roll_from_pools(luck, upgrade_pools, rng, positive_luck_ramp)
		if item != null:
			picks.append({"module": target, "upgrade": item})
	selection_generated.emit("upgrade", picks)
	return picks

# ---------- 3) 神器 3 选 1（双池 + fallback 保底）----------

func generate_artifacts(rare: bool = false) -> Array:
	var picks: Array = []
	var chosen := {}
	var main_pool := rare_artifact_pool if rare else artifact_pool
	var fallbacks: Array = rare_artifact_fallbacks if rare else artifact_fallbacks
	for i in 3:
		var item = main_pool.roll_item(rng) if main_pool and not main_pool.is_empty() else null
		if item == null or chosen.has(item.id):
			item = _pick_fallback(fallbacks, chosen)
		if item != null:
			picks.append(item)
			chosen[item.id] = true
	# 缺槽从 fallback 填充（对齐 PopulateMissingArtifactChoicesFromFallbacks）
	while picks.size() < 3 and not fallbacks.is_empty():
		var item = _pick_fallback(fallbacks, chosen)
		if item == null:
			break
		picks.append(item)
		chosen[item.id] = true
	selection_generated.emit("artifact_rare" if rare else "artifact", picks)
	return picks

func _pick_fallback(fallbacks: Array, chosen: Dictionary) -> ArtifactDefinition:
	for item in fallbacks:
		if not chosen.has(item.id):
			return item
	return null

# ---------- 4) 载具升级 2 选 1（Tier 链 + 变体）----------

## 返回两个变体：[{stats, title, bonus_lines}, ...]；bonus_lines 为 8 项属性对比行
func generate_vehicle_upgrades(current: VehicleStats) -> Array:
	if vehicle_tiers.is_empty():
		return []
	var options: Array = []
	var candidates := vehicle_tiers.filter(func(v): return v != current and v.vehicle_size_rank > current.vehicle_size_rank)
	if candidates.is_empty():
		candidates = vehicle_tiers.filter(func(v): return v != current)
	for i in mini(2, candidates.size()):
		var next_stats: VehicleStats = candidates[rng.randi_range(0, candidates.size() - 1)]
		options.append({
			"stats": next_stats,
			"title": "%s -> %s" % [current.stats_name, next_stats.stats_name],
			"bonus_lines": _stat_diff_lines(current, next_stats),
		})
	selection_generated.emit("vehicle", options)
	return options

func _stat_diff_lines(a: VehicleStats, b: VehicleStats) -> Array:
	return [
		"HP %.0f -> %.0f" % [a.max_hp, b.max_hp],
		"速度 %.1f -> %.1f" % [a.max_velocity, b.max_velocity],
		"氮气 %.0f -> %.0f" % [a.max_nitro, b.max_nitro],
		"质量 %d -> %d" % [a.rigid_body_mass, b.rigid_body_mass],
		"吞噬 rank %d -> %d" % [a.can_absorb_vehicles_of_size_rank, b.can_absorb_vehicles_of_size_rank],
	]

# ---------- 提交 ----------

func commit(kind: String, chosen: Variant) -> void:
	if kind == "new_module":
		installed_modules.append(chosen)
	selection_committed.emit(kind, chosen)

## reroll 缩放：未解锁新模块越多，reroll 收益越低（对齐 GetUnlockedNewModuleCountForRerollScaling 的方向性语义，GAP：精确公式在原生码）
func reroll_cost_factor() -> float:
	return 1.0 / (1.0 + 0.15 * reroll_count)
