class_name M0VehicleController
extends CharacterBody3D

const CombatResolverScript = preload("res://scripts/combat_resolver.gd")

signal feedback(message: String)
signal state_changed
signal disabled
signal harvested(amount: int)
signal action_effect(kind: String, origin: Vector3, end: Vector3)

var assembler: LoadoutAssembler
var camera: Camera3D
var aim_direction := Vector3(0, 0, -1)
var cargo := 0
var max_cargo := 3
var heat := 0.0
var health := 100.0
## C9：耐久上限（神器/船长的 max_hp additive 加值在 _refresh_max_health 应用）
var max_health := 100.0
var max_speed := 7.0
var base_speed := 7.0
var primary_cooldown := 0.0
var throw_cooldown := 0.0
var dash_cooldown := 0.0
var charge := 0.0
var gameplay_enabled := true
var invulnerable := false
var dash_pending := false
var dash_remaining := 0.0
var dash_hit_ids: Array[String] = []
var packed_enemy_ids: Array[String] = []
var tool_anim_time := 0.0
var _last_position := Vector3.ZERO
var visual_root: Node3D
var bucket_visual: Node3D
var chassis_visual: Node3D
var boom_visual: Node3D
var cabin_visual: MeshInstance3D
## 部件化车身（player_stage01_whale）；进化后换 evolved_rig
var body_rig: ProceduralRig
## Weaver 资产车头朝 -X，游戏前方是 -Z
## 部件化车身朝向修正已统一到 ProceduralRig（manifest.forward）
const BODY_SCALE := 1.55
## 3C 驾驶状态
var heading := Vector3(0, 0, -1)
var _fwd_speed := 0.0
var _yaw_rate := 0.0
var _long_accel := 0.0
var _pitch := 0.0
var _roll := 0.0
var _head_yaw := 0.0
var _lunge := 0.0
var _last_move_dir := Vector3.ZERO
var aim_mode := "mouse"   # mouse / pad：最后使用的瞄准设备
## C13：进化形态（rank>=2 换二阶鲸正式模型）
var evolved_rig: ProceduralRig
var evolution_rank := 0
## C17 状态机 + 手感
signal damaged(amount: float)
signal dodged
signal status_changed(kind: String, active: bool)
var status := StatusEffects.new()
var knock_velocity := Vector3.ZERO
var crit_chance := 0.12
var crit_rng := RandomNumberGenerator.new()
const CRIT_MULT := 1.8
const IFRAME_TIME := 0.4
var _lean := Vector2.ZERO
var _fear_dir := Vector3.ZERO
var _burn_accum := 0.0

func apply_knock(v: Vector3) -> void:
	if status.has("nitro") or status.has("invincible"):
		return
	knock_velocity += Vector3(v.x, 0, v.z)
	var j := _juice()
	if j != null and v.length() > 1.0:
		var l := j.world_to_local_dir(v)
		j.snap_lean(l, clampf(v.length() * 0.025, 0.08, 0.32))
		j.snap_stretch(l, clampf(v.length() * 0.02, 0.05, 0.25))

func _rig() -> ProceduralRig:
	return evolved_rig if evolved_rig != null else body_rig

func _juice() -> AnimJuice:
	var r := _rig()
	return r.juice if r != null else null

## 按了但做不了（冷却 / 无货 / 过热 / 空槽）：摇头 + 拒绝音，0.35s 限频 —— 永远不让按键“没反应”
var _deny_anim_until := 0
func deny_feedback(text := "") -> void:
	var now := Time.get_ticks_msec()
	if now < _deny_anim_until:
		return
	_deny_anim_until = now + 350
	var j := _juice()
	if j != null:
		j.deny()
	WanderburgAudio.hit("deny", -14.0, 0.05)
	if not text.is_empty():
		feedback.emit(text)

func apply_evolution(rank: int) -> bool:
	evolution_rank = rank
	if rank < 2 or evolved_rig != null or visual_root == null:
		return evolved_rig != null
	var holder := Node3D.new()
	holder.name = "EvolvedForm"
	visual_root.add_child(holder)
	evolved_rig = ProceduralRig.attach(holder, "player_stage02_whale")
	if evolved_rig == null:
		holder.queue_free()
		return false
	holder.position.y = -0.55
	for child in visual_root.get_children():
		if child != holder and child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	if chassis_visual != null:
		chassis_visual.visible = false
	if boom_visual != null:
		boom_visual.visible = false
	evolved_rig.play_attack(0.6, true, 0.4, 1.4)
	if evolved_rig.juice != null:
		evolved_rig.juice.snap_squash(0.45)
		evolved_rig.juice.after(0.22, func(): evolved_rig.juice.kick_lift(3.0))
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0:
		aim_mode = "mouse"
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5 \
			and (event as InputEventJoypadMotion).axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		# 拿起手柄开车：在推右摇杆前先咬向车头
		if aim_mode == "mouse" and Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.25).length() < 0.1:
			aim_mode = "pad"

func _ready() -> void:
	add_to_group("player_vehicle")
	_create_collision()
	_create_visuals()
	_create_aim_reticle()
	_last_position = global_position
	status.applied.connect(func(k: String, _d: float): status_changed.emit(k, true))
	status.expired.connect(func(k: String): status_changed.emit(k, false))
	var aura := SkillVfx.attach_status_aura(self, status, 1.6, 1.5)
	if aura != null:
		aura.set("show_callouts", true)

func setup(module_assembler: LoadoutAssembler, gameplay_camera: Camera3D) -> void:
	assembler = module_assembler
	camera = gameplay_camera
	if not assembler.loadout_changed.is_connected(_on_loadout_changed):
		assembler.loadout_changed.connect(_on_loadout_changed)
	_on_loadout_changed(assembler.active_ids)

func _stats() -> Dictionary:
	if assembler != null and assembler.has_method("get_stats"):
		return assembler.get_stats()
	return {"power": 14.0, "reach": 3.0, "radius": 1.35, "speed": 7.0, "cargo_capacity": 3}

