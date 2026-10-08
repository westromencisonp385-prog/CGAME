class_name LuckEngine
extends RefCounted

## Luck/稀有度引擎（语义对齐 ModuleSelection：Roll/GetRarityProbabilities/CalculateLuckWeights）。
## GAP：LuckBaseWeights / PositiveLuckScaling / NegativeLuckScaling 的具体数值在原生码中，
## 此处为可调占位（约束：基础权重和为 1）；后续可通过 Ghidra 反汇编 RVA 0x5E9A50 精确还原。

enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

const RARITY_COUNT := 4

## 基础概率（luck=0 时）。占位值：common 62 / uncommon 26 / rare 9 / epic 3（%）
const LUCK_BASE_WEIGHTS: Array[float] = [62.0, 26.0, 9.0, 3.0]
## 正向 luck 时高档位获得权重（每点 luck 的增幅系数）
const POSITIVE_LUCK_SCALING: Array[float] = [0.94, 1.05, 1.28, 1.62]
## 负向 luck 时低档位获得权重
const NEGATIVE_LUCK_SCALING: Array[float] = [1.06, 0.95, 0.78, 0.52]

## luck：有效值域 [-N, +N]；positiveLuckRamp 控制正向增长趋缓（对齐 positiveLuckRamp 字段语义）
static func calculate_luck_weights(luck: float, ramp: float = 1.0) -> Array[float]:
	var weights: Array[float] = []
	weights.resize(RARITY_COUNT)
	var effective := effective_positive_luck(luck, ramp)
	for i in RARITY_COUNT:
		var scale: float = POSITIVE_LUCK_SCALING[i] if effective >= 0.0 else NEGATIVE_LUCK_SCALING[i]
		weights[i] = LUCK_BASE_WEIGHTS[i] * pow(scale, absf(effective))
	# 归一化
	var t := 0.0
	for w in weights:
		t += w
	for i in RARITY_COUNT:
		weights[i] /= t
	return weights

## 正向 luck 收益递减：effect = luck / (1 + luck / ramp)（可调 ramp）
static func effective_positive_luck(raw: float, ramp: float = 1.0) -> float:
	if raw <= 0.0:
		return raw
	return raw / (1.0 + raw / maxf(ramp, 0.01))

## 四档概率向量 (common, uncommon, rare, epic)
static func rarity_probabilities(luck: float, ramp: float = 1.0) -> Vector4:
	var w := calculate_luck_weights(luck, ramp)
	return Vector4(w[0], w[1], w[2], w[3])

## 抽取稀有度档位索引（0-3），对齐 ModuleSelection.Roll(luck)
static func roll(luck: float, rng: RandomNumberGenerator, ramp: float = 1.0) -> int:
	var w := calculate_luck_weights(luck, ramp)
	var x := rng.randf()
	var acc := 0.0
	for i in RARITY_COUNT:
		acc += w[i]
		if x <= acc:
			return i
	return RARITY_COUNT - 1

## 给一个 ProbabilityList<ModuleDefinition> 按 luck 抽取：先抽档位，再从对应稀有度池抽条目。
## pools: Array[ProbabilityList]，索引对应 Rarity 枚举；高档池空时逐档降级。
static func roll_from_pools(luck: float, pools: Array, rng: RandomNumberGenerator, ramp: float = 1.0) -> Variant:
	var tier := roll(luck, rng, ramp)
	for down in range(tier, -1, -1):
		var pool: ProbabilityList = pools[down]
		if not pool.is_empty():
			return pool.roll_item(rng)
	return null
