class_name AutoWeapons
extends Node

## B1 模块自动攻击（docs/design/combat-v1.md §3.1）
## 每个已装模块除了 Q/E/R/空格 主动技能，还会按自己的冷却自动开火，不占按键。
## 朝向按槽位限定（对齐原作 AttackMode）：开车本身就是瞄准。
##   front  车头 ±FRONT_HALF°
##   side   左右两舷 ±SIDE_HALF°（两边都有目标时两边各打一发）
##   back   车尾 ±BACK_HALF°，或沿行驶轨迹留下地面效果
##   top    360° 炮塔，转向速度有限，对准后才开火
##   crew   范围内随机目标（狙击手打血最多的）
## 伤害全部带 source = "auto:<模块id>"，进 DamagePipeline 记账。

const FRONT_HALF := 25.0
const SIDE_HALF := 40.0
const BACK_HALF := 40.0
const TOP_TURN_DEG := 300.0
const TOP_ALIGN_DEG := 14.0
const RETRY := 0.08
const C_FIRE := Color("#E3A52B")
const C_FROST := Color("#7FD3E0")
const C_SHOCK := Color("#C9B8F0")
const C_VOID := Color("#8C7BA8")
const C_BONE := Color("#EFE3C8")
const C_WATER := Color("#5FB7C9")
const C_HEAL := Color("#8FD694")

