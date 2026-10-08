class_name ModuleDefinitionV2
extends Resource

## 模块定义 v2（schema 对齐 Module2 关键字段组；旧 ModuleDefinition 保持兼容，由 loadout 侧继续引用）。

enum ModuleSlot { NONE, FRONT, SIDE, BACK, TOP, CREW, CAPTAIN }

@export_group("General")
@export var module_id: String = ""
@export var module_name: String = ""
@export_multiline var module_description: String = ""
@export_multiline var active_description: String = ""
@export var display_image: Texture2D
## 稀有度权重（对齐 Module2.rarity: float，参与升级池权重）
@export var rarity: float = 1.0

@export_group("Slots")
## 允许槽位（对齐 frontSlot/sideSlot/backSlot/topSlot/crewSlot/captainSlot 六布尔 → 数组）
@export var allowed_slots: Array[ModuleDefinitionV2.ModuleSlot] = []

@export_group("Active Ability")
@export var active_base_damage: float = 0.0
@export var active_base_cooldown: float = 5.0
@export var active_duration: float = 0.0
@export var active_range: float = 0.0
@export var active_ammo: int = 0
@export var ability_base_size: float = 1.0
@export var ability_max_size: float = 2.0
@export var ability_base_speed: float = 10.0
@export var ability_max_speed: float = 20.0
@export var activation_charges: int = 0

@export_group("Auto Attack (Passive)")
@export var passive_base_damage: float = 0.0
@export var auto_base_cooldown: float = 2.0
@export var passive_duration: float = 0.0
@export var passive_ammo: float = 0.0
@export var auto_attack_base_size: float = 1.0
@export var auto_attack_max_size: float = 2.0
@export var auto_attack_base_speed: float = 10.0
@export var auto_attack_max_speed: float = 20.0

@export_group("Upgrades")
## 常规升级池（安装后进全局升级池，对齐 UpgradesAddToPool）
@export var upgrades_pool: Array[UpgradeDefinition] = []
@export var legendary_upgrades: Array[UpgradeDefinition] = []
@export var special_upgrade_0a: UpgradeDefinition
@export var special_upgrade_0b: UpgradeDefinition
@export var special_upgrade_1a: UpgradeDefinition
@export var special_upgrade_1b: UpgradeDefinition

@export_group("Presentation")
@export var visual_scene_path: String = "res://scripts/module_visual.gd"
@export var color: Color = Color.WHITE
