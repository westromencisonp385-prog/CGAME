class_name ProbabilityList
extends RefCounted

## 加权抽取容器（语义对齐 RNGNeeds ProbabilityList<T> 的用法面）。
## item 为 Variant（Resource 或任意对象），weight > 0。

var entries: Array[Dictionary] = []

func add(item: Variant, weight: float) -> void:
	if weight <= 0.0:
		push_warning("ProbabilityList: 非正权重被忽略 (%s, %s)" % [item, weight])
		return
	entries.append({"item": item, "weight": weight})

func total_weight() -> float:
	var t := 0.0
	for e in entries:
		t += e.weight
	return t

func is_empty() -> bool:
	return entries.is_empty()

## 按权重抽取一项；copy_pool=true 时返回随机索引，调用方也可直接用 roll_item。
func roll(rng: RandomNumberGenerator) -> int:
	if entries.is_empty():
		return -1
	var t := total_weight()
	var x := rng.randf() * t
	for i in entries.size():
		x -= entries[i].weight
		if x <= 0.0:
			return i
	return entries.size() - 1

func roll_item(rng: RandomNumberGenerator) -> Variant:
	var idx := roll(rng)
	return entries[idx].item if idx >= 0 else null

## 语义对齐 CopyArtifactPool：深拷贝条目，临时池变动不影响原池。
func clone() -> ProbabilityList:
	var c := ProbabilityList.new()
	for e in entries:
		c.add(e.item, e.weight)
	return c

static func from_pairs(pairs: Array) -> ProbabilityList:
	var pl := ProbabilityList.new()
	for p in pairs:
		pl.add(p[0], p[1])
	return pl
