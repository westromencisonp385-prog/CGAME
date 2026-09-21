extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _place(enemy: Node, at: Vector3) -> void:
	enemy.global_position = at
	if enemy.has_method("restore_snapshot"):
		enemy.restore_snapshot(enemy.get_snapshot())

func _cooldown_ready(main: Node) -> void:
	main.player.primary_cooldown = 0.0
	main.player.throw_cooldown = 0.0
	main.player.dash_cooldown = 0.0

func _run() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	check(packed_scene != null, "Main scene is available")
	if packed_scene == null:
		quit(1)
		return
	var main: Node = packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var gm: Node = main.gm
	check(gm != null and gm.has_method("execute"), "GM seam is available")
	if gm == null:
		quit(1)
		return
	check(gm.execute("reset").get("ok", false), "Training reset works")
	check(gm.execute("preset", {"name": "magnet"}).get("ok", false), "Whale/magnet preset installs")
	var light: EnemyDummy = main.enemies[0] as EnemyDummy
	var light_two: EnemyDummy = main.enemies[1] as EnemyDummy
	var light_three: EnemyDummy = main.enemies[2] as EnemyDummy
	var release_victim: EnemyDummy = main.enemies[3] as EnemyDummy
	var heavy: EnemyDummy = main.enemies[4] as EnemyDummy
	_place(light, main.player.global_position + Vector3(0, 0, -2.0))
	_place(light_two, main.player.global_position + Vector3(0.8, 0, -2.2))
	_place(light_three, main.player.global_position + Vector3(-0.8, 0, -2.2))
	_place(heavy, main.player.global_position + Vector3(0, 0, -2.8))
	main.player.aim_direction = Vector3(0, 0, -1)
	_cooldown_ready(main)
	var pack_result: Dictionary = main.player.perform_primary()
	check(pack_result.get("performed", false) and pack_result.get("packed", false), "Normal primary packs a qualified light enemy")
	check(light.packed, "Packed enemy enters packed state")
	check(light.process_mode == Node.PROCESS_MODE_DISABLED, "Packed enemy AI is disabled")
	check(not light.visible, "Packed enemy is hidden from the combat scene")
	check(int(gm.get_state().get("packed_count", 0)) == 1, "Packed count is externally observable")
	var packed_health := light.current_health
	_cooldown_ready(main)
	var second_pack: Dictionary = main.player.perform_primary()
	check(second_pack.get("performed", false) and int(gm.get_state().get("packed_count", 0)) == 2, "Primary can pack a second light up to capacity")
	check(light_two.packed or light_three.packed, "Second eligible target enters packed state")
	_cooldown_ready(main)
	var overflow: Dictionary = main.player.perform_primary()
	check(not bool(overflow.get("packed", false)) and int(gm.get_state().get("packed_count", 0)) == 2, "Whale packing is capped at two targets")
	_cooldown_ready(main)
	check(is_equal_approx(light.current_health, packed_health), "Packed enemies ignore ordinary primary hit processing")
	var heavy_health := heavy.current_health
	var heavy_pack: Dictionary = gm.execute("whale_pack", {"target_id": heavy.enemy_id})
	check(not heavy_pack.get("ok", true), "Heavy enemy is rejected by whale packing")
	check(not heavy.packed, "Heavy enemy remains unpacked")
	check(heavy.current_health <= heavy_health, "Heavy target remains in normal combat instead of packed state")
	var save_result: Dictionary = gm.execute("save")
	check(save_result.get("ok", false), "GM save accepts packed state")
	var packed_snapshot_ids: Array = main.player.get_snapshot().get("packed_enemy_ids", [])
	check(packed_snapshot_ids.size() == 2 and packed_snapshot_ids[0] == light.enemy_id, "Player snapshot records the packed targets")
	check(gm.execute("reset").get("ok", false), "Reset clears the live packed state")
	check(int(gm.get_state().get("packed_count", 0)) == 0, "Reset clears packed count")
	check(gm.execute("freeze_ai", {"enabled": true}).get("ok", false), "GM can freeze AI before load")
	check(gm.execute("load").get("ok", false), "GM load restores packed state")
	check(int(gm.get_state().get("packed_count", 0)) == 2, "Load restores packed count")
	check(gm.execute("freeze_ai", {"enabled": false}).get("ok", false), "GM can unfreeze AI after load")
	var restored_light: EnemyDummy = main.enemies[0] as EnemyDummy
	var restored_second: EnemyDummy = null
	for candidate in main.enemies:
		if candidate.enemy_id == packed_snapshot_ids[1]:
			restored_second = candidate
			break
	check(restored_light.packed, "Load restores the packed enemy flag")
	check(restored_second != null and restored_light.process_mode == Node.PROCESS_MODE_DISABLED and restored_second.process_mode == Node.PROCESS_MODE_DISABLED, "Packed enemies stay AI-disabled after freeze toggles")
	main.player.aim_direction = Vector3.RIGHT
	release_victim = main.enemies[3] as EnemyDummy
	release_victim.global_position = main.player.global_position + Vector3(5.2, 0, 0.2)
	var victim_health := release_victim.current_health
	_cooldown_ready(main)
	var release_result: Dictionary = main.player.throw_cargo()
	check(release_result.get("performed", false) and release_result.get("hit", false), "Packed enemy can be released with normal throw")
	var landing: Vector3 = release_result.get("landing", Vector3.ZERO)
	check(landing.x > main.player.global_position.x + 4.0 and absf(landing.z - main.player.global_position.z) < 0.6, "Release lands along the current aim direction")
	check(int(gm.get_state().get("packed_count", 0)) == 1, "Release consumes one packed slot")
	check(not restored_light.packed and restored_light.pack_used, "Released enemy cannot be packed again")
	check(release_victim.current_health < victim_health, "Release blast damages nearby enemies at the landing point")
	var after_release_victim_health := release_victim.current_health
	var health_after_release := float(restored_light.current_health)
	_cooldown_ready(main)
	var second_release: Dictionary = main.player.throw_cargo()
	check(second_release.get("performed", false), "Second packed enemy can release separately")
	check(is_equal_approx(float(restored_light.current_health), health_after_release), "Released target does not take duplicate damage")
	check(is_equal_approx(float(release_victim.current_health), after_release_victim_health), "Same blast does not re-hit the same victim later")
	_cooldown_ready(main)
	var empty_release: Dictionary = main.player.throw_cargo()
	check(not empty_release.get("performed", true), "No hidden third release remains")
	check(gm.execute("preset", {"name": "storm"}).get("ok", false), "Replacing the magnet module is allowed")
	check(int(gm.get_state().get("packed_count", 0)) == 0, "Replacing whale modules clears packed load safely")
	check(gm.execute("spawn", {"kind": "light", "count": 1}).get("ok", false), "GM light spawn works")
	var gm_enemy: EnemyDummy = main.gm_enemies[0] as EnemyDummy
	gm_enemy.global_position = main.player.global_position + Vector3(0, 0, -1.5)
	check(not gm.execute("whale_pack", {"target_id": gm_enemy.enemy_id}).get("ok", true), "GM-spawned enemies cannot enter packed save state")
	var invalid_snapshot: Dictionary = main.get_snapshot()
	invalid_snapshot.player.packed_enemy_ids = [light_three.enemy_id, release_victim.enemy_id, heavy.enemy_id]
	check(not main.validate_snapshot(invalid_snapshot), "Snapshot rejects more than two packed ids")
	invalid_snapshot = main.get_snapshot()
	invalid_snapshot.player.packed_enemy_ids = [heavy.enemy_id]
	for state in invalid_snapshot.enemies:
		if state.enemy_id == heavy.enemy_id:
			state.packed = true
			state.dead = true
	check(not main.validate_snapshot(invalid_snapshot), "Snapshot rejects dead and packed conflict")
	var demo: Dictionary = gm.execute("whale_demo")
	check(demo.get("ok", false), "GM whale_demo prepares a playable demo")
	check(not gm.visible, "whale_demo leaves the GM panel closed for direct play")
	check(int(gm.get_state().get("packed_count", 0)) == 0, "whale_demo does not pre-pack targets")
	_cooldown_ready(main)
	var demo_primary: Dictionary = main.player.perform_primary()
	check(demo_primary.get("performed", false) and demo_primary.get("packed", false), "whale_demo can be played through normal primary")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("WHALE PACK FLOW PASS: qualified packing, heavy rejection, save/load, and one-shot release")
	quit(0 if failures.is_empty() else 1)
