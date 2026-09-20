extends SceneTree
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var arena: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	arena.simulation_enabled = false
	arena.player.set_physics_process(false)
	for enemy in arena.enemies:
		enemy.set_process(false)
	var before: Dictionary = arena.get_snapshot()
	var scrap = arena.targets[0]
	var scrap_id: String = scrap.target_id
	scrap.destroy_target()
	await process_frame
	check(arena.get_snapshot().targets.size() == before.targets.size() - 1, "Destroyed debris leaves checkpoint state")
	check(arena.restore_snapshot(before), "Earlier checkpoint can rebuild destroyed debris")
	check(arena.targets.any(func(t): return t.target_id == scrap_id), "Restored debris is interactable again")
	var invalid: Dictionary = before.duplicate(true)
	invalid.player.position = ["bad", 0, 0]
	check(not arena.restore_snapshot(invalid), "Bad coordinate rejected without replacing the world")
	check(arena.get_snapshot().targets.size() == before.targets.size(), "Rejected checkpoint preserves active world")
	arena.collected = 3
	arena.player.position = Vector3(6, 0.5, -6)
	check(arena.try_repair(), "Collected material allows close-range pump interaction")
	check(arena.repair_done, "Repair changes visible world progress")
	check(arena.restore_snapshot(before) and not arena.repair_done, "Restoring earlier checkpoint reverses local repair consistently")
	arena.player.receive_damage(999.0)
	await process_frame
	check(arena.outcome == "failed", "Vehicle death ends the contract")
	check(not arena.try_repair(), "Failed contract cannot repair")
	arena.reset_contract()
	check(arena.outcome == "active" and arena.player.health == 100.0, "Retry returns to a playable new contract")
	arena.collected = 3
	arena.player.position = Vector3(6, 0.5, -6)
	arena.try_repair()
	for enemy in arena.enemies:
		enemy.take_damage(999.0)
	check(arena.outcome == "won", "Repair plus cleared threats completes the contract")
	var count: int = arena.defeated
	for enemy in arena.enemies:
		enemy.take_damage(999.0)
	check(arena.defeated == count, "Dead enemies cannot settle twice")
	paused = false
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("CONTRACT FLOW PASS: reconstruction, invalid input, repair rollback, loss/retry/win")
	quit(0 if failures.is_empty() else 1)
