class_name EnemyDummy
extends Node3D

const FORMAL_B01_MODEL := preload("res://assets/models/formal_slice/b01_reverse_crab_formal.glb")

signal defeated(enemy: EnemyDummy)
signal hit_player(amount: float)
signal action_effect(kind: String, origin: Vector3, end: Vector3)

@export var enemy_id: String = "crawler"
@export var health: float = 35.0
@export var speed: float = 1.2
@export var kind: String = "light" # light, heavy, ranged

var current_health: float = 35.0
var wet_time := 0.0
var dead := false
var player: Node3D
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var visual_root: Node3D
var shadow: MeshInstance3D
var attack_timer := 0.0
var _home_position := Vector3.ZERO
var _wobble_time := 0.0
var packed := false
var pack_used := false
## C11 程序化动画（可为 null，回落旧视觉）
var rig: ProceduralRig
## C16 原型（空 = 旧逻辑）
var archetype_id := ""
var tier := "minion"
var behavior := "chase"
var contact_damage := -1.0
var _beh_t := 0.0
var _dash_t := 0.0
var _charge_dir := Vector3.ZERO
var _orbit_sign := 1.0
signal elite_ability(enemy: EnemyDummy, center: Vector3, radius: float, damage: float)

func configure_archetype(new_id: String, archetype: String, at: Vector3 = Vector3.ZERO) -> EnemyDummy:
	var def: Dictionary = EnemyArchetypes.get_def(archetype)
	if def.is_empty():
		return configure(new_id, "light", 35.0, 1.3, at)
	configure(new_id, str(def["kind"]), float(def["hp"]), float(def["speed"]), at)
	archetype_id = archetype
	tier = str(def["tier"])
	behavior = str(def["behavior"])
	contact_damage = float(def["damage"])
	_orbit_sign = -1.0 if (new_id.hash() & 1) == 1 else 1.0
	_beh_t = float(new_id.hash() % 100) / 100.0
	return self

func configure(new_id: String, enemy_kind: String, hp: float, move_speed: float, at: Vector3 = Vector3.ZERO) -> EnemyDummy:
	enemy_id = new_id
	kind = enemy_kind
	health = hp
	current_health = hp
	speed = move_speed
	position = at
	_home_position = at
	return self

func _ready() -> void:
	add_to_group("enemies")
	if current_health <= 0.0:
		current_health = health
	_home_position = position
	_build_visual()
	var h := rig._model_height if rig != null else 1.2
	SkillVfx.attach_status_aura(self, status, h, maxf(h * 0.45, 0.5))
	if is_inside_tree() and not (self is BossEntity):
		call_deferred("_spawn_fx")

func _spawn_fx() -> void:
	if not is_inside_tree() or dead or packed or not visible:
		return
	var s := clampf(rig._model_height if rig != null else 1.0, 0.6, 2.0)
	SkillVfx.dust_ring(global_position, 1.3 * s)
	VfxKit.burst(global_position + Vector3(0, 0.3, 0), "debris", Color("#5a4a3a"), 0.6 * s, 0.8)
	if tier == "elite":
		SkillVfx.pillar(global_position, 1.4, 5.0, VfxKit.RED, 0.6)

