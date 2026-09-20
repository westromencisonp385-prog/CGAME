class_name M0GMController
extends Node
## Safe, data-only game master surface for debug/editor builds.
## Every action goes through Main's public gameplay APIs; no eval or scene mutation
## is exposed to the UI/CLI.

signal state_changed(state: Dictionary)

var main: Node
var enabled := false
var visible := false
var invulnerable := false
var freeze_ai := false
var current_time_scale := 1.0
var startup_scenario := ""
var qa_capture_path := ""
var command_history: Array[String] = []
var test_save_service := M0SaveService.new()
const TEST_SAVE_PATH := "user://gm_test_checkpoint"
const MAX_GM_ENEMIES := 80

func setup(owner: Node) -> void:
	main = owner
	# GM is intentionally unavailable in an exported release.  --gm can enable
	# the panel in debug builds, while editor runs remain convenient by default.
	enabled = OS.is_debug_build() or Engine.is_editor_hint()
	test_save_service.configure(TEST_SAVE_PATH)
	_parse_command_line()
	if enabled:
		print(JSON.stringify({"event": "gm_ready", "enabled": true, "state": get_state()}))
		if not startup_scenario.is_empty():
			call_deferred("run_startup_scenario")
		if not qa_capture_path.is_empty():
			call_deferred("_capture_debug_build")

func _parse_command_line() -> void:
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if text == "--gm":
			# Keep this explicit for the CLI contract; release builds still remain off.
			enabled = enabled and OS.is_debug_build()
		elif text == "--no-gm":
			enabled = false
		elif text.begins_with("--scenario="):
			startup_scenario = text.trim_prefix("--scenario=")
		elif text.begins_with("--qa-capture="):
			qa_capture_path = text.trim_prefix("--qa-capture=")

func _capture_debug_build() -> void:
	# Export templates cannot use editor --script/--path overrides. This debug-only
	# entry point exercises the embedded main scene and writes its real viewport.
	if not enabled or DisplayServer.get_name() == "headless" or not qa_capture_path.ends_with(".png"):
		push_error("QA capture requires debug build, real renderer and .png path")
		get_tree().quit(1)
		return
	for _index in range(30):
		await get_tree().process_frame
	execute("panel", {"open": true})
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(qa_capture_path) != OK:
		push_error("QA capture could not save the rendered build")
		get_tree().quit(1)
		return
	print("QA_CAPTURE_PASS: " + qa_capture_path)
	get_tree().quit(0)

func run_startup_scenario() -> void:
	if startup_scenario.is_empty():
		return
	execute("reset")
	var result := execute("preset", {"name": startup_scenario})
	if not bool(result.get("ok", false)):
		result = execute(startup_scenario)
	print(JSON.stringify({"event": "gm_scenario", "scenario": startup_scenario, "result": result}))

func toggle_panel() -> Dictionary:
	if not enabled:
		return _error("GM 仅在 Godot 编辑器/Debug 构建可用")
	visible = not visible
	state_changed.emit(get_state())
	return _ok({"visible": visible})

func set_panel_visible(open: bool) -> void:
	if enabled:
		visible = open
		state_changed.emit(get_state())

