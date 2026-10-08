class_name AbilityLibrary
extends RefCounted

## C17 技能库：40 个模块 → 33 种施放行为（逆向主动技能 13 种之外扩展到挂件系）。
## 每种行为都有：明确的形状（弹道/扇形/直线/圆/链/位移/召唤/增益）、可见的特效、对应的手感力度。
## cast(main, module_id, damage, reach, mods) -> {"hits": int, "shape": String}
## mods：来自模块升级（damage/cooldown/range/crit/echo）。

const SHAPES := {
	"mage_pyro": "fireball", "mage_cryo": "frost_cone", "mage_storm": "chain", "mage_void": "void_lance",
	"mage_tide": "tide_wave", "mage_gravity": "gravity_well", "mage_frost_nova": "frost_nova",
	"crew_engineer": "repair", "crew_sniper": "snipe", "crew_medic": "medic", "crew_bomber": "mortar",
	"crew_cook": "soup", "crew_scout": "volley", "crew_rigger": "resupply",
	"turret_layer": "turret", "arms_dealer": "resupply", "barracks": "barracks", "top_cannon_tower": "barrage",
	"turret_tesla": "tesla", "top_mortar": "mortar_line", "top_archer": "volley",
	"front_cannon": "cannon", "ballista": "pierce_bolt", "harpoon_gun": "harpoon", "ramme": "ram",
	"magnet_crane": "magnet_pull", "quake_hammer": "quake",
	"side_cannon": "broadside", "side_flamethrower": "flame_cone", "emp_coil": "emp", "shield_dome": "shield",
	"scrap_cyclone": "cyclone", "whale_roar": "roar",
	"back_dash": "dash", "back_mine_layer": "mines", "back_trail": "tar", "firewall_spreader": "firewall",
	"teleporter": "blink", "overclock": "overclock", "repair_drone": "drone_heal",
}

const C_FIRE := Color("#E3A52B")
const C_FROST := Color("#7FD3E0")
const C_SHOCK := Color("#C9B8F0")
const C_VOID := Color("#8C7BA8")
const C_BONE := Color("#EFE3C8")
const C_RED := Color("#D9412B")
const C_HEAL := Color("#8FD694")

static func shape_of(module_id: String) -> String:
	return str(SHAPES.get(module_id, "pulse"))

static func distinct_shapes() -> Array:
	var seen := {}
	for v in SHAPES.values():
		seen[v] = true
	return seen.keys()

# ------------------------------------------------------------ helpers

static func _enemies(main: Node) -> Array:
	var out := []
	for n in main.get_tree().get_nodes_in_group("enemies"):
		if n is EnemyDummy and not n.dead and not n.packed and n.visible:
			out.append(n)
	return out

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

static func _aim(main: Node) -> Vector3:
	var a: Vector3 = main.player.aim_direction
	a = _flat(a)
	return a.normalized() if a.length() > 0.01 else Vector3(0, 0, -1)

static func _feel() -> GameFeel:
	return GameFeel.instance

## 统一结算：伤害 + 状态 + 击退（重型/Boss 自带减免）
static func _strike(e: EnemyDummy, dmg: float, src: Dictionary, from: Vector3) -> void:
	if e == null or e.dead:
		return
	var d := dmg
	if e.kind == "heavy" and bool(src.get("anti_heavy", false)):
		d *= 1.8
	e._apply_source_status(src)
	var tag := "crit" if bool(src.get("crit", false)) else str(src.get("number_kind", "normal"))
	e.take_damage(d, tag)
	var kb := float(src.get("knock", 3.0))
	if kb != 0.0:
		var dir := _flat(e.global_position - from)
		if bool(src.get("pull", false)):
			dir = -dir
		e.apply_knockback(dir, absf(kb))

static func _circle(main: Node, center: Vector3, r: float, dmg: float, src: Dictionary) -> int:
	var n := 0
	for e in _enemies(main):
		var reach := r + (1.2 if e is BossEntity else 0.5)
		if _flat(e.global_position - center).length() <= reach:
			_strike(e, dmg, src, center)
			n += 1
	return n

static func _cone(main: Node, origin: Vector3, dir: Vector3, r: float, half_deg: float, dmg: float, src: Dictionary) -> int:
	var n := 0
	var cosv := cos(deg_to_rad(half_deg))
	for e in _enemies(main):
		var v := _flat(e.global_position - origin)
		var dist := v.length()
		if dist <= r + (1.0 if e is BossEntity else 0.4) and dist > 0.05 and v.normalized().dot(dir) >= cosv:
			_strike(e, dmg, src, origin)
			n += 1
	return n

