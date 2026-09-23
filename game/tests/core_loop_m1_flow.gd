extends SceneTree
## M1 slice: repair opens a physical shortcut and a contract grants persistent blueprint progress.

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.simulation_enabled = false
	main.player.set_physics_process(false)
	for enemy in main.enemies:
		enemy.set_process(false)

	check(main.gm.execute("campaign_reset").get("ok", false), "M1 test starts from a clean campaign")
	check(not bool(main.gm.get_state().get("shortcut_open", true)), "shortcut starts closed")
	check(main.world.has_method("is_shortcut_open"), "world exposes shortcut state")
	check(not main.world.is_shortcut_open(), "closed shortcut is observable through world")
	main.player.global_position = Vector3(9.0, 0.5, 1.0)
	check(main.player.test_move(main.player.global_transform, Vector3(0, 0, -3.0)), "closed shortcut blocks direct traversal")

	main.collected = 3
	main.player.global_position = Vector3(6, 0.5, -6)
	check(main.try_repair(), "repair remains available before shortcut opens")
	check(main.repair_done and main.world.is_shortcut_open(), "repair opens the physical shortcut")
	check(main.shortcut_gate != null and main.shortcut_gate.disabled, "repair disables the shortcut collision gate")
	main.player.global_position = Vector3(9.0, 0.5, 1.0)
	check(not main.player.test_move(main.player.global_transform, Vector3(0, 0, -3.0)), "repaired shortcut permits direct traversal")

	var before_victory: Dictionary = main.get_snapshot()
	check(main.gm.execute("save").get("ok", false), "GM can save a pre-reward run state")
	check(main.gm.execute("clear_enemies").get("ok", false), "public training clear resolves the contract")
	check(main.outcome == "won", "repair plus cleared threats completes the M1 contract")
	var reward_id := str(main.M1_REWARD_BLUEPRINT_ID)
	check(reward_id in main.get_unlocked_blueprints(), "contract commits a stable blueprint reward")
	var reward_count: int = main.get_unlocked_blueprints().size()
	main.gm.execute("clear_enemies")
	check(main.get_unlocked_blueprints().size() == reward_count, "reopening victory does not duplicate reward")
	check(main.gm.execute("load").get("ok", false), "older GM run checkpoint can be restored")
	check(main.outcome == "active" and reward_id in main.get_unlocked_blueprints(), "loading older GM run does not roll back permanent blueprint")
	var legacy_snapshot: Dictionary = before_victory.duplicate(true)
	legacy_snapshot["progress"] = {"version": 1, "unlocked_blueprints": []}
	check(main.restore_snapshot(legacy_snapshot), "older run checkpoint with legacy progress can be read")
	check(reward_id in main.get_unlocked_blueprints(), "legacy run progress field cannot erase permanent blueprint")
	var impossible_route: Dictionary = before_victory.duplicate(true)
	impossible_route.world.repair_done = false
	impossible_route.world.shortcut_open = true
	check(not main.restore_snapshot(impossible_route), "shortcut without repaired pump is rejected before replacing the world")
	check(reward_id in main.get_unlocked_blueprints(), "rejected route leaves campaign progress intact")

	check(main.repair_done and main.world.is_shortcut_open(), "replayed run retains the earlier repair")
	for enemy in main.enemies:
		if not enemy.dead:
			enemy.take_damage(999.0)
	check(main.gm.execute("save").get("ok", false), "GM save accepts repaired route and reward")
	check(main.gm.execute("reset").get("ok", false), "new expedition clears local contract state")
	check(main.outcome == "active" and not main.repair_done and not main.world.is_shortcut_open(), "reset clears local repair state")
	check(reward_id in main.get_unlocked_blueprints(), "reset preserves permanent blueprint reward")
	check(main.gm.execute("load").get("ok", false), "GM load restores the saved contract")
	check(main.repair_done and main.world.is_shortcut_open(), "GM load restores repaired shortcut")
	check(reward_id in main.get_unlocked_blueprints(), "GM load restores blueprint progress")

	var normal_save_path := "user://m1_normal_flow_%s" % Time.get_ticks_usec()
	main.save_service.configure(normal_save_path)
	check(main.save_snapshot(), "normal F5 save accepts M1 state")
	main.gm.execute("reset")
	check(main.load_snapshot(), "normal F9 load accepts M1 state")
	check(main.repair_done and main.world.is_shortcut_open(), "normal F9 restores repaired shortcut")
	check(reward_id in main.get_unlocked_blueprints(), "normal F9 restores reward progress")

	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("CORE LOOP M1 PASS: repaired shortcut, persistent reward, and save/load separation")
	quit(0 if failures.is_empty() else 1)