func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "EnemyVisual"
	add_child(visual_root)
	shadow = _add_cylinder("ContactShadow", 0.58 if kind != "heavy" else 0.82, 0.025, Vector3(0, 0.025, 0), Color("#344542"))
	shadow.scale = Vector3(1.25, 1.0, 0.72)
	# The first formal slice uses an authored B01 candidate for one named enemy.
	# Gameplay state, AI, hit shape and save data remain EnemyDummy authority.
	if enemy_id == "crawler_a" and _attach_formal_b01_visual():
		return
	if not archetype_id.is_empty():
		var def: Dictionary = EnemyArchetypes.get_def(archetype_id)
		rig = ProceduralRig.attach(visual_root, str(def.get("slot", "")))
		if rig != null:
			position.y = maxf(position.y, 0.0)
			if tier == "elite":
				_add_elite_marks(str(def["name"]))
			return
	# C11：优先挂拆件 + 程序化动画版本（腿交替/履带震动/翅膀拍动），其次静态正式模型，最后白模。
	var rig_slot := "enemy_light_v2" if kind == "heavy" else ("enemy_ranged_v1" if kind == "ranged" else "enemy_light_v1")
	rig = ProceduralRig.attach(visual_root, rig_slot)
	if rig != null:
		position.y = maxf(position.y, 0.0)
		return
	# C10：白模全量替换——heavy/light/ranged 槽位优先挂 Weaver 正式模型，缺失回落白模。
	var formal_slot := "enemy_heavy" if kind == "heavy" else ("enemy_ranged" if kind == "ranged" else "enemy_light")
	if FormalModelLibrary.attach(visual_root, formal_slot, "EnemyFormalModel") != null:
		position.y = maxf(position.y, height_for_kind() * 0.5)
		return
	mesh_instance = MeshInstance3D.new()
	var mesh: Mesh
	var height := height_for_kind()
	if kind == "heavy":
		var heavy_mesh := BoxMesh.new()
		heavy_mesh.size = Vector3(1.5, height, 1.35)
		mesh = heavy_mesh
	else:
		var wedge := CylinderMesh.new()
		wedge.top_radius = 0.16
		wedge.bottom_radius = 0.58
		wedge.height = height
		wedge.radial_segments = 6
		mesh = wedge
	mesh_instance.mesh = mesh
	material = StandardMaterial3D.new()
	material.albedo_color = Color("#df604e") if kind != "heavy" else Color("#8c4b59")
	material.metallic = 0.2
	material.roughness = 0.68
	mesh_instance.material_override = material
	visual_root.add_child(mesh_instance)
	position.y = maxf(position.y, height * 0.5)
	_add_box("LeftTrack", Vector3(0.18, 0.22, 0.9 if kind != "heavy" else 1.1), Vector3(-0.42 if kind != "heavy" else -0.7, 0.12, 0), Color("#253d48"))
	_add_box("RightTrack", Vector3(0.18, 0.22, 0.9 if kind != "heavy" else 1.1), Vector3(0.42 if kind != "heavy" else 0.7, 0.12, 0), Color("#253d48"))
	for side in [-1.0, 1.0]:
		_add_cylinder("TrackHub", 0.11 if kind != "heavy" else 0.16, 0.08, Vector3(side * (0.52 if kind != "heavy" else 0.82), 0.14, 0), Color("#f2c85c"), Vector3(0, 0, 90))
	# The enemy's readable behaviour shape is a leaning wedge or a heavy block;
	# the small warning plate adds comedy without turning it into a face.
	_add_box("WarningPlate", Vector3(0.75 if kind != "heavy" else 1.0, 0.1, 0.12), Vector3(0, height * 0.62, -0.36), Color("#f2c85c"))
	_add_box("WarningStripe", Vector3(0.18, 0.11, 0.4), Vector3(-0.31 if kind != "heavy" else -0.42, height * 0.62, -0.36), Color("#253d48"))
	_add_box("WarningStripe", Vector3(0.18, 0.11, 0.4), Vector3(0.31 if kind != "heavy" else 0.42, height * 0.62, -0.36), Color("#253d48"))
	if kind == "heavy":
		_add_box("HeavyShoulder", Vector3(1.85, 0.18, 0.45), Vector3(0, 0.65, -0.52), Color("#df604e"))
		_add_cylinder("HeavyBeacon", 0.18, 0.22, Vector3(0, height + 0.12, 0), Color("#f2c85c"))
	else:
		_add_cylinder("WobbleAntenna", 0.07, 0.75, Vector3(0.12, height * 0.72, 0.06), Color("#eee3c7"))

func _attach_formal_b01_visual() -> bool:
	if ProceduralRig.has_rig("enemy_crab_b01"):
		rig = ProceduralRig.attach(visual_root, "enemy_crab_b01")
		if rig != null:
			rig.name = "B01FormalVisualCandidate"
			position.y = maxf(position.y, 0.0)
			return true
	var model := FORMAL_B01_MODEL.instantiate() as Node3D
	if model == null:
		return false
	model.name = "B01FormalVisualCandidate"
	model.rotation_degrees.x = -90.0
	model.scale = Vector3.ONE * 0.82
	model.position = Vector3(0.0, -0.68, 0.0)
	visual_root.add_child(model)
	return true

