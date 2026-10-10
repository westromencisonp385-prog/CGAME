extends Node3D
## A complete short M0 experiment, without claiming M1 campaign/platform scope.
const Catalog = preload("res://scripts/module_catalog.gd")
const InputSetup = preload("res://scripts/m0_input.gd")
const ArenaVisual = preload("res://scripts/arena_visual.gd")
const HUD = preload("res://scripts/m0_hud.gd")
const GMController = preload("res://scripts/gm_controller.gd")
const Sound = preload("res://scripts/wanderburg_audio.gd")
const BiomeSys = preload("res://scripts/systems/biome_system.gd")
const BiomeGateScript = preload("res://scripts/systems/biome_gate.gd")
const BiomeKeyPickupScript = preload("res://scripts/systems/biome_key_pickup.gd")
const BiomeWeatherScript = preload("res://scripts/systems/biome_weather.gd")
const SummonScript = preload("res://scripts/systems/summon_entity.gd")
const TARGET_LAYOUT := [
	["scrap_01", "soft", -5.0, 3.0, 18.0], ["scrap_02", "soft", -7.0, 1.0, 18.0],
	["scrap_03", "light", -3.0, -2.0, 22.0], ["scrap_04", "light", 0.0, -2.0, 22.0],
	["barrier_01", "hard", 3.0, -3.0, 40.0], ["barrier_02", "hard", 5.0, -3.0, 40.0],
	["scrap_05", "soft", 6.0, 3.0, 18.0], ["scrap_06", "light", 8.0, 1.0, 22.0],
	["repair_pump", "repair", 6.0, -7.0, 30.0]
]
const ENEMY_LAYOUT := [
	["crawler_a", "light", -8.0, -5.0], ["crawler_b", "light", -6.0, -6.0],
	["crawler_c", "light", -7.0, -8.0], ["crawler_d", "light", -9.0, -8.0],
	["guardian", "heavy", 10.0, -11.5]
]
const CONTRACT_ID := "river_revival_01"
const CONTRACT_BRIEF := {
	"title": "复苏河岸",
	"anchor": "C04 repair pump",
	"threat": "B01 reverse-crab barricade and guardian",
	"signature_build": "magnetic_whale",
	"stages": ["clear_scrap", "whale_pack", "repair_pump", "clear_threats"],
}
const M1_REWARD_BLUEPRINT_ID := "blueprint_magnetic_compactor"
const CAMPAIGN_SAVE_PATH := "user://reclaimer_campaign_progress"

var player: M0VehicleController
var assembler: LoadoutAssembler
var save_service := M0SaveService.new()
var campaign_service := M0SaveService.new()
var campaign_progress: Dictionary = {"version": 1, "unlocked_blueprints": []}
var definitions: Dictionary
var targets: Array[EngineeringTarget] = []
var enemies: Array[EnemyDummy] = []
var gm_enemies: Array[EnemyDummy] = []
var entities: Node3D
var world: Node3D
var ui: CanvasLayer
var gm: M0GMController
var audio: WanderburgAudio
var elapsed := 0.0
var collected := 0
var defeated := 0
var repair_done := false
var shortcut_open := false
var outcome := "active"
var garage_open := false
var manual_pause := false
var target_slot := 0
var simulation_enabled := true
var shortcut_gate: CollisionShape3D
var campaign_reward_pending := ""
var reward_retry_clock := 0.0
## Wanderburg 对齐系统束（C2/C3/C4）：选择流 / 单局经济任务 / 载具成长
var selection_engine: SelectionEngine
var selection_ui: SelectionUI
var last_selection_options: Array = []
var run_systems: RunSystems
var vehicle_progression: VehicleProgression
## S3/C5/C6 切片：v2 模块定义桥接、Boss 实体、技能施放冷却
var v2_definitions: Dictionary = {}
var boss: BossEntity = null
var ability_cooldowns: Dictionary = {}
## C7 群系锁钥 + 技能召唤分支
var biome_system: BiomeSystem
var biome_weather: BiomeWeather
var biome_gates: Array = []
var biome_keys: Array = []
var summons: Array = []
var active_summon_slots: Array = [null, null, null]
## C17：手感层 / 长期档案 / 模块升级 / 选择队列 / 战斗统计
var feel: GameFeel
var cam_rig: CameraRig3C
var profile := ProfileStore.new()
var profile_enabled := false
var module_levels: Dictionary = {}       # module_id -> {damage, cooldown, range, crit, echo, level}
var pending_selections: Array = []
## 延时弹出的选择：[到期毫秒, kind]（让升级 / 击杀演出先播完）
var _deferred_selections: Array = []

func queue_selection(kind: String, delay_sec: float) -> void:
	_deferred_selections.append([Time.get_ticks_msec() + int(delay_sec * 1000.0), kind])
var overclock_time := 0.0
var run_stats: Dictionary = {"kills": 0, "elites": 0, "bosses": 0, "casts": 0, "dodges": 0, "loot": 0, "silver_at_start": 0}
var _kill_times: Array = []
var _last_crits := 0
var _last_status_count := 0
var vehicle_choice_ranks := [2, 4]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 导出版启动即最大化：4K 屏上 1280x720 小窗只占 1/9，细节全挤成一团（F11 切全屏）
	if OS.has_feature("template") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	InputSetup.configure()
	definitions = Catalog.create_definitions()
	world = ArenaVisual.new()
	add_child(world)
	_build_shortcut_gate()
	entities = Node3D.new()
	entities.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(entities)
	player = M0VehicleController.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	assembler = LoadoutAssembler.new()
	player.add_child(assembler)
	assembler.setup(player, definitions)
	player.setup(assembler, world.camera)
	player.stat_modifier_provider = func(stat_name: String): return run_systems.total_bonus(stat_name) if run_systems != null else 0.0
	if world.has_method("set_vehicle"):
		world.set_vehicle(player)
	player.feedback.connect(feedback)
	player.disabled.connect(func(): finish_contract("failed"))
	player.harvested.connect(_harvested)
	player.action_effect.connect(world.present_effect)
	world.add_to_group("effects_sink")
	feel = GameFeel.new()
	add_child(feel)
	feel.setup(world.camera, entities)
	cam_rig = CameraRig3C.new()
	cam_rig.setup(world.camera)
	player.dodged.connect(_on_player_dodged)
	profile_enabled = DisplayServer.get_name() != "headless"
	if profile_enabled:
		profile.load_profile()
	audio = Sound.new()
	add_child(audio)
	campaign_service.configure(CAMPAIGN_SAVE_PATH)
	_load_campaign_progress()
	_init_wanderburg_systems()
	ui = HUD.new()
	add_child(ui)
	gm = GMController.new()
	gm.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(gm)
	ui.setup(self)
	reset_contract()
	gm.setup(self)
	gm.state_changed.connect(_on_gm_state_changed)
	ui.refresh_gm_panel()

