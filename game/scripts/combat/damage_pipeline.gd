class_name DamagePipeline
extends RefCounted

## B1 统一伤害管线（docs/design/combat-v1.md §3.2）
## 所有我方对敌伤害最终都进 EnemyDummy.take_damage(amount, kind_tag, source)，
## 在那里调用 resolve() 做减免，再调用 record() 按来源记账。
##
## 来源 id 约定：
##   bite          挖斗咬合（含电弧连锁）
##   throw         投掷货物
##   dash          冲刺冲撞
##   summon        召唤物（炮塔 / 营地 / 脉冲）
##   auto:<id>     模块自动攻击
##   cast:<id>     模块主动技能
##   other         没有标注来源（应当越来越少，测试里会检查占比）
##
## 同步调用链（技能里直接 take_damage 的地方）用 push()/pop() 提供上下文；
## 异步的弹道 / 地面区域在创建时用 current() 记住来源。

static var ledger: Dictionary = {}   # source -> 实际造成的伤害（不含溢出）
static var hit_count: Dictionary = {}
static var kill_count: Dictionary = {}
static var _stack: Array[String] = []

const LABELS := {"bite": "挖斗咬合", "throw": "投掷", "dash": "冲刺冲撞", "summon": "召唤物", "other": "其他"}

static func reset() -> void:
	ledger.clear()
	hit_count.clear()
	kill_count.clear()
	_stack.clear()

static func push(source: String) -> void:
	_stack.append(source)

static func pop() -> void:
	if not _stack.is_empty():
		_stack.pop_back()

static func current() -> String:
	return _stack.back() if not _stack.is_empty() else "other"

## 减免：护甲按次减固定值（至少保留 20%），再乘目标的受伤倍率（正面盾、破韧等在 B3/B5 里写这个倍率）
static func resolve(target: Object, amount: float) -> float:
	var a := maxf(0.0, amount)
	if a <= 0.0 or target == null:
		return 0.0
	var armor := float(target.get("armor")) if target.get("armor") != null else 0.0
	if armor > 0.0:
		a = maxf(a * 0.2, a - armor)
	var taken = target.get("damage_taken_mult")
	if taken != null:
		a *= float(taken)
	return a

static func record(source: String, dealt: float, killed: bool) -> void:
	var s := source if not source.is_empty() else "other"
	ledger[s] = float(ledger.get(s, 0.0)) + maxf(dealt, 0.0)
	hit_count[s] = int(hit_count.get(s, 0)) + 1
	if killed:
		kill_count[s] = int(kill_count.get(s, 0)) + 1

static func total() -> float:
	var t := 0.0
	for v in ledger.values():
		t += float(v)
	return t

## 来源归到「卡」：auto:x / cast:x 都算模块 x
static func module_of(source: String) -> String:
	if source.begins_with("auto:") or source.begins_with("cast:"):
		return source.substr(5)
	return ""

static func channel_of(source: String) -> String:
	if source.begins_with("auto:") or source == "bite":
		return "auto"
	if source.begins_with("cast:"):
		return "active"
	return source

## 按卡汇总，降序：[{key, label, damage, share, kills}]
static func summary(name_of: Callable = Callable()) -> Array:
	var grouped: Dictionary = {}
	var kills: Dictionary = {}
	for s in ledger:
		var key := module_of(s)
		if key.is_empty():
			key = s
		grouped[key] = float(grouped.get(key, 0.0)) + float(ledger[s])
		kills[key] = int(kills.get(key, 0)) + int(kill_count.get(s, 0))
	var t := maxf(total(), 0.001)
	var out: Array = []
	for k in grouped:
		var label := str(LABELS.get(k, k))
		if name_of.is_valid() and not LABELS.has(k):
			label = str(name_of.call(k))
		out.append({"key": k, "label": label, "damage": grouped[k], "share": float(grouped[k]) / t, "kills": kills[k]})
	out.sort_custom(func(a, b): return float(a.damage) > float(b.damage))
	return out

## 自动 / 主动 / 其他 三通道占比（平衡验收用）
static func channel_split() -> Dictionary:
	var out := {"auto": 0.0, "active": 0.0, "other": 0.0}
	for s in ledger:
		var c := channel_of(s)
		if c == "auto" or c == "active":
			out[c] = float(out[c]) + float(ledger[s])
		else:
			out["other"] = float(out["other"]) + float(ledger[s])
	return out
