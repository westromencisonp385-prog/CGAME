class_name VehicleProgression
extends RefCounted

## 载具成长运行时（语义对齐 VM：吞噬成长 sizeRank/collectorRadius + activeSlots 4 槽状态机）。
## 纯逻辑层：不依赖场景树，可 headless 测试；由 vehicle_controller 持有并喂事件。

signal size_rank_advanced(new_rank: int)
signal tier_upgraded(new_stats: VehicleStats)

const MAX_RANK := 5

## Tier 链（对齐 nextUpgrade 链）：T0 基础挖掘机 → T1 重装 → T2 巨鲸底盘
static func default_tier_chain() -> Array:
	var t0 := VehicleStats.new()
	t0.stats_name = "基础工程车"
	t0.max_hp = 100.0
	t0.rigid_body_mass = 1000
	t0.max_velocity = 7.0
	t0.vehicle_size_rank = 0
	t0.can_absorb_vehicles_of_size_rank = 0
	t0.collector_radius = 2.5
	t0.max_nitro = 100.0
	t1_next(t0)
	var t1 := t0.next_upgrade
	var t2 := t1.next_upgrade
	return [t0, t1, t2]

static func t1_next(t0: VehicleStats) -> void:
	var t1 := VehicleStats.new()
	t1.stats_name = "重装作业车"
	t1.max_hp = 180.0
	t1.rigid_body_mass = 1800
	t1.max_velocity = 6.0
	t1.vehicle_size_rank = 1
	t1.can_absorb_vehicles_of_size_rank = 1
	t1.collector_radius = 3.2
	t1.max_nitro = 120.0
	t0.next_upgrade = t1
	var t2 := VehicleStats.new()
	t2.stats_name = "巨鲸底盘"
	t2.max_hp = 320.0
	t2.rigid_body_mass = 3200
	t2.max_velocity = 5.5
	t2.vehicle_size_rank = 2
	t2.can_absorb_vehicles_of_size_rank = 2
	t2.collector_radius = 4.4
	t2.max_nitro = 150.0
	t1.next_upgrade = t2

var stats: VehicleStats
var growth_points: float = 0.0
## 4 个主动技能槽（对齐 activeSlotsCapacity=4）：{def: ModuleDefinitionV2, cooldown: float, charges: int}
var active_slots: Array = []

func _init(initial_stats: VehicleStats = null) -> void:
	stats = initial_stats if initial_stats != null else default_tier_chain()[0]
	active_slots.resize(4)

## 吞噬成长（对齐 VehicleAbsorb：吸收 size_rank ≤ can_absorb 的目标 → 成长点 → 升 rank）
func absorb(target_size_rank: int) -> Dictionary:
	if target_size_rank > stats.can_absorb_vehicles_of_size_rank:
		return {"absorbed": false, "reason": "target_too_large"}
	growth_points += 1.0 + float(target_size_rank)
	var advanced := false
	while growth_points >= growth_needed() and stats.vehicle_size_rank < MAX_RANK:
		growth_points -= growth_needed()
		stats.vehicle_size_rank += 1
		stats.collector_radius += 0.4
		stats.max_hp += 25.0
		advanced = true
		size_rank_advanced.emit(stats.vehicle_size_rank)
	return {"absorbed": true, "rank": stats.vehicle_size_rank, "advanced": advanced, "points": growth_points}

func growth_needed() -> float:
	return 3.0 + float(stats.vehicle_size_rank) * 2.0

## Tier 升级（对齐 nextUpgrade 链推进）
func upgrade_tier() -> VehicleStats:
	if stats.next_upgrade == null:
		return null
	stats = stats.next_upgrade
	growth_points = 0.0
	active_slots.clear()
	active_slots.resize(4)
	tier_upgraded.emit(stats)
	return stats

# ---------- 4 主动技能槽 ----------

func equip_ability(slot: int, module: ModuleDefinitionV2) -> bool:
	if slot < 0 or slot >= 4 or module == null:
		return false
	active_slots[slot] = {"def": module, "cooldown": 0.0, "charges": module.activation_charges}
	return true

func tick(delta: float) -> void:
	for entry in active_slots:
		if entry is Dictionary and not entry.is_empty():
			entry["cooldown"] = maxf(0.0, float(entry["cooldown"]) - delta)

## 施放：返回 {cast, reason}；对齐 VM 的冷却/充能双闸门
func cast_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= 4:
		return {"cast": false, "reason": "invalid_slot"}
	var entry: Variant = active_slots[slot]
	if entry == null or (entry is Dictionary and entry.is_empty()):
		return {"cast": false, "reason": "empty_slot"}
	var e: Dictionary = entry
	if float(e["cooldown"]) > 0.0:
		return {"cast": false, "reason": "cooling_down", "remaining": float(e["cooldown"])}
	if int(e["charges"]) < 0:
		return {"cast": false, "reason": "no_charges"}
	if int(e["charges"]) > 0:
		e["charges"] = int(e["charges"]) - 1
	var base_cooldown := float(e["def"].active_base_cooldown)
	e["cooldown"] = base_cooldown
	return {"cast": true, "damage": float(e["def"].active_base_damage), "range": float(e["def"].active_range), "cooldown_set": base_cooldown}

func cooldowns() -> Array:
	var out: Array = []
	for entry in active_slots:
		out.append(float(entry["cooldown"]) if entry is Dictionary and not entry.is_empty() else 0.0)
	return out

# ---------- 快照 ----------

func get_snapshot() -> Dictionary:
	var slots: Array = []
	for entry in active_slots:
		if entry is Dictionary and not entry.is_empty():
			slots.append({"id": entry["def"].module_id, "cooldown": entry["cooldown"], "charges": entry["charges"]})
		else:
			slots.append({})
	return {"tier": stats.stats_name, "rank": stats.vehicle_size_rank, "growth": growth_points, "slots": slots}

func restore_snapshot(data: Dictionary) -> bool:
	if not data is Dictionary or not data.get("rank") is int:
		return false
	stats.vehicle_size_rank = int(data["rank"])
	growth_points = float(data.get("growth", 0.0))
	return stats.vehicle_size_rank >= 0 and stats.vehicle_size_rank <= MAX_RANK
