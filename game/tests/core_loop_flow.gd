extends SceneTree
## Highest agreed seam: a short M0 run from work action to repair and outcome.

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
	main.simulation_enabled = true
	main.player.set_physics_process(false)
	for enemy in main.enemies:
		enemy.set_process(false)
	check(main.outcome == "active", "run starts active")

	# Engineering action -> collected material -> visible stage growth.
	for _round in range(4):
		var target: EngineeringTarget = null
		for candidate in main.targets:
			if is_instance_valid(candidate) and not candidate.dead and candidate.target_kind != "repair":
				target = candidate
				break
		if target == null:
			break
		var swings := 0
		while is_instance_valid(target) and not target.dead and swings < 5:
			main.player.global_position = target.global_position + Vector3(0, 0.0, 2.0)
			main.player.aim_direction = Vector3(0, 0, -1)
			main.player.primary_cooldown = 0.0
			main.player.perform_primary()
			await process_frame
			swings += 1
	check(main.collected >= 4, "repeated engineering work produces enough material")
	check(main.assembler.stage == 2, "recovery crosses the stage growth threshold")

	# Build choice -> combination -> one-shot release.
	var preset: Dictionary = main.gm.execute("preset", {"name": "magnet"})
	check(preset.get("ok", false), "a legal build can be selected during the run")
	var light_a: EnemyDummy = main.enemies[0] as EnemyDummy
	var light_b: EnemyDummy = main.enemies[1] as EnemyDummy
	light_a.global_position = main.player.global_position + Vector3(0, 0, -2.0)
	light_b.global_position = main.player.global_position + Vector3(0.8, 0, -2.2)
	main.player.aim_direction = Vector3(0, 0, -1)
	main.player.primary_cooldown = 0.0
	var work: Dictionary = main.player.perform_primary()
	check(work.get("packed", false), "the selected build creates a visible combination result")
	check(int(main.gm.get_state().get("packed_count", 0)) == 1, "combination state is observable")
	main.player.throw_cooldown = 0.0
	var release: Dictionary = main.player.throw_cargo()
	check(release.get("performed", false) and release.get("hit", false), "the combination has a one-shot release action")
	check(int(main.gm.get_state().get("packed_count", 0)) == 0, "release consumes the temporary combination state")

	# Repair -> world state -> contract outcome.
	main.player.global_position = Vector3(6, 0.5, -6)
	check(main.try_repair(), "recovered material opens the repair interaction")
	check(main.repair_done and main.world.green_zone.visible, "repair changes the visible world state")
	for enemy in main.enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.take_damage(999.0)
	check(main.outcome == "won", "repair plus cleared threats completes the run")

	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("CORE LOOP PASS: work, growth, build, combination, repair, and outcome")
	quit(0 if failures.is_empty() else 1)
