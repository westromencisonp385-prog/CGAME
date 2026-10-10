extends SceneTree

## C28 强度采样：机器人只用 WASD + 技能（攻击全自动，同真人操作口径）打完整局，按 1 秒采样强度曲线
## 用法：godot --path game --headless --script res://tests/c28_balance_sim.gd [-- immortal] [-- seed=N]
## 输出 artifacts/qa/c28_level/telemetry[_immortal].json
const OUT := "D:/工作/InverseGame/WaWa/CGAME/artifacts/qa/c28_level"
const SPEED := 4.0
const REAL_LIMIT := 900.0
var main: Node
var d
var immortal := false
var seed_value := 777
var _dash_cd := 0.0
var _summon_cd := 5.0
var _last_hp := 100.0
var _wander := Vector3(1, 0, 0)
var _wander_t := 0.0
var deaths: Array = []

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "immortal":
			immortal = true
		elif a.begins_with("seed="):
			seed_value = int(a.substr(5))
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	main.ui.hint_time = 0.0
	seed(seed_value)
	main.start_campaign(0, seed_value)
	d = main.director
	if immortal:
		main.debug_hp_bonus = 100000.0
	Engine.time_scale = SPEED
	var t0 := Time.get_ticks_msec()
	var last_print := 0
	while (Time.get_ticks_msec() - t0) / 1000.0 < REAL_LIMIT:
		await physics_frame
		_bot_tick(main.get_physics_process_delta_time())
		if Time.get_ticks_msec() - last_print > 10000:
			last_print = Time.get_ticks_msec()
			print("PROG real=%ds stage=%d t=%.0f state=%s alive=%d hp=%.0f lv=%d sel=%s paused=%s ts=%.2f pend=%d" % [(last_print - t0) / 1000, d.stage_index + 1, d.t, d.state, d.alive_hostiles(), main.player.health, main.vehicle_progression.level, main.selection_ui.visible, paused, Engine.time_scale, main.pending_selections.size() + main._deferred_selections.size()])
		if main.outcome != "active":
			break
	Engine.time_scale = 1.0
	_release_all()
	var summary := _summarize()
	var path := "%s/telemetry%s_s%d.json" % [OUT, "_immortal" if immortal else "", seed_value]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"seed": seed_value, "immortal": immortal, "outcome": main.outcome, "summary": summary, "samples": d.telemetry}, "  "))
	f.close()
	print("SIM outcome=%s reached_stage=%d level=%d kills=%d real=%.0fs" % [main.outcome, d.stage_index + 1, main.vehicle_progression.level, int(main.run_stats["kills"]), (Time.get_ticks_msec() - t0) / 1000.0])
	for s in summary:
		print("SIM %s" % JSON.stringify(s))
	# B1：伤害来源 / 通道占比（目标：自动 ≈ 70%，主动 ≈ 30%）
	var split := DamagePipeline.channel_split()
	var tot := maxf(DamagePipeline.total(), 1.0)
	print("SIM CHANNEL auto=%.0f%% active=%.0f%% other=%.0f%%" % [float(split.auto) / tot * 100.0, float(split.active) / tot * 100.0, float(split.other) / tot * 100.0])
	var top := DamagePipeline.summary(func(k): return ContentV2Catalog.name_of(str(k)))
	print("SIM TOP %s" % JSON.stringify(top.slice(0, 8).map(func(r): return "%s %d%%" % [r.label, int(round(float(r.share) * 100.0))])))
	quit(0)

func _summarize() -> Array:
	var out: Array = []
	for si in range(1, 5):
		var rows: Array = d.telemetry.filter(func(r): return int(r["stage"]) == si)
		if rows.is_empty():
			continue
		var dmg := 0.0
		var peak_alive := 0
		var peak_threat := 0.0
		var min_hp := 1e9
		var min_ratio := 1.0
		var boss_t := -1.0
		for r in rows:
			dmg += float(r["dmg_taken"])
			peak_alive = maxi(peak_alive, int(r["alive"]))
			peak_threat = maxf(peak_threat, float(r["threat"]))
			min_hp = minf(min_hp, float(r["hp"]))
			min_ratio = minf(min_ratio, float(r["hp"]) / maxf(float(r["max_hp"]), 1.0))
			if bool(r["boss"]) and boss_t < 0.0:
				boss_t = float(r["t"])
		out.append({"stage": si, "duration": float(rows.back()["t"]), "dmg_taken": snappedf(dmg, 1), "dmg_per_min": snappedf(dmg / maxf(float(rows.back()["t"]), 1.0) * 60.0, 1),
			"peak_alive": peak_alive, "peak_threat": peak_threat, "min_hp": min_hp, "min_hp_pct": snappedf(min_ratio * 100.0, 1), "level_end": int(rows.back()["level"]),
			"kills_end": int(rows.back()["kills"]), "boss_seen_at": boss_t, "boss_fight": snappedf(float(rows.back()["t"]) - boss_t, 1) if boss_t >= 0.0 else -1.0, "overtime": rows.any(func(r): return bool(r["overtime"]))})
	return out