func _physics_process(delta: float) -> void:
	if not gameplay_enabled or health <= 0.0:
		return
	primary_cooldown = maxf(0.0, primary_cooldown - delta)
	throw_cooldown = maxf(0.0, throw_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	heat = maxf(0.0, heat - delta * (30.0 if status.has("overheat") else 12.0))
	tool_anim_time = maxf(0.0, tool_anim_time - delta)
	# C17：状态推进 —— 灼烧扣血、热量满进入过热
	var burn := status.tick(delta)
	if burn > 0.0:
		_burn_accum += burn
		if _burn_accum >= 2.0:
			_apply_raw_damage(_burn_accum, "burn")
			_burn_accum = 0.0
	if heat >= 99.5 and not status.has("overheat"):
		status.apply("overheat", 2.2)
		feedback.emit("过热！挖斗停转 2 秒")
		if GameFeel.instance != null:
			GameFeel.instance.shake(0.2)
	if boom_visual != null:
		boom_visual.rotation.x = sin(tool_anim_time * 28.0) * 0.22 if tool_anim_time > 0.0 else move_toward(boom_visual.rotation.x, 0.0, delta * 4.0)
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down", Tuning3C.get_f("drive", "stick_deadzone"))
	var move_dir := Vector3(movement.x, 0.0, movement.y)
	if status.has("fear"):
		if _fear_dir.length() < 0.1 or randf() < delta * 2.0:
			_fear_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		move_dir = _fear_dir
	if not status.can_move():
		move_dir = Vector3.ZERO
	_last_move_dir = move_dir
	_input_pose(move_dir)
	var stats := _stats()
	max_speed = float(stats.get("speed", base_speed)) * status.speed_multiplier()
	_drive(delta, move_dir)
	# 击退叠加在驾驶速度上，快速衰减
	if knock_velocity.length() > 0.01:
		velocity.x += knock_velocity.x
		velocity.z += knock_velocity.z
		knock_velocity = knock_velocity.move_toward(Vector3.ZERO, delta * 60.0)
	if visual_root != null:
		if status.has("invincible") and not status.has("nitro"):
			visual_root.visible = int(Time.get_ticks_msec() / 60) % 2 == 0
		else:
			visual_root.visible = true
	var before := global_position
	var pre_velocity := velocity
	move_and_slide()
	_wall_bounce(pre_velocity)
	var displacement := global_position.distance_to(before)
	_update_aim_from_movement(move_dir)
	if displacement > 0.01:
		record_drive_displacement(displacement)
	_update_body_pose(delta)
	_update_aim_reticle()
	_emit_drive_dust(delta)
	if body_rig != null and evolved_rig == null:
		body_rig.set_speed(absf(_fwd_speed))
	if evolved_rig != null:
		evolved_rig.set_speed(absf(_fwd_speed))
	if boom_visual != null:
		boom_visual.rotation.y = atan2(-aim_direction.x, -aim_direction.z)
	if assembler != null and assembler.visual_root != null:
		assembler.visual_root.rotation.y = atan2(-aim_direction.x, -aim_direction.z)
	if dash_pending:
		dash_remaining = maxf(0.0, dash_remaining - delta)
		_resolve_dash_contacts(before, global_position)
		if dash_remaining <= 0.0:
			dash_pending = false
			var jd := _juice()
			if jd != null:
				var fd := jd.world_to_local_dir(heading)
				jd.land(0.7)
				jd.snap_lean(-fd, 0.16)
				jd.snap_stretch(fd, -0.14)
	if Input.is_action_pressed("primary"):
		perform_primary()
	if Input.is_action_just_pressed("throw_cargo"):
		throw_cargo()
	if Input.is_action_just_pressed("dash"):
		try_dash()
	if assembler != null and assembler.has_tag("magnet"):
		_pull_nearby_targets(delta)
	state_changed.emit()
	_last_position = global_position

## ---------------------------------------------------------------- 3C 驾驶（docs/design/3c-v1.md §3）
## 坦克式朝向车：车头以转向速率追输入方向；速度沿车头，转弯保留前进份额；侧向速度按抓地衰减。
func _drive(delta: float, move_dir: Vector3) -> void:
	var d: Dictionary = Tuning3C.data()["drive"]
	var input_mag := minf(move_dir.length(), 1.0)
	var nitro := status.has("nitro")
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var fwd := planar.dot(heading)
	var lateral := planar - heading * fwd
	var prev_heading := heading
	var target_speed := 0.0
	if input_mag > 0.01:
		var want := move_dir.normalized()
		var ang := heading.signed_angle_to(want, Vector3.UP)
		var abs_deg := absf(rad_to_deg(ang))
		var speed_frac := clampf(absf(fwd) / maxf(max_speed, 0.1), 0.0, 1.0)
		var rate := lerpf(float(d["turn_rate_still"]), float(d["turn_rate_full"]), speed_frac)
		var share := lerpf(1.0, float(d["forward_share_min"]), clampf(abs_deg / 90.0, 0.0, 1.0))
		if abs_deg > float(d["uturn_angle"]):
			rate *= float(d["uturn_turn_mult"])
			share = float(d["uturn_speed_share"])
		var step := deg_to_rad(rate) * delta
		heading = heading.rotated(Vector3.UP, clampf(ang, -step, step)).normalized()
		target_speed = max_speed * share * input_mag
	var accel := max_speed / maxf(float(d["accel_time"]), 0.05) * (2.2 if nitro else 1.0)
	var brake := max_speed / maxf(float(d["brake_time"]), 0.05) * (0.45 if nitro else 1.0)
	fwd = move_toward(fwd, target_speed, (accel if target_speed > fwd else brake) * delta)
	lateral *= exp(-float(d["grip"]) * delta)
	velocity.x = heading.x * fwd + lateral.x
	velocity.z = heading.z * fwd + lateral.z
	_yaw_rate = prev_heading.signed_angle_to(heading, Vector3.UP) / maxf(delta, 1e-4)
	_long_accel = lerpf(_long_accel, (fwd - _fwd_speed) / maxf(delta, 1e-4), minf(delta * 12.0, 1.0))
	_fwd_speed = fwd

## 撞墙：move_and_slide 已去掉法向分量，这里按入射速度补一个反弹并轻震
func _wall_bounce(pre_velocity: Vector3) -> void:
	var d: Dictionary = Tuning3C.data()["drive"]
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider() as Node
		if body == null or not body is StaticBody3D:
			continue
		var n := c.get_normal()
		n.y = 0.0
		if n.length() < 0.5:
			continue
		n = n.normalized()
		var into := -pre_velocity.dot(n)
		if into < float(d["wall_bounce_min_speed"]):
			continue
		velocity += n * into * float(d["wall_bounce"])
		_fwd_speed = Vector3(velocity.x, 0.0, velocity.z).dot(heading)
		var j := _juice()
		if j != null:
			var nl := j.world_to_local_dir(n)
			j.snap_stretch(nl, -clampf(into * 0.035, 0.1, 0.32))
			j.snap_lean(nl, clampf(into * 0.025, 0.06, 0.24))
		if GameFeel.instance != null:
			GameFeel.instance.shake(clampf(into * 0.015, 0.04, 0.14))
		break

## 驾驶输入的第 0 帧姿态（预备 → 惯性驱动接手）
var _prev_move := Vector3.ZERO
func _input_pose(move_dir: Vector3) -> void:
	var j := _juice()
	var mag := move_dir.length()
	var prev_mag := _prev_move.length()
	if j != null:
		if mag > 0.3 and prev_mag < 0.3:
			# 起步：压低、车头抬起，像蹬地
			var l := j.world_to_local_dir(move_dir)
			j.snap_squash(0.14)
			j.snap_lean(-l, 0.14)
			j.kick_push(l, 1.2)
		elif mag < 0.3 and prev_mag >= 0.3 and absf(_fwd_speed) > 2.5:
			# 松手刹车：前栽 + 沿前方拉长，然后弹回
			var f := j.world_to_local_dir(heading)
			j.snap_lean(f, 0.2)
			j.snap_stretch(f, 0.16)
		elif mag > 0.3 and prev_mag > 0.3 and move_dir.normalized().dot(_prev_move.normalized()) < -0.2:
			# 反向急打：扭身
			var turn := heading.signed_angle_to(move_dir, Vector3.UP)
			j.snap_yaw(clampf(turn * 0.25, -0.35, 0.35))
			j.snap_squash(0.1)
	_prev_move = move_dir

## 车身姿态：偏航 = 物理车头（+ 咬合甩头），俯仰 = 纵向加速度，侧倾 = 角速度 × 速度
func _update_body_pose(delta: float) -> void:
	var c: Dictionary = Tuning3C.data()["character"]
	var k := 1.0 - exp(-float(c["lean_k"]) * delta)
	var head_target := 0.0
	var lunge_target := 0.0
	if tool_anim_time > 0.0:
		var rel := heading.signed_angle_to(aim_direction, Vector3.UP)
		var lim := deg_to_rad(float(c["bite_head_turn_max_deg"]))
		head_target = clampf(rel, -lim, lim)
		lunge_target = float(c["bite_lunge"])
	var sk := 1.0 - exp(-float(c["bite_spring_k"]) * delta)
	_head_yaw = lerpf(_head_yaw, head_target, sk)
	_lunge = lerpf(_lunge, lunge_target, sk)
	var yaw := atan2(-heading.x, -heading.z) + _head_yaw
	if chassis_visual != null:
		chassis_visual.rotation.y = yaw
		chassis_visual.position = Vector3(heading.x, 0.0, heading.z) * _lunge + Vector3(0, chassis_visual.position.y, 0)
	if evolved_rig != null:
		(evolved_rig.get_parent() as Node3D).rotation.y = yaw
	var pmax := deg_to_rad(float(c["pitch_max_deg"]))
	var rmax := deg_to_rad(float(c["roll_max_deg"]))
	var pitch_t := clampf(_long_accel * float(c["pitch_per_accel"]) * 0.01745, -pmax, pmax)
	var roll_t := clampf(-_yaw_rate * absf(_fwd_speed) * float(c["roll_per_yawrate"]) * 10.0 * 0.01745, -rmax, rmax)
	_pitch = lerpf(_pitch, pitch_t, k)
	_roll = lerpf(_roll, roll_t, k)
	if visual_root != null:
		var right := heading.cross(Vector3.UP).normalized()
		visual_root.basis = Basis(right, _pitch) * Basis(heading, _roll)

## 当前驾驶读数（调试 / 测试）
var _dust_t := 0.0
func _emit_drive_dust(delta: float) -> void:
	var spd := absf(_fwd_speed)
	var turning := absf(_yaw_rate) > 2.0 and spd > 2.0
	var braking := _long_accel < -18.0
	if spd < 2.2 and not braking:
		return
	_dust_t -= delta * (2.0 if turning or braking else 1.0)
	if _dust_t > 0.0:
		return
	_dust_t = 0.09
	var right := heading.cross(Vector3.UP).normalized()
	var rear := global_position - heading * 1.4
	for s in [-1.0, 1.0]:
		CombatVfx.puff(Vector3(rear.x, 0.0, rear.z) + right * s * 0.8, 0.5 if turning or braking else 0.38)

func drive_state() -> Dictionary:
	return {"heading": heading, "fwd_speed": _fwd_speed, "yaw_rate": _yaw_rate, "long_accel": _long_accel}

func _update_aim_from_movement(move_dir: Vector3) -> void:
	var aim_input := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.25)
	if aim_input.length() > 0.1:
		aim_mode = "pad"
		aim_direction = Vector3(aim_input.x, 0.0, aim_input.y).normalized()
		return
	if aim_mode == "pad":
		# 摇杆模式松开右摇杆：挖斗咬向车头，符合“开车撞上去咬”的直觉
		aim_direction = heading
		return
	if camera == null:
		return
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return
	var ray_origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var ray_direction := camera.project_ray_normal(get_viewport().get_mouse_position())
	if absf(ray_direction.y) > 0.001:
		var distance := (global_position.y - ray_origin.y) / ray_direction.y
		var planar: Vector3 = ray_origin + ray_direction * distance - global_position
		planar.y = 0.0
		if planar.length() > 0.2:
			aim_direction = planar.normalized()

