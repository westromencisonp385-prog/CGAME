extends SceneTree
## Real renderer capture harness for AI-assisted QA.
## This script deliberately refuses --headless: a zero-size/dummy image is not evidence.

const SCENARIO_ORDER := ["clean", "built", "whale", "preview", "gm", "repair", "effects", "restored"]
const FRAME_SETTLE := 18

var capture_dir := ""
var quit_after_iterations := 240
var use_gm := true
var main_scene: Node
var scenarios: Array[Dictionary] = []
var failures: Array[String] = []
var frame_count := 0
var available_commands: Array[String] = []

func _init() -> void:
	_parse_args()
	call_deferred("_boot")

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--quit-after="):
			quit_after_iterations = maxi(1, int(arg.trim_prefix("--quit-after=")))
		elif arg == "--no-gm":
			use_gm = false
	if capture_dir.is_empty():
		failures.append("missing --capture-dir=<absolute path>")
		capture_dir = "user://wanderburg-capture"
	DirAccess.make_dir_recursive_absolute(capture_dir)

func _boot() -> void:
	# A capture launched with --headless is an invalid visual test, even if it exits 0.
	if DisplayServer.get_name().to_lower() == "headless":
		failures.append("headless renderer refused: capture requires a real window/GPU")
		_write_evidence()
		quit(1)
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		failures.append("could not load res://scenes/main.tscn")
		_write_evidence()
		quit(1)
		return
	main_scene = packed.instantiate()
	root.add_child(main_scene)
	await _wait_iterations(FRAME_SETTLE)
	if use_gm:
		_probe_gm()
	await _capture_scenario("clean", Callable(self, "_scenario_clean"))
	await _capture_scenario("built", Callable(self, "_scenario_built"))
	await _capture_scenario("whale", Callable(self, "_scenario_whale"))
	await _capture_scenario("preview", Callable(self, "_scenario_preview"))
	await _capture_scenario("gm", Callable(self, "_scenario_gm"))
	await _capture_scenario("repair", Callable(self, "_scenario_repair"))
	await _capture_scenario("effects", Callable(self, "_scenario_effects"))
	await _capture_scenario("restored", Callable(self, "_scenario_restored"))
	_write_evidence()
	quit(0 if failures.is_empty() else 1)

func _wait_iterations(iterations: int) -> void:
	var count := mini(iterations, quit_after_iterations)
	for _i in range(count):
		frame_count += 1
		await process_frame

func _gm_node() -> Node:
	if not use_gm or main_scene == null:
		return null
	var candidate: Variant = main_scene.get("gm")
	return candidate as Node

func _probe_gm() -> void:
	var gm := _gm_node()
	if gm == null or not gm.has_method("execute"):
		failures.append("GM unavailable: expected main.gm.execute(command,args)")
		return
	var result: Variant = gm.call("execute", "help", {})
	if result is Dictionary:
		var data: Variant = result.get("data", {})
		if data is Dictionary:
			var commands: Variant = data.get("commands", [])
			if commands is Array:
				for item in commands:
					available_commands.append(str(item))
		elif data is Array:
			for item in data:
				available_commands.append(str(item))
		if not bool(result.get("ok", false)):
			failures.append("GM help failed: %s" % str(result.get("error", "unknown error")))
	else:
		failures.append("GM help returned non-dictionary result")

func _gm_execute(command: String, args: Dictionary = {}) -> Dictionary:
	var gm := _gm_node()
	if gm == null or not gm.has_method("execute"):
		return {"ok": false, "error": "GM unavailable", "data": {}}
	var result: Variant = gm.call("execute", command, args)
	if result is Dictionary:
		return result
	return {"ok": false, "error": "GM command returned non-dictionary", "data": {}}

func _scenario_clean() -> Dictionary:
	# Main starts in a fresh contract; no synthetic image or hidden test scene is used.
	return {"ok": true, "data": {"state": _state_snapshot()}}

