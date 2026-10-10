class_name StageDirector
extends Node

## C28 关卡导演（对齐原作 WaveSpawner，docs/design/level-v1.md，数值 config/stages.json）
## 一局 4 阶段；每阶段四条刷怪线并行：
##   涓流   —— 按间隔曲线从敌人池抽组（稀有度 + 解锁时间），组大小 × 强度曲线；Boss 在场时下调
##   节拍   —— 写死时间的关键波次（杂兵潮、精英、宝箱车、补给车、废料场）
##   蜂群   —— 阶段中段的大潮，提前 warn 秒预警
##   加时   —— 超过 overtime_at 还没打掉 Boss：清场者越刷越快
## 另外：3 个敌巢（靠近才出兵）、Boss 屏幕外入场、阶段清场 → 换群系 → 下一阶段。
## 刷怪点永远在镜头外 + 场地内；每帧最多生成 spawns_per_frame 个（避免卡顿），存活上限 max_alive。

signal stage_started(index: int)
signal stage_cleared(index: int)
signal campaign_won
signal swarm_warning(seconds: float)
signal overtime_started

const CONFIG_PATH := "res://config/stages.json"
const THREAT_WEIGHT := {"swarm": 1.0, "minion": 3.0, "elite": 12.0, "boss": 40.0}

var main: Node
var config: Dictionary = {}
var stages: Array = []
var stage_index := -1
var t := 0.0
var state := "idle"          # idle / playing / clear / won
var running := false
var rng := RandomNumberGenerator.new()
var boss: Node = null
var boss_spawned := false
var overtime := false
var ot_t := 0.0
var _ot_clock := 0.0
var _trickle_clock := 2.0
var _beat_done: Dictionary = {}
var _warned: Dictionary = {}
var _queue: Array = []
var _clear_t := 0.0
var nests: Array = []
var stage_enemies: Array = []
var stage_targets: Array = []
var warn_until := 0.0
## 强度采样（每秒一条）：测试 / 调参看曲线用
var telemetry: Array = []
var _sample_t := 0.0
var _hp_last := -1.0
var _dmg_acc := 0.0
var stats := {"spawned": 0, "dropped": 0, "beats": 0, "swarms": 0, "overtime_spawns": 0, "nest_spawns": 0, "escaped": 0}

func setup(owner_main: Node) -> void:
	main = owner_main
	process_mode = Node.PROCESS_MODE_PAUSABLE
	load_config()

func load_config() -> void:
	var path := CONFIG_PATH
	if OS.has_feature("template"):
		var side := OS.get_executable_path().get_base_dir().path_join("stages.json")
		if FileAccess.file_exists(side):
			path = side
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("StageDirector: 读不到 %s" % path)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		config = parsed
		stages = config.get("stages", [])

func g(key: String, fallback: Variant) -> Variant:
	return (config.get("global", {}) as Dictionary).get(key, fallback)

func stage() -> Dictionary:
	return stages[stage_index] if stage_index >= 0 and stage_index < stages.size() else {}

func start(index := 0, seed_value := 0) -> void:
	rng.seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())
	telemetry.clear()
	_begin_stage(index)

func stop() -> void:
	running = false
	state = "idle"
	_queue.clear()

# ---------------------------------------------------------------- 阶段

func _begin_stage(index: int) -> void:
	stage_index = index
	t = 0.0
	ot_t = 0.0
	_ot_clock = 0.0
	_trickle_clock = 2.0
	_beat_done.clear()
	_warned.clear()
	_queue.clear()
	boss = null
	boss_spawned = false
	overtime = false
	state = "playing"
	running = true
	_clear_stage_entities()
	var s := stage()
	if main.has_method("apply_stage_biome"):
		main.apply_stage_biome(str(s.get("biome", "river")))
	_spawn_nests()
	_spawn_scrap_fields()
	stage_started.emit(index)

func _clear_stage_entities() -> void:
	for e in stage_enemies + nests:
		if is_instance_valid(e):
			e.queue_free()
	stage_enemies.clear()
	nests.clear()
	for tg in stage_targets:
		if is_instance_valid(tg):
			tg.queue_free()
	stage_targets.clear()

