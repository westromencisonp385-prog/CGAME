extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var vehicle := M0VehicleController.new()
	arena.add_child(vehicle)
	vehicle.set_physics_process(false)
	vehicle.aim_direction = Vector3.RIGHT
	vehicle.primary_cooldown = 0.2
	vehicle.throw_cooldown = 0.3
	vehicle.dash_cooldown = 1.0
	var before := vehicle.get_snapshot()
	vehicle.receive_damage(200.0)
	check(not vehicle.gameplay_enabled, "A destroyed engineering vehicle freezes gameplay")
	check(not bool(vehicle.perform_primary().get("performed", true)), "A destroyed vehicle cannot use the tool")
	check(vehicle.restore_snapshot(before), "A valid vehicle snapshot restores")
	check(vehicle.aim_direction == Vector3.RIGHT, "Restore preserves the tool direction")
	check(vehicle.primary_cooldown == 0.2 and vehicle.throw_cooldown == 0.3 and vehicle.dash_cooldown == 1.0, "Restore preserves cooldown progress")
	check(vehicle.gameplay_enabled, "A living snapshot resumes the vehicle")
	vehicle.primary_cooldown = 0.0
	vehicle.aim_direction = Vector3.FORWARD
	var rubble := EngineeringTarget.new().configure("rubble", "soft", 200.0, Vector3(0, 0.6, -2.0))
	arena.add_child(rubble)
	var first_hit := vehicle.perform_primary()
	check(bool(first_hit.get("performed", false)), "The empty bucket still attacks")
	check(vehicle.cargo == 0, "Chipping an intact object does not mint repeated cargo")
	while rubble.current_hp > 0.0:
		vehicle.primary_cooldown = 0.0
		vehicle.perform_primary()
	check(vehicle.cargo == 1, "Consuming one rubble resource awards one cargo")
	vehicle.primary_cooldown = 0.0
	vehicle.perform_primary()
	check(vehicle.cargo == 1, "A spent rubble resource cannot be collected twice")
	var assembler := LoadoutAssembler.new()
	vehicle.add_child(assembler)
	assembler.setup(vehicle, ModuleCatalog.create_definitions())
	vehicle.setup(assembler, null)
	check(assembler.set_preview("water_cannon", 0) and assembler.confirm_preview(), "Water installs in first function socket")
	check(assembler.set_preview("electric_arc", 1) and assembler.confirm_preview(), "Arc installs alongside water")
	check(assembler.set_preview("inertia_flywheel") and assembler.confirm_preview(), "Flywheel installs on the drive interface")
	vehicle.record_drive_displacement(5.0)
	check(vehicle.charge > 0.0, "Flywheel charge comes from real displacement")
	var charged := vehicle.charge
	vehicle.reset_vehicle(Vector3(3, 0.5, 3))
	check(vehicle.charge == 0.0 and vehicle.health == 100.0 and vehicle.gameplay_enabled, "Retry reset clears transient vehicle state")
	vehicle.charge = charged
	var near := EnemyDummy.new().configure("near", "light", 300.0, 0.0, Vector3(0, 0.7, -2.0))
	var outside_swing := EnemyDummy.new().configure("chain", "light", 300.0, 0.0, Vector3(2.8, 0.7, -4.5))
	arena.add_child(near)
	arena.add_child(outside_swing)
	near.apply_wet()
	outside_swing.apply_wet()
	vehicle.global_position = Vector3(0, 0.5, 0)
	vehicle.primary_cooldown = 0.0
	var combo := vehicle.perform_primary()
	check(int(combo.get("chain_hits", 0)) >= 1, "Wet targets support a real arc jump beyond the bucket strike")
	check(outside_swing.current_health < 300.0, "A chained target receives damage")
	near.wet_time = 0.0
	outside_swing.wet_time = 0.0
	vehicle.primary_cooldown = 0.0
	var dry := vehicle.perform_primary()
	check(int(dry.get("chain_hits", 0)) == 0, "Water laid this strike cannot immediately create a same-strike recursive chain")
	var heavy := EnemyDummy.new().configure("heavy", "heavy", 100.0, 0.0, Vector3(0, 0.7, -3.0))
	arena.add_child(heavy)
	var heavy_position := heavy.global_position
	check(not heavy.pull_toward(Vector3.ZERO, 1.0) and heavy.global_position == heavy_position, "Heavy targets resist the magnet")
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS combat_flow: death freeze and snapshot cooldown/aim")
	quit(0 if failures.is_empty() else 1)