func perform_primary() -> Dictionary:
	if not gameplay_enabled or health <= 0.0 or primary_cooldown > 0.0:
		return {"performed": false, "hits": 0, "chain_hits": 0}
	if not status.can_act():
		if Input.is_action_just_pressed("primary"):
			deny_feedback("过热中 · 挖斗停转" if status.has("overheat") else "")
		return {"performed": false, "hits": 0, "chain_hits": 0, "reason": "status_blocked"}
	primary_cooldown = 0.32
	tool_anim_time = 0.24
	heat = minf(100.0, heat + 8.0)
	var now_ms := Time.get_ticks_msec()
	_combo_step = (_combo_step + 1) % 3 if now_ms < _combo_until else 0
	_combo_until = now_ms + 620
	var finisher := _combo_step == 2
	var stats := _stats()
	var reach := float(stats.get("reach", 3.0))
	var radius := float(stats.get("radius", 1.35))
	var power := float(stats.get("power", 14.0))
	var crit := crit_rng.randf() < crit_chance + _modifier("luck") * 0.01
	if crit:
		power *= CRIT_MULT
	var source := {"dash": false, "water": assembler != null and assembler.has_module("water_cannon"), "electric": assembler != null and assembler.has_module("electric_arc"), "wet_duration": 4.0, "crit": crit, "knock": 4.0 * (1.8 if finisher else 1.0)}
	if bool(source.water):
		action_effect.emit("water_beam", global_position, global_position + aim_direction * reach)
	var hit_count := 0
	var chain_hits := 0
	var pack_result := _try_pack_from_primary(reach, radius)
	var struck_enemies: Array[Node] = []
	for node in get_tree().get_nodes_in_group("engineering_targets"):
		if node is EngineeringTarget:
			var result: Dictionary = node.try_engineering_hit(global_position, aim_direction, radius, reach, power, source)
			if bool(result.get("hit", false)):
				hit_count += 1
				if GameFeel.instance != null:
					GameFeel.instance.flash(node)
					GameFeel.instance.shake(0.06)
					GameFeel.instance.hitstop(0.025, 0.05)
			var amount := int(result.get("harvested", 0))
			if amount > 0:
				cargo = mini(int(stats.get("cargo_capacity", max_cargo)), cargo + amount)
				harvested.emit(amount)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyDummy and not node.packed:
			var enemy_result: Dictionary = node.try_engineering_hit(global_position, aim_direction, radius, reach, power, source)
			if bool(enemy_result.get("hit", false)):
				hit_count += 1
				struck_enemies.append(node)
	if source.electric:
		for source_enemy in struck_enemies:
			if not is_instance_valid(source_enemy) or not source_enemy.is_wet():
				continue
			var chain_targets: Array[Node3D] = CombatResolverScript.select_chain_targets(source_enemy, get_tree().get_nodes_in_group("enemies"), 2, 4.5)
			for node in chain_targets:
				if node is EnemyDummy and node.packed:
					continue
				node.take_damage(power * 0.55)
				chain_hits += 1
				action_effect.emit("arc_chain", source_enemy.global_position, node.global_position)
	_bite_feedback(hit_count, finisher, reach, radius)
	return {"performed": true, "hits": hit_count, "chain_hits": chain_hits, "cargo": cargo, "packed": bool(pack_result.get("packed", false)), "packed_count": packed_enemy_ids.size(), "combo_step": _combo_step}