func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)

func _press_dir(v: Vector3) -> void:
	_release_all()
	if v.length() < 0.05:
		return
	v = v.normalized()
	if v.x < -0.15: Input.action_press("move_left", minf(1.0, -v.x * 1.4))
	if v.x > 0.15: Input.action_press("move_right", minf(1.0, v.x * 1.4))
	if v.z < -0.15: Input.action_press("move_up", minf(1.0, -v.z * 1.4))
	if v.z > 0.15: Input.action_press("move_down", minf(1.0, v.z * 1.4))

func _bot_tick(dt: float) -> void:
	var p = main.player
	if main.selection_ui.visible:
		main.selection_ui._choose(randi() % maxi(1, main.selection_ui._cards.size()))
		return
	if main.manual_pause or main.garage_open:
		return
	if p.health <= 0.0:
		return
	var me: Vector3 = p.global_position
	var repulse := Vector3.ZERO
	var nearest: Node3D = null
	var nd := INF
	var crowd := 0
	for e in d.stage_enemies + ([d.boss] if d.boss_alive() else []):
		if not is_instance_valid(e) or e.dead or not EnemyArchetypes.is_hostile(str(e.tier)) and not (e is BossEntity):
			continue
		var off: Vector3 = me - e.global_position
		off.y = 0
		var dist := off.length()
		if dist < nd and str(e.tier) != "boss" and not (e is BossEntity):
			nd = dist
			nearest = e
		var w := 1.0
		if e is BossEntity:
			w = 7.0
		elif str(e.tier) == "elite":
			w = 3.0
		if dist < 7.0:
			crowd += 1
			repulse += off.normalized() * w / maxf(dist * dist, 0.6)
	var want := Vector3.ZERO
	if d.boss_alive() and crowd < 14:
		nearest = d.boss
		nd = me.distance_to(d.boss.global_position)
	if nearest != null and nd < 16.0 or (nearest != null and nearest is BossEntity):
		var to: Vector3 = nearest.global_position - me
		to.y = 0
		var tangent := Vector3(-to.z, 0, to.x).normalized()
		var radial := to.normalized() * clampf((nd - 2.6) * 0.5, -1.0, 1.0)
		want = tangent * 0.8 + radial + repulse * 2.2
	else:
		# 没敌人：去最近的中立 / 敌巢 / 废料，否则游走
		var goal: Node3D = null
		var gd := INF
		for e in d.stage_enemies + d.nests:
			if is_instance_valid(e) and not e.dead and str(e.tier) in ["neutral", "structure"]:
				var dd: float = me.distance_to(e.global_position)
				if dd < gd:
					gd = dd
					goal = e
		for tg in d.stage_targets:
			if is_instance_valid(tg) and not tg.dead:
				var dd2: float = me.distance_to(tg.global_position)
				if dd2 < gd:
					gd = dd2
					goal = tg
		if goal != null:
			want = goal.global_position - me
		else:
			_wander_t -= dt
			if _wander_t <= 0.0:
				_wander_t = 3.0
				_wander = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			want = _wander
	# 墙：往场地中心拉
	var edge := Vector3(-me.x / ArenaLayout.HALF.x, 0, -me.z / ArenaLayout.HALF.y)
	if absf(me.x) > ArenaLayout.HALF.x - 8.0 or absf(me.z) > ArenaLayout.HALF.y - 8.0:
		want += edge * 2.0
	_press_dir(want)
	# 冲刺：掉血或被围时
	_dash_cd -= dt
	if _dash_cd <= 0.0 and (p.health < _last_hp - 4.0 or crowd >= 10):
		_dash_cd = 2.5
		p.try_dash()
	_last_hp = p.health
	# 技能：附近有敌人就放
	if nd < 9.0 or d.boss_alive():
		var slots: Array = main.vehicle_progression.active_slots
		var cds: Array = main.vehicle_progression.cooldowns()
		for i in 4:
			if i < slots.size() and slots[i] is Dictionary and not (slots[i] as Dictionary).is_empty() and float(cds[i]) <= 0.0:
				main._try_cast(i)
	_summon_cd -= dt
	if _summon_cd <= 0.0 and nd < 10.0:
		var k := randi() % 3
		if float(main.summon_cooldowns[k]) <= 0.0:
			_summon_cd = 18.0
			main._try_summon(k)