func height_for_kind() -> float:
	return 1.4 if kind != "heavy" else 1.9

## 精英：头顶名牌（骨白字 + 红底，与 UI v2 一致）+ 旋转红色警示环
func _add_elite_marks(display: String) -> void:
	var h := rig._model_height if rig != null else 2.0
	var tag := Label3D.new()
	tag.name = "EliteNameplate"
	tag.text = "精英 · " + display
	tag.font = P5Theme.title_font()
	tag.font_size = 44
	tag.outline_size = 14
	tag.modulate = Color("#EFE3C8")
	tag.outline_modulate = Color("#D9412B")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.pixel_size = 0.006
	tag.position = Vector3(0, h + 0.55, 0)
	add_child(tag)
	var ring := MeshInstance3D.new()
	ring.name = "EliteRing"
	var tm := TorusMesh.new()
	tm.inner_radius = h * 0.55
	tm.outer_radius = h * 0.62
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("#D9412B")
	ring.material_override = m
	ring.position.y = 0.04
	ring.scale = Vector3(1, 0.2, 1)
	add_child(ring)

## 行为：返回本帧位移（不含近战判定）
func _behave(delta: float, offset: Vector3) -> Vector3:
	var dist := offset.length()
	var dir := offset.normalized() if dist > 0.01 else Vector3.ZERO
	_beh_t += delta
	match behavior:
		"hopper":
			if _dash_t > 0.0:
				_dash_t -= delta
				var u := 1.0 - clampf(_dash_t / 0.35, 0.0, 1.0)
				if visual_root != null:
					visual_root.position.y = sin(u * PI) * 1.1
				if _dash_t <= 0.0:
					if visual_root != null:
						visual_root.position.y = 0.0
					if rig != null and rig.juice != null:
						rig.juice.land(1.2)
					CombatVfx.puff(global_position, 0.6)
					SkillVfx.dust_ring(global_position, 1.0)
				return dir * speed * 2.6 * delta
			if _beh_t > 1.6:
				_beh_t = 0.0
				_dash_t = 0.35
				if rig != null:
					rig.play_attack(0.3, false, 0.05)
					if rig.juice != null:
						rig.juice.takeoff(1.2)
						rig.juice.snap_lean(rig.juice.world_to_local_dir(dir), 0.25)
				CombatVfx.puff(global_position, 0.45)
			return dir * speed * 0.4 * delta if dist > 1.8 else Vector3.ZERO
		"ranged":
			if dist < 4.5:
				return -dir * speed * delta
			if dist > 6.0:
				return dir * speed * delta
			return Vector3.ZERO
		"flyer":
			var side := Vector3(-dir.z, 0, dir.x) * _orbit_sign
			var radial := (dist - 3.0) * 0.6
			return (side + dir * radial).normalized() * speed * delta
		"roller":
			return dir * speed * (1.8 if dist < 5.0 else 1.0) * delta if dist > 1.6 else Vector3.ZERO
		"charger":
			if _dash_t > 0.0:
				_dash_t -= delta
				_trail_t -= delta
				if _trail_t <= 0.0:
					_trail_t = 0.06
					SkillVfx.afterimage(visual_root, VfxKit.RED, 0.2)
					CombatVfx.puff(global_position, 0.7)
				return _charge_dir * speed * 5.0 * delta
			if _beh_t > 3.2 and dist < 9.0:
				_beh_t = 0.0
				_charge_warned = false
				if _charge_dir.length() < 0.01:
					_charge_dir = dir
				_dash_t = 0.55
				if rig != null and rig.juice != null:
					rig.juice.release(1.5, rig.juice.world_to_local_dir(_charge_dir), true)
				SkillVfx.dust_ring(global_position, 2.0)
				SkillVfx.speed_lines(global_position, _charge_dir, VfxKit.RED)
				if rig != null:
					rig.play_attack(0.6, true, 0.05)
				if GameFeel.instance != null:
					GameFeel.instance.shake(0.15)
				return Vector3.ZERO
			if _beh_t > 2.4:
				# 蓄力停顿：锁定方向并在地面画出冲锋路径（读招窗口 0.8s）
				if not _charge_warned:
					_charge_warned = true
					_charge_dir = dir
					if rig != null and rig.juice != null:
						rig.juice.anticipate(1.4, 0.8, -rig.juice.world_to_local_dir(dir))
					if is_inside_tree():
						Telegraph.line(get_parent(), global_position, dir, speed * 5.0 * 0.55 + 1.5, 2.2, 0.8, func(_c: Vector3): pass)
				return Vector3.ZERO
			return dir * speed * delta if dist > 2.0 else Vector3.ZERO
		"caster":
			if _beh_t > 3.0:
				_beh_t = 0.0
				if rig != null:
					rig.play_attack(1.25, false, 0.72, 1.2, offset)
				var target_at := global_position + offset
				if is_inside_tree():
					var me := self
					Telegraph.circle(get_parent(), target_at, 2.6, 0.9, func(center: Vector3):
						if is_instance_valid(me) and not me.dead:
							me.action_effect.emit("arc_chain", me.global_position, center)
							me.elite_ability.emit(me, center, 2.6, contact_damage), Color("#8C7BA8"))
				else:
					elite_ability.emit(self, target_at, 2.6, contact_damage)
			if dist < 5.0:
				return -dir * speed * delta
			if dist > 7.0:
				return dir * speed * delta
			return Vector3.ZERO
	return dir * speed * delta if dist > 1.8 else Vector3.ZERO