## 咬合的表现层：鲸口张合、扫弧、前扑、镜头顶、打击音。不改判定结果。
var _combo_step := 0
var _combo_until := 0
var _deny_until := 0

func _bite_feedback(hits: int, finisher: bool, reach: float, radius: float) -> void:
	var rig := _rig()
	var aim := Vector3(aim_direction.x, 0, aim_direction.z).normalized()
	if rig != null:
		# 预备只占 ~30ms：第 0 帧压低后缩、鲸口张开，紧接着前扑咬合
		rig.play_attack(0.36 if finisher else 0.28, finisher, 0.1, 1.15 if hits > 0 else 0.9, aim)
		if rig.juice != null:
			rig.juice.snap_yaw([0.28, -0.28, 0.0][_combo_step])
			if finisher:
				rig.juice.kick_lift(2.6)
	CombatVfx.swipe(global_position + aim * 0.5, aim, reach + radius * 0.5, _combo_step)
	# 前扑：打中更狠，收尾最狠；会被刹车 / 抓地吃掉，只是一下顶出去的手感
	var lunge := (3.2 if hits > 0 else 1.6) * (1.5 if finisher else 1.0)
	velocity += aim * lunge
	var feel := GameFeel.instance
	if feel != null:
		feel.kick(aim, (0.16 + 0.06 * mini(hits, 3)) * (1.6 if finisher else 1.0))
		if finisher and hits > 0:
			feel.hitstop(0.08, 0.02)
			feel.shake(0.3)
			feel.impact_ring(global_position + aim * reach, 2.4, Color("#D9412B"), 0.26)
		elif hits == 0:
			CombatVfx.dust(global_position + aim * reach, 0.9)
	if hits > 0:
		WanderburgAudio.hit("bite_heavy" if finisher else "bite_hit", -7.0 if finisher else -9.0)
	else:
		WanderburgAudio.hit("bite", -12.0, 0.12)

func throw_cargo() -> Dictionary:
	if not gameplay_enabled or throw_cooldown > 0.0:
		return {"performed": false, "hit": false}
	if not packed_enemy_ids.is_empty():
		return _release_packed_enemy()
	if cargo <= 0:
		var now_ms := Time.get_ticks_msec()
		if now_ms >= _deny_until:
			_deny_until = now_ms + 450
			feedback.emit("鲸口里没有废料 · 先咬碎废料堆")
			WanderburgAudio.hit("deny", -10.0, 0.0)
			if GameFeel.instance != null:
				GameFeel.instance.flash(visual_root, Color("#D9412B"), 0.1)
			var jn := _juice()
			if jn != null:
				jn.deny()
		return {"performed": false, "hit": false}
	throw_cooldown = 0.45
	cargo -= 1
	var damage := 24.0 + float(cargo) * 3.0 + (8.0 if assembler != null and assembler.has_module("wide_bucket") else 0.0)
	var best: Node = null
	var best_distance := 8.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is EnemyDummy or node.dead or node.packed:
			continue
		var planar: Vector3 = node.global_position - global_position
		planar.y = 0.0
		if planar.length() < best_distance and aim_direction.dot(planar.normalized()) > 0.55:
			best = node
			best_distance = planar.length()
	var aim := Vector3(aim_direction.x, 0, aim_direction.z).normalized()
	var origin := global_position
	var land: Vector3 = (best as Node3D).global_position if best != null else origin + aim * 5.0
	var fly := clampf(origin.distance_to(land) / 24.0, 0.15, 0.3)
	# 出手：鲸口吐出、车身后坐、镜头往后顶
	var rig := _rig()
	if rig != null:
		rig.play_attack(0.34, true, 0.2, 1.1, aim)
	velocity -= aim * 2.4
	WanderburgAudio.hit("throw_launch", -10.0)
	if GameFeel.instance != null:
		GameFeel.instance.kick(-aim, 0.14)
	var target := best
	CombatVfx.projectile(origin + aim * 1.2, land, fly, func():
		var at := land
		if target != null and is_instance_valid(target) and not target.dead:
			at = (target as Node3D).global_position
			target.take_damage(damage)
		action_effect.emit("throw", origin, at)
		WanderburgAudio.hit("throw_hit", -6.0)
		if GameFeel.instance != null:
			GameFeel.instance.impact_ring(at, 2.6, Color("#E3A52B"), 0.3)
			GameFeel.instance.shake(0.32 if target != null else 0.16)
			GameFeel.instance.kick(aim, 0.22)
			if target != null:
				GameFeel.instance.hitstop(0.06, 0.03))
	if best != null:
		feedback.emit("废料投掷命中")
		return {"performed": true, "hit": true}
	feedback.emit("废料投掷")
	return {"performed": true, "hit": false}