func _process(delta: float) -> void:
	if not _deferred_selections.is_empty():
		var now := Time.get_ticks_msec()
		var due: Array = _deferred_selections.filter(func(d): return int(d[0]) <= now)
		if not due.is_empty():
			_deferred_selections = _deferred_selections.filter(func(d): return int(d[0]) > now)
			for d in due:
				open_selection_flow(str(d[1]))
	if outcome == "active" and not get_tree().paused and simulation_enabled:
		elapsed += delta
	if outcome == "active" and not campaign_reward_pending.is_empty():
		reward_retry_clock += delta
		if reward_retry_clock >= 2.0:
			reward_retry_clock = 0.0
			check_victory()
	if player != null:
		var hovered := get_viewport().gui_get_hovered_control()
		player.gameplay_enabled = outcome == "active" and not garage_open and not manual_pause and not gm.visible and simulation_enabled and (hovered == null or not _is_gameplay_blocking_control(hovered))
		if player.health <= 0.0 and outcome == "active":
			finish_contract("failed")
		# C7：技能冷却递减（修复 tick 缺失缺陷）+ 群系环境速度修正
		if vehicle_progression != null:
			vehicle_progression.tick(delta)
		for i in range(summon_cooldowns.size()):
			summon_cooldowns[i] = maxf(0.0, float(summon_cooldowns[i]) - delta)
		summons = summons.filter(func(s): return is_instance_valid(s))
		var speed_factor := float(biome_system.environment_effect()["speed_factor"]) if biome_system != null else 1.0
		player.max_speed = player.base_speed * speed_factor * (1.0 + clampf(run_systems.total_bonus("speed"), -0.5, 1.0))
		if run_systems.total_bonus("regen") > 0.0 and player.health > 0.0:
			player.health = minf(player.health + run_systems.total_bonus("regen") * delta, player.max_health)
		var new_max := 100.0 + run_systems.total_bonus("max_hp") + _vehicle_hp_bonus()
		if new_max != player.max_health:
			var ratio := player.health / maxf(player.max_health, 1.0)
			player.max_health = new_max
			player.health = minf(player.health, new_max) if ratio >= 1.0 else ratio * new_max
		# C17：超频期间主作业冷却减半；战斗统计 → 任务
		if overclock_time > 0.0:
			overclock_time -= delta
			player.primary_cooldown = minf(player.primary_cooldown, 0.16)
		if feel != null:
			var crits := int(feel.stats.get("crits", 0))
			if crits > _last_crits:
				run_systems.report("crit", crits - _last_crits)
				_last_crits = crits
		if EnemyDummy.status_applied_count > _last_status_count:
			run_systems.report("status_applied", EnemyDummy.status_applied_count - _last_status_count)
			_last_status_count = EnemyDummy.status_applied_count
		# 3C 相机（docs/design/3c-v1.md）：速度前瞻、分档缩放、Boss 缩放，与瞄准解耦
		var boss_on: bool = boss != null and is_instance_valid(boss) and not boss.dead
		if cam_rig != null:
			cam_rig.update(delta, player.global_position, player.velocity, boss_on)
	if ui != null:
		ui.refresh(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if garage_open:
			toggle_garage()
		elif outcome == "active":
			toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("garage") and outcome == "active":
		toggle_garage()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not get_tree().paused:
		try_repair()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F1:
				if gm != null:
					gm.toggle_panel()
					if ui != null:
						ui.refresh_gm_panel()
				get_viewport().set_input_as_handled()
			KEY_F5: save_snapshot()
			KEY_F9: load_snapshot()
			KEY_F6: reset_contract()
			KEY_F7: open_selection_flow("new_module")
			KEY_F4: spawn_roster_wave(true)
			KEY_F8: summon_boss()
			KEY_1: _try_cast(0)
			KEY_2: _try_cast(1)
			KEY_3: _try_cast(2)
			KEY_4: _try_cast(3)
			KEY_5: _try_summon(0)
			KEY_6: _try_summon(1)
			KEY_7: _try_summon(2)
			KEY_G: _cycle_biome()
			KEY_F11:
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
				get_viewport().set_input_as_handled()
			KEY_F10:
				feedback("3C 参数已重载" if Tuning3C.reload() else "3C 参数文件读取失败，使用默认值")
				get_viewport().set_input_as_handled()

## 子智能体 C2/C3/C4：Wanderburg 对齐系统束初始化
func _init_wanderburg_systems() -> void:
	# C2 选择流：四档池 + 引擎 + UI
	selection_engine = SelectionEngine.new()
	selection_engine.new_module_pools = ContentV2Catalog.build_module_pools(ContentV2Catalog.create_v2_definitions())
	selection_engine.upgrade_pools = ContentV2Catalog.build_upgrade_pools()
	selection_engine.vehicle_tiers = VehicleProgression.default_tier_chain()
	selection_ui = SelectionUI.new()
	add_child(selection_ui)
	selection_ui.option_chosen.connect(_on_selection_chosen)
	selection_ui.target_provider = _pick_target
	selection_ui.pick_landed.connect(_play_pick_fx)
	selection_ui.visibility_changed.connect(func():
		if player != null:
			_sync_pause())
	selection_ui.reroll_requested.connect(func(_kind: String):
		selection_engine.reroll_count += 1
		open_selection_flow(last_selection_kind(), true))
	# C9 神器双池 + fallback（对齐 PopulateMissingArtifactChoicesFromFallbacks）
	var roster := ContentRoster.create_artifacts()
	var pools := ContentRoster.build_artifact_pools(roster)
	selection_engine.artifact_pool = pools["normal"]
	selection_engine.rare_artifact_pool = pools["rare"]
	selection_engine.artifact_fallbacks = roster.filter(func(a): return not a.rare).slice(0, 3)
	selection_engine.rare_artifact_fallbacks = roster.filter(func(a): return a.rare).slice(0, 3)
	# C4 单局系统束
	run_systems = RunSystems.new()
	run_systems.quest_achieved.connect(func(qid: String):
		var q := RunSystems.quest_def(qid)
		feedback("任务达成 · %s · 银币 +%d" % [RunSystems.quest_name(qid), int(q.get("reward_silver", 0))])
		audio.play_event("quest_complete")
		if ui != null:
			ui.stamp_banner("title_quest"))
	# C3 载具成长
	vehicle_progression = VehicleProgression.new()
	vehicle_progression.size_rank_advanced.connect(func(rank: int):
		run_systems.report("absorbs", 1)
		if cam_rig != null:
			cam_rig.set_tier(rank)
		var form_change: bool = player != null and player.evolved_rig == null and player.apply_evolution(rank)
		feedback("进化完成 · 叠河鲸形态 · Lv.%d" % (rank + 1) if form_change else "升级 · 底盘 Lv.%d · 耐久与吸取范围提升" % (rank + 1))
		LevelUpFx.level_up(player, rank, form_change)
		if ui != null:
			ui.on_level_up(rank)
			if form_change:
				ui.stamp_banner("title_levelup")
		if vehicle_choice_ranks.has(rank):
			# 等落地冲击演完再弹 2 选 1
			queue_selection("vehicle", 0.75))
	vehicle_progression.growth_changed.connect(func(_p: float, _n: float):
		if ui != null:
			ui.on_growth_changed())
	# C7 群系系统初始化：纯逻辑层 + 天气粒子层
	biome_system = BiomeSys.new()
	biome_system.biome_changed.connect(_on_biome_changed)
	biome_system.key_acquired.connect(func(key_id: String): feedback("钥匙神器到手 · %s 群系已永久解锁" % key_id))
	biome_weather = BiomeWeatherScript.new()
	world.add_child(biome_weather)
	# S3 桥接：v2 模块转旧定义，合并进装配器（可预览可安装）
	for pool in selection_engine.new_module_pools:
		for entry in pool.entries:
			var legacy := ContentBridge.to_legacy(entry["item"])
			v2_definitions[legacy.id] = legacy
			assembler.definitions[legacy.id] = legacy
	_sync_equipped_abilities()

## 把 selection_engine 已装模块自动装备进 4 个主动技能槽（F7 选择后即可 1-4 施放）
func _sync_equipped_abilities() -> void:
	if vehicle_progression == null or selection_engine == null:
		return
	for i in range(mini(selection_engine.installed_modules.size(), 4)):
		vehicle_progression.equip_ability(i, selection_engine.installed_modules[i])

func last_selection_kind() -> String:
	return "new_module"

## F7 选择流：new_module 3 选 1；artifact 3 选 1（C9 双池+保底）；captain 雇佣 3 选 1（C9）
var captain_options_pool: Array = []

func open_selection_flow(kind: String, is_reroll: bool = false) -> void:
	if outcome != "active":
		return
	if selection_ui.visible and not is_reroll:
		pending_selections.append(kind)
		return
	# 菜单 / 改装台 / GM 打开时不盖上去：排队，关掉后再弹
	if not is_reroll and (garage_open or manual_pause or (gm != null and gm.visible)):
		pending_selections.append(kind)
		return
	_current_selection_kind = kind
	var subtitle := ""
	match kind:
		"new_module":
			last_selection_options = selection_engine.generate_new_modules(selection_engine.installed_modules.map(func(m): return m.module_id))
		"artifact":
			# rare 概率：每击败 2 个 Boss 提升（简化触发器，GAP：原生精确公式）
			var rare := run_systems.bosses_defeated >= 2 and run_systems.bosses_defeated % 2 == 0
			last_selection_options = selection_engine.generate_artifacts(rare)
		"captain":
			last_selection_options = _generate_captain_options()
		"upgrade":
			if selection_engine.installed_modules.is_empty():
				# 还没有技能可升级 → 改给新模块
				_current_selection_kind = "new_module"
				kind = "new_module"
				last_selection_options = selection_engine.generate_new_modules()
			else:
				last_selection_options = selection_engine.generate_upgrades()
		"vehicle":
			last_selection_options = _vehicle_choices()
			subtitle = "当前 · %s" % vehicle_progression.stats.stats_name
	if last_selection_options.is_empty():
		feedback("暂无可选项")
		_open_next_pending()
		return
	if feel != null:
		feel.slowmo(0.2, 0.25)
	selection_ui.open_selection(kind, last_selection_options, subtitle)
	_sync_pause()

var _current_selection_kind := "new_module"

func _open_next_pending() -> void:
	if pending_selections.is_empty() or outcome != "active":
		return
	var next: String = pending_selections.pop_front()
	call_deferred("open_selection_flow", next)

## 载具升级 2 选 1：同一档的「重装」与「迅捷」两种变体（对齐 Tier2-5 A/B 变体）
const VEHICLE_VARIANTS := [
	[{"name": "重装作业车", "hp": 180.0, "speed": 6.3, "nitro": 120.0, "mass": 1800, "radius": 3.2},
	 {"name": "迅捷侦察车", "hp": 130.0, "speed": 8.6, "nitro": 160.0, "mass": 1100, "radius": 3.6}],
	[{"name": "巨鲸底盘", "hp": 320.0, "speed": 5.8, "nitro": 150.0, "mass": 3200, "radius": 4.4},
	 {"name": "鲨齿突击车", "hp": 210.0, "speed": 9.4, "nitro": 220.0, "mass": 1600, "radius": 4.0}],
]
var vehicle_tier_index := 0

func _vehicle_choices() -> Array:
	if vehicle_tier_index >= VEHICLE_VARIANTS.size():
		return []
	var cur: VehicleStats = vehicle_progression.stats
	var options := []
	for v in VEHICLE_VARIANTS[vehicle_tier_index]:
		var s := VehicleStats.new()
		s.stats_name = v["name"]
		s.max_hp = v["hp"]
		s.max_velocity = v["speed"]
		s.max_nitro = v["nitro"]
		s.rigid_body_mass = v["mass"]
		s.collector_radius = v["radius"]
		s.vehicle_size_rank = cur.vehicle_size_rank
		s.can_absorb_vehicles_of_size_rank = cur.can_absorb_vehicles_of_size_rank + 1
		options.append({"stats": s, "title": "%s → %s" % [cur.stats_name, s.stats_name], "bonus_lines": selection_engine._stat_diff_lines(cur, s)})
	return options

func _vehicle_hp_bonus() -> float:
	if vehicle_progression == null or vehicle_tier_index == 0:
		return 0.0
	return vehicle_progression.stats.max_hp - 100.0

func _apply_vehicle_stats(s: VehicleStats) -> void:
	var rank := vehicle_progression.stats.vehicle_size_rank
	s.vehicle_size_rank = rank
	vehicle_progression.stats = s
	vehicle_tier_index += 1
	player.base_speed = s.max_velocity
	player.set("collector_bonus", s.collector_radius - 2.5)
	player.health = minf(player.health + 40.0, 100.0 + _vehicle_hp_bonus() + run_systems.total_bonus("max_hp"))
	if feel != null:
		feel.screen_flash(Color("#EFE3C8"), 0.5, 0.3)
		feel.impact_ring(player.global_position, 5.0, Color("#E3A52B"), 0.5)
		feel.shake(0.4)

func _generate_captain_options() -> Array:
	if captain_options_pool.is_empty():
		captain_options_pool = ContentRoster.create_captains()
	var picks: Array = []
	var pool := captain_options_pool.duplicate()
	pool.shuffle()
	for i in mini(3, pool.size()):
		picks.append(pool[i])
	return picks

func _on_selection_chosen(kind: String, index: int) -> void:
	if index < 0 or index >= last_selection_options.size():
		return
	_sync_pause()
	match kind:
		"new_module":
			var module: ModuleDefinitionV2 = last_selection_options[index]
			selection_engine.commit(kind, module)
			_sync_equipped_abilities()
			feedback("新模块入列 · %s（已进改装台，1-4 施放，B 键预览安装）" % module.module_name)
		"artifact":
			var artifact: ArtifactDefinition = last_selection_options[index]
			run_systems.equip_artifact(artifact)
			feedback("神器上手 · %s：%s" % [artifact.display_name, artifact.description])
		"captain":
			var captain: CaptainDefinition = last_selection_options[index]
			if run_systems.spend_silver(60, "hire_captain"):
				run_systems.hire_captain(captain)
				feedback("船长上船 · %s：%s" % [captain.display_name, captain.description])
			else:
				feedback("银币不足，雇佣失败（需 60）")
		"upgrade":
			var pick: Dictionary = last_selection_options[index]
			var mod: ModuleDefinitionV2 = pick["module"]
			var up: UpgradeDefinition = pick["upgrade"]
			var lv: Dictionary = module_levels.get(mod.module_id, {"level": 0})
			lv["level"] = int(lv.get("level", 0)) + 1
			for k in up.stat_gains:
				lv[k] = float(lv.get(k, 0.0)) + float(up.stat_gains[k])
			module_levels[mod.module_id] = lv
			_last_upgrade_id = mod.module_id
			feedback("技能升级 · %s Lv.%d · %s" % [mod.module_name, int(lv["level"]), up.description])
		"vehicle":
			var opt: Dictionary = last_selection_options[index]
			_apply_vehicle_stats(opt["stats"])
			feedback("底盘升级 · %s" % opt["stats"].stats_name)
	match kind:
		"new_module":
			run_systems.report("module_taken", 1)
		"artifact", "artifact_rare":
			run_systems.report("artifact_taken", 1)
	_pending_pick_fx = [kind, _pick_callout(kind, index), _pick_slot(kind)]
	if not selection_ui.outro_running():
		_play_pick_fx(kind)
	last_selection_options = []
	_open_next_pending()

## 选卡演出：飞卡落到目标（技能槽 / 车身）的那一刻，车身 power_up + 槽位弹一下
var _pending_pick_fx: Array = []
func _play_pick_fx(_kind: String) -> void:
	if _pending_pick_fx.is_empty():
		return
	var fx := _pending_pick_fx
	_pending_pick_fx = []
	LevelUpFx.power_up(player, str(fx[1]), str(fx[0]))
	if ui != null:
		ui.on_pick_applied(str(fx[0]), int(fx[2]))

## 飞卡目标（屏幕坐标）：新模块 / 技能升级 → 对应技能槽；其余 → 车身
func _pick_target(kind: String) -> Vector2:
	var slot := _pick_slot(kind)
	if slot >= 0 and ui != null and slot < ui.skill_slots.size() and ui.skill_slots[slot].is_visible_in_tree():
		var s: Control = ui.skill_slots[slot]
		return s.get_global_transform_with_canvas() * (s.size * 0.5)
	var cam := get_viewport().get_camera_3d()
	if cam != null and player != null:
		return cam.unproject_position(player.global_position + Vector3(0, 1.0, 0))
	return Vector2(640, 400)

## 头顶字：选了什么
func _pick_callout(kind: String, index: int) -> String:
	if index < 0 or index >= last_selection_options.size():
		return ""
	var o: Variant = last_selection_options[index]
	match kind:
		"new_module":
			return "NEW! " + (o as ModuleDefinitionV2).module_name
		"upgrade":
			var m: ModuleDefinitionV2 = o["module"]
			return "%s Lv.%d" % [m.module_name, int((module_levels.get(m.module_id, {}) as Dictionary).get("level", 1))]
		"artifact", "artifact_rare":
			return (o as ArtifactDefinition).display_name
		"captain":
			return "船长 " + (o as CaptainDefinition).display_name
		"vehicle":
			return (o["stats"] as VehicleStats).stats_name
	return ""

## 选的东西落在哪个技能槽（-1 = 不对应技能槽）
func _pick_slot(kind: String) -> int:
	if vehicle_progression == null or (kind != "new_module" and kind != "upgrade"):
		return -1
	var target_id := ""
	if kind == "new_module" and not selection_engine.installed_modules.is_empty():
		target_id = selection_engine.installed_modules[selection_engine.installed_modules.size() - 1].module_id
	elif kind == "upgrade" and not _last_upgrade_id.is_empty():
		target_id = _last_upgrade_id
	for i in vehicle_progression.active_slots.size():
		var e: Variant = vehicle_progression.active_slots[i]
		if e is Dictionary and not (e as Dictionary).is_empty() and e["def"].module_id == target_id:
			return i
	return -1

var _last_upgrade_id := ""

## 1-4 施放：找到第一个已安装的 v2 模块（按装配器实际安装状态），走成长系统冷却闸门
func _try_cast(slot: int) -> void:
	if outcome != "active" or garage_open or manual_pause or gm.visible:
		return
	if vehicle_progression == null:
		return
	var cast := vehicle_progression.cast_slot(slot)
	if not bool(cast["cast"]):
		match str(cast.get("reason", "")):
			"empty_slot":
				player.deny_feedback("%d 号槽没有技能 · F7 选模块" % (slot + 1))
			"cooling_down":
				player.deny_feedback()
				feedback("技能冷却中 · %.1f 秒" % float(cast.get("remaining", 0.0)))
			"no_charges":
				player.deny_feedback()
				feedback("充能耗尽")
		if ui != null and ui.has_method("deny_skill"):
			ui.deny_skill(slot)
		return
	var entry: Dictionary = vehicle_progression.active_slots[slot]
	var module_id := str(entry["def"].module_id)
	var mods: Dictionary = module_levels.get(module_id, {})
	var dmg := _scaled_ability_damage(float(cast.get("damage", 0.0))) * (1.0 + float(mods.get("damage", 0.0)))
	var result := AbilityLibrary.cast(self, module_id, dmg, float(cast.get("range", 10.0)), mods)
	_cast_presentation(module_id, str(entry["def"].module_name), str(result.get("shape", "")))
	entry["cooldown"] = _scaled_cooldown(float(cast.get("cooldown_set", 0.0))) * clampf(1.0 - float(mods.get("cooldown", 0.0)), 0.25, 1.5)
	run_systems.report("ability_cast", 1)
	run_stats["casts"] = int(run_stats["casts"]) + 1
	audio.play_event("ability_cast")
	if ui != null and ui.has_method("pulse_skill"):
		ui.pulse_skill(slot)
	var shape: String = result.get("shape", "")
	if int(result.get("hits", 0)) == 0 and shape in ["chain", "snipe", "void_lance", "frost_cone", "flame_cone", "quake", "emp", "roar"]:
		feedback("%s · 落空" % entry["def"].module_name)

## 施法表现：脚下施法环 + 技能名 + 车身出力 + 对应挂件的动作（只表现）
func _cast_presentation(module_id: String, title: String, shape: String) -> void:
	if player == null:
		return
	SkillVfx.cast_flourish(player.global_position, shape, title)
	var body: ProceduralRig = player.evolved_rig if player.evolved_rig != null else player.body_rig
	if body != null:
		body.play_attack(0.3, false, 0.12, 0.8, player.aim_direction)
		if body.juice != null:
			body.juice.cast_pop(1.0)
	var mount := player.find_child("Installed_" + module_id, true, false)
	if mount != null:
		for r in mount.find_children("ProceduralRig*", "", true, false):
			if r is ProceduralRig:
				(r as ProceduralRig).play_attack(0.36, true)
		var tw := mount.create_tween()
		var base: Vector3 = (mount as Node3D).scale
		tw.tween_property(mount, "scale", base * 1.25, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mount, "scale", base, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## C9：神器+船长伤害修饰（damage/ability_damage 两类 additive 求和后乘算）
func _scaled_ability_damage(base: float) -> float:
	return base * (1.0 + run_systems.total_bonus("ability_damage") + run_systems.total_bonus("damage"))

## C9：神器+船长冷却缩减（cooldown 类，值域 0~0.85 钳制）
func _scaled_cooldown(base: float) -> float:
	return base * (1.0 - clampf(run_systems.total_bonus("cooldown"), 0.0, 0.85))

func _apply_ability_hit(damage: float, reach: float, module_id: String) -> void:
	var source := AbilityEffects.source_for(module_id)
	var forward: Vector3 = player.aim_direction if player.aim_direction.length() > 0.01 else Vector3(0, 0, -1)
	var hit_count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			var result := enemy.try_engineering_hit(player.global_position, forward, 1.2, reach, damage, source)
			if bool(result["hit"]):
				hit_count += 1
	# Boss 同协议受击
	if boss != null and is_instance_valid(boss) and not boss.dead:
		var boss_result := boss.try_engineering_hit(player.global_position, forward, 1.6, reach, damage, source)
		if bool(boss_result["hit"]):
			hit_count += 1
	feedback("技能命中 ×%d" % hit_count if hit_count > 0 else "技能落空")

# ---------- C7 群系锁钥 ----------

## G 键轮换群系：river → desert → swamp → river；锁定则提示所需钥匙
func _cycle_biome() -> void:
	if outcome != "active":
		return
	var order := ["river", "desert", "swamp"]
	var index := order.find(biome_system.current_id)
	var next: String = order[(index + 1) % order.size()]
	var result: Dictionary = biome_system.switch_to(next)
	if bool(result["switched"]):
		feedback("进入群系 · %s" % biome_system.current_biome()["name"])
	else:
		match str(result["reason"]):
			"locked":
				var required := str(biome_system.biome(next)["required_key"])
				var key_name := "沙漠钥匙" if required == BiomeSystem.KEY_DESERT else "沼泽钥匙"
				feedback("%s 已封锁 · 需要%s（找废料堆里的金色钥匙）" % [biome_system.biome(next)["name"], key_name])
			"already_there":
				pass
			_:
				pass

## 群系切换应用：场景调色 + 天气粒子 + 锁门/钥匙世界物重建
func _on_biome_changed(biome_id: String) -> void:
	world.apply_biome(biome_id)
	biome_weather.apply_biome(biome_id)
	_rebuild_biome_world()
	run_systems.report("biome_switch", 1)

## 群系世界物：每群系一组（门 + 钥匙），清除后按当前群系重建
func _rebuild_biome_world() -> void:
	for node in biome_gates + biome_keys:
		if is_instance_valid(node):
			node.queue_free()
	biome_gates.clear()
	biome_keys.clear()
	match biome_system.current_id:
		"river":
			_spawn_biome_key(BiomeSystem.KEY_DESERT, Vector3(-10.5, 0, 12.0))
		"desert":
			_spawn_biome_gate("gate_swamp", BiomeSystem.KEY_SWAMP, Vector3(0, 0, -14.5))
			_spawn_biome_key(BiomeSystem.KEY_SWAMP, Vector3(12.0, 0, 8.0))
		"swamp":
			_spawn_biome_gate("gate_river", BiomeSystem.KEY_DESERT, Vector3(0, 0, 14.0))

func _spawn_biome_gate(gate_id: String, key: String, at: Vector3) -> void:
	var gate := BiomeGateScript.new().configure(gate_id, key, at)
	gate.player = player
	gate.biome_system_ref = biome_system
	entities.add_child(gate)
	biome_gates.append(gate)
	gate.locked_feedback.connect(func(_g: BiomeGate):
		var required := str(_g.required_key)
		var key_name := "沙漠钥匙" if required == BiomeSystem.KEY_DESERT else "沼泽钥匙"
		feedback("大门紧锁 · 需要%s" % key_name))
	gate.unlocked.connect(func(_g: BiomeGate):
		feedback("大门开启 · 通路已打开")
		audio.play_event("change"))

func _spawn_biome_key(key_id: String, at: Vector3) -> void:
	var key := BiomeKeyPickupScript.new().configure(key_id, at)
	entities.add_child(key)
	biome_keys.append(key)
	key.picked_up.connect(func(kid: String):
		var grant := biome_system.grant_key(kid)
		if bool(grant["granted"]):
			run_systems.equip_artifact(_make_key_artifact(kid))
			feedback("拾取%s · 群系永久解锁" % ("沙漠钥匙" if kid == BiomeSystem.KEY_DESERT else "沼泽钥匙"))
			audio.play_event("quest_complete")
			run_systems.report("biome_keys", 1)
		else:
			feedback("钥匙已在手"))
	if player != null and is_instance_valid(player):
		_track_key_proximity(key)

## 钥匙靠近即拾取（0.9 米接触半径）
func _track_key_proximity(key: BiomeKeyPickup) -> void:
	var timer := Timer.new()
	timer.wait_time = 0.15
	timer.autostart = true
	key.add_child(timer)
	timer.timeout.connect(func():
		if not is_instance_valid(key) or key.is_collected or outcome != "active":
			return
		if player != null and is_instance_valid(player) and player.global_position.distance_to(key.global_position) <= 1.4:
			key.try_collect())

## 钥匙神器（对齐 DesertKey/SwampKey 的 RequireComponent(Artifact) 语义）
func _make_key_artifact(key_id: String) -> ArtifactDefinition:
	var artifact := ArtifactDefinition.new()
	artifact.id = key_id
	artifact.display_name = "沙漠钥匙" if key_id == BiomeSystem.KEY_DESERT else "沼泽钥匙"
	artifact.description = "开启对应群系的锁钥之门，持有即永久解锁"
	artifact.factor = 1.0
	artifact.tags = PackedStringArray([key_id])
	return artifact

# ---------- C7 技能召唤分支（5/6/7）----------

const SUMMON_KIND_BY_SLOT := [SummonEntity.SummonKind.TURRET, SummonEntity.SummonKind.EMP, SummonEntity.SummonKind.CAMP]
const SUMMON_COOLDOWNS := [9.0, 14.0, 16.0]
var summon_cooldowns := [0.0, 0.0, 0.0]

func _try_summon(slot: int, from_ability := false) -> void:
	if outcome != "active" or garage_open or manual_pause or gm.visible:
		return
	if slot < 0 or slot >= SUMMON_KIND_BY_SLOT.size():
		return
	if not from_ability and float(summon_cooldowns[slot]) > 0.0:
		feedback("召唤冷却中 · %.1f 秒" % float(summon_cooldowns[slot]))
		return
	if active_summon_slots[slot] != null and is_instance_valid(active_summon_slots[slot]):
		if not from_ability:
			feedback("召唤物已驻场")
			return
		active_summon_slots[slot].queue_free()
	run_systems.report("summon_used", 1)
	var kind: SummonEntity.SummonKind = SUMMON_KIND_BY_SLOT[slot]
	var forward: Vector3 = player.aim_direction.normalized() if player.aim_direction.length() > 0.01 else Vector3(0, 0, -1)
	var at := player.global_position + forward * 3.2
	at.y = 0.0
	var summon: SummonEntity = SummonScript.new().configure(kind, at, 4.0)
	summon.player = player
	entities.add_child(summon)
	summons.append(summon)
	active_summon_slots[slot] = summon
	summon_cooldowns[slot] = float(SUMMON_COOLDOWNS[slot])
	summon.action_effect.connect(_on_summon_effect)
	summon.expired.connect(func(_s: SummonEntity):
		if active_summon_slots[slot] == _s:
			active_summon_slots[slot] = null)
	audio.play_event("ability_cast")
	feedback("已召唤 · %s" % SummonEntity.LABELS[kind])

func _on_summon_effect(kind: String, origin: Vector3, end: Vector3) -> void:
	match kind:
		"turret_fire":
			var target := AbilityLibrary._nearest(self, origin, 16.0)
			if target != null:
				var dir := target.global_position - origin
				var shot := Projectile.fire(entities, origin, dir, 22.0, 6.0, "player", Color("#EFE3C8"))
				shot.size = 0.2
				shot.lifetime = 1.0
			return
		"camp_heal":
			player.health = minf(player.max_health, player.health + 5.0)
			if feel != null:
				feel.number(player.global_position, 5.0, "heal")
	world.present_effect(kind, origin, end)

func _summon_damage_pulse(origin: Vector3, damage: float, reach: float) -> void:
	for enemy in enemies + gm_enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(origin) <= reach:
			enemy.take_damage(damage)
	if boss != null and is_instance_valid(boss) and not boss.dead and boss.global_position.distance_to(origin) <= reach:
		boss.take_damage(damage)

## F8 召 Boss：三阶段鲸王，击败后任务结算
func summon_boss() -> void:
	if outcome != "active":
		return
	if boss != null and is_instance_valid(boss) and not boss.dead:
		feedback("Boss 已在场")
		return
	var boss_id: String = ContentRoster.next_boss_id(run_systems.bosses_defeated)
	var roster_entry: Dictionary = ContentRoster.BOSS_ROSTER[boss_id]
	var boss_title: String = str(roster_entry["title"])
	boss = BossEntity.new().configure_boss(boss_id, Vector3(0, 1.2, -11.0), roster_entry)
	boss.summoner = func(arch: String, at: Vector3): spawn_archetype(arch, at)
	entities.add_child(boss)
	boss.player = player
	boss.hit_player.connect(player.receive_damage)
	boss.action_effect.connect(world.present_effect)
	boss.pattern_started.connect(func(attack: String):
		if ui != null and ui.has_method("boss_callout"):
			ui.boss_callout(BossPatterns.NAMES.get(attack, attack)))
	boss.phase_changed.connect(func(phase: int):
		feedback("%s 进入阶段 %d · 解锁招式「%s」" % [boss_title, phase, BossPatterns.NAMES.get(BossPatterns.available(boss_id, phase).back(), "")])
		audio.play_event("boss_phase"))
	boss.defeated.connect(func(_e: EnemyDummy):
		feedback("%s 已败 · 赏金 +80 · 神器选择就绪" % boss_title)
		audio.play_event("boss_defeat")
		run_systems.earn_silver(int(round(80.0 * (1.0 + run_systems.total_bonus("silver_gain")))), "boss_defeat")
		run_systems.bosses_defeated += 1
		run_systems.report("boss_defeated", 1)
		run_stats["bosses"] = int(run_stats["bosses"]) + 1
		_drop_loot(_e.global_position, "boss")
		boss = null
		open_selection_flow("artifact")
		check_victory())
	audio.play_event("boss_spawn")
	if cam_rig != null:
		cam_rig.start_boss_intro(boss.global_position if boss.is_inside_tree() else Vector3(0, 0, -16.0))
	if ui != null:
		ui.stamp_banner("title_boss")
	feedback("%s 现身 · 河谷深处" % boss_title)

func unlocked_module_ids() -> Array:
	return selection_engine.installed_modules.map(func(m): return m.module_id)

func _clear_entities() -> void:
	for child in entities.get_children():
		entities.remove_child(child)
		child.queue_free()
	targets.clear()
	enemies.clear()
	gm_enemies.clear()
	boss = null
	ability_cooldowns.clear()
	biome_gates.clear()
	biome_keys.clear()
	summons.clear()
	active_summon_slots = [null, null, null]
	summon_cooldowns = [0.0, 0.0, 0.0]

func reset_contract() -> void:
	_clear_entities()
	if gm != null:
		gm.reset_flags()
	get_tree().paused = false
	outcome = "active"
	manual_pause = false
	garage_open = false
	pending_selections.clear()
	_deferred_selections.clear()
	elapsed = 0.0
	collected = 0
	defeated = 0
	repair_done = false
	reward_retry_clock = 0.0
	set_shortcut_open(false)
	assembler.restore({"version": 1, "active_ids": ["", ""], "core_id": "basic_bucket", "drive_id": "", "stage": 1})
	player.reset_vehicle(Vector3(0, 0.5, 7))
	if biome_system != null:
		biome_system.current_id = "river"
		_on_biome_changed("river")
	for item in TARGET_LAYOUT:
		_spawn_target(item)
	for item in ENEMY_LAYOUT:
		_spawn_enemy(item)
	ui.close_modals()
	ui.refresh_gm_panel()
	feedback("先回收废料。B / 手柄 Y 打开改装台，尝试不同组合。")

func _spawn_target(item: Array) -> EngineeringTarget:
	var target := EngineeringTarget.new().configure(str(item[0]), str(item[1]), float(item[4]), Vector3(float(item[2]), 0.6, float(item[3])))
	entities.add_child(target)
	targets.append(target)
	target.destroyed.connect(func(_t: EngineeringTarget): feedback("废料回收 · 通路打开"))
	target.action_effect.connect(world.present_effect)
	target.repaired.connect(func(_t: EngineeringTarget):
		repair_done = true
		world.green_zone.show()
		set_shortcut_open(true)
		player.health = minf(player.health + 30.0, player.max_health)
		run_systems.report("repair", 1)
		if feel != null:
			feel.number(player.global_position, 30.0, "heal")
			feel.impact_ring(_t.global_position, 8.0, Color("#8FD694"), 0.8)
		feedback("水泵启动 · 耐久恢复 +30 · 河岸复苏")
		check_victory()
	)
	return target

func _spawn_enemy(item: Array, formal_target: bool = true) -> EnemyDummy:
	var kind := str(item[1])
	var enemy := EnemyDummy.new().configure(str(item[0]), kind, 90.0 if kind == "heavy" else 35.0, 0.6 if kind == "heavy" else 1.3, Vector3(float(item[2]), 0.7, float(item[3])))
	enemy.player = player
	entities.add_child(enemy)
	if formal_target:
		enemies.append(enemy)
	else:
		gm_enemies.append(enemy)
	enemy.hit_player.connect(player.receive_damage)
	enemy.action_effect.connect(world.present_effect)
	enemy.defeated.connect(func(_e: EnemyDummy):
		_register_kill(_e)
		if formal_target:
			defeated += 1
			feedback("威胁解除 · %d / %d" % [defeated, ENEMY_LAYOUT.size()])
			check_victory()
		else:
			feedback("GM 敌人已解除")
	)
	return enemy

func spawn_gm_enemy(kind: String, at: Vector3) -> EnemyDummy:
	if gm_enemies.size() >= 80:
		return null
	var id := "gm_%s_%03d" % [kind, gm_enemies.size() + 1]
	if EnemyArchetypes.ARCHETYPES.has(kind):
		return spawn_archetype(kind, at, id)
	return _spawn_enemy([id, kind, at.x, at.z], false)

## C16：按原型生成（小怪 / 精英）
func spawn_archetype(archetype: String, at: Vector3, id := "") -> EnemyDummy:
	if gm_enemies.size() >= 80:
		return null
	if id.is_empty():
		id = "ar_%s_%03d" % [archetype, gm_enemies.size() + 1]
	var enemy := EnemyDummy.new().configure_archetype(id, archetype, Vector3(at.x, 0.7, at.z))
	enemy.player = player
	entities.add_child(enemy)
	gm_enemies.append(enemy)
	enemy.hit_player.connect(player.receive_damage)
	enemy.action_effect.connect(world.present_effect)
	enemy.elite_ability.connect(_on_elite_ability)
	var def: Dictionary = EnemyArchetypes.get_def(archetype)
	enemy.defeated.connect(func(_e: EnemyDummy):
		var scale := EnemyArchetypes.reward_scale(enemy.tier)
		run_systems.earn_silver(int(round(5.0 * scale)), "enemy_" + enemy.tier)
		_register_kill(_e)
		if enemy.tier == "elite":
			feedback("精英「%s」已败 · 银币 +%d · 升级选择就绪" % [def.get("name", archetype), int(5.0 * scale)])
			audio.play_event("boss_phase")
			queue_selection("upgrade", 0.6)
		else:
			feedback("%s 已解除" % def.get("name", archetype)))
	if enemy.tier == "elite":
		feedback("精英「%s」出现！" % def.get("name", archetype))
		if ui != null:
			ui.stamp_banner("title_elite")
	return enemy

## 精英 caster：电弧圈范围伤害（玩家在预警圈内才受伤 + 短眩晕）
func _on_elite_ability(enemy: EnemyDummy, center: Vector3, radius: float, damage: float) -> void:
	world.present_effect("arc_chain", enemy.global_position if is_instance_valid(enemy) else center, center)
	if feel != null:
		feel.impact_ring(center, radius, Color("#8C7BA8"), 0.3)
	if player != null:
		var d := Vector2(player.global_position.x - center.x, player.global_position.z - center.z).length()
		if d <= radius + 0.9:
			player.receive_damage(damage)
			player.status.apply("stun", 0.4)

## 击杀登记：任务、连杀（2.5 秒内 5 杀 = 1 次「一网打尽」）、掉落
## C24 击杀给进化能量（对齐原作“吞噬成长”）：小怪 0.5、精英 2、Boss 4；能量球飞到车身才入账
const GROWTH_PER_KILL := {"minion": 0.5, "light": 0.5, "heavy": 0.8, "ranged": 0.6, "elite": 2.0, "boss": 4.0}

func _grant_growth_from(at: Vector3, points: float) -> void:
	if vehicle_progression == null or points <= 0.0 or player == null:
		return
	var orbs := clampi(int(ceil(points * 2.0)), 1, 8)
	var each := points / float(orbs)
	for i in orbs:
		LevelUpFx.growth_orb(at, player, func():
			if vehicle_progression != null and outcome == "active":
				vehicle_progression.gain_growth(each))

func _register_kill(e: EnemyDummy) -> void:
	run_systems.report("enemy_defeated", 1)
	run_stats["kills"] = int(run_stats["kills"]) + 1
	_grant_growth_from(e.global_position, GROWTH_PER_KILL.get(e.tier, 0.5))
	if e.tier == "elite":
		run_systems.report("elite_defeated", 1)
		run_stats["elites"] = int(run_stats["elites"]) + 1
	var now := elapsed
	_kill_times.append(now)
	_kill_times = _kill_times.filter(func(t): return now - float(t) <= 2.5)
	if _kill_times.size() >= 5:
		_kill_times.clear()
		run_systems.report("multikill", 1)
		feedback("一网打尽！")
		if feel != null:
			feel.slowmo(0.35, 0.35)
		if ui != null:
			ui.stamp_banner("title_multikill")
	_drop_loot(e.global_position, e.tier)

func _drop_loot(at: Vector3, tier: String) -> void:
	if not is_inside_tree():
		return
	var coins := 2 if tier == "minion" else (8 if tier == "elite" else 20)
	var value := 1 if tier == "minion" else (3 if tier == "elite" else 4)
	for p in LootPickup.burst(entities, at, coins, value, "silver"):
		p.collected.connect(_on_loot)
	var repair_count := 0
	if tier == "boss":
		repair_count = 3
	elif tier == "elite" or randf() < 0.12:
		repair_count = 1
	for p in LootPickup.burst(entities, at, repair_count, 10, "repair"):
		p.collected.connect(_on_loot)

func _on_loot(kind: String, amount: int) -> void:
	if kind == "silver":
		run_systems.earn_silver(amount, "loot")
		run_systems.report("loot", amount)
		run_stats["loot"] = int(run_stats["loot"]) + amount

## 完美闪避：冲刺无敌帧吃掉一次伤害 → 小慢动作 + 提示
func _on_player_dodged() -> void:
	run_systems.report("perfect_dodge", 1)
	run_stats["dodges"] = int(run_stats["dodges"]) + 1
	if feel != null:
		feel.slowmo(0.3, 0.3)
		feel.impact_ring(player.global_position, 2.6, Color("#EFE3C8"), 0.3)
	if ui != null and ui.has_method("boss_callout"):
		ui.boss_callout("闪避！", Color("#EFE3C8"))

## C16：一波花名册（5 种小怪各 2 只 + 1 只随机精英），F4 / GM
func spawn_roster_wave(with_elite := true) -> Array:
	var spawned := []
	var base: Vector3 = player.global_position if player != null else Vector3.ZERO
	var minions := EnemyArchetypes.ids_of_tier("minion")
	for i in minions.size() * 2:
		var a := TAU * float(i) / float(minions.size() * 2)
		var at := base + Vector3(cos(a), 0, sin(a)) * 9.0
		var e := spawn_archetype(minions[i % minions.size()], at)
		if e != null:
			spawned.append(e)
	if with_elite:
		var elites := EnemyArchetypes.ids_of_tier("elite")
		var pick: String = elites[randi() % elites.size()]
		var e2 := spawn_archetype(pick, base + Vector3(0, 0, -11.0))
		if e2 != null:
			spawned.append(e2)
	return spawned

func clear_gm_and_formal_enemies() -> void:
	for enemy in enemies + gm_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	gm_enemies.clear()

func set_gm_ai_frozen(frozen: bool) -> void:
	for enemy in enemies + gm_enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED if frozen or enemy.packed else Node.PROCESS_MODE_PAUSABLE

func _harvested(amount: int) -> void:
	collected += amount
	if run_systems != null:
		run_systems.report("harvested", amount)
	if vehicle_progression != null and amount > 0:
		vehicle_progression.absorb(0)
		if player != null:
			LevelUpFx.growth_orb(player.global_position + player.aim_direction * 2.5, player)
	if collected >= 4 and assembler.stage == 1:
		assembler.set_stage(2)
		feedback("结构进化 · 作业范围提升，重量降低移动速度")
	elif collected == 3 and assembler.has_module("magnet") and assembler.has_module("wide_bucket"):
		feedback("鲸口合同 · 废料已够修泵；先把一台轻型敌机压进颚口，再把它投向护卫")

func try_repair() -> bool:
	if outcome != "active" or garage_open or manual_pause or player.health <= 0.0:
		return false
	for target in targets:
		if is_instance_valid(target) and target.target_kind == "repair" and not target.repaired_state and player.global_position.distance_to(target.global_position) <= 3.5:
			if collected < 3:
				feedback("水泵需要先回收 3 单位废料")
				return false
			target.interact_repair()
			return true
	feedback("靠近青色水泵，按 R / 手柄 A 启动")
	return false

func check_victory() -> void:
	if outcome == "active" and repair_done and defeated == ENEMY_LAYOUT.size():
		finish_contract("won")

func get_contract_phase() -> String:
	# The phase is derived from authoritative run state so HUD guidance survives
	# retries and checkpoints without introducing a second objective state machine.
	if repair_done:
		return "河岸复苏 · 终局清场"
	if collected < 3:
		return "清障回收 · 先凑够 3 废料"
	if assembler != null and assembler.has_module("magnet") and assembler.has_module("wide_bucket") and CONTRACT_BRIEF.signature_build == "magnetic_whale":
		if player != null and player.packed_enemy_ids.is_empty():
			return "鲸口打包 · 吸入轻型敌机再投送"
		return "鲸口投送 · 释放压缩敌机制造空档"
	return "接近水泵 · 按 R / A 修复"

func resolve_training_enemies() -> void:
	defeated = ENEMY_LAYOUT.size()
	check_victory()

func _build_shortcut_gate() -> void:
	var gate := StaticBody3D.new()
	gate.name = "RepairShortcutCollisionAuthority"
	gate.position = Vector3(9.0, 0.85, -1.0)
	add_child(gate)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10.8, 1.7, 0.7)
	collider.shape = shape
	gate.add_child(collider)
	shortcut_gate = collider
	set_shortcut_open(false)

func set_shortcut_open(open: bool) -> void:
	shortcut_open = open and repair_done
	if shortcut_gate != null:
		shortcut_gate.disabled = shortcut_open
	if world != null and world.has_method("set_shortcut_open"):
		world.set_shortcut_open(shortcut_open)

func finish_contract(result: String) -> void:
	if outcome != "active":
		return
	if result == "won" and not _commit_contract_reward():
		feedback("蓝图写盘失败 · 合同暂不结算，稍后自动重试")
		return
	outcome = result
	garage_open = false
	assembler.clear_preview()
	ui.show_result()
	_sync_pause()
	_persist_profile()

func _persist_profile() -> bool:
	if not profile_enabled:
		return false
	profile.absorb_run(run_systems, selection_engine.installed_modules.map(func(m): return m.module_id), biome_system.unlocked_biome_ids if biome_system != null else [], run_stats)
	return profile.save_profile()

func toggle_garage() -> void:
	if outcome != "active":
		return
	garage_open = not garage_open
	if garage_open and gm != null and gm.visible:
		gm.set_panel_visible(false)
	if not garage_open:
		assembler.clear_preview()
	ui.show_garage(garage_open)
	_sync_pause()

func toggle_pause() -> void:
	if outcome != "active":
		return
	manual_pause = not manual_pause
	_sync_pause()

func _sync_pause() -> void:
	var picking: bool = selection_ui != null and selection_ui.visible
	var modal: bool = garage_open or manual_pause or (gm != null and gm.visible)
	get_tree().paused = modal or picking or outcome != "active"
	player.gameplay_enabled = not get_tree().paused and simulation_enabled
	if not modal and not picking and not pending_selections.is_empty():
		_open_next_pending()

func _on_gm_state_changed(_state: Dictionary) -> void:
	if gm.visible and garage_open:
		garage_open = false
		assembler.clear_preview()
		ui.show_garage(false)
	_sync_pause()

func request_preview(module_id: String) -> void:
	if not assembler.set_preview(module_id, target_slot):
		assembler.clear_preview()
		feedback("当前模块已安装，或与选中挂点不兼容")

func confirm_loadout() -> bool:
	var success := assembler.confirm_preview()
	feedback("模块已安装 · 回到战场试试" if success else "无法安装：检查槽位、重复模块和资源")
	return success

func _is_gameplay_blocking_control(control: Control) -> bool:
	if ui == null:
		return false
	return ui.is_gameplay_blocking_control(control)

func get_snapshot() -> Dictionary:
	var target_states: Array = []
	var enemy_states: Array = []
	for target in targets:
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			target_states.append(target.get_snapshot())
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy_states.append(enemy.get_snapshot())
	var snapshot := {"version": 2, "player": player.get_snapshot(), "loadout": assembler.snapshot(), "targets": target_states, "enemies": enemy_states,
		"mission": {"elapsed": elapsed, "collected": collected, "defeated": defeated, "outcome": outcome},
		"world": {"repair_done": repair_done, "shortcut_open": shortcut_open},
		"biome": biome_system.get_snapshot() if biome_system != null else {}}
	return snapshot

func save_snapshot() -> bool:
	var snapshot: Dictionary = get_snapshot()
	var success := validate_snapshot(snapshot) and save_service.save_snapshot(snapshot)
	feedback("检查点已保存 · F9 恢复" if success else "保存失败，原检查点保留")
	return success

func load_snapshot() -> bool:
	var state := save_service.load_snapshot()
	if state.is_empty() or not restore_snapshot(state):
		feedback("没有有效检查点，当前出击保持不变")
		return false
	feedback("检查点恢复 · 装配、资源、敌人和修复状态已还原")
	return true

func restore_snapshot(data: Dictionary) -> bool:
	if not validate_snapshot(data):
		return false
	_clear_entities()
	assembler.restore(data.loadout)
	player.restore_snapshot(data.player)
	repair_done = false
	for state in data.targets:
		for item in TARGET_LAYOUT:
			if item[0] == state.target_id:
				var target := _spawn_target(item)
				target.restore_snapshot(state)
				repair_done = repair_done or target.repaired_state
	for state in data.enemies:
		for item in ENEMY_LAYOUT:
			if item[0] == state.enemy_id:
				_spawn_enemy(item).restore_snapshot(state)
	player.rebind_packed_enemies()
	elapsed = float(data.mission.elapsed)
	collected = int(data.mission.collected)
	defeated = int(data.mission.defeated)
	outcome = str(data.mission.outcome)
	garage_open = false
	manual_pause = false
	var world_state: Dictionary = data.get("world", {})
	repair_done = bool(world_state.get("repair_done", repair_done))
	var restored_shortcut := bool(world_state.get("shortcut_open", repair_done))
	world.green_zone.visible = repair_done
	set_shortcut_open(restored_shortcut)
	if biome_system != null and data.get("biome", {}) is Dictionary and not (data["biome"] as Dictionary).is_empty():
		biome_system.restore_snapshot(data["biome"])
		_on_biome_changed(biome_system.current_id)
	ui.close_modals()
	if outcome != "active":
		ui.show_result()
	_sync_pause()
	if gm != null:
		set_gm_ai_frozen(gm.freeze_ai)
	return true

func get_unlocked_blueprints() -> Array:
	var result: Array = campaign_progress.get("unlocked_blueprints", [])
	return result.duplicate()

func _load_campaign_progress() -> void:
	var loaded := campaign_service.load_snapshot()
	if not loaded.is_empty() and _validate_campaign_progress(loaded):
		campaign_progress = loaded.duplicate(true)

func _save_campaign_progress() -> bool:
	return campaign_service.save_snapshot(campaign_progress)

func _save_campaign_candidate(candidate: Dictionary) -> bool:
	return campaign_service.save_snapshot(candidate)

func _validate_campaign_progress(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 1 or not data.get("unlocked_blueprints", []) is Array:
		return false
	var seen: Dictionary = {}
	for blueprint_id in data.get("unlocked_blueprints", []):
		if not blueprint_id is String or str(blueprint_id).is_empty() or seen.has(blueprint_id):
			return false
		seen[blueprint_id] = true
	return true

func _commit_contract_reward() -> bool:
	var unlocked: Array = campaign_progress.get("unlocked_blueprints", [])
	if unlocked.has(M1_REWARD_BLUEPRINT_ID):
		campaign_reward_pending = ""
		return true
	var candidate := campaign_progress.duplicate(true)
	var candidate_unlocked: Array = candidate.get("unlocked_blueprints", [])
	candidate_unlocked.append(M1_REWARD_BLUEPRINT_ID)
	candidate["unlocked_blueprints"] = candidate_unlocked
	if _save_campaign_candidate(candidate):
		campaign_progress = candidate
		campaign_reward_pending = ""
		return true
	campaign_reward_pending = M1_REWARD_BLUEPRINT_ID
	return false

func reset_campaign_progress() -> bool:
	var candidate := {"version": 1, "unlocked_blueprints": []}
	if not _save_campaign_candidate(candidate):
		return false
	campaign_progress = candidate
	campaign_reward_pending = ""
	return true

func validate_snapshot(data: Dictionary) -> bool:
	if data.get("version") != 2 or not data.get("player") is Dictionary or not data.get("loadout") is Dictionary or not data.get("targets") is Array or not data.get("enemies") is Array or not data.get("mission") is Dictionary:
		return false
	if data.has("world"):
		var world_state: Variant = data.get("world")
		if not world_state is Dictionary:
			return false
		if not world_state.get("repair_done", false) is bool or not world_state.get("shortcut_open", false) is bool:
			return false
		if bool(world_state.get("shortcut_open", false)) and not bool(world_state.get("repair_done", false)):
			return false
	if data.has("progress"):
		var saved_progress: Variant = data.get("progress")
		if not saved_progress is Dictionary or not _validate_campaign_progress(saved_progress):
			return false
	if not assembler.validate_snapshot(data.loadout) or not player.validate_snapshot(data.player):
		return false
	for coordinate in data.player.position:
		if not coordinate is float and not coordinate is int:
			return false
		if not is_finite(float(coordinate)):
			return false
	var mission: Dictionary = data.mission
	for key in ["elapsed", "collected", "defeated"]:
		if not mission.get(key) is float and not mission.get(key) is int:
			return false
		if not is_finite(float(mission[key])) or float(mission[key]) < 0:
			return false
	if not mission.get("outcome") in ["active", "won", "failed"] or int(mission.defeated) > ENEMY_LAYOUT.size():
		return false
	var seen: Dictionary = {}
	for state in data.targets:
		if not state is Dictionary:
			return false
		var matches := TARGET_LAYOUT.filter(func(item: Array): return item[0] == state.get("target_id") and item[1] == state.get("target_kind"))
		if matches.is_empty() or seen.has(state.target_id):
			return false
		var item: Array = matches[0]
		var probe := EngineeringTarget.new().configure(item[0], item[1], item[4])
		var valid: bool = probe.validate_snapshot(state)
		probe.free()
		if not valid:
			return false
		seen[state.target_id] = true
	if not seen.has("repair_pump"):
		return false
	if data.has("world"):
		var repaired_pump := false
		for state in data.targets:
			if state.target_id == "repair_pump":
				repaired_pump = bool(state.get("repaired", false))
				break
		var world_state: Dictionary = data.world
		if bool(world_state.repair_done) != repaired_pump or bool(world_state.shortcut_open) != repaired_pump:
			return false
	seen.clear()
	var enemy_states_by_id: Dictionary = {}
	for state in data.enemies:
		if not state is Dictionary:
			return false
		var matches := ENEMY_LAYOUT.filter(func(item: Array): return item[0] == state.get("enemy_id") and item[1] == state.get("kind"))
		if matches.is_empty() or seen.has(state.enemy_id):
			return false
		var item: Array = matches[0]
		var probe := EnemyDummy.new().configure(item[0], item[1], 90.0 if item[1] == "heavy" else 35.0, 1.0)
		var valid: bool = probe.validate_snapshot(state)
		probe.free()
		if not valid:
			return false
		seen[state.enemy_id] = true
		enemy_states_by_id[state.enemy_id] = state
	var packed_ids: Array = data.player.get("packed_enemy_ids", [])
	for packed_id in packed_ids:
		if not enemy_states_by_id.has(packed_id) or not bool(enemy_states_by_id[packed_id].get("packed", false)) or str(enemy_states_by_id[packed_id].get("kind", "")) != "light":
			return false
	for enemy_id in enemy_states_by_id:
		var enemy_state: Dictionary = enemy_states_by_id[enemy_id]
		if bool(enemy_state.get("packed", false)) and not packed_ids.has(enemy_id):
			return false
	return true

func feedback(message: String) -> void:
	if ui != null:
		ui.feedback(message)
	if audio != null:
		audio.play_feedback(message)

func prepare_whale_demo() -> Dictionary:
	reset_contract()
	assembler.restore({"version": 1, "core_id": "wide_bucket", "drive_id": "", "active_ids": ["magnet", ""], "stage": 2})
	player.reset_vehicle(Vector3(0, 0.5, 7))
	player.aim_direction = Vector3(0, 0, -1)
	var offsets := [Vector3(0, 0, -2.0), Vector3(1.0, 0, -2.4), Vector3(-1.0, 0, -2.4), Vector3(0, 0, -5.2), Vector3(0.2, 0, -3.2)]
	for index in range(mini(enemies.size(), offsets.size())):
		enemies[index].global_position = player.global_position + offsets[index]
	if gm != null:
		gm.set_panel_visible(false)
	return {"seed": "whale_demo_m0", "player": player.global_position, "light_ids": [enemies[0].enemy_id, enemies[1].enemy_id], "heavy_id": enemies[4].enemy_id}
