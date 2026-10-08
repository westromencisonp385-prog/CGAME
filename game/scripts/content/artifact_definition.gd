class_name ArtifactDefinition
extends Resource

## 神器数据定义（schema 对齐 Artifact + ArtifactOption + ArtifactTag 体系）。

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## 是否进入 rare 池（对齐 Artifact.rare 与 rare_artifact_fallbacks）
@export var rare: bool = false
## 神器强度系数（对齐 artifact_factor）
@export var factor: float = 1.0
@export var icon: Texture2D
## 效果标签（对齐 ArtifactTag 体系）：修饰器按 tag 匹配应用
@export var tags: PackedStringArray = PackedStringArray()
## 数值修饰：stat_name -> additive/multiplier 值
@export var stat_modifiers: Dictionary = {}

func has_tag(tag: String) -> bool:
	return tags.has(tag)

func get_modifier(stat_name: String, default_value: float = 0.0) -> float:
	return float(stat_modifiers.get(stat_name, default_value))