func pack_enemy(target: Node) -> Dictionary:
	if not gameplay_enabled or health <= 0.0:
		return {"packed": false, "reason": "vehicle_disabled"}
	if assembler == null or not assembler.has_module("magnet") or not assembler.has_module("wide_bucket"):
		return {"packed": false, "reason": "requires_whale_magnet_build"}
	if target == null or not is_instance_valid(target) or not target is EnemyDummy:
		return {"packed": false, "reason": "target_not_packable"}
	var enemy := target as EnemyDummy
	if enemy.enemy_id.begins_with("gm_"):
		return {"packed": false, "reason": "gm_target_not_saved"}
	if not enemy.can_be_magnetized():
		return {"packed": false, "reason": "target_rejected"}
	var capacity := mini(2, int(_stats().get("cargo_capacity", max_cargo)))
	if packed_enemy_ids.size() >= capacity:
		return {"packed": false, "reason": "pack_capacity_full"}
	if global_position.distance_to(enemy.global_position) > 3.4:
		return {"packed": false, "reason": "target_out_of_range"}
	if not enemy.pack_into_whale():
		return {"packed": false, "reason": "target_rejected"}
	packed_enemy_ids.append(enemy.enemy_id)
	action_effect.emit("whale_pack", global_position, enemy.global_position)
	feedback.emit("鲸口打包 · %s" % enemy.enemy_id)
	return {"packed": true, "target_id": enemy.enemy_id, "packed_count": packed_enemy_ids.size()}

func _try_pack_from_primary(reach: float, radius: float) -> Dictionary:
	var best: EnemyDummy = null
	var best_distance := minf(3.4, reach + radius)
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is EnemyDummy:
			continue
		var enemy := node as EnemyDummy
		if enemy.enemy_id.begins_with("gm_") or not enemy.can_be_magnetized():
			continue
		var planar: Vector3 = enemy.global_position - global_position
		planar.y = 0.0
		var distance := planar.length()
		if distance < 0.05 or distance > best_distance:
			continue
		if aim_direction.normalized().dot(planar.normalized()) < 0.45:
			continue
		best = enemy
		best_distance = distance
	if best == null:
		return {"packed": false, "reason": "no_pack_target"}
	return pack_enemy(best)

func _release_packed_enemy() -> Dictionary:
	if packed_enemy_ids.is_empty():
		return {"performed": false, "hit": false, "reason": "no_packed_enemy"}
	var target_id: String = str(packed_enemy_ids.pop_front())
	var target: EnemyDummy = null
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyDummy and node.enemy_id == target_id:
			target = node
			break
	throw_cooldown = 0.45
	if target == null or not is_instance_valid(target):
		return {"performed": true, "hit": false, "target_id": target_id, "packed_count": packed_enemy_ids.size(), "reason": "target_missing"}
	var origin := global_position
	var landing := origin + aim_direction.normalized() * 5.2
	landing.y = target.global_position.y
	target.release_from_whale()
	target.global_position = landing
	var damage := 48.0 + (12.0 if assembler != null and assembler.has_module("wide_bucket") else 0.0)
	target.take_damage(damage)
	var blast_hits := 0
	var hit_ids: Dictionary = {}
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is EnemyDummy:
			continue
		var enemy := node as EnemyDummy
		if enemy == target or enemy.dead or enemy.packed or hit_ids.has(enemy.enemy_id):
			continue
		if enemy.global_position.distance_to(landing) <= 1.75:
			enemy.take_damage(damage * 0.65)
			hit_ids[enemy.enemy_id] = true
			blast_hits += 1
	action_effect.emit("whale_release", origin, landing)
	feedback.emit("鲸口投掷 · %s" % target_id)
	return {"performed": true, "hit": true, "target_id": target_id, "damage": damage, "blast_hits": blast_hits, "landing": landing, "packed_count": packed_enemy_ids.size()}

func rebind_packed_enemies() -> void:
	var valid_ids: Array[String] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyDummy and packed_enemy_ids.has(node.enemy_id) and not node.dead and node.packed:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			valid_ids.append(node.enemy_id)
	packed_enemy_ids = valid_ids

func try_dash() -> bool:
	if not gameplay_enabled or dash_cooldown > 0.0 or not status.can_move():
		if gameplay_enabled and health > 0.0:
			deny_feedback("冲刺冷却 · %.1f 秒" % dash_cooldown if dash_cooldown > 0.0 else "")
		return false
	dash_cooldown = 1.8
	var dash_power := Tuning3C.get_f("dash", "power_flywheel") if assembler != null and assembler.has_module("inertia_flywheel") else Tuning3C.get_f("dash", "power")
	var dash_dir := _last_move_dir if _last_move_dir.length() > 0.2 else heading
	heading = Vector3(dash_dir.x, 0.0, dash_dir.z).normalized()
	_fwd_speed = maxf(_fwd_speed, 0.0) + dash_power
	velocity = Vector3(heading.x * _fwd_speed, velocity.y, heading.z * _fwd_speed)
	dash_pending = true
	dash_remaining = 0.35
	dash_hit_ids.clear()
	status.apply("nitro", 0.45)
	status.apply("invincible", 0.28)
	if GameFeel.instance != null:
		GameFeel.instance.fov_punch(7.0)
		GameFeel.instance.shake(0.1)
		GameFeel.instance.kick(heading, 0.2)
	SkillVfx.dash_trail(self, Color("#EFE3C8"), 0.32)
	SkillVfx.speed_lines(global_position, heading)
	SkillVfx.dust_ring(global_position, 0.9)
	var rig := _rig()
	if rig != null and rig.juice != null:
		var j := rig.juice
		var f := j.world_to_local_dir(heading)
		j.snap_squash(0.24)
		j.snap_lean(-f, 0.12)
		j.after(0.04, func():
			j.snap_squash(-0.2)
			j.snap_stretch(f, 0.55)
			j.snap_lean(f, 0.22)
			j.kick_lift(1.2))
	WanderburgAudio.hit("throw_launch", -11.0, 0.15)
	feedback.emit("液压冲刺")
	return true

