extends SceneTree
## External behavior checks for the debug GM seam. Runs headless in Godot 4.7.2.

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var gm: M0GMController = main.gm
	check(gm != null, "main exposes gm controller")
	check(gm.enabled, "GM is enabled in debug test build")
	check(gm.execute("status").get("ok", false), "status command works")
	check(gm.execute("panel", {"open": true}).ok, "GM panel opens through the same command seam")
	check(paused and not main.player.gameplay_enabled, "GM panel blocks driving and attack even away from its rectangle")
	check(gm.execute("panel", {"open": false}).ok and not paused, "Closing GM returns to the previous active simulation")
	check(gm.execute("preset", {"name": "storm"}).get("ok", false), "storm preset installs")
	check(main.assembler.active_ids == ["water_cannon", "electric_arc"], "storm has two legal function modules")
	check(gm.execute("preview", {"module": "magnet", "slot": 1}).get("ok", false), "preview command creates ghost")
	check(gm.execute("confirm").get("ok", false), "confirm installs ghost")
	check(main.assembler.active_ids[1] == "magnet", "confirmed preview reaches runtime loadout")
	check(gm.execute("invulnerable", {"enabled": true}).get("ok", false), "invulnerable toggles")
	var health_before: float = main.player.health
	main.player.receive_damage(200.0)
	check(is_equal_approx(main.player.health, health_before), "invulnerable blocks combat damage")
	check(gm.execute("refill").get("ok", false), "refill command works")
	check(main.player.cargo == main.player.max_cargo and is_equal_approx(main.player.charge, 100.0), "refill reaches max resources")
	check(gm.execute("spawn", {"kind": "light", "count": 3}).get("ok", false), "spawn creates training enemies")
	check(main.gm_enemies.size() == 3 and main.enemies.size() == 5, "GM enemies do not change formal target count")
	check(gm.execute("freeze_ai", {"enabled": true}).get("ok", false), "freeze AI command works")
	check(main.enemies[0].process_mode == Node.PROCESS_MODE_DISABLED, "freeze AI disables enemy processing")
	check(gm.execute("save").get("ok", false), "GM save is accepted")
	main.player.health = 1.0
	check(gm.execute("load").get("ok", false), "GM load restores isolated save")
	check(is_equal_approx(main.player.health, health_before), "GM load restores health")
	check(main.enemies[0].process_mode == Node.PROCESS_MODE_DISABLED, "Frozen AI remains frozen after checkpoint reconstruction")
	check(gm.execute("clear_enemies").get("ok", false), "clear enemies works")
	check(main.gm_enemies.is_empty() and main.enemies.is_empty() and main.defeated == main.ENEMY_LAYOUT.size(), "clear marks formal training threats resolved")
	check(not gm.execute("time_scale", {"value": 1.5}).get("ok", true), "invalid time scale rejected")
	check(not gm.execute("stage", {"value": 1.5}).ok, "Fractional stage rejected")
	check(not gm.execute("heal", {"amount": {}}).ok, "Object passed as numeric argument rejected safely")
	check(not gm.execute("spawn", {"count": -2}).ok, "Negative spawn count rejected")
	check(gm.execute("time_scale", {"value": 0.25}).ok, "Slow motion works")
	main.reset_contract()
	check(Engine.time_scale == 1.0 and not gm.invulnerable and not gm.freeze_ai, "Normal retry clears GM modifiers as well")
	Engine.time_scale = 1.0
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("GM FLOW PASS: command seam, presets, preview, combat, isolated save, and training enemies")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)
