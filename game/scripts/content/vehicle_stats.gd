class_name VehicleStats
extends Resource

## 载具基础属性（schema 对齐 VMBaseStats，字段一一对应；曲线类字段首版简化为标量）。

@export_group("Identity")
@export var stats_name: String = ""
@export_multiline var description: String = ""
## 升级链：Tier2-5 底盘池（对齐 vehicleBasesPrefabsTier2..5 + nextUpgrade）
@export var next_upgrade: VehicleStats

@export_group("Body")
@export var max_hp: float = 100.0
@export var rigid_body_mass: int = 1000
@export var vehicle_size: float = 1.0
## 吞噬成长阶（对齐 vehicleSizeRank）
@export var vehicle_size_rank: int = 0
## 可吞噬的最高 size_rank（对齐 canAbsorbVehiclesOfSizeRank）
@export var can_absorb_vehicles_of_size_rank: int = 0
@export var collector_radius: float = 2.5

@export_group("Nitro")
@export var max_nitro: float = 100.0
@export var nitro_consumption_rate: float = 25.0
@export var nitro_regen_rate: float = 10.0

@export_group("Movement")
@export var max_velocity: float = 12.0
@export var max_velocity_reverse: float = 6.0
@export var slow_down_multiplier: float = 0.85
@export var breaking_multiplier: float = 1.0
## 主动技能槽数（对齐 activeSlotsCapacity，确证为 4）
@export var active_slots_capacity: int = 4

@export_group("Combat")
@export var range_add_to_enemy_attack: float = 0.0
@export var step_damage: float = 0.0
@export var step_damage_radius: float = 0.0