func record_drive_displacement(distance: float) -> void:
	if distance <= 0.0:
		return
	charge = minf(100.0, charge + distance * (5.0 if assembler != null and assembler.has_module("inertia_flywheel") else 1.5))

func reset_vehicle(at: Vector3 = Vector3.ZERO) -> void:
	global_position = at
	health = 100.0
	cargo = 0
	heat = 0.0
	charge = 0.0
	primary_cooldown = 0.0
	throw_cooldown = 0.0
	dash_cooldown = 0.0
	dash_pending = false
	dash_remaining = 0.0
	dash_hit_ids.clear()
	packed_enemy_ids.clear()
	velocity = Vector3.ZERO
	aim_direction = Vector3(0, 0, -1)
	heading = Vector3(0, 0, -1)
	_fwd_speed = 0.0
	_yaw_rate = 0.0
	_long_accel = 0.0
	invulnerable = false
	gameplay_enabled = true
	status.clear()
	knock_velocity = Vector3.ZERO
	_combo_step = 0
	_combo_until = 0
	_burn_accum = 0.0

func _resolve_dash_contacts(from: Vector3, to: Vector3) -> void:
	if from.distance_to(to) < 0.04:
		return
	var multiplier := 1.8 if assembler != null and assembler.has_module("inertia_flywheel") and charge >= 20.0 else 1.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is EnemyDummy or node.dead:
			continue
		if node.global_position.distance_to(to) < 2.4 and not dash_hit_ids.has(node.enemy_id):
			node.take_damage(20.0 * multiplier, "crit" if multiplier > 1.0 else "normal")
			node.apply_knockback(node.global_position - to, 9.0 * multiplier)
			dash_hit_ids.append(node.enemy_id)
			if multiplier > 1.0:
				charge = 0.0
			action_effect.emit("dash_hit", from, node.global_position)

## C9：外部属性修饰提供者（main 注入：返回 stat_name -> bonus 值，神器+船长聚合）
var stat_modifier_provider: Callable = Callable()

func _modifier(stat_name: String) -> float:
	return 0.0 if stat_modifier_provider == null or not stat_modifier_provider.is_valid() else float(stat_modifier_provider.call(stat_name))

func receive_damage(amount: float) -> void:
	if invulnerable or health <= 0.0:
		return
	if status.has("invincible") and (dash_pending or status.has("nitro")):
		SkillVfx.afterimage(visual_root, Color("#7FD3E0"), 0.4)
		dodged.emit()
		return
	var mitigated := amount * (1.0 - clampf(_modifier("armor"), 0.0, 0.85))
	var shielded := status.has("shield")
	mitigated = status.absorb(mitigated)
	if mitigated <= 0.0:
		if shielded and GameFeel.instance != null:
			GameFeel.instance.number(global_position, amount, "shield")
			GameFeel.instance.impact_ring(global_position, 2.2, Color("#7FD3E0"), 0.22)
			VfxKit.burst(global_position + Vector3(0, 1.0, 0), "frost", Color("#7FD3E0"), 1.0, 1.0)
		return
	_apply_raw_damage(mitigated, "hit")
	var rig := evolved_rig if evolved_rig != null else body_rig
	if rig != null:
		rig.play_hit()
	VfxKit.impact(global_position + Vector3(0, 1.0, 0), Color("#D9412B"), 1.3)
	# 无敌帧：连续受击不会被瞬间秒掉，也给玩家脱身窗口
	if health > 0.0:
		status.apply("invincible", IFRAME_TIME)

func _apply_raw_damage(mitigated: float, source_tag: String) -> void:
	if invulnerable or health <= 0.0:
		return
	health = maxf(0.0, health - maxf(0.0, mitigated))
	damaged.emit(mitigated)
	if GameFeel.instance != null and is_inside_tree():
		if source_tag == "burn":
			GameFeel.instance.number(global_position, mitigated, "burn")
		else:
			GameFeel.instance.on_player_hurt(self, mitigated)
	feedback.emit("受到 %.0f 点伤害" % mitigated)
	if health <= 0.0:
		gameplay_enabled = false
		velocity = Vector3.ZERO
		status.clear()
		disabled.emit()
		feedback.emit("工程车失效，按 F9 恢复快照")

func on_module_visuals_changed() -> void:
	if body_rig != null and assembler != null:
		var jaw := body_rig.model.find_child("Jaw", true, false) as Node3D
		if jaw != null:
			var wide := assembler.has_module("wide_bucket")
			var big := wide and assembler.stage >= 2
			body_rig.set_part_scale(jaw, 1.32 if big else (1.15 if wide else 1.0))
		return
	if bucket_visual == null or assembler == null:
		return
	var wide := assembler.has_module("wide_bucket")
	bucket_visual.scale = Vector3(1.5, 0.8, 1.1) if wide else Vector3.ONE
	if bucket_visual.has_node("BucketMesh"):
		(bucket_visual.get_node("BucketMesh") as MeshInstance3D).material_override = _material(Color("#f2bd45") if wide else Color("#c68b31"))

func _on_loadout_changed(_active_ids: Array[String]) -> void:
	var stats := _stats()
	max_cargo = int(stats.get("cargo_capacity", 3))
	if (assembler == null or not assembler.has_module("magnet") or not assembler.has_module("wide_bucket")) and not packed_enemy_ids.is_empty():
		clear_packed_enemies()
	on_module_visuals_changed()

func clear_packed_enemies() -> void:
	var ids := packed_enemy_ids.duplicate()
	packed_enemy_ids.clear()
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyDummy and ids.has(node.enemy_id) and node.packed:
			node.global_position = global_position + aim_direction.normalized() * 1.8
			node.release_from_whale()

