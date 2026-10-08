class_name BiomeKeyPickup
extends Node3D

## C7 钥匙拾取物（对齐 DesertKey/SwampKey：RequireComponent(Artifact)——钥匙即神器）。
## 玩家接触即授予神器 + 群系永久解锁；reward 视觉与主反馈由 main 接线。

signal picked_up(key_id: String)

var key_id := ""
var is_collected := false
var visual_root: Node3D
var _spin_time := 0.0

const KEY_COLORS := {
	"key_desert": Color("#f2c85c"),
	"key_swamp": Color("#8fb573"),
}

func configure(new_key_id: String, at: Vector3) -> BiomeKeyPickup:
	key_id = new_key_id
	position = at
	return self

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	visual_root = ProceduralVisuals.load_visual(
		"biome_key_%s.tscn" % ("desert" if key_id == BiomeSystem.KEY_DESERT else "swamp"),
		func(): return ProceduralVisuals.build_key(KEY_COLORS.get(key_id, Color.WHITE)))
	visual_root.name = "KeyVisual"
	add_child(visual_root)

func _process(delta: float) -> void:
	if is_collected:
		return
	_spin_time += delta
	if visual_root != null:
		visual_root.rotation.y = _spin_time * 1.6
		visual_root.position.y = sin(_spin_time * 2.2) * 0.08

func try_collect() -> bool:
	if is_collected:
		return false
	is_collected = true
	visible = false
	picked_up.emit(key_id)
	return true
