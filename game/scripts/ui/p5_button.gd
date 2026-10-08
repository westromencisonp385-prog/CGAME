class_name P5Button
extends Button

## C14 P5 风格按钮：底层 P5Plate 程序绘制，文字在上。
## hover（参考 P5S 菜单选中项）：
##   1. 色块由石油蓝翻成番茄红并整体放大 6% + 歪 -2°（弹出过冲）
##   2. 背后骨白错位板拉开
##   3. 左侧红色三角指针从左滑入
##   4. 文字由骨白变墨黑字重不变，向右推 6px
## press：下压 + 弹性回位；focus 与 hover 等价（手柄可用）。

const P5_RED := Color("#D9412B")
const P5_BLUE := Color("#23394A")
const P5_BONE := Color("#EFE3C8")
const P5_INK := Color("#1B1B1D")

var plate: P5Plate
var pointer: Polygon2D
var label_offset := 0.0
var _tw: Tween
var base_face := P5_BLUE
var hover_face := P5_RED

func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_constant_override("h_separation", 8)
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, _pad())
	add_theme_color_override("font_color", P5_BONE)
	add_theme_color_override("font_hover_color", P5_INK)
	add_theme_color_override("font_focus_color", P5_INK)
	add_theme_color_override("font_pressed_color", P5_INK)
	add_theme_color_override("font_hover_pressed_color", P5_INK)
	add_theme_color_override("font_disabled_color", Color(P5_BONE, 0.4))

func _pad() -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _ready() -> void:
	plate = P5Plate.new()
	plate.face_color = base_face
	plate.accent_color = P5_BONE
	plate.accent_offset = Vector2(-6, 5)
	plate.shadow_offset = Vector2(5, 6)
	plate.skew = 0.28
	plate.cut = 10.0
	plate.show_facet = false
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.show_behind_parent = true
	add_child(plate)
	move_child(plate, 0)
	pointer = Polygon2D.new()
	pointer.polygon = PackedVector2Array([Vector2(0, -9), Vector2(16, 0), Vector2(0, 9)])
	pointer.color = P5_RED
	pointer.visible = false
	add_child(pointer)
	resized.connect(_layout)
	_layout()
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	focus_entered.connect(_on_enter)
	focus_exited.connect(_on_focus_lost)
	button_down.connect(plate.press)

func _on_enter() -> void:
	_set_hot(true)

func _on_exit() -> void:
	if not has_focus():
		_set_hot(false)

func _on_focus_lost() -> void:
	_set_hot(false)

func _set_text_push(v: float) -> void:
	label_offset = v
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		(get_theme_stylebox(s) as StyleBoxEmpty).content_margin_left = 30.0 + v
	queue_redraw()

func _layout() -> void:
	if plate == null:
		return
	plate.position = Vector2.ZERO
	plate.size = size
	pivot_offset = size * 0.5
	pointer.position = Vector2(-20, size.y * 0.5)

func _set_hot(on: bool) -> void:
	if disabled:
		on = false
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	plate.set_hover(on)
	_tw.tween_property(plate, "face_color", hover_face if on else base_face, 0.10)
	_tw.tween_property(self, "scale", Vector2.ONE * (1.06 if on else 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "rotation", deg_to_rad(-2.0 if on else 0.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pointer.visible = true
	_tw.tween_property(pointer, "position:x", -4.0 if on else -26.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_property(pointer, "modulate:a", 1.0 if on else 0.0, 0.12)
	_tw.tween_method(_set_text_push, label_offset, 8.0 if on else 0.0, 0.14)
	plate.queue_redraw()