func mult(key: String) -> float:
	return float((stage().get("mult", {}) as Dictionary).get(key, 1.0))

func hp_mult_for(tier: String) -> float:
	if tier == "swarm":
		return mult("hp_swarm")
	if tier == "neutral":
		return 1.0
	return mult("hp")

func progress() -> float:
	return clampf(t / maxf(float(stage().get("overtime_at", 240.0)), 1.0), 0.0, 1.0)

static func curve(points: Array, x: float) -> float:
	if points.is_empty():
		return 1.0
	if x <= float(points[0][0]):
		return float(points[0][1])
	for i in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		if x <= float(b[0]):
			var u := (x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			return lerpf(float(a[1]), float(b[1]), u)
	return float(points.back()[1])

func boss_alive() -> bool:
	return boss != null and is_instance_valid(boss) and not boss.dead

# ---------------------------------------------------------------- 主循环

func _process(delta: float) -> void:
	if not running or main == null or main.outcome != "active":
		return
	_drain_queue()
	_sample(delta)
	if state == "clear":
		_clear_t -= delta
		if _clear_t <= 0.0 and not _selection_open():
			_advance()
		return
	if state != "playing":
		return
	t += delta
	var s := stage()
	_tick_beats(s)
	_tick_trickle(s, delta)
	if not boss_spawned and t >= float(s.get("boss_at", 150.0)):
		spawn_boss()
	if not overtime and t >= float(s.get("overtime_at", 240.0)) and boss_alive():
		overtime = true
		overtime_started.emit()
		if main.ui != null:
			main.ui.boss_callout("加时！清场者出动", Color("#D9412B"))
		main.feedback("加时 · 清场者出动 · 快打掉 Boss")
	if overtime:
		_tick_overtime(s, delta)

func _selection_open() -> bool:
	return (main.selection_ui != null and main.selection_ui.visible) or not main.pending_selections.is_empty() or not main._deferred_selections.is_empty()

func _tick_beats(s: Dictionary) -> void:
	var beats: Array = s.get("beats", [])
	for i in beats.size():
		var b: Dictionary = beats[i]
		if _beat_done.has(i):
			continue
		var bt := float(b.get("t", 0.0))
		if str(b.get("type")) == "swarm" and not _warned.has(i) and t >= bt - float(b.get("warn", 4.0)):
			_warned[i] = true
			var secs := bt - t
			warn_until = t + secs
			swarm_warning.emit(secs)
			if main.ui != null:
				main.ui.boss_callout("蜂群来袭！", Color("#D9412B"))
			if GameFeel.instance != null:
				GameFeel.instance.shake(0.25)
			main.feedback("蜂群来袭 · %d 秒后两侧夹击" % int(ceil(secs)))
			if main.audio != null:
				main.audio.play_event("boss_spawn")
		if t >= bt:
			_beat_done[i] = true
			fire_beat(b)

func fire_beat(b: Dictionary) -> void:
	stats["beats"] = int(stats["beats"]) + 1
	match str(b.get("type", "wave")):
		"wave":
			_enqueue_wave(str(b["a"]), _count(int(b.get("n", 1)), str(b["a"])), str(b.get("pattern", "ahead")))
		"swarm":
			stats["swarms"] = int(stats["swarms"]) + 1
			for w in b.get("waves", []):
				_enqueue_wave(str(w["a"]), _count(int(w.get("n", 1)), str(w["a"])), str(w.get("pattern", "double")))
		"neutral":
			match str(b.get("what", "")):
				"scrap_field":
					_spawn_scrap_cluster(_pattern_points(1, "ahead", 0.85)[0], int(b.get("n", 6)))
				_:
					_enqueue_wave(str(b["what"]), int(b.get("n", 1)), str(b.get("pattern", "ahead")))
	if b.has("call") and main.ui != null:
		main.ui.boss_callout(str(b["call"]), Color("#E3A52B"))

## 数量 × 阶段倍率（精英 / 中立不乘）
func _count(n: int, archetype: String) -> int:
	var tier := str(EnemyArchetypes.get_def(archetype).get("tier", "minion"))
	if tier in ["elite", "neutral", "structure"]:
		return n
	return maxi(1, int(round(float(n) * mult("count"))))

func _tick_trickle(s: Dictionary, delta: float) -> void:
	_trickle_clock -= delta
	if _trickle_clock > 0.0:
		return
	var tr: Dictionary = s.get("trickle", {})
	_trickle_clock = curve(tr.get("interval", [[0, 6.0]]), progress())
	var entry := _pick_pool(tr.get("pool", []))
	if entry.is_empty():
		return
	var strength := trickle_strength()
	var nr: Array = entry.get("n", [1, 1])
	var n := float(rng.randi_range(int(nr[0]), int(nr[1]))) * strength
	var count := _count(maxi(1, int(round(n))), str(entry["a"]))
	var patterns := ["ahead", "ahead", "random", "surround"]
	_enqueue_wave(str(entry["a"]), count, patterns[rng.randi() % patterns.size()])

func trickle_strength() -> float:
	var tr: Dictionary = stage().get("trickle", {})
	var s := curve(tr.get("strength", [[0, 1.0]]), progress())
	if boss_alive():
		s *= float(g("boss_trickle_dip", 0.55))
	return s

func _pick_pool(pool: Array) -> Dictionary:
	var weights: Dictionary = g("rarity_weights", {"common": 70, "uncommon": 25, "rare": 5})
	var eligible := pool.filter(func(e): return t >= float(e.get("from", 0.0)))
	if eligible.is_empty():
		return {}
	var total := 0.0
	for e in eligible:
		total += float(weights.get(str(e.get("rarity", "common")), 10))
	var roll := rng.randf() * total
	for e in eligible:
		roll -= float(weights.get(str(e.get("rarity", "common")), 10))
		if roll <= 0.0:
			return e
	return eligible.back()

func _tick_overtime(s: Dictionary, delta: float) -> void:
	ot_t += delta
	_ot_clock -= delta
	if _ot_clock > 0.0:
		return
	var ot: Dictionary = s.get("overtime", {})
	_ot_clock = curve(ot.get("interval", [[0, 12.0]]), ot_t)
	for e in ot.get("pool", []):
		var nr: Array = e.get("n", [1, 1])
		var n := rng.randi_range(int(nr[0]), int(nr[1]))
		stats["overtime_spawns"] = int(stats["overtime_spawns"]) + n
		_enqueue_wave(str(e["a"]), n, "ahead")

# ---------------------------------------------------------------- 刷怪位置（照搬原作 6 种模式）

func _focus() -> Vector3:
	return main.player.global_position if main.player != null else Vector3.ZERO

func _travel_dir() -> Vector3:
	var p = main.player
	if p == null:
		return Vector3(0, 0, -1)
	var v := Vector3(p.velocity.x, 0, p.velocity.z)
	if v.length() > 1.0:
		return v.normalized()
	var h: Vector3 = p.heading
	return Vector3(h.x, 0, h.z).normalized() if h.length() > 0.1 else Vector3(0, 0, -1)

func cam_size() -> float:
	return main.world.camera.size if main.world != null and main.world.camera != null else 19.0

func spawn_radius() -> float:
	return ArenaLayout.offscreen_radius(cam_size(), float(g("offscreen_margin", 4.0)))

## 返回 count 个簇中心（每簇再在 _enqueue_wave 里抖开）。radius_scale < 1 可让中立目标出现在屏幕边缘
func _pattern_points(clusters: int, pattern: String, radius_scale := 1.0) -> Array:
	var focus := _focus()
	var r := spawn_radius() * radius_scale
	var fwd := _travel_dir()
	var base := atan2(fwd.z, fwd.x)
	var angles: Array = []
	match pattern:
		"ahead":
			angles = [base + rng.randf_range(-0.35, 0.35)]
		"surround":
			var k := maxi(clusters, 6)
			for i in k:
				angles.append(base + TAU * float(i) / float(k) + rng.randf_range(-0.12, 0.12))
		"double":
			var side := base + PI * 0.5 + rng.randf_range(-0.4, 0.4)
			angles = [side, side + PI]
		"all":
			angles = [base, base + PI * 0.5, base + PI, base + PI * 1.5]
		"groups":
			for i in maxi(clusters, 3):
				angles.append(rng.randf() * TAU)
		_:
			angles = [rng.randf() * TAU]
	var out: Array = []
	for a in angles:
		out.append(_legal_point(focus, float(a), r))
	return out

## 场地内 + 镜头外：靠墙时换角度重试，实在不行取夹回场地的点
func _legal_point(focus: Vector3, angle: float, r: float) -> Vector3:
	for k in 10:
		var a := angle + (0.0 if k == 0 else (0.45 * float((k + 1) / 2) * (1.0 if k % 2 == 1 else -1.0)))
		var p := focus + Vector3(cos(a), 0, sin(a)) * r
		if ArenaLayout.inside(p, ArenaLayout.EDGE_PAD) and not ArenaLayout.in_view(p, focus, cam_size(), -1.0):
			return p
	var fallback := ArenaLayout.clamp_inside(focus + Vector3(cos(angle), 0, sin(angle)) * r)
	return fallback

func _enqueue_wave(archetype: String, count: int, pattern: String) -> void:
	if EnemyArchetypes.get_def(archetype).is_empty() or count <= 0:
		return
	var centers := _pattern_points(int(ceil(count / 6.0)), pattern)
	var per := int(ceil(float(count) / float(centers.size())))
	var left := count
	for c in centers:
		var n := mini(per, left)
		left -= n
		var spread := 1.6 + sqrt(float(n)) * 0.7
		var focus := _focus()
		var cs := cam_size()
		for i in n:
			var a := rng.randf() * TAU
			var dd := sqrt(rng.randf()) * spread
			var at := ArenaLayout.clamp_inside((c as Vector3) + Vector3(cos(a) * dd, 0, sin(a) * dd), 1.0)
			var guard := 0
			while ArenaLayout.in_view(at, focus, cs, -0.5) and guard < 6:
				var out := Vector3(at.x - focus.x, 0, at.z - focus.z)
				out = out.normalized() if out.length() > 0.1 else Vector3(1, 0, 0)
				at = ArenaLayout.clamp_inside(at + out * 2.5, 1.0)
				guard += 1
			_queue.append([archetype, at])
		if left <= 0:
			break

func alive_hostiles() -> int:
	var n := 0
	for e in stage_enemies:
		if is_instance_valid(e) and not e.dead and EnemyArchetypes.is_hostile(str(e.tier)):
			n += 1
	return n

func _drain_queue() -> void:
	if _queue.is_empty():
		return
	stage_enemies = stage_enemies.filter(func(e): return is_instance_valid(e) and not e.dead)
	var budget := int(g("spawns_per_frame", 3))
	var cap := int(g("max_alive", 80))
	var alive := alive_hostiles()
	var kept: Array = []
	while not _queue.is_empty() and budget > 0:
		var req: Array = _queue.pop_front()
		var tier := str(EnemyArchetypes.get_def(str(req[0])).get("tier", "minion"))
		if alive >= cap and tier in ["swarm", "minion"]:
			stats["dropped"] = int(stats["dropped"]) + 1
			continue
		var e := spawn(str(req[0]), req[1])
		if e != null:
			budget -= 1
			alive += 1
	_queue = kept + _queue

func spawn(archetype: String, at: Vector3) -> Node:
	var def := EnemyArchetypes.get_def(archetype)
	var tier := str(def.get("tier", "minion"))
	var cap := int(g("max_alive", 80))
	var alive := alive_hostiles()
	if (tier in ["swarm", "minion"] and alive >= cap) or alive >= int(cap * 1.25):
		stats["dropped"] = int(stats["dropped"]) + 1
		return null
	if bool(def.get("overtime", false)):
		var ot_alive := stage_enemies.filter(func(e): return is_instance_valid(e) and not e.dead and e.archetype_id == archetype).size()
		if ot_alive >= int(g("overtime_max_alive", 6)):
			stats["dropped"] = int(stats["dropped"]) + 1
			return null
	var e: Node = main.spawn_stage_enemy(archetype, at, hp_mult_for(tier), mult("dmg"))
	if e != null:
		stage_enemies.append(e)
		stats["spawned"] = int(stats["spawned"]) + 1
		if e.has_signal("escaped"):
			e.escaped.connect(func(_x): stats["escaped"] = int(stats["escaped"]) + 1)
	return e

# ---------------------------------------------------------------- 敌巢 / 废料场

func _spawn_nests() -> void:
	var cfg: Dictionary = stage().get("nests", {})
	if cfg.is_empty():
		return
	for p in ArenaLayout.NESTS:
		var at := Vector3((p as Vector2).x, 0.0, (p as Vector2).y)
		var nest: Node = main.spawn_stage_enemy("nest", at, 1.0, 1.0)
		if nest == null:
			continue
		nest.health = float(cfg.get("hp", 220.0))
		nest.current_health = nest.health
		nest.nest_interval = float(cfg.get("interval", 3.5))
		nest.nest_range = float(cfg.get("range", 18.0))
		nest.nest_spawn_requested.connect(_on_nest_spawn)
		nests.append(nest)

func _on_nest_spawn(nest: Node) -> void:
	var cfg: Dictionary = stage().get("nests", {})
	if state != "playing" or nest.nest_children.size() >= int(cfg.get("max_alive", 5)) or alive_hostiles() >= int(g("max_alive", 80)):
		return
	var pool: Array = cfg.get("spawn", ["swarm_flea"])
	var arch := str(pool[rng.randi() % pool.size()])
	var n := 2 if str(EnemyArchetypes.get_def(arch).get("tier")) == "swarm" else 1
	for i in n:
		if nest.nest_children.size() >= int(cfg.get("max_alive", 5)):
			break
		var at: Vector3 = nest.global_position + Vector3(rng.randf_range(-1.5, 1.5), 0, 2.4 + rng.randf_range(0.0, 1.0))
		var e := spawn(arch, ArenaLayout.clamp_inside(at, 1.0))
		if e != null:
			nest.nest_children.append(e)
			stats["nest_spawns"] = int(stats["nest_spawns"]) + 1
			SkillVfx.dust_ring(at, 1.4)
	if nest.rig == null and nest.visual_root != null:
		var tw: Tween = nest.create_tween()
		tw.tween_property(nest.visual_root, "scale", Vector3(1.08, 0.9, 1.08), 0.08)
		tw.tween_property(nest.visual_root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_scrap_fields() -> void:
	for p in ArenaLayout.SCRAP_FIELDS:
		_spawn_scrap_cluster(Vector3((p as Vector2).x, 0.0, (p as Vector2).y), 7)

func _spawn_scrap_cluster(center: Vector3, n: int) -> void:
	for i in n:
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.3, 0.3)
		var d := 1.2 + rng.randf_range(0.0, 2.6)
		var at := ArenaLayout.clamp_inside(center + Vector3(cos(a) * d, 0, sin(a) * d), 1.5)
		var tg: Node = main.spawn_stage_scrap("soft" if i % 3 != 2 else "light", at)
		if tg != null:
			stage_targets.append(tg)

# ---------------------------------------------------------------- Boss / 清场 / 推进

func spawn_boss() -> void:
	if boss_spawned:
		return
	boss_spawned = true
	var s := stage()
	var focus := _focus()
	var to_arena := Vector3(ArenaLayout.BOSS_ARENA.x, 0, ArenaLayout.BOSS_ARENA.y) - focus
	var ang := atan2(to_arena.z, to_arena.x) if to_arena.length() > 6.0 else rng.randf() * TAU
	var at := _legal_point(focus, ang, maxf(spawn_radius() * 0.8, 18.0))
	boss = main.summon_boss_at(str(s.get("boss", "boss_kanoning")), Vector3(at.x, 1.2, at.z), mult("hp_boss") if (stage().get("mult", {}) as Dictionary).has("hp_boss") else mult("hp"), mult("dmg_boss") if (stage().get("mult", {}) as Dictionary).has("dmg_boss") else mult("dmg"))
	if boss != null:
		boss.defeated.connect(func(_b): _on_boss_down())

func force_boss() -> void:
	if state == "playing" and not boss_spawned:
		t = maxf(t, float(stage().get("boss_at", 150.0)) - 0.01)

func skip_stage() -> void:
	if state == "playing":
		_on_boss_down()

func _on_boss_down() -> void:
	if state != "playing":
		return
	state = "clear"
	_clear_t = float(g("stage_break", 4.0))
	_queue.clear()
	stage_cleared.emit(stage_index)
	_rout()

## 阶段清场：剩下的敌人溃散（不给奖励），掉落物全部吸给玩家
func _rout() -> void:
	for e in stage_enemies:
		if is_instance_valid(e) and not e.dead and EnemyArchetypes.is_hostile(str(e.tier)) and not (e is BossEntity):
			e.dead = true
			if e.is_inside_tree():
				SkillVfx.dust_ring(e.global_position, 1.2)
				var tw: Tween = e.create_tween()
				tw.tween_property(e, "scale", Vector3(1.1, 0.05, 1.1), 0.3 + rng.randf() * 0.4)
				tw.tween_callback(e.queue_free)
	for n in nests:
		if is_instance_valid(n) and not n.dead:
			n.nest_range = 0.0
	if main.has_method("vacuum_loot"):
		main.vacuum_loot()

func _advance() -> void:
	if stage_index + 1 >= stages.size():
		state = "won"
		running = false
		campaign_won.emit()
		return
	_begin_stage(stage_index + 1)

# ---------------------------------------------------------------- 采样 / HUD

func on_player_damaged(amount: float) -> void:
	_dmg_acc += amount

func threat_near(radius := 25.0) -> float:
	var focus := _focus()
	var sum := 0.0
	for e in stage_enemies:
		if is_instance_valid(e) and not e.dead and EnemyArchetypes.is_hostile(str(e.tier)):
			if (e.global_position - focus).length() <= radius:
				sum += float(THREAT_WEIGHT.get(str(e.tier), 3.0))
	if boss_alive() and (boss.global_position - focus).length() <= radius * 1.5:
		sum += THREAT_WEIGHT["boss"]
	return sum

func _sample(delta: float) -> void:
	_sample_t -= delta
	if _sample_t > 0.0:
		return
	_sample_t = 1.0
	var p = main.player
	var vp = main.vehicle_progression
	telemetry.append({
		"stage": stage_index + 1, "t": snappedf(t, 0.1), "state": state, "alive": alive_hostiles(),
		"threat": snappedf(threat_near(), 0.1), "hp": snappedf(float(p.health), 0.1) if p != null else 0.0,
		"max_hp": float(p.max_health) if p != null else 100.0, "dmg_taken": snappedf(_dmg_acc, 0.1),
		"level": int(vp.level) if vp != null else 1, "boss": boss_alive(), "overtime": overtime,
		"kills": int(main.run_stats.get("kills", 0)), "queue": _queue.size(),
		"boss_hp": snappedf(float(boss.current_health), 1) if boss_alive() else 0.0,
		"boss_dist": snappedf(boss.global_position.distance_to(_focus()), 0.1) if boss_alive() else -1.0,
	})
	_dmg_acc = 0.0

func swarm_times() -> Array:
	var out: Array = []
	for b in stage().get("beats", []):
		if str(b.get("type")) == "swarm":
			out.append(float(b.get("t", 0.0)))
	return out

func hud_line() -> String:
	var s := stage()
	if s.is_empty():
		return ""
	var head := "阶段 %d/%d  %s" % [stage_index + 1, stages.size(), str(s.get("name", ""))]
	if state == "clear":
		return head + "  ·  清场！"
	if boss_alive():
		return head + ("  ·  加时！快打 Boss" if overtime else "  ·  击败 Boss")
	var left := float(s.get("boss_at", 150.0)) - t
	return head + "  ·  Boss %02d:%02d" % [int(left) / 60, int(left) % 60]