## kind: bolt / lob / cone / chain / snipe / pulse / zap / drop / ram / support
## 数值是 Lv.1、未计神器和底盘成长时的基础值
const PROFILES := {
	# ---- 法师：顶置 360°
	"mage_pyro": {"slot": "top", "kind": "bolt", "cd": 2.2, "dmg": 9.0, "r": 12.0, "spd": 16.0, "size": 0.38, "style": "fire", "tint": C_FIRE, "splash": 1.8, "burn": true},
	"mage_cryo": {"slot": "top", "kind": "bolt", "cd": 1.6, "dmg": 6.0, "r": 11.0, "spd": 18.0, "size": 0.3, "tint": C_FROST, "chill": true},
	"mage_storm": {"slot": "top", "kind": "chain", "cd": 2.0, "dmg": 7.0, "r": 11.0, "hops": 2, "stun": 0.15},
	"mage_void": {"slot": "top", "kind": "bolt", "cd": 3.0, "dmg": 16.0, "r": 13.0, "spd": 24.0, "size": 0.34, "tint": C_VOID, "pierce": 3, "anti_heavy": true},
	"mage_tide": {"slot": "top", "kind": "bolt", "cd": 1.6, "dmg": 7.0, "r": 10.0, "spd": 15.0, "size": 0.42, "tint": C_WATER, "wet": true, "knock": 4.5},
	"mage_gravity": {"slot": "top", "kind": "lob", "cd": 4.0, "dmg": 12.0, "r": 10.0, "splash": 2.4, "tint": C_VOID, "pull": true, "knock": 3.0},
	"mage_frost_nova": {"slot": "top", "kind": "pulse", "cd": 3.2, "dmg": 6.0, "r": 3.4, "tint": C_FROST, "chill": true},
	# ---- 船员：随机目标 / 辅助
	"crew_engineer": {"slot": "crew", "kind": "support", "cd": 5.0, "fx": "repair", "amount": 3.0},
	"crew_sniper": {"slot": "crew", "kind": "snipe", "cd": 3.5, "dmg": 30.0, "r": 20.0, "anti_heavy": true},
	"crew_medic": {"slot": "crew", "kind": "support", "cd": 6.0, "fx": "heal_low", "amount": 5.0},
	"crew_bomber": {"slot": "crew", "kind": "lob", "cd": 3.0, "dmg": 12.0, "r": 13.0, "splash": 2.0, "tint": C_FIRE},
	"crew_cook": {"slot": "crew", "kind": "support", "cd": 8.0, "fx": "shield", "amount": 8.0, "dur": 4.0},
	"crew_scout": {"slot": "crew", "kind": "bolt", "cd": 0.9, "dmg": 5.0, "r": 13.0, "spd": 26.0, "size": 0.18, "tint": C_BONE},
	"crew_rigger": {"slot": "crew", "kind": "support", "cd": 6.0, "fx": "cdr", "amount": 0.6},
	# ---- 炮塔系：顶置 360°
	"turret_layer": {"slot": "top", "kind": "bolt", "cd": 0.9, "dmg": 5.0, "r": 12.0, "spd": 26.0, "size": 0.16, "tint": C_BONE},
	"arms_dealer": {"slot": "top", "kind": "bolt", "cd": 2.2, "dmg": 6.0, "r": 10.0, "spd": 22.0, "size": 0.18, "tint": C_BONE, "count": 3, "spread": 12.0},
	"barracks": {"slot": "top", "kind": "support", "cd": 4.0, "fx": "repair", "amount": 2.0},
	"top_cannon_tower": {"slot": "top", "kind": "bolt", "cd": 2.4, "dmg": 11.0, "r": 13.0, "spd": 18.0, "size": 0.36, "tint": C_BONE, "splash": 1.5, "knock": 4.0},
	"turret_tesla": {"slot": "top", "kind": "zap", "cd": 2.6, "dmg": 6.0, "r": 5.0, "count": 3, "stun": 0.25},
	"top_mortar": {"slot": "top", "kind": "lob", "cd": 3.4, "dmg": 15.0, "r": 15.0, "splash": 2.3, "tint": C_FIRE},
	"top_archer": {"slot": "top", "kind": "bolt", "cd": 1.4, "dmg": 5.5, "r": 13.0, "spd": 24.0, "size": 0.16, "tint": C_BONE, "count": 3, "spread": 10.0},
	# ---- 前挂件：车头 ±25°
	"front_cannon": {"slot": "front", "kind": "bolt", "cd": 2.4, "dmg": 18.0, "r": 15.0, "spd": 20.0, "size": 0.42, "tint": C_BONE, "splash": 1.6, "knock": 6.0, "kick": 0.06},
	"ballista": {"slot": "front", "kind": "bolt", "cd": 2.2, "dmg": 14.0, "r": 18.0, "spd": 30.0, "size": 0.22, "tint": C_BONE, "pierce": 4, "anti_heavy": true},
	"harpoon_gun": {"slot": "front", "kind": "bolt", "cd": 2.8, "dmg": 9.0, "r": 12.0, "spd": 22.0, "size": 0.24, "tint": C_BONE, "pull": true, "knock": 5.0, "stun": 0.3},
	"ramme": {"slot": "front", "kind": "ram", "cd": 0.5, "dmg": 10.0, "r": 2.4, "knock": 6.0},
	"magnet_crane": {"slot": "front", "kind": "cone", "cd": 1.8, "dmg": 4.0, "r": 7.0, "half": 30.0, "pull": true, "knock": 3.0, "vfx": "tide_wave"},
	"quake_hammer": {"slot": "front", "kind": "pulse", "cd": 2.2, "dmg": 16.0, "r": 3.0, "offset": 1.8, "tint": C_BONE, "knock": 5.0, "kick": 0.08},
	# ---- 侧挂件：左右两舷 ±40°
	"side_cannon": {"slot": "side", "kind": "bolt", "cd": 1.6, "dmg": 10.0, "r": 12.0, "spd": 20.0, "size": 0.3, "tint": C_BONE, "knock": 3.0},
	"side_flamethrower": {"slot": "side", "kind": "cone", "cd": 0.8, "dmg": 3.0, "r": 5.0, "half": 25.0, "burn": true, "vfx": "flame_cone"},
	"emp_coil": {"slot": "side", "kind": "pulse", "cd": 5.0, "dmg": 3.0, "r": 4.0, "tint": C_SHOCK, "stun": 0.4},
	"shield_dome": {"slot": "side", "kind": "support", "cd": 7.0, "fx": "shield", "amount": 8.0, "dur": 3.0},
	"scrap_cyclone": {"slot": "side", "kind": "pulse", "cd": 1.1, "dmg": 6.0, "r": 3.0, "tint": C_BONE, "knock": 2.0},
	"whale_roar": {"slot": "side", "kind": "pulse", "cd": 6.0, "dmg": 2.0, "r": 5.0, "tint": C_VOID, "fear": 0.8},
	# ---- 后挂件：车尾 ±40° / 轨迹
	"back_dash": {"slot": "back", "kind": "cone", "cd": 1.0, "dmg": 4.0, "r": 3.5, "half": 30.0, "burn": true, "vfx": "flame_cone", "moving": true},
	"back_mine_layer": {"slot": "back", "kind": "drop", "cd": 2.5, "dmg": 14.0, "hz": "mine", "hz_r": 2.2, "life": 10.0, "max": 6},
	"back_trail": {"slot": "back", "kind": "drop", "cd": 1.2, "dmg": 0.0, "hz": "tar", "hz_r": 1.8, "life": 4.0, "max": 5},
	"firewall_spreader": {"slot": "back", "kind": "drop", "cd": 1.5, "dmg": 4.0, "hz": "fire", "hz_r": 1.6, "life": 3.0, "max": 4},
	"teleporter": {"slot": "back", "kind": "zap", "cd": 2.2, "dmg": 8.0, "r": 8.0, "count": 1, "stun": 0.2, "arc": true},
	"overclock": {"slot": "back", "kind": "support", "cd": 4.0, "fx": "heat", "amount": 15.0},
	"repair_drone": {"slot": "back", "kind": "support", "cd": 4.0, "fx": "repair", "amount": 2.0},
}

