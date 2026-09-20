extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

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
	var light: Node = main.enemies[0]
	var heavy: Node = main.enemies[4]
	light.global_position = main.player.global_position + Vector3(0, 0, -2.0)
	heavy.global_position = main.player.global_position + Vector3(2.0, 0, -2.0)
	main.player.aim_direction = Vector3(0, 0, -1)
	var pack_result: Dictionary = gm.execute("whale_pack", {"target_id": light.enemy_id})
	check(pack_result.get("ok", false), "Qualified light enemy can be packed through GM seam")
	check(light.packed, "Packed enemy enters packed state")
	check(not light.visible, "Packed enemy is hidden from the combat scene")
	check(int(gm.get_state().get("packed_count", 0)) == 1, "Packed count is externally observable")
	var heavy_pack: Dictionary = gm.execute("whale_pack", {"target_id": heavy.enemy_id})
	check(not heavy_pack.get("ok", true), "Heavy enemy is rejected by whale packing")
	check(not heavy.packed, "Heavy enemy remains unpacked")
	var save_result: Dictionary = gm.execute("save")
	check(save_result.get("ok", false), "GM save accepts packed state")
	var packed_snapshot_ids: Array = main.player.get_snapshot().get("packed_enemy_ids", [])
	check(packed_snapshot_ids == [light.enemy_id], "Player snapshot records the packed target")
	check(gm.execute("reset").get("ok", false), "Reset clears the live packed state")
	check(int(gm.get_state().get("packed_count", 0)) == 0, "Reset clears packed count")
	check(gm.execute("load").get("ok", false), "GM load restores packed state")
	check(int(gm.get_state().get("packed_count", 0)) == 1, "Load restores packed count")
	var restored_light: EnemyDummy = main.enemies[0] as EnemyDummy
	check(restored_light.packed, "Load restores the packed enemy flag")
	var release_result: Dictionary = gm.execute("whale_throw")
	check(release_result.get("ok", false), "Packed enemy can be released once")
	check(int(gm.get_state().get("packed_count", 0)) == 0, "Release consumes the packed slot")
	check(not restored_light.packed and restored_light.pack_used, "Released enemy cannot be packed again")
	check(bool(release_result.get("data", {}).get("hit", false)), "Release resolves as a combat hit")
	var health_after_release := float(restored_light.current_health)
	var second_release: Dictionary = gm.execute("whale_throw")
	check(not second_release.get("ok", true), "A released target cannot be thrown twice")
	check(is_equal_approx(float(restored_light.current_health), health_after_release), "Repeated release does not duplicate damage")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("WHALE PACK FLOW PASS: qualified packing, heavy rejection, save/load, and one-shot release")
	quit(0 if failures.is_empty() else 1)
