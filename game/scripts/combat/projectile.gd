class_name Projectile
extends Node3D

## C17 飞行物：敌方弹道（喷油/炮弹/Boss 弹幕）与玩家弹道（火球/鱼叉/齐射）。
## 弹道可见、速度适中、可以躲 —— 远程敌人的压力来自走位而不是数值。
##   team = "enemy"：碰到玩家（player_vehicle 组）→ receive_damage + 可选状态
##   team = "player"：碰到首个敌人（enemies 组）→ on_hit.call(enemy, position)
## 视觉：一个发光小球 + 拉长的尾迹（沿速度方向拉伸的胶囊）。

var team := "enemy"
var velocity := Vector3.ZERO
var damage := 5.0
var hit_radius := 0.6
var lifetime := 3.0
var color := Color("#D9412B")
var status_kind := ""
var status_time := 0.0
var status_mag := 0.0
var pierce := 0
var on_hit: Callable
var on_expire: Callable
var size := 0.32
var _age := 0.0
var _hit_ids: Dictionary = {}
var _body: MeshInstance3D
var _trail: MeshInstance3D

static func fire(parent: Node, from: Vector3, dir: Vector3, spd: float, dmg: float, side := "enemy", tint := Color("#D9412B")) -> Projectile:
	var p := Projectile.new()
	p.team = side
	p.velocity = Vector3(dir.x, 0, dir.z).normalized() * spd
	p.damage = dmg
	p.color = tint
	p.position = Vector3(from.x, 0.9, from.z)
	parent.add_child(p)
	return p

func _ready() -> void:
	name = "Projectile"
	add_to_group("projectiles")
	add_to_group("projectiles_" + team)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	_body = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	_body.mesh = sm
	_body.material_override = m
	add_child(_body)
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.albedo_color = Color(color, 0.45)
	_trail = MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = size * 0.7
	cm.height = size * 5.0
	_trail.mesh = cm
	_trail.material_override = tm
	_trail.rotation_degrees.x = 90.0
	_trail.position = Vector3(0, 0, size * 2.2)
	var pivot := Node3D.new()
	pivot.name = "TrailPivot"
	pivot.add_child(_trail)
	add_child(pivot)
	_face()

func _face() -> void:
	if velocity.length() > 0.01:
		var pivot := get_node_or_null("TrailPivot") as Node3D
		if pivot != null:
			pivot.rotation.y = atan2(-velocity.x, -velocity.z)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_expire()
		return
	position += velocity * delta
	_face()
	if team == "enemy":
		for node in get_tree().get_nodes_in_group("player_vehicle"):
			var p := node as Node3D
			var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
			if d <= hit_radius + 1.0:
				if p.has_method("receive_damage"):
					p.receive_damage(damage)
				if not status_kind.is_empty() and p.get("status") != null:
					p.status.apply(status_kind, status_time, status_mag)
				_pop()
				return
	else:
		for node in get_tree().get_nodes_in_group("enemies"):
			if not node is EnemyDummy:
				continue
			var e := node as EnemyDummy
			if e.dead or e.packed or _hit_ids.has(e.get_instance_id()):
				continue
			var reach := hit_radius + (1.4 if e is BossEntity else 0.7)
			var d2 := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length()
			if d2 <= reach:
				_hit_ids[e.get_instance_id()] = true
				if on_hit.is_valid():
					on_hit.call(e, global_position)
				else:
					e.take_damage(damage)
				if pierce <= 0:
					_pop()
					return
				pierce -= 1

func _pop() -> void:
	if GameFeel.instance != null:
		GameFeel.instance.impact_ring(global_position, 1.2, color, 0.22)
	queue_free()

func _expire() -> void:
	if on_expire.is_valid():
		on_expire.call(global_position)
	queue_free()