static var instance: AutoWeapons

var main: Node
var enabled := true
var shots_fired: Dictionary = {}   # module_id -> 次数（测试 / 构筑面板用）
var _state: Dictionary = {}
var _last_sound_ms := 0

func _init(owner_main: Node = null) -> void:
	main = owner_main
	name = "AutoWeapons"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	instance = self

static func profile_of(module_id: String) -> Dictionary:
	return PROFILES.get(module_id, {})

static func slot_label(slot: String) -> String:
	return {"front": "车头", "side": "两舷", "back": "车尾", "top": "顶置 360°", "crew": "乘员"}.get(slot, slot)

## 选卡说明用的一行：「自动 · 车头 · 每 2.4 秒」
static func describe(module_id: String) -> String:
	var p := profile_of(module_id)
	if p.is_empty():
		return ""
	return "自动攻击 · %s · 每 %.1f 秒" % [slot_label(str(p.slot)), float(p.cd)]

func reset() -> void:
	_state.clear()
	shots_fired.clear()

func _physics_process(delta: float) -> void:
	if not enabled or main == null or str(main.get("outcome")) != "active":
		return
	var p: Node3D = main.get("player")
	if p == null or not bool(p.get("gameplay_enabled")) or float(p.get("health")) <= 0.0:
		return
	if p.get("status") != null and not p.status.can_act():
		return
	var se = main.get("selection_engine")
	if se == null:
		return
	for m in se.installed_modules:
		var id: String = m.module_id
		var prof := profile_of(id)
		if prof.is_empty():
			continue
		if not _state.has(id):
			_state[id] = {"cd": randf_range(0.15, 0.6), "yaw": _flat(p.heading), "hazards": []}
		var st: Dictionary = _state[id]
		var cd := float(st.cd) - delta
		if str(prof.slot) == "top":
			_turn_top(st, prof, p, delta)
		if cd > 0.0:
			st.cd = cd
			continue
		DamagePipeline.push("auto:" + id)
		var fired := _fire(id, prof, st, p)
		DamagePipeline.pop()
		if fired:
			shots_fired[id] = int(shots_fired.get(id, 0)) + 1
			st.cd = float(prof.cd) * _cooldown_factor(id)
			_mount_pop(id, st)
		else:
			st.cd = RETRY

# ------------------------------------------------------------ 数值

func _mods(id: String) -> Dictionary:
	var lv = main.get("module_levels")
	return (lv as Dictionary).get(id, {}) if lv is Dictionary else {}

func _cooldown_factor(id: String) -> float:
	var f: float = main._scaled_cooldown(1.0) if main.has_method("_scaled_cooldown") else 1.0
	return f * clampf(1.0 - float(_mods(id).get("cooldown", 0.0)), 0.25, 1.5)