func reset_flags() -> void:
	Engine.time_scale = 1.0
	current_time_scale = 1.0
	invulnerable = false
	freeze_ai = false
	visible = false
	if main != null and main.player != null:
		main.player.invulnerable = false

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func execute(command: String, args: Dictionary = {}) -> Dictionary:
	var name := command.strip_edges().to_lower()
	command_history.push_back(name)
	if command_history.size() > 40:
		command_history.pop_front()
	if not enabled:
		return _error("GM 仅在 Godot 编辑器/Debug 构建可用")
	if main == null:
		return _error("GM 尚未连接到主场景")
	var result: Dictionary
	match name:
		"help": result = _ok({"commands": ["help", "status", "panel", "preset", "heal", "invulnerable", "refill", "freeze_ai", "time_scale", "stage", "spawn", "garage", "preview", "confirm", "reset", "save", "load", "repair", "clear_enemies", "whale_pack", "whale_throw", "vfx"]})
		"status": result = _ok(get_state())
		"panel": result = _panel_command(args)
		"preset": result = _preset(str(args.get("name", "")))
		"heal": result = _heal(args)
		"invulnerable": result = _set_invulnerable(args)
		"refill": result = _refill(args)
		"freeze_ai": result = _set_freeze_ai(args)
		"time_scale": result = _set_time_scale(args)
		"stage": result = _set_stage(args)
		"spawn": result = _spawn(args)
		"garage": result = _garage(args)
		"preview": result = _preview(args)
		"confirm": result = _confirm()
		"reset", "reset_training": result = _reset()
		"save": result = _save_test_snapshot()
		"load": result = _load_test_snapshot()
		"repair": result = _repair()
		"clear_enemies": result = _clear_enemies()
		"whale_pack": result = _whale_pack(args)
		"whale_throw": result = _whale_throw()
		"vfx": result = _set_vfx(args)
		_: result = _error("未知 GM 命令：%s" % name)
	if bool(result.get("ok", false)):
		state_changed.emit(get_state())
	return result

func get_state() -> Dictionary:
	if main == null:
		return {"enabled": enabled, "visible": visible}
	var p: Node = main.player
	var a: Node = main.assembler
	var state := {
		"enabled": enabled,
		"visible": visible,
		"invulnerable": invulnerable,
		"freeze_ai": freeze_ai,
		"time_scale": current_time_scale,
		"scenario": startup_scenario,
		"health": float(p.health) if p != null else 0.0,
		"cargo": int(p.cargo) if p != null else 0,
		"charge": float(p.charge) if p != null else 0.0,
		"stage": int(a.stage) if a != null else 0,
		"loadout": a.snapshot() if a != null else {},
		"formal_enemies": int(main.enemies.size()),
		"gm_enemies": int(main.gm_enemies.size()),
		"defeated": int(main.defeated),
		"repair_done": bool(main.repair_done),
		"outcome": str(main.outcome),
		"test_save_path": TEST_SAVE_PATH,
		"packed_count": int(main.player.packed_enemy_ids.size()) if main.player != null else 0,
		"packed_enemy_ids": main.player.packed_enemy_ids.duplicate() if main.player != null else [],
		"last_command": command_history.back() if not command_history.is_empty() else ""
	}
	return state

func _preset(name: String) -> Dictionary:
	var presets := {
		"magnet": {"core_id": "wide_bucket", "drive_id": "", "active_ids": ["magnet", ""]},
		"storm": {"core_id": "basic_bucket", "drive_id": "", "active_ids": ["water_cannon", "electric_arc"]},
		"ram": {"core_id": "wide_bucket", "drive_id": "inertia_flywheel", "active_ids": ["", ""]}
	}
	if not presets.has(name):
		return _error("preset 必须是 magnet、storm 或 ram")
	var snapshot: Dictionary = {"version": 1}
	snapshot.merge(presets[name])
	snapshot["stage"] = clampi(int(main.assembler.stage), 1, 2)
	if not main.assembler.restore(snapshot):
		return _error("装配不合法：%s" % name)
	return _ok({"preset": name, "loadout": main.assembler.snapshot()})

func _panel_command(args: Dictionary) -> Dictionary:
	var parsed: Variant = _read_bool(args, visible)
	if parsed == null:
		return _error("panel open 必须是 true/false")
	if bool(parsed) and main.garage_open:
		main.toggle_garage()
	set_panel_visible(bool(parsed))
	return _ok({"open": visible})

func _heal(args: Dictionary) -> Dictionary:
	var raw: Variant = args.get("amount", 100.0)
	if not _is_number(raw):
		return _error("heal amount 必须是非负数")
	var amount := float(raw)
	if not is_finite(amount) or amount < 0.0:
		return _error("heal amount 必须是非负数")
	main.player.health = minf(100.0, main.player.health + amount)
	return _ok({"health": main.player.health})

func _set_invulnerable(args: Dictionary) -> Dictionary:
	var parsed: Variant = _read_bool(args, invulnerable)
	if parsed == null:
		return _error("invulnerable enabled 必须是 true/false")
	invulnerable = bool(parsed)
	main.player.invulnerable = invulnerable
	return _ok({"invulnerable": invulnerable})

