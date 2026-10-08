class_name AbilityEffects
extends RefCounted

## 技能施放的最小战斗映射：module_id → try_engineering_hit 的 source 标记。
## 对齐 EnemyDummy 的既省略分支：water 铺湿 / electric 干燥减伤 / dash 重型加成。

static func source_for(module_id: String) -> Dictionary:
	if module_id.begins_with("mage_cryo"):
		return {"water": true, "wet_duration": 4.0}
	if module_id.begins_with("mage_storm"):
		return {"electric": true}
	if module_id.begins_with("mage_void"):
		return {"dash": true}
	if module_id.begins_with("mage_pyro"):
		return {"burn": true}
	return {}
