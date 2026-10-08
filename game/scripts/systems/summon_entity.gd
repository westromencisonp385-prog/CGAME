class_name SummonEntity
extends Node3D

## C7 技能分支召唤物（对齐 ActiveModule 系列 13 技能的可召唤分支语义）：
## turret（对齐 TurretLayer/主动 Cannon 类）：驻留自动开火；
## emp（对齐主动 ForcePush 语义重写）：脉冲范围伤害；
## camp（对齐 Barracks 语义重写）：驻留治疗。
## 纯逻辑态（timer/charges/damage）可 headless 测试；视觉由 _build_visual 构建。

signal action_effect(kind: String, origin: Vector3, end: Vector3)
signal expired(summon: SummonEntity)

enum SummonKind { TURRET, EMP, CAMP }

const LIFETIME := {"turret": 12.0, "emp": 0.0, "camp": 10.0}
const INTERVALS := {"turret": 1.1, "emp": 0.0, "camp": 1.0}
const COLORS := {
	SummonKind.TURRET: Color("#f2c85c"),
	SummonKind.EMP: Color("#9dc7d1"),
	SummonKind.CAMP: Color("#78d6a8"),
}
const LABELS := {SummonKind.TURRET: "自动炮塔", SummonKind.EMP: "EMP 脉冲", SummonKind.CAMP: "临时营地"}

var summon_kind: SummonKind = SummonKind.TURRET
var damage: float = 4.0
var reach: float = 16.0
var heal_per_pulse: float = 5.0
var fire_timer := 0.0
var lifetime_left := 0.0
var pulses_fired := 0
var player: Node3D
var visual_root: Node3D

func configure(kind: SummonKind, at: Vector3, power: float) -> SummonEntity:
	summon_kind = kind
	position = at
	damage = power
	match kind:
		SummonKind.TURRET:
			reach = 16.0
			lifetime_left = LIFETIME["turret"]
		SummonKind.EMP:
			reach = 9.0
			lifetime_left = 0.0
		SummonKind.CAMP:
			reach = 5.0
			heal_per_pulse = 5.0
			lifetime_left = LIFETIME["camp"]
	fire_timer = 0.35
	return self

func _ready() -> void:
	_build_visual()
	if summon_kind == SummonKind.EMP:
		action_effect.emit("emp", global_position, global_position)
		pulses_fired += 1

func _build_visual() -> void:
	visual_root = ProceduralVisuals.load_visual(
		"summon_%s.tscn" % ["emp" if summon_kind == SummonKind.EMP else ("camp" if summon_kind == SummonKind.CAMP else "turret")],
		func(): return ProceduralVisuals.build_summon(COLORS[summon_kind], summon_kind == SummonKind.EMP, str(LABELS[summon_kind])))
	visual_root.name = "SummonVisual"
	add_child(visual_root)

func _process(delta: float) -> void:
	if lifetime_left > 0.0:
		lifetime_left -= delta
		if lifetime_left <= 0.0:
			expired.emit(self)
			queue_free()
			return
	fire_timer -= delta
	if fire_timer > 0.0:
		return
	var self_pos := global_position if is_inside_tree() else position
	match summon_kind:
		SummonKind.TURRET:
			fire_timer = INTERVALS["turret"]
			action_effect.emit("turret_fire", self_pos, self_pos)
		SummonKind.EMP:
			fire_timer = 999.0
		SummonKind.CAMP:
			fire_timer = INTERVALS["camp"]
			if player != null and is_instance_valid(player):
				var target := player.global_position if player.is_inside_tree() else player.position
				action_effect.emit("camp_heal", self_pos, target)

func remaining_lifetime() -> float:
	return maxf(0.0, lifetime_left)
