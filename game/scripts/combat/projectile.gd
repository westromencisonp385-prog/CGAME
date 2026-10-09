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
## 外观：auto（按颜色推断）/ fire / frost / bolt / shell / oil / orb
var style := "auto"
var _trail_fx: GPUParticles3D
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
	if style == "auto":
		style = _infer_style()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lerp(Color.WHITE, 0.45) if style != "oil" else color
	_body = MeshInstance3D.new()
	_body.name = "VfxProjectileCore"
	var stretch := 1.0
	match style:
		"bolt":
			var bm := CapsuleMesh.new()
			bm.radius = size * 0.45
			bm.height = size * 5.0
			bm.radial_segments = 8
			bm.rings = 2
			_body.mesh = bm
			_body.rotation_degrees.x = 90.0
			stretch = 0.6
		_:
			var sm := SphereMesh.new()
			sm.radius = size
			sm.height = size * 2.0
			sm.radial_segments = 12
			sm.rings = 6
			_body.mesh = sm
	_body.material_override = m
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 外辉：加色半透明大球
	var glow := MeshInstance3D.new()
	glow.name = "VfxProjectileGlow"
	var gm := SphereMesh.new()
	gm.radius = size * 1.9 * stretch
	gm.height = gm.radius * 2.0
	gm.radial_segments = 10
	gm.rings = 5
	glow.mesh = gm
	glow.material_override = VfxKit.flat_mat(Color(color, 0.35 if style != "oil" else 0.0), true)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if style != "oil" else BaseMaterial3D.BLEND_MODE_MIX
	tm.albedo_color = Color(color, 0.45)
	_trail = MeshInstance3D.new()
	_trail.name = "VfxProjectileTrail"
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
	pivot.add_child(_body)
	pivot.add_child(glow)
	add_child(pivot)
	# 粒子拖尾（世界坐标，留下一路轨迹）
	if VfxKit.parent() != null:
		var preset := "embers"
		var tint := color
		match style:
			"frost":
				preset = "frost"
			"shell", "orb":
				preset = "smoke"
				tint = Color(0.45, 0.42, 0.4, 0.55)
			"oil":
				preset = "water"
			"bolt":
				preset = "embers"
				tint = color.lerp(Color.WHITE, 0.3)
		_trail_fx = VfxKit.emitter(preset, tint, size * 1.6, 1.4)
		_trail_fx.name = "VfxProjectileParticles"
		var pm := _trail_fx.process_material as ParticleProcessMaterial
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 0.8
		pm.gravity = Vector3(0, 0.5 if preset != "water" else -6.0, 0)
		_trail_fx.lifetime = 0.35 if preset != "smoke" else 0.6
		add_child(_trail_fx)
	_face()

func _infer_style() -> String:
	if color.is_equal_approx(Color("#1B1B1D")):
		return "oil"
	if color.r > 0.8 and color.g > 0.55 and color.b < 0.3:
		return "fire"
	if color.b > 0.75 and color.r < 0.6:
		return "frost"
	return "orb"

## 拖尾粒子交给世界：脱离弹体、停止发射、自然消散
func _release_trail() -> void:
	if _trail_fx == null or not is_instance_valid(_trail_fx):
		return
	var parent := VfxKit.parent()
	if parent == null:
		return
	var gt := _trail_fx.global_transform
	remove_child(_trail_fx)
	parent.add_child(_trail_fx)
	_trail_fx.global_transform = gt
	_trail_fx.emitting = false
	var fx := _trail_fx
	get_tree().create_timer(fx.lifetime + 0.2).timeout.connect(func():
		if is_instance_valid(fx):
			fx.queue_free())
	_trail_fx = null

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
	_release_trail()
	if style == "oil":
		VfxKit.burst(global_position, "water", color, 1.0, 1.2)
		VfxKit.decal(global_position, 1.0, "splat", Color(color, 0.7), 2.0)
	else:
		VfxKit.impact(global_position, color, clampf(size * 3.0, 0.7, 1.6))
	queue_free()

func _expire() -> void:
	_release_trail()
	if on_expire.is_valid():
		on_expire.call(global_position)
	else:
		VfxKit.burst(global_position, "smoke", Color(color, 0.5), 0.4, 0.5)
	queue_free()