## 伤害：模块升级 × 神器/船长 × 底盘成长（跟挖斗同一条成长线）
func damage_of(id: String) -> float:
	var prof := profile_of(id)
	var base := float(prof.get("dmg", 0.0))
	var p: Node = main.get("player")
	var power_scale := 1.0
	if p != null and p.has_method("_stats"):
		power_scale = clampf(float(p._stats().get("power", 14.0)) / 14.0, 1.0, 4.0)
	var bonus := 0.0
	var rs = main.get("run_systems")
	if rs != null and rs.has_method("total_bonus"):
		bonus = float(rs.total_bonus("damage"))
	return base * (1.0 + float(_mods(id).get("damage", 0.0))) * (1.0 + bonus) * power_scale

func _src(id: String, prof: Dictionary, crit: bool) -> Dictionary:
	var s := {"source": "auto:" + id, "crit": crit, "knock": float(prof.get("knock", 1.2)), "number_kind": "normal"}
	for k in ["burn", "chill", "anti_heavy", "pull"]:
		if prof.has(k):
			s[k] = prof[k]
	if prof.has("stun"):
		s["stun"] = float(prof.stun)
	if prof.has("fear"):
		s["fear"] = float(prof.fear)
	if bool(prof.get("burn", false)):
		s["burn_dps"] = 3.0
		s["burn_time"] = 2.5
	return s

func _roll(p: Node, id: String) -> Array:
	var chance := float(p.get("crit_chance")) if p.get("crit_chance") != null else 0.1
	if p.has_method("_modifier"):
		chance += float(p._modifier("luck")) * 0.01
	if float(_mods(id).get("crit", 0.0)) >= 1.0:
		chance = 1.0
	var crit := randf() < chance
	return [damage_of(id) * (1.8 if crit else 1.0), crit]

# ------------------------------------------------------------ 瞄准

static func _flat(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0, v.z)
	return f.normalized() if f.length() > 0.001 else Vector3(0, 0, -1)

func _enemies() -> Array:
	return AbilityLibrary._enemies(main)

## 弧内最近的敌人（Boss 稍微优先，敌巢靠后）
func _in_arc(origin: Vector3, axis: Vector3, half_deg: float, r: float) -> EnemyDummy:
	var cosv := cos(deg_to_rad(half_deg))
	var best: EnemyDummy = null
	var best_score := INF
	for e in _enemies():
		var v := Vector3(e.global_position.x - origin.x, 0, e.global_position.z - origin.z)
		var d := v.length()
		var extra := 1.2 if e is BossEntity else 0.4
		if d > r + extra or d < 0.05:
			continue
		if half_deg < 180.0 and v.normalized().dot(axis) < cosv:
			continue
		var score := d
		if e is BossEntity:
			score -= 3.0
		elif str(e.tier) == "structure":
			score += 4.0
		if score < best_score:
			best_score = score
			best = e
	return best

func _turn_top(st: Dictionary, prof: Dictionary, p: Node3D, delta: float) -> void:
	var t := _in_arc(p.global_position, Vector3.FORWARD, 360.0, float(prof.get("r", 10.0)))
	if t == null:
		return
	var want := _flat(t.global_position - p.global_position)
	var cur: Vector3 = st.yaw
	var ang := cur.signed_angle_to(want, Vector3.UP)
	var step := deg_to_rad(TOP_TURN_DEG) * delta
	st.yaw = cur.rotated(Vector3.UP, clampf(ang, -step, step))
	st.target = t

func _muzzle(p: Node3D, slot: String, side_sign := 1.0) -> Vector3:
	var h := _flat(p.heading)
	var right := h.cross(Vector3.UP)
	var base := Vector3(p.global_position.x, 0, p.global_position.z)
	match slot:
		"front":
			return base + h * 1.3
		"side":
			return base + right * 0.9 * side_sign
		"back":
			return base - h * 1.3
	return base

# ------------------------------------------------------------ 开火