func _scenario_built() -> Dictionary:
	if not use_gm:
		return {"skip": true, "reason": "--no-gm"}
	var result := _gm_execute("preset", {"name": "magnet"})
	if not bool(result.get("ok", false)):
		return {"skip": true, "reason": "GM preset unavailable: %s" % str(result.get("error", "unknown"))}
	var stage := _gm_execute("stage", {"value": 2})
	if not bool(stage.get("ok", false)):
		return {"skip": true, "reason": "GM stage 2 unavailable: %s" % str(stage.get("error", "unknown"))}
	await _wait_iterations(FRAME_SETTLE)
	return {"ok": true, "data": {"gm": result, "stage": stage, "state": _state_snapshot()}}

func _scenario_preview() -> Dictionary:
	if not use_gm:
		return {"skip": true, "reason": "--no-gm"}
	# Preview is only captured when GM advertises those public commands; no guessed fallback.
	if not available_commands.has("preview"):
		return {"skip": true, "reason": "GM help did not advertise preview"}
	var open := _gm_execute("garage", {"open": true})
	if not bool(open.get("ok", false)):
		return {"skip": true, "reason": "GM garage unavailable: %s" % str(open.get("error", "unknown"))}
	var preview := _gm_execute("preview", {"id": "water_cannon", "slot": 0})
	if not bool(preview.get("ok", false)):
		return {"skip": true, "reason": "GM preview unavailable: %s" % str(preview.get("error", "unknown"))}
	await _wait_iterations(FRAME_SETTLE)
	return {"ok": true, "data": {"open": open, "preview": preview, "state": _state_snapshot()}}

func _scenario_whale() -> Dictionary:
	if not use_gm:
		return {"skip": true, "reason": "--no-gm"}
	var demo := _gm_execute("whale_demo", {})
	if not bool(demo.get("ok", false)):
		return {"skip": true, "reason": "GM whale demo unavailable: %s" % str(demo.get("error", "unknown"))}
	var player: M0VehicleController = main_scene.get("player") as M0VehicleController
	if player == null:
		return {"skip": true, "reason": "player unavailable"}
	player.aim_direction = Vector3(0, 0, -1)
	player.primary_cooldown = 0.0
	var result: Dictionary = player.perform_primary()
	if not bool(result.get("packed", false)):
		return {"skip": true, "reason": "normal primary did not pack the demo target"}
	await _wait_iterations(FRAME_SETTLE)
	return {"ok": true, "data": {"demo": demo, "primary": result, "state": _state_snapshot()}}

func _scenario_gm() -> Dictionary:
	if not use_gm:
		return {"skip": true, "reason": "--no-gm"}
	var panel_command := ""
	if available_commands.has("set_panel_visible"):
		panel_command = "set_panel_visible"
	elif available_commands.has("toggle_panel"):
		panel_command = "toggle_panel"
	elif available_commands.has("panel"):
		panel_command = "panel"
	if panel_command.is_empty():
		return {"skip": true, "reason": "GM help did not advertise a panel visibility command"}
	var panel_args := {"open": true}
	if panel_command == "toggle_panel":
		panel_args = {}
	var panel := _gm_execute(panel_command, panel_args)
	if not bool(panel.get("ok", false)):
		return {"skip": true, "reason": "GM panel command unavailable: %s" % str(panel.get("error", "unknown"))}
	var result := _gm_execute("status", {})
	if not bool(result.get("ok", false)):
		return {"skip": true, "reason": "GM status unavailable: %s" % str(result.get("error", "unknown"))}
	await _wait_iterations(FRAME_SETTLE)
	return {"ok": true, "data": {"panel": panel, "gm": result, "state": _state_snapshot()}}

func _scenario_repair() -> Dictionary:
	if not use_gm:
		return {"skip": true, "reason": "--no-gm"}
	var reset := _gm_execute("reset", {})
	if not bool(reset.get("ok", false)):
		return {"skip": true, "reason": "GM reset unavailable: %s" % str(reset.get("error", "unknown"))}
	var result := _gm_execute("repair", {})
	if not bool(result.get("ok", false)):
		return {"skip": true, "reason": "GM repair unavailable: %s" % str(result.get("error", "unknown"))}
	await _wait_iterations(FRAME_SETTLE)
	return {"ok": true, "data": {"reset": reset, "gm": result, "state": _state_snapshot()}}