func _refill(args: Dictionary) -> Dictionary:
	var raw_cargo: Variant = args.get("cargo", main.player.max_cargo)
	var raw_charge: Variant = args.get("charge", 100.0)
	if not _is_integer(raw_cargo) or not _is_number(raw_charge):
		return _error("refill cargo 必须是整数，charge 必须是数字")
	var cargo := int(raw_cargo)
	var charge := float(raw_charge)
	if cargo < 0 or cargo > 64 or not is_finite(charge) or charge < 0.0 or charge > 100.0:
		return _error("refill 范围：cargo 0..64，charge 0..100")
	main.player.cargo = mini(cargo, main.player.max_cargo)
	main.player.charge = charge
	main.player.heat = 0.0
	return _ok({"cargo": main.player.cargo, "charge": main.player.charge})

func _set_freeze_ai(args: Dictionary) -> Dictionary:
	var parsed: Variant = _read_bool(args, freeze_ai)
	if parsed == null:
		return _error("freeze_ai enabled 必须是 true/false")
	freeze_ai = bool(parsed)
	main.set_gm_ai_frozen(freeze_ai)
	return _ok({"freeze_ai": freeze_ai})

func _set_time_scale(args: Dictionary) -> Dictionary:
	var raw: Variant = args.get("value", 1.0)
	if not _is_number(raw):
		return _error("time_scale 必须是数字")
	var value := float(raw)
	if not [0.25, 0.5, 1.0, 2.0].has(value):
		return _error("time_scale 只支持 0.25、0.5、1 或 2")
	current_time_scale = value
	Engine.time_scale = value
	return _ok({"time_scale": value})

func _set_stage(args: Dictionary) -> Dictionary:
	var raw: Variant = args.get("value", 1)
	if not _is_integer(raw):
		return _error("stage 必须是整数 1 或 2")
	var value := int(raw)
	if value < 1 or value > 2 or not main.assembler.set_stage(value):
		return _error("stage 只支持 1 或 2")
	return _ok({"stage": value})

func _spawn(args: Dictionary) -> Dictionary:
	var kind := str(args.get("kind", "light"))
	if kind not in ["light", "heavy", "ranged"]:
		return _error("spawn kind 必须是 light、heavy 或 ranged")
	var raw_count: Variant = args.get("count", 1)
	if not _is_integer(raw_count):
		return _error("spawn count 必须是整数")
	var count := int(raw_count)
	if count < 1:
		return _error("spawn count 必须至少为 1")
	if count > MAX_GM_ENEMIES - main.gm_enemies.size():
		return _error("GM 敌人上限为 80 个")
	if main.gm_enemies.size() >= MAX_GM_ENEMIES:
		return _error("GM 敌人已达到 80 个上限")
	for index in count:
		var angle := TAU * float(index) / float(maxi(count, 1))
		main.spawn_gm_enemy(kind, Vector3(cos(angle) * 7.0, 0.7, sin(angle) * 7.0 + 1.0))
	return _ok({"spawned": count, "kind": kind, "gm_enemies": main.gm_enemies.size()})

func _garage(args: Dictionary) -> Dictionary:
	var parsed: Variant = _read_bool(args, not main.garage_open)
	if parsed == null:
		return _error("garage open 必须是 true/false")
	var desired := bool(parsed)
	if main.garage_open != desired:
		main.toggle_garage()
	return _ok({"open": main.garage_open})

func _preview(args: Dictionary) -> Dictionary:
	var id_value: Variant = args.get("module", args.get("id", ""))
	var slot_value: Variant = args.get("slot", main.target_slot)
	if not id_value is String or not _is_integer(slot_value) or int(slot_value) not in [0, 1]:
		return _error("preview 要求 module字符串和 slot 0/1")
	var module_id: String = id_value
	var slot := int(slot_value)
	if not main.assembler.set_preview(module_id, slot):
		return _error("模块无法预览：%s" % module_id)
	main.target_slot = slot
	return _ok({"module": module_id, "slot": slot, "preview": main.assembler.preview_id})