func _pull_nearby_targets(delta: float) -> void:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if count >= 4 or not node is EnemyDummy or not node.can_be_magnetized():
			continue
		if global_position.distance_to(node.global_position) < 5.5 and node.pull_toward(global_position, delta * 1.3):
			count += 1
	for node in get_tree().get_nodes_in_group("engineering_targets"):
		if count >= 4 or not node is EngineeringTarget or not node.can_be_magnetized():
			continue
		if global_position.distance_to(node.global_position) < 5.5 and node.pull_toward(global_position, delta * 0.7):
			count += 1

## ---------------------------------------------------------------- 瞄准指示（K5）
var _reticle: MeshInstance3D
var _bite_marker: MeshInstance3D
var _reticle_point := Vector3.ZERO

func _create_aim_reticle() -> void:
	if not bool(Tuning3C.get_v("aim", "reticle")):
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.937, 0.890, 0.784, 0.85)
	mat.no_depth_test = true
	mat.render_priority = 2
	_reticle = MeshInstance3D.new()
	_reticle.name = "VfxAimReticle"
	var ring := TorusMesh.new()
	var r := Tuning3C.get_f("aim", "reticle_radius")
	ring.inner_radius = r * 0.78
	ring.outer_radius = r
	ring.rings = 32
	ring.ring_segments = 4
	_reticle.mesh = ring
	_reticle.material_override = mat
	_reticle.scale = Vector3(1, 0.08, 1)
	_reticle.top_level = true
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_reticle)
	var mat2 := mat.duplicate() as StandardMaterial3D
	mat2.albedo_color = Color(0.851, 0.255, 0.169, 0.9)
	_bite_marker = MeshInstance3D.new()
	_bite_marker.name = "VfxBiteMarker"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 0.55, 0.06)
	_bite_marker.mesh = prism
	_bite_marker.material_override = mat2
	_bite_marker.top_level = true
	_bite_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bite_marker)

func _update_aim_reticle() -> void:
	if _reticle == null:
		return
	var reach := float(_stats().get("reach", 3.0))
	var base := Vector3(global_position.x, 0.06, global_position.z)
	var point := base + aim_direction * reach
	if aim_mode == "mouse" and camera != null and DisplayServer.get_name() != "headless":
		var mp := get_viewport().get_mouse_position()
		var o := camera.project_ray_origin(mp)
		var dir := camera.project_ray_normal(mp)
		if absf(dir.y) > 0.001:
			point = o + dir * ((0.06 - o.y) / dir.y)
	_reticle_point = point
	_reticle.global_position = point
	_reticle.visible = health > 0.0
	# 箭头：车前挖斗咬合距离处，指向瞄准方向；冷却中变淡
	var tip := base + aim_direction * (reach + 0.2)
	_bite_marker.global_transform = Transform3D(Basis.looking_at(aim_direction, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5), tip)
	(_bite_marker.material_override as StandardMaterial3D).albedo_color.a = 0.35 if primary_cooldown > 0.0 else 0.9
	_bite_marker.visible = health > 0.0

func _create_collision() -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.2, 2.0)
	collider.shape = shape
	collider.position.y = 0.6
	add_child(collider)

func _create_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VehicleVisuals"
	add_child(visual_root)
	# 车身 = 部件化鲸口车（A01 v3），方块底盘只在资产缺失时兜底
	var body_holder := Node3D.new()
	body_holder.name = "WhaleBody"
	visual_root.add_child(body_holder)
	body_rig = ProceduralRig.attach(body_holder, "player_stage01_whale")
	if body_rig != null:
		body_holder.position.y = -0.55
		body_holder.scale = Vector3.ONE * BODY_SCALE
		chassis_visual = body_holder
		return
	body_holder.queue_free()
	_create_whitebox_visuals()

func has_authored_body() -> bool:
	return body_rig != null

func _create_whitebox_visuals() -> void:
	chassis_visual = MeshInstance3D.new()
	var chassis_mesh := BoxMesh.new()
	chassis_mesh.size = Vector3(2.8, 0.72, 2.35)
	chassis_visual.mesh = chassis_mesh
	chassis_visual.material_override = _material(Color("#253d48"))
	visual_root.add_child(chassis_visual)
	for x in [-1.0, 1.0]:
		var track := MeshInstance3D.new()
		var track_mesh := BoxMesh.new()
		track_mesh.size = Vector3(0.52, 0.55, 2.55)
		track.mesh = track_mesh
		track.position = Vector3(x * 1.05, -0.25, 0.0)
		track.material_override = _material(Color("#171d22"))
		visual_root.add_child(track)
		var tread_band := MeshInstance3D.new()
		var band_mesh := BoxMesh.new()
		band_mesh.size = Vector3(0.08, 0.25, 2.2)
		tread_band.mesh = band_mesh
		tread_band.position = Vector3(x * 1.05 - x * 0.24, -0.25, 0.0)
		tread_band.material_override = _material(Color("#56666a"))
		visual_root.add_child(tread_band)
		for z in [-0.82, 0.0, 0.82]:
			_add_cylinder_visual(visual_root, "TrackHub", 0.18, 0.08, Vector3(x * 1.05, -0.2, z), Color("#e9ad38"), Vector3(0, 0, 90))
	# A single warm panel makes the player silhouette legible against the olive ground.
	_add_box_visual(visual_root, "ChassisSafetyPanel", Vector3(2.25, 0.12, 1.58), Vector3(0, 0.39, 0.1), Color("#e9ad38"))
	_add_box_visual(visual_root, "ChassisNose", Vector3(2.35, 0.2, 0.3), Vector3(0, 0.12, -1.18), Color("#df604e"))
	_add_box_visual(visual_root, "ChassisRearPlate", Vector3(2.2, 0.15, 0.25), Vector3(0, 0.46, 1.08), Color("#49636b"))
	cabin_visual = MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.22, 0.95, 1.18)
	cabin_visual.mesh = cabin_mesh
	cabin_visual.position = Vector3(0, 0.92, 0.28)
	cabin_visual.material_override = _material(Color("#2e5c69"))
	visual_root.add_child(cabin_visual)
	_add_box_visual(visual_root, "CabinWindow", Vector3(0.88, 0.42, 0.08), Vector3(0, 1.0, -0.33), Color("#a8d6d1"))
	_add_box_visual(visual_root, "CabinRoof", Vector3(1.38, 0.14, 1.34), Vector3(0, 1.45, 0.28), Color("#eee3c7"))
	_add_cylinder_visual(visual_root, "Beacon", 0.14, 0.18, Vector3(0, 1.67, 0.28), Color("#df604e"))
	boom_visual = Node3D.new()
	boom_visual.name = "TwoStageBoom"
	visual_root.add_child(boom_visual)
	for i in 2:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.44, 0.42, 1.9)
		arm.mesh = arm_mesh
		arm.position = Vector3(0, 0.85 - i * 0.1, -0.8 - i * 0.9)
		arm.rotation_degrees.x = -20.0 if i == 0 else 18.0
		arm.material_override = _material(Color("#e9ad38"))
		boom_visual.add_child(arm)
		_add_cylinder_visual(boom_visual, "BoomPivot%d" % i, 0.22, 0.18, Vector3(0, 0.82 - i * 0.1, -0.83 - i * 0.9), Color("#253d48"), Vector3(90, 0, 0))
	bucket_visual = Node3D.new()
	bucket_visual.name = "BucketVisual"
	boom_visual.add_child(bucket_visual)
	var bucket := MeshInstance3D.new()
	bucket.name = "BucketMesh"
	var bucket_mesh := BoxMesh.new()
	bucket_mesh.size = Vector3(1.75, 0.58, 1.25)
	bucket.mesh = bucket_mesh
	bucket.position = Vector3(0, 0.1, -1.7)
	bucket.material_override = _material(Color("#e9ad38"))
	bucket_visual.add_child(bucket)
	_add_box_visual(bucket_visual, "BucketInside", Vector3(1.38, 0.12, 0.7), Vector3(0, 0.18, -1.87), Color("#806149"))
	for side in [-1.0, 1.0]:
		_add_box_visual(bucket_visual, "BucketSide", Vector3(0.12, 0.65, 1.38), Vector3(side * 0.84, 0.1, -1.7), Color("#c98f30"))
		_add_cylinder_visual(bucket_visual, "BucketTooth", 0.08, 0.42, Vector3(side * 0.5, -0.21, -2.34), Color("#eee3c7"), Vector3(90, 0, 0))
	_add_box_visual(bucket_visual, "BucketBackRail", Vector3(1.42, 0.13, 0.16), Vector3(0, 0.54, -1.2), Color("#253d48"))
	# Lamps are deliberately simple geometric punctuation rather than faces.
	for side in [-1.0, 1.0]:
		_add_cylinder_visual(visual_root, "WorkLamp", 0.12, 0.08, Vector3(side * 0.72, 0.2, -1.23), Color("#fff1b5"), Vector3(90, 0, 0))