func _fire(id: String, prof: Dictionary, st: Dictionary, p: Node3D) -> bool:
	var slot := str(prof.slot)
	var kind := str(prof.kind)
	if kind == "support":
		return _support(id, prof, p)
	if kind == "drop":
		return _drop(id, prof, st, p)
	if kind == "ram":
		return _ram(id, prof, p)
	if kind == "pulse":
		return _pulse(id, prof, p, _flat(p.heading))
	if bool(prof.get("moving", false)) and _speed(p) < 1.5:
		return false
	var h := _flat(p.heading)
	var r := float(prof.get("r", 10.0))
	var shots: Array = []   # [origin, target]
	match slot:
		"front":
			var o := _muzzle(p, "front")
			var t := _in_arc(o, h, FRONT_HALF, r)
			if t != null:
				shots.append([o, t])
		"back":
			var ob := _muzzle(p, "back")
			var tb := _in_arc(ob, -h, BACK_HALF if not bool(prof.get("arc", false)) else 70.0, r)
			if tb != null:
				shots.append([ob, tb])
		"side":
			var right := h.cross(Vector3.UP)
			for sgn in [1.0, -1.0]:
				var os := _muzzle(p, "side", sgn)
				var ts := _in_arc(os, right * sgn, SIDE_HALF, r)
				if ts != null:
					shots.append([os, ts])
		"top":
			var tt: Variant = st.get("target")
			if tt == null or not is_instance_valid(tt) or tt.dead or not tt.visible:
				return false
			var want := _flat(tt.global_position - p.global_position)
			if rad_to_deg(absf((st.yaw as Vector3).angle_to(want))) > TOP_ALIGN_DEG:
				return false
			if _flat_dist(p.global_position, tt.global_position) > r + 1.0:
				return false
			shots.append([Vector3(p.global_position.x, 0, p.global_position.z), tt])
		"crew":
			var t2 := _crew_target(kind, r, p)
			if t2 != null:
				shots.append([Vector3(p.global_position.x, 0, p.global_position.z), t2])
	if shots.is_empty():
		return false
	for s in shots:
		_shoot(id, prof, kind, s[0], s[1], p)
	_sound(kind)
	if prof.has("kick") and GameFeel.instance != null:
		GameFeel.instance.shake(float(prof.kick))
	return true

func _crew_target(kind: String, r: float, p: Node3D) -> EnemyDummy:
	var cands: Array = []
	for e in _enemies():
		if _flat_dist(p.global_position, e.global_position) <= r and str(e.tier) != "structure":
			cands.append(e)
	if cands.is_empty():
		return null
	if kind == "snipe":
		cands.sort_custom(func(a, b): return float(a.current_health) > float(b.current_health))
		return cands[0]
	return cands[randi() % cands.size()]

static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _speed(p: Node3D) -> float:
	var v = p.get("velocity")
	return Vector2(v.x, v.z).length() if v is Vector3 else 0.0

