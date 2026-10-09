class_name AreaHazard
extends Node3D

## C17 地面区域（技能用）：
##   mine   触发地雷：敌人进入 trigger_radius → 预警闪 0.15s → 爆炸（radius 范围伤害 + 击退）
##   fire   火区：持续 duration，范围内敌人每 0.5s 受伤并灼烧
##   tar    焦油：范围内敌人减速 70%
##   tesla  电磁塔：每 1.2s 麻痹 radius 内敌人 0.5s 并造成伤害
##   heal   治疗区：载具在范围内每秒回复 damage 点

var hz_kind := "mine"
var radius := 2.5
var trigger_radius := 1.3
var damage := 20.0
var duration := 8.0
var _age := 0.0
var _pulse := 0.0
var _armed := false
var _fuse := -1.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D

const COLORS := {"mine": Color("#D9412B"), "fire": Color("#E3A52B"), "tar": Color("#1B1B1D"), "tesla": Color("#8C7BA8"), "heal": Color("#8FD694")}

static func spawn(parent: Node, k: String, at: Vector3, r: float, dmg: float, life: float) -> AreaHazard:
	var h := AreaHazard.new()
	h.hz_kind = k
	h.radius = r
	h.damage = dmg
	h.duration = life
	h.position = Vector3(at.x, 0.06, at.z)
	parent.add_child(h)
	return h

func _ready() -> void:
	name = "Hazard_" + hz_kind
	add_to_group("hazards")
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var c: Color = COLORS.get(hz_kind, Color.WHITE)
	_mesh = MeshInstance3D.new()
	if hz_kind == "mine":
		var sm := CylinderMesh.new()
		sm.top_radius = 0.28
		sm.bottom_radius = 0.38
		sm.height = 0.2
		sm.radial_segments = 8
		_mesh.mesh = sm
		_mat.albedo_color = c
		_mesh.position.y = 0.1
	elif hz_kind == "tesla":
		var cm := CylinderMesh.new()
		cm.top_radius = 0.12
		cm.bottom_radius = 0.4
		cm.height = 1.8
		_mesh.mesh = cm
		_mat.albedo_color = c
		_mesh.position.y = 0.9
	else:
		var dm := CylinderMesh.new()
		dm.top_radius = radius
		dm.bottom_radius = radius
		dm.height = 0.03
		dm.radial_segments = 24
		_mesh.mesh = dm
		_mat.albedo_color = Color(c, 0.42 if hz_kind != "tar" else 0.6)
	_mesh.material_override = _mat
	add_child(_mesh)
	_mesh.name = "VfxHazardBody"
	if VfxKit.parent() == null:
		return
	var fx: GPUParticles3D = null
	match hz_kind:
		"fire":
			fx = VfxKit.emitter("embers", Color("#E3A52B"), clampf(radius, 0.8, 1.8), 2.2)
			(fx.process_material as ParticleProcessMaterial).emission_sphere_radius = radius * 0.8
			var smoke := VfxKit.emitter("smoke", Color(0.3, 0.27, 0.25, 0.55), clampf(radius * 0.6, 0.5, 1.2), 0.5)
			smoke.position.y = 0.8
			add_child(smoke)
		"tar":
			fx = VfxKit.emitter("dust", Color(0.12, 0.11, 0.1, 0.8), 0.35, 0.8)
			(fx.process_material as ParticleProcessMaterial).emission_sphere_radius = radius * 0.7
		"heal":
			fx = VfxKit.emitter("heal", Color("#8FD694"), 0.8, 0.8)
			(fx.process_material as ParticleProcessMaterial).emission_sphere_radius = radius * 0.8
		"tesla":
			fx = VfxKit.emitter("shock", Color("#C9B8F0"), 0.4, 0.6)
			fx.position.y = 1.8
	if fx != null:
		fx.position.y = maxf(fx.position.y, 0.2)
		add_child(fx)
	if hz_kind == "mine":
		_blink = MeshInstance3D.new()
		_blink.name = "VfxMineLight"
		var bm := SphereMesh.new()
		bm.radius = 0.12
		bm.height = 0.24
		_blink.mesh = bm
		_blink.material_override = VfxKit.flat_mat(Color("#FF5A3C"), true)
		_blink.position.y = 0.28
		add_child(_blink)

var _blink: MeshInstance3D

func _enemies_within(r: float) -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is EnemyDummy and not n.dead and not n.packed:
			var d := Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length()
			if d <= r + (1.2 if n is BossEntity else 0.4):
				out.append(n)
	return out

func _process(delta: float) -> void:
	_age += delta
	if has_meta("follow"):
		for p in get_tree().get_nodes_in_group("player_vehicle"):
			global_position = Vector3(p.global_position.x, 0.06, p.global_position.z)
			break
	if _age >= duration and _fuse < 0.0:
		if hz_kind == "mine":
			_explode()
		else:
			queue_free()
		return
	match hz_kind:
		"mine":
			_armed = _age > 0.35
			_mesh.position.y = 0.1 + absf(sin(_age * 6.0)) * 0.04
			if _blink != null:
				_blink.visible = fmod(_age, 0.08 if _fuse >= 0.0 else 0.8) < (0.04 if _fuse >= 0.0 else 0.12)
			if _fuse >= 0.0:
				_fuse -= delta
				_mat.albedo_color = Color.WHITE if int(_fuse * 30.0) % 2 == 0 else COLORS["mine"]
				if _fuse <= 0.0:
					_explode()
			elif _armed and not _enemies_within(trigger_radius).is_empty():
				_fuse = 0.15
		"fire":
			_pulse -= delta
			_mat.albedo_color.a = 0.32 + 0.12 * sin(_age * 14.0)
			if _pulse <= 0.0:
				_pulse = 0.5
				for e in _enemies_within(radius):
					e.status.apply("burning", 2.0, 5.0)
					e.take_damage(damage * 0.5, "burn")
		"tar":
			for e in _enemies_within(radius):
				e.status.apply("slow", 0.4, 0.7)
		"tesla":
			_pulse -= delta
			if _pulse <= 0.0:
				_pulse = 1.2
				for e in _enemies_within(radius):
					e.status.apply("stun", 0.5)
					e.take_damage(damage, "shock")
					VfxKit.lightning(global_position + Vector3(0, 1.8, 0), e.global_position + Vector3(0, 0.8, 0), COLORS["tesla"].lightened(0.4))
				if GameFeel.instance != null:
					GameFeel.instance.impact_ring(global_position, radius, COLORS["tesla"], 0.3)
		"heal":
			for p in get_tree().get_nodes_in_group("player_vehicle"):
				if p.global_position.distance_to(global_position) <= radius + 1.0:
					p.health = minf(float(p.health) + damage * delta, float(p.max_health))

func _explode() -> void:
	for e in _enemies_within(radius):
		e.take_damage(damage)
		e.apply_knockback(e.global_position - global_position, 10.0)
	if GameFeel.instance != null:
		GameFeel.instance.shake(0.25)
		GameFeel.instance.hitstop(0.05, 0.05)
	VfxKit.explosion(global_position, radius, COLORS["mine"])
	queue_free()
