class_name CaptainDefinition
extends Resource

## 船长数据定义（对齐 Wanderburg 船长体系：被动天赋载体）。
## 船长不占模块槽，雇佣后天赋常驻（对齐 passive perk 语义）。

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## 天赋数值：stat_name -> additive/multiplier 值（与 ArtifactDefinition.get_modifier 同构）
@export var stat_modifiers: Dictionary = {}

func get_modifier(stat_name: String, default_value: float = 0.0) -> float:
	return float(stat_modifiers.get(stat_name, default_value))