static func _line(main: Node, origin: Vector3, dir: Vector3, length: float, width: float, dmg: float, src: Dictionary) -> int:
	var n := 0
	for e in _enemies(main):
		var v := _flat(e.global_position - origin)
		var along := v.dot(dir)
		if along < -0.5 or along > length + 0.5:
			continue
		var side := (v - dir * along).length()
		if side <= width * 0.5 + (1.0 if e is BossEntity else 0.45):
			_strike(e, dmg, src, origin)
			n += 1
	return n

static func _nearest(main: Node, origin: Vector3, max_d: float, dir := Vector3.ZERO, min_dot := -2.0, exclude := {}) -> EnemyDummy:
	var best: EnemyDummy = null
	var bd := max_d
	for e in _enemies(main):
		if exclude.has(e.get_instance_id()):
			continue
		var v := _flat(e.global_position - origin)
		var d := v.length()
		if d > bd:
			continue
		if dir != Vector3.ZERO and d > 0.1 and v.normalized().dot(dir) < min_dot:
			continue
		best = e
		bd = d
	return best

static func _fx(main: Node, kind: String, a: Vector3, b: Vector3) -> void:
	if main.world != null:
		main.world.present_effect(kind, a, b)

static func _proj(main: Node, from: Vector3, dir: Vector3, spd: float, dmg: float, tint: Color, src: Dictionary, size := 0.32, life := 1.4) -> Projectile:
	var p := Projectile.fire(main.entities, from, dir, spd, dmg, "player", tint)
	p.size = size
	p.lifetime = life
	p.on_hit = func(e: EnemyDummy, _at: Vector3): _strike(e, dmg, src, from)
	return p

## 扇形闪光（火焰 / 冰锥 / 水浪）：一块扇形面片，0.25s 内展开并淡出
static func _fan_flash(main: Node, origin: Vector3, dir: Vector3, r: float, half_deg: float, tint: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	var base_ang := atan2(dir.x, dir.z)
	for i in steps:
		var a0 := base_ang + deg_to_rad(lerpf(-half_deg, half_deg, float(i) / steps))
		var a1 := base_ang + deg_to_rad(lerpf(-half_deg, half_deg, float(i + 1) / steps))
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a0), 0, cos(a0)) * r)
		st.add_vertex(Vector3(sin(a1), 0, cos(a1)) * r)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(tint, 0.6)
	mi.material_override = m
	mi.position = Vector3(origin.x, 0.2, origin.z)
	mi.scale = Vector3(0.2, 1, 0.2)
	main.entities.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(mi.queue_free)

## 直线光束（贯穿枪 / 狙击 / 冲撞路径）
static func _beam(main: Node, origin: Vector3, dir: Vector3, length: float, width: float, tint: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.18, length)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(tint, 0.85)
	mi.material_override = m
	mi.position = Vector3(origin.x, 0.9, origin.z) + dir * length * 0.5
	mi.rotation.y = atan2(dir.x, dir.z)
	main.entities.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.15, 1, 1), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(mi.queue_free)

static func _ring(at: Vector3, r: float, tint: Color, dur := 0.3) -> void:
	if _feel() != null:
		_feel().impact_ring(at, r, tint, dur)

static func _kick(trauma: float, stop := 0.0, fov := 0.0) -> void:
	var f := _feel()
	if f == null:
		return
	f.shake(trauma)
	if stop > 0.0:
		f.hitstop(stop, 0.05)
	if fov > 0.0:
		f.fov_punch(fov)

# ------------------------------------------------------------ cast

static func cast(main: Node, module_id: String, damage: float, reach: float, mods: Dictionary = {}) -> Dictionary:
	var shape := shape_of(module_id)
	var r := reach * (1.0 + float(mods.get("range", 0.0)))
	var src := {"crit": float(mods.get("crit", 0.0)) >= 1.0}
	var hits := _cast_shape(main, shape, damage * (1.8 if src["crit"] else 1.0), r, src)
	var echo := float(mods.get("echo", 0.0))
	if echo > 0.0 and main.is_inside_tree():
		var etw := main.create_tween()
		etw.tween_interval(0.4)
		etw.tween_callback(func():
			if main.outcome == "active":
				_cast_shape(main, shape, damage * echo, r, src.duplicate()))
	return {"hits": hits, "shape": shape}

