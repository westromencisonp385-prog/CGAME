class_name StatusEffects
extends RefCounted

## C17 状态机（对齐 VM 状态面：burning / fear / stun / slow / invincible / shield / nitro / overheat）。
## 原作用协程到期；这里用「剩余时间」字典 + tick，headless 可测，载具和敌人共用。
##   burning    每秒 magnitude 点伤害（tick 返回本帧应扣血量）
##   fear       移动反向/乱转（宿主读取 is_feared），不能作业
##   stun       不能移动、不能作业
##   slow       速度 × (1 - magnitude)
##   invincible 免伤（受击后的无敌帧、冲撞技能）
##   shield     吸收 magnitude 点伤害，打空即失效
##   nitro      速度 × 1.65，免疫减速与击退
##   overheat   不能作业（热量满）

signal applied(kind: String, duration: float)
signal expired(kind: String)

const KINDS := ["burning", "fear", "stun", "slow", "invincible", "shield", "nitro", "overheat"]
const LABELS := {"burning": "灼烧", "fear": "恐惧", "stun": "眩晕", "slow": "减速", "invincible": "无敌", "shield": "护盾", "nitro": "氮气", "overheat": "过热"}
const COLORS := {"burning": Color("#E3A52B"), "fear": Color("#8C7BA8"), "stun": Color("#EFE3C8"), "slow": Color("#5FB7C9"), "invincible": Color("#EFE3C8"), "shield": Color("#5FB7C9"), "nitro": Color("#D9412B"), "overheat": Color("#D9412B")}

var timers: Dictionary = {}
var magnitudes: Dictionary = {}
## 抗性：kind -> 0..1（Boss 对控制抗性高）
var resist: Dictionary = {}

func apply(kind: String, duration: float, magnitude := 0.0) -> bool:
	if not KINDS.has(kind) or duration <= 0.0:
		return false
	var r := float(resist.get(kind, 0.0))
	if r >= 1.0:
		return false
	duration *= (1.0 - r)
	# 氮气期间免疫减速；无敌期间免疫控制
	if kind == "slow" and has("nitro"):
		return false
	if (kind == "stun" or kind == "fear") and has("invincible"):
		return false
	var fresh := not has(kind)
	timers[kind] = maxf(float(timers.get(kind, 0.0)), duration)
	magnitudes[kind] = maxf(float(magnitudes.get(kind, 0.0)), magnitude) if not fresh else magnitude
	if fresh:
		applied.emit(kind, duration)
	return true

func has(kind: String) -> bool:
	return float(timers.get(kind, 0.0)) > 0.0

func remaining(kind: String) -> float:
	return maxf(0.0, float(timers.get(kind, 0.0)))

func magnitude(kind: String) -> float:
	return float(magnitudes.get(kind, 0.0)) if has(kind) else 0.0

func clear(kind := "") -> void:
	if kind.is_empty():
		for k in timers.keys():
			if has(k):
				expired.emit(k)
		timers.clear()
		magnitudes.clear()
		return
	if has(kind):
		timers.erase(kind)
		magnitudes.erase(kind)
		expired.emit(kind)

## 净化负面状态（医护/维修技能）
func cleanse() -> int:
	var n := 0
	for k in ["burning", "fear", "stun", "slow"]:
		if has(k):
			clear(k)
			n += 1
	return n

## 推进时间；返回本帧灼烧伤害
func tick(delta: float) -> float:
	var burn := magnitude("burning") * delta
	for k in timers.keys():
		var before := float(timers[k])
		if before <= 0.0:
			continue
		timers[k] = before - delta
		if float(timers[k]) <= 0.0:
			timers.erase(k)
			magnitudes.erase(k)
			expired.emit(k)
	return burn

func speed_multiplier() -> float:
	if has("stun"):
		return 0.0
	var m := 1.0
	if has("slow"):
		m *= clampf(1.0 - magnitude("slow"), 0.2, 1.0)
	if has("nitro"):
		m *= 1.65
	if has("fear"):
		m *= 1.1
	return m

func can_act() -> bool:
	return not has("stun") and not has("fear") and not has("overheat")

func can_move() -> bool:
	return not has("stun")

## 受伤结算：返回实际扣血量（无敌 → 0；护盾先吸收）
func absorb(amount: float) -> float:
	if amount <= 0.0 or has("invincible"):
		return 0.0
	if has("shield"):
		var hp := magnitude("shield")
		if hp >= amount:
			magnitudes["shield"] = hp - amount
			if hp - amount <= 0.01:
				clear("shield")
			return 0.0
		clear("shield")
		return amount - hp
	return amount

func active_list() -> Array:
	var out := []
	for k in KINDS:
		if has(k):
			out.append(k)
	return out

func get_snapshot() -> Dictionary:
	return {"timers": timers.duplicate(), "magnitudes": magnitudes.duplicate()}

func restore_snapshot(data: Dictionary) -> void:
	timers = (data.get("timers", {}) as Dictionary).duplicate()
	magnitudes = (data.get("magnitudes", {}) as Dictionary).duplicate()