func _confirm() -> Dictionary:
	var ok: bool = main.confirm_loadout()
	return _ok({"confirmed": ok, "loadout": main.assembler.snapshot()}) if ok else _error("没有可确认的合法预览")

func _reset() -> Dictionary:
	Engine.time_scale = 1.0
	current_time_scale = 1.0
	invulnerable = false
	freeze_ai = false
	main.reset_contract()
	main.player.invulnerable = false
	main.set_gm_ai_frozen(false)
	return _ok({"reset": true})

func _save_test_snapshot() -> Dictionary:
	var ok := test_save_service.save_snapshot(main.get_snapshot())
	return _ok({"saved": ok, "path": TEST_SAVE_PATH}) if ok else _error("GM 测试存档保存失败")

func _load_test_snapshot() -> Dictionary:
	var state := test_save_service.load_snapshot()
	if state.is_empty() or not main.restore_snapshot(state):
		return _error("没有有效 GM 测试存档")
	return _ok({"loaded": true, "path": TEST_SAVE_PATH})

func _repair() -> Dictionary:
	for target in main.targets:
		if is_instance_valid(target) and target.target_kind == "repair" and not target.repaired_state:
			main.collected = maxi(main.collected, 3)
			if target.interact_repair():
				return _ok({"repair_done": true})
	return _ok({"repair_done": main.repair_done})

func _clear_enemies() -> Dictionary:
	main.clear_gm_and_formal_enemies()
	# Clearing formal threats is an explicit training shortcut; mark them as
	# resolved so the normal repair -> victory path remains testable.
	main.defeated = main.ENEMY_LAYOUT.size()
	main._check_victory()
	return _ok({"cleared": true, "formal_enemies": main.enemies.size(), "gm_enemies": main.gm_enemies.size(), "defeated": main.defeated})

func _whale_pack(args: Dictionary) -> Dictionary:
	var requested_id := str(args.get("target_id", args.get("enemy_id", "")))
	var candidate: EnemyDummy = null
	for enemy in main.enemies + main.gm_enemies:
		if not is_instance_valid(enemy) or enemy.dead or not enemy.can_be_magnetized():
			continue
		if requested_id.is_empty() or enemy.enemy_id == requested_id:
			if candidate == null or main.player.global_position.distance_to(enemy.global_position) < main.player.global_position.distance_to(candidate.global_position):
				candidate = enemy
	if candidate == null:
		return _error("没有可打包的轻型目标")
	var result: Dictionary = main.player.pack_enemy(candidate)
	return _ok(result) if bool(result.get("packed", false)) else _error(str(result.get("reason", "鲸口打包失败")))

func _whale_throw() -> Dictionary:
	var result: Dictionary = main.player.throw_cargo()
	return _ok(result) if bool(result.get("performed", false)) else _error(str(result.get("reason", "没有可投掷的载荷")))

func _set_vfx(args: Dictionary) -> Dictionary:
	var parsed: Variant = _read_bool(args, true)
	if parsed == null:
		return _error("vfx enabled 必须是 true/false")
	var value := bool(parsed)
	if main.world != null and main.world.has_method("set_effects_enabled"):
		main.world.set_effects_enabled(value)
		return _ok({"vfx": value})
	return _error("当前世界没有 VFX 开关")

func _read_bool(args: Dictionary, fallback: bool) -> Variant:
	if not args.has("enabled") and not args.has("value") and not args.has("visible") and not args.has("open"):
		return fallback
	var value: Variant = args.get("enabled", args.get("value", args.get("visible", args.get("open", fallback))))
	if value is String:
		var text := str(value).to_lower()
		if text in ["1", "true", "yes", "on", "enabled"]:
			return true
		if text in ["0", "false", "no", "off", "disabled"]:
			return false
		return null
	if typeof(value) == TYPE_BOOL:
		return value
	if _is_integer(value) and int(value) in [0, 1]:
		return int(value) == 1
	return null

func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

func _is_integer(value: Variant) -> bool:
	return _is_number(value) and is_finite(float(value)) and float(value) == floorf(float(value))

func _ok(data: Dictionary) -> Dictionary:
	return {"ok": true, "error": "", "data": data}

func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "data": {}}
