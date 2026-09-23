extends SceneTree
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.simulation_enabled = false
	main.player.set_physics_process(false)
	main.player.position = Vector3(-5, 0.5, 5)
	main.player.aim_direction = Vector3.FORWARD
	main.player.gameplay_enabled = true
	var before: Dictionary = main.get_snapshot()
	# G1 presentation contract: readable silhouette/scenery exists without becoming
	# a second gameplay authority. These nodes are purely visual children.
	check(main.player.visual_root != null and main.player.visual_root.has_node("ChassisSafetyPanel"), "Styled vehicle silhouette is present")
	check(main.world.get_node_or_null("DryRiverAndBanks") != null and main.world.get_node_or_null("EdgeLandmarks") != null, "River and landmark presentation layer is present")
	var route_before: Node3D = main.world.get_node_or_null("RouteBeforeRepair")
	var route_after: Node3D = main.world.get_node_or_null("RouteAfterRepair")
	check(route_before != null and route_after != null, "Repair route landmarks are present")
	check(route_before != null and route_before.visible and route_after != null and not route_after.visible, "Unrepaired route reads as blocked")
	main.world.green_zone.show()
	main.world._process(0.0)
	check(route_before != null and not route_before.visible and route_after != null and route_after.visible, "Repair route reads as a usable shortcut")
	main.world.set_effects_enabled(true)
	var with_effects: Dictionary = main.player.perform_primary()
	var first: Dictionary = main.get_snapshot()
	check(main.restore_snapshot(before), "Reference state restores")
	main.player.gameplay_enabled = true
	main.world.set_effects_enabled(false)
	var without_effects: Dictionary = main.player.perform_primary()
	var second: Dictionary = main.get_snapshot()
	check(with_effects == without_effects, "Disabling VFX preserves hit and harvest results")
	check(first.targets == second.targets and first.player.cargo == second.player.cargo, "VFX settings do not alter resources or target health")
	main.world.set_effects_enabled(true)
	for index in range(40):
		main.world.present_effect("hit", Vector3.ZERO, Vector3(index * 0.1, 0, -2))
	var effects: Dictionary = main.world.effects.get_status()
	check(effects.live_effects <= effects.burst_limit, "Concurrent bursts stay within budget")
	check(effects.dust_texture_loaded, "Generated dust texture is imported and used by native particles")
	main.world.set_effects_enabled(false)
	check(main.world.effects.get_status().live_effects == 0, "VFX toggle releases active presentation objects after budget stress")
	main.world.set_effects_enabled(true)
	main.world.present_effect("whale_pack", Vector3.ZERO, Vector3(0, 0, -2))
	main.world.present_effect("whale_release", Vector3.ZERO, Vector3(0, 0, -5))
	main.world.present_effect("repair", Vector3(6, 0, -7), Vector3(6, 0, -7))
	effects = main.world.effects.get_status()
	check(effects.live_effects > 0 and effects.live_effects <= effects.burst_limit, "Whale and repair presentation events stay bounded")
	main.world.set_effects_enabled(false)
	check(main.world.effects.get_status().live_effects == 0, "VFX toggle releases active presentation objects")
	paused = false
	main.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("PRESENTATION FLOW PASS: identical gameplay, generated texture loaded, bounded effects")
	quit(0 if failures.is_empty() else 1)
