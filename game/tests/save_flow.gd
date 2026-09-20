extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var store := M0SaveService.new()
	store.configure("user://test_save_%s" % Time.get_ticks_usec())
	var first := {"version": 2, "cargo": 2, "module": "magnet"}
	var second := {"version": 2, "cargo": 0, "module": "water_cannon"}
	assert(store.save_snapshot(first))
	assert(store.save_snapshot(second))
	assert(store.load_snapshot().module == "water_cannon")
	var broken := FileAccess.open(store.path + ".b", FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	assert(store.load_snapshot().module == "magnet", "Damaged newest checkpoint must recover previous")
	for suffix in [".a", ".b", ".tmp"]:
		DirAccess.remove_absolute(store.path + suffix)
	print("SAVE FLOW PASS: recover intact checkpoint after newest file corruption")
	quit()