func _shoot(id: String, prof: Dictionary, kind: String, origin: Vector3, target: EnemyDummy, p: Node3D) -> void:
	var roll := _roll(p, id)
	var dmg: float = roll[0]
	var src := _src(id, prof, roll[1])
	var dir := _flat(target.global_position - origin)
	var tint: Color = prof.get("tint", C_BONE)
	match kind:
		"bolt":
			var n := int(prof.get("count", 1))
			var spread := float(prof.get("spread", 0.0))
			for i in n:
				var a := deg_to_rad(spread * (float(i) - float(n - 1) * 0.5))
				_bolt(prof, origin, dir.rotated(Vector3.UP, a), dmg, src, tint)
			VfxKit.muzzle(origin + Vector3(0, 0.9, 0), dir, tint, clampf(float(prof.get("size", 0.3)) * 3.0, 0.6, 1.4))
		"lob":
			var to := Vector3(target.global_position.x, 0, target.global_position.z)
			var dur := clampf(_flat_dist(origin, to) / 14.0, 0.35, 0.9)
			var splash := float(prof.get("splash", 2.0))
			SkillVfx.lob(origin, to, dur, tint, 0.28)
			AbilityLibrary._ring(to, splash, Color(tint, 0.6), dur)
			var tw := main.create_tween()
			tw.tween_interval(dur)
			tw.tween_callback(func():
				if str(main.get("outcome")) != "active":
					return
				AbilityLibrary._circle(main, to, splash, dmg, src)
				VfxKit.explosion(to, splash, tint, false)
				AbilityLibrary._kick(0.05))
		"cone":
			var half := float(prof.get("half", 30.0))
			var r := float(prof.get("r", 5.0))
			var axis := dir
			AbilityLibrary._cone(main, origin, axis, r, half, dmg, src)
			SkillVfx.cone_spray(origin, axis, r, half, str(prof.get("vfx", "flame_cone")))
		"chain":
			var hit := {}
			var from := origin + Vector3(0, 1.1, 0)
			var cur: EnemyDummy = target
			for i in int(prof.get("hops", 2)) + 1:
				if cur == null:
					break
				hit[cur.get_instance_id()] = true
				VfxKit.lightning(from, cur.global_position + Vector3(0, 0.7, 0), C_SHOCK)
				AbilityLibrary._strike(cur, dmg * (1.0 if i == 0 else 0.7), src, from)
				from = cur.global_position + Vector3(0, 0.7, 0)
				cur = AbilityLibrary._nearest(main, cur.global_position, 4.5, Vector3.ZERO, -2.0, hit)
		"snipe":
			var a2 := origin + Vector3(0, 1.3, 0)
			VfxKit.beam(a2, target.global_position + Vector3(0, 0.7, 0), C_BONE, 0.1, 0.18)
			VfxKit.impact(target.global_position + Vector3(0, 0.7, 0), C_BONE, 1.1)
			AbilityLibrary._strike(target, dmg, src, origin)
		"zap":
			var hit2 := {}
			var cur2: EnemyDummy = target
			for i in int(prof.get("count", 1)):
				if cur2 == null:
					break
				hit2[cur2.get_instance_id()] = true
				VfxKit.lightning(origin + Vector3(0, 1.0, 0), cur2.global_position + Vector3(0, 0.7, 0), C_SHOCK)
				AbilityLibrary._strike(cur2, dmg, src, origin)
				cur2 = AbilityLibrary._nearest(main, origin, float(prof.get("r", 5.0)), Vector3.ZERO, -2.0, hit2)

func _bolt(prof: Dictionary, origin: Vector3, dir: Vector3, dmg: float, src: Dictionary, tint: Color) -> void:
	var spd := float(prof.get("spd", 18.0))
	var life := (float(prof.get("r", 10.0)) + 1.5) / spd
	var pr := Projectile.fire(main.entities, origin, dir, spd, dmg, "player", tint)
	pr.size = float(prof.get("size", 0.3))
	pr.lifetime = life
	pr.pierce = int(prof.get("pierce", 0))
	if prof.has("style"):
		pr.style = str(prof.style)
	var splash := float(prof.get("splash", 0.0))
	var wet := bool(prof.get("wet", false))
	var m := main
	pr.on_hit = func(e: EnemyDummy, at: Vector3):
		if wet and is_instance_valid(e):
			e.apply_wet(3.0)
		if splash > 0.0:
			AbilityLibrary._circle(m, at, splash, dmg, src)
			VfxKit.explosion(at, splash, tint, false)
		else:
			AbilityLibrary._strike(e, dmg, src, origin)

func _pulse(id: String, prof: Dictionary, p: Node3D, h: Vector3) -> bool:
	var center := Vector3(p.global_position.x, 0, p.global_position.z) + h * float(prof.get("offset", 0.0))
	var r := float(prof.get("r", 3.0))
	if _in_arc(center, h, 360.0, r) == null:
		return false
	var roll := _roll(p, id)
	var src := _src(id, prof, roll[1])
	AbilityLibrary._circle(main, center, r, roll[0], src)
	var tint: Color = prof.get("tint", C_BONE)
	AbilityLibrary._ring(center, r, tint, 0.3)
	VfxKit.burst(center + Vector3(0, 0.4, 0), "sparks", tint, clampf(r / 3.0, 0.7, 1.6))
	if prof.has("kick"):
		AbilityLibrary._kick(float(prof.kick))
	_sound("pulse")
	return true