func _scenario_effects() -> Dictionary:
	if not use_gm:
		return {"skip": true, "reason": "--no-gm"}
	var result := _gm_execute("vfx", {"enabled": true})
	if not bool(result.get("ok", false)):
		return {"skip": true, "reason": "GM vfx unavailable: %s" % str(result.get("error", "unknown"))}
	await _wait_iterations(FRAME_SETTLE)
	return {"ok": true, "data": {"gm": result, "state": _state_snapshot()}}

func _scenario_restored() -> Dictionary:
	if not use_gm:
		return {"skip": true, "reason": "--no-gm"}
	var saved := _gm_execute("save", {})
	if not bool(saved.get("ok", false)):
		return {"skip": true, "reason": "GM save unavailable: %s" % str(saved.get("error", "unknown"))}
	var changed := _gm_execute("preset", {"name": "ram"})
	if not bool(changed.get("ok", false)):
		return {"skip": true, "reason": "GM preset unavailable: %s" % str(changed.get("error", "unknown"))}
	var restored := _gm_execute("load", {})
	if not bool(restored.get("ok", false)):
		return {"skip": true, "reason": "GM load unavailable: %s" % str(restored.get("error", "unknown"))}
	await _wait_iterations(FRAME_SETTLE)
	return {"ok": true, "data": {"saved": saved, "changed": changed, "restored": restored, "state": _state_snapshot()}}

func _capture_scenario(name: String, action: Callable) -> void:
	var result: Dictionary = await action.call()
	var status := "captured"
	if bool(result.get("skip", false)):
		status = "skipped"
		failures.append("scenario %s skipped: %s" % [name, str(result.get("reason", "unknown"))])
	elif not bool(result.get("ok", false)):
		status = "failed"
		failures.append("scenario %s failed: %s" % [name, str(result.get("reason", "unknown"))])
	await _wait_iterations(FRAME_SETTLE)
	var filename := "%s.png" % name
	var output := capture_dir.path_join(filename)
	var saved := false
	if status == "captured":
		await RenderingServer.frame_post_draw
		var texture := get_root().get_texture() if get_root() != null else null
		var image := texture.get_image() if texture != null else null
		if image != null and image.get_width() > 0 and image.get_height() > 0:
			var error := image.save_png(output)
			saved = error == OK
			if not saved:
				failures.append("scenario %s could not save PNG (%s)" % [name, str(error)])
		else:
			failures.append("scenario %s returned an empty viewport image" % name)
		status = "captured" if saved else "failed"
	elif status == "skipped":
		output = ""
	scenarios.append({"name": name, "status": status, "screenshot": output, "frames": frame_count, "result": result})

func _state_snapshot() -> Dictionary:
	if main_scene == null:
		return {}
	var state: Dictionary = {}
	var gm := _gm_node()
	if gm != null and gm.has_method("get_state"):
		var result: Variant = gm.call("get_state")
		if result is Dictionary:
			state["gm"] = result
	if main_scene.has_method("get_snapshot"):
		state["main"] = main_scene.call("get_snapshot")
	return state

func _write_evidence() -> void:
	var renderer := RenderingServer.get_current_rendering_method() if RenderingServer.has_method("get_current_rendering_method") else DisplayServer.get_name()
	var evidence := {
		"engine": Engine.get_version_info(),
		"commit": "",
		"renderer": renderer,
		"gpu": RenderingServer.get_video_adapter_name(),
		"scenario": scenarios,
		"frames": frame_count,
		"screenshots": scenarios.map(func(item: Dictionary): return item.get("screenshot", "")),
		"logs": [],
		"passed": failures.is_empty(),
		"failures": failures,
		"gm_commands": available_commands,
		"capture_dir": capture_dir
	}
	var path := capture_dir.path_join("runtime-evidence.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(evidence, "  "))
		file.close()
	else:
		failures.append("could not write evidence JSON: %s" % path)
