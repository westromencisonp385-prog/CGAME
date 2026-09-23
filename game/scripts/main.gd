extends Node3D
## A complete short M0 experiment, without claiming M1 campaign/platform scope.
const Catalog = preload("res://scripts/module_catalog.gd")
const InputSetup = preload("res://scripts/m0_input.gd")
const ArenaVisual = preload("res://scripts/arena_visual.gd")
const HUD = preload("res://scripts/m0_hud.gd")
const GMController = preload("res://scripts/gm_controller.gd")
const Sound = preload("res://scripts/prototype_audio.gd")
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
	["guardian", "heavy", 7.0, -10.0]
]
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
var audio: Node
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if world.has_method("set_vehicle"):
		world.set_vehicle(player)
	player.feedback.connect(feedback)
	player.disabled.connect(func(): finish_contract("failed"))
	player.harvested.connect(_harvested)
	player.action_effect.connect(world.present_effect)
	audio = Sound.new()
	add_child(audio)
	campaign_service.configure(CAMPAIGN_SAVE_PATH)
	_load_campaign_progress()
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
		var desired := Vector3(player.position.x * 0.16, 26.0, 18.0 + player.position.z * 0.14)
		world.camera.position = world.camera.position.lerp(desired, minf(delta * 4.0, 1.0))
		world.camera.look_at(Vector3(player.position.x * 0.12, 0.0, player.position.z * 0.08 - 1.4))
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

func _clear_entities() -> void:
	for child in entities.get_children():
		entities.remove_child(child)
		child.queue_free()
	targets.clear()
	enemies.clear()
	gm_enemies.clear()

func reset_contract() -> void:
	_clear_entities()
	if gm != null:
		gm.reset_flags()
	get_tree().paused = false
	outcome = "active"
	manual_pause = false
	garage_open = false
	elapsed = 0.0
	collected = 0
	defeated = 0
	repair_done = false
	reward_retry_clock = 0.0
	set_shortcut_open(false)
	assembler.restore({"version": 1, "active_ids": ["", ""], "core_id": "basic_bucket", "drive_id": "", "stage": 1})
	player.reset_vehicle(Vector3(0, 0.5, 7))
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
		player.health = minf(player.health + 30.0, 100.0)
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
	return _spawn_enemy([id, kind, at.x, at.z], false)

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
	if collected >= 4 and assembler.stage == 1:
		assembler.set_stage(2)
		feedback("结构进化 · 作业范围提升，重量降低移动速度")

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
	get_tree().paused = garage_open or manual_pause or outcome != "active" or (gm != null and gm.visible)
	player.gameplay_enabled = not get_tree().paused and simulation_enabled

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
		"world": {"repair_done": repair_done, "shortcut_open": shortcut_open}}
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
