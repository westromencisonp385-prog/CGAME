class_name LootPickup
extends Node3D

## C17 磁吸掉落（对齐 VehicleItemMagnetDrop）：敌人死亡喷出银币 / 维修件，
## 先抛物线弹出落地，再在收集半径内加速飞向载具——“吸金”的爽感来自加速曲线和到手时的小数字。

signal collected(kind: String, amount: int)

var kind := "silver"   # silver / repair
var amount := 1
var _vel := Vector3.ZERO
var _age := 0.0
var _grounded := false
var _homing := false
var _speed := 0.0
var collect_radius := 4.5
var _mesh: Node3D

static func burst(parent: Node, at: Vector3, count: int, value_each: int, loot_kind := "silver") -> Array:
	var out := []
	for i in count:
		var p := LootPickup.new()
		p.kind = loot_kind
		p.amount = value_each
		var a := randf() * TAU
		var s := randf_range(2.0, 4.5)
		p._vel = Vector3(cos(a) * s, randf_range(5.0, 7.5), sin(a) * s)
		p.position = at + Vector3(0, 0.8, 0)
		parent.add_child(p)
		out.append(p)
	return out

func _ready() -> void:
	name = "Loot"
	add_to_group("loot")
	var authored := WorldDressing.instance_meshes(self, "prop_repair_kit" if kind == "repair" else "prop_coin")
	if authored != null:
		authored.scale = Vector3.ONE * (0.75 if kind == "repair" else 0.85)
		_mesh = authored
		return
	var mi := MeshInstance3D.new()
	_mesh = mi
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if kind == "repair":
		var bm := BoxMesh.new()
		bm.size = Vector3(0.36, 0.36, 0.36)
		mi.mesh = bm
		m.albedo_color = Color("#8FD694")
	else:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.22
		cm.height = 0.07
		cm.radial_segments = 10
		mi.mesh = cm
		mi.rotation_degrees.x = 90
		m.albedo_color = Color("#E3A52B")
	mi.material_override = m
	add_child(mi)

func _physics_process(delta: float) -> void:
	_age += delta
	_mesh.rotation.y += delta * 9.0
	var player: Node3D = null
	for n in get_tree().get_nodes_in_group("player_vehicle"):
		player = n
		break
	if _homing and player != null:
		_speed = minf(_speed + delta * 42.0, 30.0)
		var to := player.global_position + Vector3(0, 0.8, 0) - global_position
		if to.length() < 0.7:
			_collect(player)
			return
		global_position += to.normalized() * minf(_speed * delta, to.length())
		return
	if not _grounded:
		_vel.y -= 22.0 * delta
		position += _vel * delta
		if position.y <= 0.25:
			position.y = 0.25
			if absf(_vel.y) > 3.0:
				_vel.y = -_vel.y * 0.35  # 一次小弹跳
				_vel.x *= 0.5
				_vel.z *= 0.5
			else:
				_grounded = true
	else:
		position.y = 0.25 + absf(sin(_age * 4.0)) * 0.12
	if player != null and _age > 0.35:
		var r := collect_radius + float(player.get("collector_bonus") if player.get("collector_bonus") != null else 0.0)
		if player.global_position.distance_to(global_position) < r:
			_homing = true
	if _age > 25.0:
		queue_free()

func _collect(player: Node3D) -> void:
	collected.emit(kind, amount)
	if kind == "repair" and player.get("health") != null:
		player.health = minf(float(player.health) + float(amount), float(player.max_health))
	if GameFeel.instance != null:
		GameFeel.instance.number(player.global_position + Vector3(0.6, 0.2, 0), amount, "heal" if kind == "repair" else "crit")
	var c := VfxKit.HEAL if kind == "repair" else VfxKit.OCHRE
	VfxKit.burst(global_position + Vector3(0, 0.5, 0), "stars", c, 0.6, 0.6)
	if kind == "repair":
		VfxKit.burst(player.global_position + Vector3(0, 0.8, 0), "heal", c, 0.8, 0.8)
	WanderburgAudio.hit("silver_gain", -16.0, 0.12)
	queue_free()
