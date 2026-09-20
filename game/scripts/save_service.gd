class_name M0SaveService
extends RefCounted

var path := "user://m0_checkpoint"

func configure(save_path: String) -> void:
	path = save_path

func save_snapshot(data: Dictionary) -> bool:
	var a := _read(path + ".a")
	var b := _read(path + ".b")
	var sequence := maxi(int(a.get("sequence", 0)), int(b.get("sequence", 0))) + 1
	var destination := path + (".a" if sequence % 2 == 1 else ".b")
	var payload := JSON.stringify(data)
	var envelope := {"format": 1, "sequence": sequence, "payload": payload, "checksum": payload.sha256_text()}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(envelope))
	file.flush()
	file.close()
	if _read(path + ".tmp").is_empty():
		return false
	# Only the inactive slot is replaced. The previous intact checkpoint survives.
	if FileAccess.file_exists(destination) and DirAccess.remove_absolute(destination) != OK:
		return false
	return DirAccess.rename_absolute(path + ".tmp", destination) == OK

func load_snapshot() -> Dictionary:
	var a := _read(path + ".a")
	var b := _read(path + ".b")
	var newest: Dictionary = a if int(a.get("sequence", -1)) >= int(b.get("sequence", -1)) else b
	return newest.get("data", {})

func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		return {}
	var envelope: Dictionary = parser.data
	if envelope.get("format") != 1 or not envelope.get("payload") is String or not envelope.get("sequence") is float and not envelope.get("sequence") is int:
		return {}
	var payload: String = envelope.payload
	if payload.sha256_text() != envelope.get("checksum"):
		return {}
	if parser.parse(payload) != OK or not parser.data is Dictionary:
		return {}
	return {"sequence": int(envelope.sequence), "data": parser.data}
