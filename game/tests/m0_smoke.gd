extends SceneTree

const ModuleCatalogScript = preload("res://scripts/module_catalog.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var definitions := ModuleCatalogScript.create_definitions()
	check(definitions.size() == 6, "catalog exposes six M0 definitions")
	for id in ["basic_bucket", "wide_bucket", "water_cannon", "electric_arc", "magnet", "inertia_flywheel"]:
		check(definitions.has(id), "catalog has " + id)
		check(ModuleCatalogScript.validate_definition(definitions[id]), "definition validates " + id)

	var owner := Node3D.new()
	var assembler := LoadoutAssembler.new()
	owner.add_child(assembler)
	assembler.setup(owner, definitions)
	check(assembler.core_id == "basic_bucket", "basic core is installed")
	check(assembler.drive_id.is_empty(), "drive starts empty")
	check(assembler.active_ids == ["", ""], "two function slots start empty")
	check(assembler.stage == 1, "stage starts at one")
	check(assembler.validate_snapshot(assembler.snapshot()), "default loadout snapshot validates")
	check(assembler.restore(assembler.snapshot()), "default loadout restores")
	check(not assembler.validate_snapshot({"version": [], "stage": 1, "core_id": "basic_bucket", "drive_id": "", "active_ids": ["", ""]}), "non-numeric version rejected safely")
	check(not assembler.validate_snapshot({"version": 1, "stage": {}, "core_id": "basic_bucket", "drive_id": "", "active_ids": ["", ""]}), "non-numeric stage rejected safely")
	check(not assembler.validate_snapshot({"version": 1, "stage": 1, "core_id": "basic_bucket", "drive_id": "", "active_ids": [null, ""]}), "non-string slot rejected safely")
	check(assembler.snapshot().get("preview_id", "__missing__") == "__missing__", "snapshot omits preview")

	var base_stats := assembler.get_stats()
	check(is_equal_approx(float(base_stats.power), 14.0), "base power")
	check(is_equal_approx(float(base_stats.reach), 3.0), "base reach")
	check(is_equal_approx(float(base_stats.radius), 1.35), "base radius")
	check(is_equal_approx(float(base_stats.speed), 7.0), "base speed")
	check(int(base_stats.cargo_capacity) == 3, "base cargo")

	check(assembler.set_preview("water_cannon", 0), "preview water in slot zero")
	check(assembler.preview_id == "water_cannon", "preview id is water")
	check(assembler.preview_slot == 0, "preview slot is zero")
	check(assembler.get_preview_summary().contains("水炮"), "preview summary names candidate")
	check(assembler.get_preview_summary().contains("功率"), "preview summary includes stat delta")
	check(assembler.preview_root != null and assembler.preview_root.get_child_count() > 0, "ghost preview exists")
	var before_confirm := assembler.snapshot()
	check(assembler.confirm_preview(), "confirm preview installs water")
	check(assembler.active_ids[0] == "water_cannon", "water installed in slot zero")
	check(assembler.validate_snapshot(assembler.snapshot()), "partial loadout validates with empty drive and slot")
	check(assembler.snapshot() != before_confirm, "confirmed state differs from pre-confirm snapshot")

	check(assembler.set_preview("electric_arc", 1), "preview electric in slot one")
	check(assembler.confirm_preview(1), "confirm electric")
	check(assembler.active_ids == ["water_cannon", "electric_arc"], "two function slots installed")
	check(assembler.has_tag("wet"), "wet tag is active")
	check(assembler.has_tag("electric"), "electric tag is active")

	var stats_with_function := assembler.get_stats()
	check(float(stats_with_function.power) > 14.0, "function power applies")
	check(assembler.set_preview("wide_bucket"), "preview core routes automatically")
	check(assembler.confirm_preview(), "confirm core candidate")
	check(assembler.core_id == "wide_bucket", "wide bucket routed to core")
	check(assembler.active_ids == ["water_cannon", "electric_arc"], "core install does not overwrite function slots")
	check(not assembler.confirm_preview(), "empty preview cannot confirm")
	check(assembler.set_preview("inertia_flywheel"), "preview drive routes automatically")
	check(assembler.confirm_preview(), "confirm drive candidate")
	check(assembler.drive_id == "inertia_flywheel", "flywheel routed to drive")
	check(not assembler.set_preview("wide_bucket", 0), "duplicate core rejected")
	check(assembler.core_id == "wide_bucket", "rejected install preserves core")
	check(not assembler.set_preview("water_cannon", 1), "duplicate function rejected")
	check(assembler.active_ids == ["water_cannon", "electric_arc"], "rejected install preserves functions")

	check(assembler.set_stage(2), "stage two accepted")
	var stage_two := assembler.get_stats()
	check(float(stage_two.reach) > float(stats_with_function.reach), "stage two adds reach")
	check(float(stage_two.speed) < float(stats_with_function.speed), "stage two has speed tradeoff")
	check(assembler.visual_root.find_child("WhaleJawGLB_P05", true, false) != null, "stage two wide bucket uses the G1 whale model")
	check(assembler.visual_root.find_child("Jaw_Upper_Stage02", true, false) != null, "stage two wide bucket has an upper jaw")
	check(assembler.visual_root.find_child("Jaw_Lower_Stage02", true, false) != null, "stage two wide bucket has a lower jaw")
	check(assembler.set_preview("magnet", 0), "stage two ghost preview")
	check(assembler.preview_root.get_child_count() > 0, "ghost remains independent of installed visuals")
	check(assembler.preview_root.get_child_count() > 0, "ghost remains independent of installed visuals")
	var saved := assembler.snapshot()
	check(assembler.validate_snapshot(saved), "valid snapshot validates")
	check(assembler.set_preview("magnet", 0), "magnet preview")
	check(assembler.snapshot() == saved, "preview does not mutate confirmed snapshot")
	check(assembler.restore(saved), "restore valid snapshot")
	check(assembler.preview_id.is_empty(), "restore clears preview")
	check(assembler.core_id == "wide_bucket" and assembler.drive_id == "inertia_flywheel", "restore core and drive")
	check(assembler.active_ids == ["water_cannon", "electric_arc"], "restore function slots")
	check(not assembler.restore({"core_id": "unknown", "active_ids": ["", ""]}), "invalid snapshot rejected")
	check(assembler.core_id == "wide_bucket", "invalid restore preserves old state")
	check(assembler.set_stage(3) == false, "invalid stage rejected")

	owner.free()
	await process_frame
	if failures.is_empty():
		print("M0 smoke: catalog, loadout, preview, routing, stage, visuals, snapshot passed")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)