func _add_box(node_name: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	var plate := StandardMaterial3D.new()
	plate.albedo_color = color
	plate.roughness = 0.72
	instance.material_override = plate
	(visual_root if visual_root != null else self).add_child(instance)
	return instance

func _add_cylinder(node_name: String, radius: float, height: float, at: Vector3, color: Color, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = rotation
	var cap := StandardMaterial3D.new()
	cap.albedo_color = color
	cap.roughness = 0.7
	instance.material_override = cap
	(visual_root if visual_root != null else self).add_child(instance)
	return instance

## C17 状态 / 击退 / 前摇
var status := StatusEffects.new()
var knock := Vector3.ZERO
var _windup := 0.0
var _windup_total := 0.0
var _burn_accum := 0.0
var _charge_warned := false
var _trail_t := 0.0
var knock_resist := 0.0

func _melee_damage() -> float:
	return contact_damage if contact_damage >= 0.0 else (4.0 if kind != "heavy" else 7.0)

func _attack_reach() -> float:
	return 6.8 if _is_ranged() else 2.3

func _is_ranged() -> bool:
	return behavior == "ranged" or (archetype_id.is_empty() and kind == "ranged")

func _process(delta: float) -> void:
	if dead:
		return
	_wobble_time += delta
	# 状态：灼烧掉血（累计到 1 点以上才结算，避免数字刷屏）
	var burn := status.tick(delta)
	if burn > 0.0:
		_burn_accum += burn
		if _burn_accum >= 3.0:
			take_damage(_burn_accum, "burn")
			_burn_accum = 0.0
			if dead:
				return
	# 击退：衰减速度
	if knock.length() > 0.01:
		global_position += knock * delta
		knock = knock.move_toward(Vector3.ZERO, delta * 22.0)
	if visual_root != null and rig == null:
		var wobble := sin(_wobble_time * (5.0 if kind != "heavy" else 2.2) + float(enemy_id.hash() % 13)) * (0.07 if kind != "heavy" else 0.025)
		visual_root.rotation.z = wobble
	if status.has("stun"):
		if visual_root != null:
			visual_root.rotation.z = sin(_wobble_time * 30.0) * 0.08
		return
	if player != null and is_instance_valid(player) and bool(player.get("gameplay_enabled")):
		var offset := player.global_position - global_position
		offset.y = 0.0
		var move_scale := status.speed_multiplier()
		if status.has("fear"):
			global_position -= offset.normalized() * speed * 1.2 * delta
		elif _windup > 0.0:
			pass  # 前摇时站定：给玩家读招
		elif archetype_id.is_empty():
			if _is_ranged():
				if offset.length() < 4.5:
					global_position -= offset.normalized() * speed * move_scale * delta
				elif offset.length() > 6.0:
					global_position += offset.normalized() * speed * move_scale * delta
			elif offset.length() > 1.8:
				global_position += offset.normalized() * speed * move_scale * delta
		else:
			global_position += _behave(delta, offset) * move_scale
			var ring := get_node_or_null("EliteRing") as Node3D
			if ring != null:
				ring.rotation.y += delta * 1.6
		if rig != null and offset.length() > 0.05:
			# 朝向玩家（模型 -Z 为正面）
			var target_yaw := atan2(-offset.x, -offset.z)
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, minf(delta * 6.0, 1.0))
		_tick_attack(delta, offset)
	if wet_time > 0.0:
		wet_time = maxf(0.0, wet_time - delta)
		if wet_time <= 0.0 and material != null:
			material.albedo_color = Color("#d5574e") if kind != "heavy" else Color("#8c4b59")

## 攻击：近战 = 前摇（身体压低 + 赭黄闪）→ 仍在范围内才出伤；远程 = 前摇后发射可躲的弹道
func _tick_attack(delta: float, offset: Vector3) -> void:
	if behavior == "caster" or status.has("fear"):
		return
	if _windup > 0.0:
		_windup -= delta
		if visual_root != null and rig == null:
			var k := 1.0 - _windup / maxf(_windup_total, 0.01)
			visual_root.scale = Vector3(1.0 + 0.12 * k, 1.0 - 0.14 * k, 1.0 + 0.12 * k)
		if _windup <= 0.0:
			if visual_root != null and rig == null:
				visual_root.scale = Vector3.ONE
			_release_attack(offset)
		return
	attack_timer -= delta
	if attack_timer > 0.0:
		return
	if offset.length() < _attack_reach():
		attack_timer = 2.2 if _is_ranged() else 1.4
		_windup_total = 0.42 if _is_ranged() else (0.38 if kind == "heavy" else 0.26)
		if behavior == "charger" and _dash_t > 0.0:
			_windup_total = 0.01  # 冲锋中直接撞
		_windup = _windup_total
		if rig != null:
			# 预备（蹲低 + 后仰）持续整个前摇，出手瞬间正好是伤害结算帧
			var dur := _windup_total + 0.32
			rig.play_attack(dur, kind == "heavy", _windup_total / dur, 1.2 if kind == "heavy" else 1.0, offset)
		if GameFeel.instance != null and visual_root != null and _windup_total > 0.05:
			GameFeel.instance.flash(visual_root, Color("#E3A52B"), _windup_total)

func _release_attack(offset: Vector3) -> void:
	if player == null or not is_instance_valid(player):
		return
	var now_offset := player.global_position - global_position
	now_offset.y = 0.0
	if _is_ranged():
		if is_inside_tree():
			var proj := Projectile.fire(get_parent(), global_position, now_offset, 9.5, _melee_damage(), "enemy", Color("#1B1B1D") if archetype_id == "oildrum" else Color("#D9412B"))
			VfxKit.muzzle(global_position, now_offset, Color("#3a3530") if archetype_id == "oildrum" else Color("#D9412B"), 0.9)
			if archetype_id == "oildrum":
				proj.status_kind = "slow"
				proj.status_time = 1.6
				proj.status_mag = 0.4
				proj.size = 0.38
		return
	if now_offset.length() > _attack_reach() + 0.5:
		CombatVfx.puff(global_position + now_offset.normalized() * 1.2, 0.5)
		return  # 玩家躲开了：前摇落空
	var dmg := _melee_damage()
	if behavior == "charger" and _dash_t > 0.0:
		dmg *= 1.6
	hit_player.emit(dmg)
	CombatVfx.swipe(global_position, now_offset.normalized(), 2.0, 2 if kind == "heavy" or behavior == "charger" else 0)
	if player.get("status") != null:
		if archetype_id == "mantis":
			player.status.apply("burning", 2.0, 3.0)
		elif behavior == "charger":
			player.status.apply("stun", 0.35)
	if player.has_method("apply_knock"):
		player.apply_knock(now_offset.normalized() * (9.0 if kind == "heavy" or behavior == "charger" else 4.0))

func apply_knockback(dir: Vector3, strength: float) -> void:
	if dead or packed:
		return
	var s := strength * (1.0 - knock_resist) * (0.5 if kind == "heavy" else 1.0)
	knock += Vector3(dir.x, 0, dir.z).normalized() * s
	if rig != null and rig.juice != null and s > 1.0:
		var l := rig.juice.world_to_local_dir(dir)
		rig.juice.snap_lean(l, clampf(s * 0.03, 0.08, 0.4))
		rig.juice.snap_stretch(l, clampf(s * 0.025, 0.06, 0.35))

func can_be_magnetized() -> bool:
	return not dead and not packed and not pack_used and kind == "light"

func pack_into_whale() -> bool:
	if not can_be_magnetized():
		return false
	packed = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	return true

func release_from_whale() -> bool:
	if not packed:
		return false
	packed = false
	pack_used = true
	visible = not dead
	process_mode = Node.PROCESS_MODE_PAUSABLE
	return true

func apply_wet(duration: float = 4.0) -> void:
	if dead:
		return
	wet_time = maxf(wet_time, duration)
	if material != null:
		material.albedo_color = Color("#63c8e4")

func is_wet() -> bool:
	return wet_time > 0.0

func try_engineering_hit(origin: Vector3, direction: Vector3, radius: float, reach: float, power: float, source: Dictionary = {}) -> Dictionary:
	if dead or packed:
		return {"hit": false, "dead": true, "wet_before": false, "target_id": enemy_id}
	var planar := global_position - origin
	planar.y = 0.0
	var distance := planar.length()
	var facing := direction.normalized().dot(planar.normalized()) if distance > 0.05 else 0.0
	if distance > reach + radius or distance < 0.05 or facing < 0.28:
		return {"hit": false, "dead": false, "wet_before": false, "target_id": enemy_id}
	var was_wet := is_wet()
	if bool(source.get("water", false)):
		apply_wet(float(source.get("wet_duration", 4.0)))
	var damage := power
	if kind == "heavy":
		damage *= 0.65
	if behavior == "roller":
		damage *= 0.7
	if bool(source.get("electric", false)) and not was_wet:
		damage *= 0.45
	if bool(source.get("dash", false)):
		damage *= 1.8
	_apply_source_status(source)
	var crit := bool(source.get("crit", false))
	take_damage(damage, "crit" if crit else str(source.get("number_kind", "normal")))
	var kb := float(source.get("knock", 3.5))
	if kb > 0.0:
		apply_knockback(planar, kb * (1.6 if crit else 1.0))
	action_effect.emit("hit", origin, global_position)
	return {"hit": true, "dead": dead, "wet_before": was_wet, "chain_eligible": was_wet and not dead, "target_id": enemy_id, "damage": damage, "crit": crit}

## 技能/投射物附带的状态
static var status_applied_count := 0

func _apply_source_status(source: Dictionary) -> void:
	var n := 0
	if bool(source.get("burn", false)) and status.apply("burning", float(source.get("burn_time", 3.0)), float(source.get("burn_dps", 4.0))):
		n += 1
	if bool(source.get("chill", false)) and status.apply("slow", float(source.get("chill_time", 2.5)), 0.5):
		n += 1
	if float(source.get("stun", 0.0)) > 0.0 and status.apply("stun", float(source["stun"])):
		n += 1
	if float(source.get("fear", 0.0)) > 0.0 and status.apply("fear", float(source["fear"])):
		n += 1
	status_applied_count += n

## kind：normal / crit / burn / frost / shock —— 只影响伤害数字的样式与顿帧力度
func take_damage(amount: float, kind_tag := "normal") -> void:
	if dead or packed:
		return
	var dealt := maxf(0.0, amount)
	current_health = maxf(0.0, current_health - dealt)
	if rig != null:
		var away := Vector3.ZERO
		if player != null and is_instance_valid(player):
			away = global_position - player.global_position
		rig.play_hit(away, clampf(0.7 + dealt / maxf(health, 1.0) * 3.0, 0.7, 1.6) * (0.5 if self is BossEntity else 1.0))
	var feel := GameFeel.instance
	if feel != null and dealt > 0.0 and is_inside_tree():
		if kind_tag == "burn":
			feel.number(global_position, dealt, "burn")
		else:
			feel.on_enemy_hit(self, dealt, kind_tag, kind == "heavy" or self is BossEntity)
	if current_health <= 0.0:
		dead = true
		if feel != null and is_inside_tree():
			feel.on_enemy_killed(self, "boss" if self is BossEntity else tier)
		if is_inside_tree():
			var hs := clampf(rig._model_height if rig != null else 1.0, 0.6, 3.0)
			SkillVfx.scrap_burst(global_position, hs)
			if self is BossEntity or tier == "elite":
				VfxKit.explosion(global_position, 2.0 * hs, VfxKit.RED)
		if rig != null and is_inside_tree():
			rig.play_death(0.9)
			get_tree().create_timer(0.9).timeout.connect(func():
				if is_instance_valid(self) and dead:
					visible = false)
		else:
			visible = false
		defeated.emit(self)

func pull_toward(point: Vector3, amount: float) -> bool:
	if not can_be_magnetized():
		return false
	var offset := point - global_position
	if offset.length() <= 0.1:
		return false
	global_position += offset.normalized() * minf(amount, offset.length())
	return true

func get_snapshot() -> Dictionary:
	return {"schema": 1, "enemy_id": enemy_id, "kind": kind, "archetype": archetype_id, "position": [global_position.x, global_position.y, global_position.z], "current_health": current_health, "wet_time": wet_time, "dead": dead, "attack_timer": attack_timer, "packed": packed, "pack_used": pack_used}

func validate_snapshot(data: Dictionary) -> bool:
	if int(data.get("schema", 0)) != 1 or str(data.get("enemy_id", "")) != enemy_id or str(data.get("kind", "")) != kind:
		return false
	var saved_packed := bool(data.get("packed", false))
	var saved_dead := bool(data.get("dead", false))
	var saved_pack_used := bool(data.get("pack_used", false))
	if saved_packed and (saved_dead or saved_pack_used or kind != "light"):
		return false
	var p = data.get("position", null)
	var hp := float(data.get("current_health", -1.0))
	var wet := float(data.get("wet_time", -1.0))
	return ["light", "heavy", "ranged"].has(kind) and p is Array and p.size() == 3 and (typeof(p[0]) == TYPE_FLOAT or typeof(p[0]) == TYPE_INT) and (typeof(p[1]) == TYPE_FLOAT or typeof(p[1]) == TYPE_INT) and (typeof(p[2]) == TYPE_FLOAT or typeof(p[2]) == TYPE_INT) and is_finite(float(p[0])) and is_finite(float(p[1])) and is_finite(float(p[2])) and is_finite(hp) and hp >= 0.0 and hp <= health and is_finite(wet) and wet >= 0.0 and wet <= 60.0

func restore_snapshot(data: Dictionary) -> bool:
	if not validate_snapshot(data):
		return false
	var p: Array = data.get("position", [_home_position.x, _home_position.y, _home_position.z])
	if p.size() < 3:
		return false
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	current_health = clampf(float(data.get("current_health", health)), 0.0, health)
	wet_time = maxf(0.0, float(data.get("wet_time", 0.0)))
	dead = bool(data.get("dead", false))
	attack_timer = maxf(0.0, float(data.get("attack_timer", 0.0)))
	packed = bool(data.get("packed", false)) and not dead
	pack_used = bool(data.get("pack_used", false))
	visible = not dead and not packed
	process_mode = Node.PROCESS_MODE_DISABLED if packed else Node.PROCESS_MODE_PAUSABLE
	if dead:
		current_health = 0.0
	return true
