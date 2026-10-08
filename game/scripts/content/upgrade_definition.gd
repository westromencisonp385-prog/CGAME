class_name UpgradeDefinition
extends Resource

## 模块升级定义（schema 对齐 ModuleUpgrade 用法面 + Module2 升级槽）。
## UpgradeType 语义：ult(大招)/passive(被动)/cooldown(冷却)/size(体型) 四维 + legendary/special 分支。

enum UpgradeType { ULT, PASSIVE, COOLDOWN, SIZE, LEGENDARY_A, LEGENDARY_B, SPECIAL_0A, SPECIAL_0B, SPECIAL_1A, SPECIAL_1B }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var type: UpgradeType = UpgradeType.PASSIVE
## 稀有度需求档（对齐 internalRarity / HasRequiredRarityValues）
@export var rarity_index: int = 0
## 数值效果：stat_name -> 每级加值
@export var stat_gains: Dictionary = {}
## 每个稀有度档的数值数组（对齐 GetRarityValue<T>(values, rarityIndex)）
@export var values_per_rarity: Array[float] = []

func gain(stat_name: String, level: int = 0) -> float:
	if not values_per_rarity.is_empty():
		var idx := clampi(level, 0, values_per_rarity.size() - 1)
		return values_per_rarity[idx]
	return float(stat_gains.get(stat_name, 0.0))