func _add_box_visual(parent: Node3D, node_name: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_cylinder_visual(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, color: Color, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.rotation_degrees = rotation
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)
	return mesh_instance

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	material.roughness = 0.62
	return material

func get_snapshot() -> Dictionary:
	return {"schema": 1, "position": [global_position.x, global_position.y, global_position.z], "health": health, "cargo": cargo, "heat": heat, "aim": [aim_direction.x, aim_direction.y, aim_direction.z], "primary_cooldown": primary_cooldown, "throw_cooldown": throw_cooldown, "dash_cooldown": dash_cooldown, "charge": charge, "dash_pending": dash_pending, "dash_remaining": dash_remaining, "dash_hit_ids": dash_hit_ids.duplicate(), "packed_enemy_ids": packed_enemy_ids.duplicate(), "crit_state": str(crit_rng.state)}

func validate_snapshot(data: Dictionary) -> bool:
	if int(data.get("schema", 0)) != 1:
		return false
	var p = data.get("position", null)
	var a = data.get("aim", null)
	var packed_ids: Variant = data.get("packed_enemy_ids", [])
	if not (p is Array and p.size() == 3 and a is Array and a.size() == 3 and packed_ids is Array):
		return false
	if packed_ids.size() > 2:
		return false
	for value in p:
		if not (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) or not is_finite(float(value)):
			return false
	for value in a:
		if not (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) or not is_finite(float(value)):
			return false
	var saved_health := float(data.get("health", -1.0))
	var saved_cargo := int(data.get("cargo", -1))
	var saved_charge := float(data.get("charge", -1.0))
	var primary := float(data.get("primary_cooldown", -1.0))
	var throwing := float(data.get("throw_cooldown", -1.0))
	var dash := float(data.get("dash_cooldown", -1.0))
	var seen_packed: Dictionary = {}
	for enemy_id in packed_ids:
		if enemy_id is not String or str(enemy_id).is_empty() or seen_packed.has(enemy_id):
			return false
		seen_packed[enemy_id] = true
	return is_finite(saved_health) and saved_health >= 0.0 and saved_health <= 1000.0 and saved_cargo >= 0 and saved_cargo <= 64 and is_finite(saved_charge) and saved_charge >= 0.0 and saved_charge <= 100.0 and is_finite(primary) and primary >= 0.0 and primary <= 30.0 and is_finite(throwing) and throwing >= 0.0 and throwing <= 30.0 and is_finite(dash) and dash >= 0.0 and dash <= 30.0

func restore_snapshot(data: Dictionary) -> bool:
	if not validate_snapshot(data):
		return false
	var p: Array = data["position"]
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	health = float(data.get("health", 100.0))
	cargo = int(data.get("cargo", 0))
	heat = float(data.get("heat", 0.0))
	var a: Array = data["aim"]
	aim_direction = Vector3(float(a[0]), float(a[1]), float(a[2]))
	primary_cooldown = float(data.get("primary_cooldown", 0.0))
	throw_cooldown = float(data.get("throw_cooldown", 0.0))
	dash_cooldown = float(data.get("dash_cooldown", 0.0))
	charge = float(data.get("charge", 0.0))
	dash_pending = bool(data.get("dash_pending", false))
	dash_remaining = maxf(0.0, float(data.get("dash_remaining", 0.0)))
	dash_hit_ids.clear()
	for hit_id in data.get("dash_hit_ids", []):
		dash_hit_ids.append(str(hit_id))
	gameplay_enabled = health > 0.0
	status.clear()
	knock_velocity = Vector3.ZERO
	_combo_step = 0
	_combo_until = 0
	if data.has("crit_state") and str(data["crit_state"]).is_valid_int():
		crit_rng.state = str(data["crit_state"]).to_int()
	packed_enemy_ids.clear()
	for enemy_id in data.get("packed_enemy_ids", []):
		if enemy_id is String and not packed_enemy_ids.has(enemy_id):
			packed_enemy_ids.append(enemy_id)
	velocity = Vector3.ZERO
	return true