static func _cast_shape(main: Node, shape: String, dmg: float, r: float, src: Dictionary) -> int:
	var p: M0VehicleController = main.player
	var at := _flat(p.global_position)
	var dir := _aim(main)
	match shape:
		"fireball":
			var s := src.duplicate()
			s.merge({"burn": true, "burn_dps": 5.0, "knock": 5.0})
			var proj := Projectile.fire(main.entities, at, dir, 17.0, dmg, "player", C_FIRE)
			proj.size = 0.45
			proj.lifetime = maxf(r / 17.0, 0.3)
			var boom := func(center: Vector3):
				_circle(main, center, 2.4, dmg, s)
				_ring(center, 2.6, C_FIRE, 0.32)
				_fx(main, "dash_hit", center, center)
				_kick(0.28, 0.05)
			proj.on_hit = func(_e: EnemyDummy, pos: Vector3): boom.call(pos)
			proj.on_expire = boom
			_kick(0.06, 0.0, 2.0)
			return 1
		"frost_cone", "flame_cone", "tide_wave":
			var half := 34.0 if shape != "tide_wave" else 55.0
			var s2 := src.duplicate()
			var tint := C_FROST
			match shape:
				"frost_cone":
					s2.merge({"chill": true, "chill_time": 2.5, "knock": 2.0, "number_kind": "frost"})
				"flame_cone":
					s2.merge({"burn": true, "burn_dps": 6.0, "knock": 1.0})
					tint = C_FIRE
				"tide_wave":
					s2.merge({"knock": 12.0, "number_kind": "frost"})
			var n := _cone(main, at, dir, r, half, dmg, s2)
			if shape != "flame_cone":
				for e in _enemies(main):
					if _flat(e.global_position - at).length() <= r and _flat(e.global_position - at).normalized().dot(dir) >= cos(deg_to_rad(half)):
						e.apply_wet(4.0)
			_fan_flash(main, at, dir, r, half, tint)
			_kick(0.14, 0.03 if n > 0 else 0.0)
			return n
		"chain":
			var hit_ids := {}
			var cur := _nearest(main, at, r, dir, 0.2)
			var from_pt := at
			var n2 := 0
			var s3 := src.duplicate()
			s3.merge({"stun": 0.25, "knock": 1.5, "number_kind": "shock"})
			var d := dmg
			while cur != null and n2 < 5:
				hit_ids[cur.get_instance_id()] = true
				_fx(main, "arc_chain", from_pt, cur.global_position)
				_strike(cur, d * (2.0 if cur.is_wet() else 1.0), s3, from_pt)
				from_pt = cur.global_position
				d *= 0.85
				n2 += 1
				cur = _nearest(main, from_pt, 5.5, Vector3.ZERO, -2.0, hit_ids)
			_kick(0.12 + 0.03 * n2, 0.04 if n2 > 0 else 0.0)
			return n2
		"void_lance", "pierce_bolt":
			var s4 := src.duplicate()
			s4.merge({"anti_heavy": shape == "void_lance", "knock": 6.0})
			if shape == "pierce_bolt":
				var bolt := _proj(main, at, dir, 26.0, dmg, C_BONE, s4, 0.26, r / 26.0)
				bolt.pierce = 4
				_kick(0.08, 0.0, 2.0)
				return 1
			var n4 := _line(main, at, dir, r, 1.6, dmg, s4)
			_beam(main, at, dir, r, 1.2, C_VOID)
			_kick(0.22, 0.06 if n4 > 0 else 0.0, 3.0)
			return n4
		"repair", "medic", "soup", "drone_heal":
			var heal := 22.0
			match shape:
				"medic":
					heal = 35.0 if p.health < p.max_health * 0.5 else 15.0
					p.status.apply("invincible", 1.0)
				"soup":
					heal = 12.0
					p.status.apply("shield", 6.0, 30.0)
				"drone_heal":
					heal = 0.0
					AreaHazard.spawn(main.entities, "heal", at, 3.0, 4.0, 5.0).set_meta("follow", true)
			p.status.cleanse()
			if heal > 0.0:
				p.health = minf(p.health + heal, p.max_health)
				if _feel() != null:
					_feel().number(p.global_position, heal, "heal")
			_ring(at, 3.0, C_HEAL, 0.4)
			_fx(main, "repair", at, at)
			return 0
		"snipe":
			var best: EnemyDummy = null
			for e in _enemies(main):
				if _flat(e.global_position - at).length() <= r and (best == null or e.current_health > best.current_health):
					best = e
			if best == null:
				return 0
			var sd := _flat(best.global_position - at).normalized()
			_beam(main, at, sd, _flat(best.global_position - at).length(), 0.22, C_BONE)
			var s5 := src.duplicate()
			s5.merge({"crit": true, "knock": 8.0})
			_strike(best, dmg, s5, at)
			_kick(0.3, 0.09, 4.0)
			return 1
		"mortar", "mortar_line":
			var spots := []
			if shape == "mortar":
				var pool := _enemies(main).filter(func(e): return _flat(e.global_position - at).length() <= r)
				pool.shuffle()
				for e in pool.slice(0, 3):
					spots.append(_flat(e.global_position))
			while spots.size() < 3:
				spots.append(at + dir * (r * (0.45 + 0.25 * spots.size())))
			var s6 := src.duplicate()
			s6.merge({"knock": 8.0})
			var i := 0
			for spot in spots:
				Telegraph.circle(main.entities, spot, 2.4, 0.5 + i * 0.12, func(center: Vector3):
					_circle(main, center, 2.4, dmg, s6)
					_fx(main, "dash_hit", center, center)
					_kick(0.2, 0.03), Telegraph.PLAYER_COLOR)
				i += 1
			return spots.size()
		"turret", "barracks":
			main._try_summon(0 if shape == "turret" else 2, true)
			return 0
		"tesla":
			AreaHazard.spawn(main.entities, "tesla", at + dir * 2.5, r, dmg, 10.0)
			_ring(at + dir * 2.5, r, C_VOID, 0.4)
			return 0
		"resupply", "overclock":
			var slots: Array = main.vehicle_progression.active_slots
			for entry in slots:
				if entry is Dictionary and not entry.is_empty():
					entry["cooldown"] = float(entry["cooldown"]) * 0.4
			p.status.apply("nitro", 3.0 if shape == "overclock" else 2.0)
			if shape == "overclock":
				p.heat = 0.0
				p.status.clear("overheat")
				main.overclock_time = 5.0
			_ring(at, 3.2, C_FIRE, 0.4)
			_kick(0.1, 0.0, 5.0)
			return 0
		"barrage":
			for k in 12:
				var a := TAU * k / 12.0
				_proj(main, at, Vector3(sin(a), 0, cos(a)), 15.0, dmg, C_BONE, src.duplicate(), 0.26, r / 15.0)
			_kick(0.2, 0.0, 2.0)
			return 12
		"volley":
			for k in 5:
				var a2 := deg_to_rad(lerpf(-24.0, 24.0, k / 4.0))
				_proj(main, at, dir.rotated(Vector3.UP, a2), 20.0, dmg, C_BONE, src.duplicate(), 0.2, r / 20.0)
			_kick(0.08)
			return 5
		"broadside":
			var right := Vector3(-dir.z, 0, dir.x)
			for side in [-1.0, 1.0]:
				for k in 3:
					var spread := deg_to_rad(lerpf(-14.0, 14.0, k / 2.0))
					_proj(main, at + right * side * 0.8, (right * side).rotated(Vector3.UP, spread), 16.0, dmg, C_BONE, src.duplicate(), 0.28, r / 16.0)
			_kick(0.2, 0.0, 2.0)
			return 6
		"cannon":
			var s7 := src.duplicate()
			s7.merge({"knock": 14.0})
			var shell := _proj(main, at, dir, 24.0, dmg, C_RED, s7, 0.5, r / 24.0)
			shell.on_hit = func(e: EnemyDummy, pos: Vector3):
				_strike(e, dmg, s7, at)
				_circle(main, pos, 1.6, dmg * 0.4, {"knock": 6.0})
				_kick(0.32, 0.07)
			p.apply_knock(-dir * 6.0)  # 后坐力
			_kick(0.18, 0.0, 3.0)
			return 1
		"harpoon":
			var hook := _proj(main, at, dir, 22.0, dmg, C_BONE, {}, 0.3, r / 22.0)
			hook.on_hit = func(e: EnemyDummy, _pos: Vector3):
				var s8 := src.duplicate()
				s8.merge({"stun": 0.6, "knock": 0.0})
				_strike(e, dmg, s8, at)
				var to_me := _flat(p.global_position - e.global_position)
				e.apply_knockback(to_me, minf(to_me.length() * 3.2, 22.0))
				_fx(main, "arc_chain", p.global_position, e.global_position)
				_kick(0.2, 0.05)
			return 1
		"ram", "dash":
			var dist := r
			p.status.apply("invincible", 0.5)
			p.status.apply("nitro", 0.5)
			p.velocity += dir * (dist * 3.2)
			var s9 := src.duplicate()
			s9.merge({"knock": 14.0 if shape == "ram" else 8.0})
			var n9 := _line(main, at, dir, dist, 2.6, dmg, s9)
			_beam(main, at, dir, dist, 2.2, C_RED if shape == "ram" else C_FIRE)
			_kick(0.3 if shape == "ram" else 0.14, 0.06 if n9 > 0 else 0.0, 9.0)
			return n9
		"magnet_pull", "gravity_well":
			var pt := at + dir * (2.6 if shape == "magnet_pull" else r * 0.6)
			var n10 := 0
			for e in _enemies(main):
				var v := _flat(pt - e.global_position)
				if v.length() <= r + 2.0:
					e.apply_knockback(v, minf(v.length() * 3.5, 26.0))
					n10 += 1
			_ring(pt, r, C_VOID, 0.45)
			if shape == "gravity_well":
				var s10 := src.duplicate()
				s10.merge({"stun": 0.6, "knock": 5.0})
				Telegraph.circle(main.entities, pt, 2.8, 0.45, func(center: Vector3):
					_circle(main, center, 2.8, dmg, s10)
					_kick(0.35, 0.07), C_VOID)
			else:
				for e in _enemies(main):
					if _flat(e.global_position - pt).length() <= r + 2.0:
						e.take_damage(dmg)
			_kick(0.12)
			return n10
		"quake", "frost_nova", "emp", "roar", "cyclone":
			var s11 := src.duplicate()
			var tint2 := C_BONE
			match shape:
				"quake":
					s11.merge({"knock": 13.0})
				"frost_nova":
					s11.merge({"stun": 0.8, "chill": true, "knock": 0.0, "number_kind": "frost"})
					tint2 = C_FROST
				"emp":
					s11.merge({"stun": 1.6, "knock": 0.0, "number_kind": "shock"})
					tint2 = C_SHOCK
				"roar":
					s11.merge({"fear": 2.0, "knock": 6.0})
					tint2 = C_RED
				"cyclone":
					s11.merge({"knock": 2.0})
			if shape == "cyclone":
				for k in 4:
					var ctw := main.create_tween()
					ctw.tween_interval(0.18 * k + 0.001)
					ctw.tween_callback(func():
						var c := _flat(main.player.global_position)
						_circle(main, c, r, dmg, s11)
						_ring(c, r, C_BONE, 0.2)
						_kick(0.08))
				return 4
			var n11 := _circle(main, at, r, dmg, s11)
			_ring(at, r, tint2, 0.4)
			_ring(at, r * 0.55, Color(tint2, 0.7), 0.3)
			_fx(main, "dash_hit", at, at)
			_kick(0.4 if shape == "quake" else 0.22, 0.07 if n11 > 0 else 0.0)
			return n11
		"shield":
			p.status.apply("shield", 6.0, 45.0)
			_ring(at, 2.4, C_FROST, 0.4)
			return 0
		"mines":
			for k in 3:
				AreaHazard.spawn(main.entities, "mine", at - dir * (1.6 + k * 1.3) + Vector3(-dir.z, 0, dir.x) * (k - 1) * 0.9, 2.6, dmg, 14.0)
			return 3
		"tar":
			for k in 4:
				AreaHazard.spawn(main.entities, "tar", at - dir * (1.4 + k * 1.6), 1.6, dmg, 7.0)
			return 4
		"firewall":
			var right2 := Vector3(-dir.z, 0, dir.x)
			for k in 5:
				AreaHazard.spawn(main.entities, "fire", at + dir * r * 0.6 + right2 * (k - 2) * 1.5, 1.2, dmg, 4.0)
			_kick(0.1)
			return 5
		"blink":
			var dest := at + dir * r
			_ring(at, 2.0, C_SHOCK, 0.3)
			p.global_position = Vector3(dest.x, p.global_position.y, dest.z)
			p.status.apply("invincible", 0.35)
			var s12 := src.duplicate()
			s12.merge({"stun": 0.6, "knock": 9.0, "number_kind": "shock"})
			var n12 := _circle(main, dest, 3.0, dmg, s12)
			_ring(dest, 3.2, C_SHOCK, 0.35)
			_fx(main, "arc_chain", at, dest)
			_kick(0.22, 0.05, 8.0)
			return n12
	# 兜底：前方脉冲
	var n0 := _cone(main, at, dir, r, 40.0, dmg, src)
	_fan_flash(main, at, dir, r, 40.0, C_BONE)
	return n0
