extends Node3D
## A complete short M0 experiment, without claiming M1 campaign/platform scope.
const Catalog = preload("res://scripts/module_catalog.gd")
const InputSetup = preload("res://scripts/m0_input.gd")
const ArenaVisual = preload("res://scripts/arena_visual.gd")
const HUD = preload("res://scripts/m0_hud.gd")
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

var player: M0VehicleController
var assembler: LoadoutAssembler
var save_service := M0SaveService.new()
var definitions: Dictionary
var targets: Array[EngineeringTarget] = []
var enemies: Array[EnemyDummy] = []
var entities: Node3D
var world: Node3D
var ui: CanvasLayer
var audio: Node
var elapsed := 0.0
var collected := 0
var defeated := 0
var repair_done := false
var outcome := "active"
var garage_open := false
var manual_pause := false
var target_slot := 0
var simulation_enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.configure()
	definitions = Catalog.create_definitions()
	world = ArenaVisual.new()
	add_child(world)
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
	player.feedback.connect(feedback)
	player.disabled.connect(func(): finish_contract("failed"))
	player.harvested.connect(_harvested)
	player.action_effect.connect(world.present_effect)
	audio = Sound.new()
	add_child(audio)
	ui = HUD.new()
	add_child(ui)
	ui.setup(self)
	reset_contract()

func _process(delta: float) -> void:
	if outcome == "active" and not get_tree().paused and simulation_enabled:
		elapsed += delta
	if player != null:
		var hovered := get_viewport().gui_get_hovered_control()
		player.gameplay_enabled = outcome == "active" and not garage_open and not manual_pause and simulation_enabled and hovered == null
		if player.health <= 0.0 and outcome == "active":
			finish_contract("failed")
		var desired := Vector3(player.position.x * 0.22, 23, 22 + player.position.z * 0.18)
		world.camera.position = world.camera.position.lerp(desired, minf(delta * 4.0, 1.0))
		world.camera.look_at(Vector3(player.position.x * 0.2, 0, player.position.z * 0.12 - 1))
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
			KEY_F5: save_snapshot()
			KEY_F9: load_snapshot()
			KEY_F6: reset_contract()

func _clear_entities() -> void:
	for child in entities.get_children():
		entities.remove_child(child)
		child.queue_free()
	targets.clear()
	enemies.clear()

func reset_contract() -> void:
	_clear_entities()
	get_tree().paused = false
	outcome = "active"
	manual_pause = false
	garage_open = false
	elapsed = 0.0
	collected = 0
	defeated = 0
	repair_done = false
	world.green_zone.hide()
	assembler.restore({"version": 1, "active_ids": ["", ""], "core_id": "basic_bucket", "drive_id": "", "stage": 1})
	player.reset_vehicle(Vector3(0, 0.5, 7))
	for item in TARGET_LAYOUT:
		_spawn_target(item)
	for item in ENEMY_LAYOUT:
		_spawn_enemy(item)
	ui.close_modals()
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
		player.health = minf(player.health + 30.0, 100.0)
		feedback("水泵启动 · 耐久恢复 +30 · 河岸复苏")
		_check_victory()
	)
	return target

func _spawn_enemy(item: Array) -> EnemyDummy:
	var kind := str(item[1])
	var enemy := EnemyDummy.new().configure(str(item[0]), kind, 90.0 if kind == "heavy" else 35.0, 0.6 if kind == "heavy" else 1.3, Vector3(float(item[2]), 0.7, float(item[3])))
	enemy.player = player
	entities.add_child(enemy)
	enemies.append(enemy)
	enemy.hit_player.connect(player.receive_damage)
	enemy.action_effect.connect(world.present_effect)
	enemy.defeated.connect(func(_e: EnemyDummy):
		defeated += 1
		feedback("威胁解除 · %d / %d" % [defeated, ENEMY_LAYOUT.size()])
		_check_victory()
	)
	return enemy

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

func _check_victory() -> void:
	if outcome == "active" and repair_done and defeated == ENEMY_LAYOUT.size():
		finish_contract("won")

func finish_contract(result: String) -> void:
	if outcome != "active":
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
	get_tree().paused = garage_open or manual_pause or outcome != "active"
	player.gameplay_enabled = not get_tree().paused and simulation_enabled

func request_preview(module_id: String) -> void:
	if not assembler.set_preview(module_id, target_slot):
		assembler.clear_preview()
		feedback("当前模块已安装，或与选中挂点不兼容")

func confirm_loadout() -> bool:
	var success := assembler.confirm_preview()
	feedback("模块已安装 · 回到战场试试" if success else "无法安装：检查槽位、重复模块和资源")
	return success

func get_snapshot() -> Dictionary:
	var target_states: Array = []
	var enemy_states: Array = []
	for target in targets:
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			target_states.append(target.get_snapshot())
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy_states.append(enemy.get_snapshot())
	return {"version": 2, "player": player.get_snapshot(), "loadout": assembler.snapshot(), "targets": target_states, "enemies": enemy_states,
		"mission": {"elapsed": elapsed, "collected": collected, "defeated": defeated, "outcome": outcome}}

func save_snapshot() -> bool:
	var success := save_service.save_snapshot(get_snapshot())
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
	elapsed = float(data.mission.elapsed)
	collected = int(data.mission.collected)
	defeated = int(data.mission.defeated)
	outcome = str(data.mission.outcome)
	garage_open = false
	manual_pause = false
	world.green_zone.visible = repair_done
	ui.close_modals()
	if outcome != "active":
		ui.show_result()
	_sync_pause()
	return true

func validate_snapshot(data: Dictionary) -> bool:
	if data.get("version") != 2 or not data.get("player") is Dictionary or not data.get("loadout") is Dictionary or not data.get("targets") is Array or not data.get("enemies") is Array or not data.get("mission") is Dictionary:
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
	seen.clear()
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
	return true

func feedback(message: String) -> void:
	if ui != null:
		ui.feedback(message)
	if audio != null:
		audio.play_feedback(message)
