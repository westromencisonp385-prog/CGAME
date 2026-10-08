class_name BiomeGate
extends Node3D

## C7 群系锁门（对齐 BiomeLock 确证签名：checkForDesertKey/checkForSwampKey → Unlock()）。
## 纯逻辑态：required_key/unlocked；视觉由 _build_visual 构建；
## 碰撞用实物 StaticBody3D，玩家靠近且持钥匙即解锁开路。

signal unlocked(gate: BiomeGate)
signal locked_feedback(gate: BiomeGate)

var gate_id := ""
var required_key := ""
var is_unlocked := false
var visual_root: Node3D
var gate_rig: ProceduralRig

func _play_open_anim() -> void:
	gate_rig.set_process(false)
	var tw := create_tween()
	for door in gate_rig.shields:
		tw.parallel().tween_property(door, "rotation:y", door.rotation.y + deg_to_rad(100.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.15)
	tw.tween_property(visual_root, "position:y", -4.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): visual_root.visible = false)
var player: Node3D
var biome_system_ref: BiomeSystem

func configure(new_id: String, key: String, at: Vector3) -> BiomeGate:
	gate_id = new_id
	required_key = key
	position = at
	return self

func _process(_delta: float) -> void:
	if is_unlocked or player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= 3.2:
		var holding: Array = biome_system_ref.keys.keys() if biome_system_ref != null else []
		try_unlock(holding)

func _ready() -> void:
	_build_visual()
	_build_collision()

func _build_visual() -> void:
	var scene_file := "biome_gate_desert.tscn" if required_key == BiomeSystem.KEY_DESERT else "biome_gate_swamp.tscn"
	var title := "荒漠之门" if required_key == BiomeSystem.KEY_DESERT else "沼泽之门"
	if ProceduralRig.has_rig("biome_gate") or FormalModelLibrary.has_model("biome_gate"):
		visual_root = Node3D.new()
		visual_root.name = "GateVisual"
		add_child(visual_root)
		gate_rig = ProceduralRig.attach(visual_root, "biome_gate")
		if gate_rig != null:
			gate_rig.name = "GateFormalModel"
		else:
			FormalModelLibrary.attach(visual_root, "biome_gate", "GateFormalModel")
		var label := Label3D.new()
		label.text = title
		label.font_size = 52
		label.pixel_size = 0.011
		label.outline_size = 5
		label.position = Vector3(0, 3.4, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		visual_root.add_child(label)
		return
	visual_root = ProceduralVisuals.load_visual(scene_file,
		func(): return ProceduralVisuals.build_gate(Color("#d9a441") if required_key == BiomeSystem.KEY_DESERT else Color("#7a9d54"), title))
	visual_root.name = "GateVisual"
	add_child(visual_root)

func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "GateBody"
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.4, 2.4, 0.6)
	collider.shape = shape
	collider.position = Vector3(0, 1.2, 0)
	body.add_child(collider)
	add_child(body)
	if body.find_children("*", "PhysicsBody3D", false).is_empty():
		pass

func try_unlock(holding_keys: Array) -> bool:
	if is_unlocked:
		return true
	if holding_keys.has(required_key):
		is_unlocked = true
		if visual_root != null:
			if gate_rig != null and is_inside_tree():
				_play_open_anim()
			else:
				visual_root.visible = false
		_disable_collision()
		unlocked.emit(self)
		return true
	locked_feedback.emit(self)
	return false

func _disable_collision() -> void:
	for body in find_children("*", "StaticBody3D", true, false):
		for collider in body.find_children("*", "CollisionShape3D", true, false):
			(collider as CollisionShape3D).disabled = true