func _ram(id: String, prof: Dictionary, p: Node3D) -> bool:
	var spd := _speed(p)
	if spd < 3.0:
		return false
	var h := _flat(p.heading)
	var o := _muzzle(p, "front")
	var base_speed := maxf(float(p.get("base_speed")) if p.get("base_speed") != null else 7.0, 1.0)
	var mult := clampf(spd / base_speed, 0.5, 2.2)
	var roll := _roll(p, id)
	var src := _src(id, prof, roll[1])
	var n := AbilityLibrary._cone(main, o - h * 0.6, h, float(prof.r), 55.0, roll[0] * mult, src)
	if n > 0:
		VfxKit.impact(o + Vector3(0, 0.6, 0), C_BONE, 1.2)
		AbilityLibrary._kick(0.07, 0.03)
		_sound("ram")
	return n > 0

func _drop(id: String, prof: Dictionary, st: Dictionary, p: Node3D) -> bool:
	if _speed(p) < 1.5:
		return false
	if _in_arc(p.global_position, Vector3.FORWARD, 360.0, 14.0) == null:
		return false
	var live: Array = (st.hazards as Array).filter(func(x): return is_instance_valid(x))
	if live.size() >= int(prof.get("max", 4)):
		st.hazards = live
		return false
	var at := _muzzle(p, "back")
	var hz := AreaHazard.spawn(main.entities, str(prof.hz), at, float(prof.hz_r), damage_of(id), float(prof.life))
	live.append(hz)
	st.hazards = live
	return true

func _support(id: String, prof: Dictionary, p: Node3D) -> bool:
	var amount := float(prof.get("amount", 0.0)) * (1.0 + float(_mods(id).get("damage", 0.0)))
	var feel := GameFeel.instance
	match str(prof.fx):
		"repair", "heal_low":
			var mx := float(p.get("max_health"))
			var hp := float(p.get("health"))
			if hp >= mx - 0.5:
				return false
			if str(prof.fx) == "heal_low" and hp > mx * 0.6:
				return false
			p.health = minf(mx, hp + amount)
			if feel != null:
				feel.number(p.global_position, amount, "heal")
			VfxKit.burst(p.global_position + Vector3(0, 1.0, 0), "sparks", C_HEAL, 0.7)
		"shield":
			if p.status.has("shield"):
				return false
			p.status.apply("shield", float(prof.get("dur", 3.0)), amount)
			AbilityLibrary._ring(p.global_position, 1.8, C_FROST, 0.3)
		"heat":
			if float(p.get("heat")) < 20.0:
				return false
			p.heat = maxf(0.0, float(p.heat) - amount)
		"cdr":
			var vp = main.get("vehicle_progression")
			if vp == null:
				return false
			var any := false
			for e in vp.active_slots:
				if e is Dictionary and not (e as Dictionary).is_empty() and float(e.get("cooldown", 0.0)) > 0.0:
					e["cooldown"] = maxf(0.0, float(e["cooldown"]) - amount)
					any = true
			if not any:
				return false
	return true

# ------------------------------------------------------------ 表现

func _mount_pop(id: String, st: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	var mount: Variant = st.get("mount")
	if (mount == null or not is_instance_valid(mount)) and now >= int(st.get("mount_retry", 0)):
		st.mount_retry = now + 2000
		var p: Node = main.get("player")
		mount = p.find_child("Installed_" + id, true, false) if p != null else null
		st.mount = mount
	if mount == null or not is_instance_valid(mount) or not mount is Node3D:
		return
	var m3 := mount as Node3D
	if not st.has("mount_scale"):
		st.mount_scale = m3.scale
	var base: Vector3 = st.mount_scale
	var tw := m3.create_tween()
	tw.tween_property(m3, "scale", base * 1.14, 0.04)
	tw.tween_property(m3, "scale", base, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _sound(kind: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_sound_ms < 90:
		return
	_last_sound_ms = now
	var audio = main.get("audio")
	if audio == null or not audio.has_method("play_event"):
		return
	var ev := "auto_shot"
	match kind:
		"lob", "pulse", "ram":
			ev = "auto_boom"
		"chain", "zap":
			ev = "auto_zap"
	audio.play_event(ev, -20.0, randf_range(0.92, 1.12))
