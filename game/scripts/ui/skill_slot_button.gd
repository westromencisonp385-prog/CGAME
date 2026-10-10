class_name SkillSlotButton
extends Button

## C23 技能槽 = 真按钮：鼠标点击施放、悬停高亮放大、按下下压回弹；数字键 1-4 同效。
## 不抢键盘焦点（战斗中空格是攻击键，焦点按钮会被空格误触发）。

var plate: P5Plate
var icon_rect: TextureRect
var cd_mask: ColorRect
var key_tag: Control
var slot_index := 0
var _tw: Tween

func setup(index: int, icon_id: String, accent: Color) -> void:
	slot_index = index
	name = "SkillSlot%d" % (index + 1)
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(72, 72)
	size = Vector2(72, 72)
	pivot_offset = Vector2(36, 36)
	rotation = deg_to_rad(-4.0)
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	plate = P5Plate.new()
	plate.size = Vector2(72, 72)
	plate.face_color = P5Theme.BLUE
	plate.accent_color = accent
	plate.skew = 0.12
	plate.cut = 12.0
	plate.accent_offset = Vector2(-5, 5)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	icon_rect = P5Theme.icon_rect(icon_id, 52)
	icon_rect.position = Vector2(10, 10)
	add_child(icon_rect)
	cd_mask = ColorRect.new()
	cd_mask.color = Color(P5Theme.INK, 0.66)
	cd_mask.position = Vector2(8, 64)
	cd_mask.size = Vector2(58, 0)
	cd_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cd_mask)
	key_tag = P5Theme.ransom_label(M0Input.SKILL_LABELS[index] if index < M0Input.SKILL_LABELS.size() else str(index + 1), 15, 0, P5Theme.INK)
	key_tag.position = Vector2(-10, -12)
	add_child(key_tag)
	mouse_entered.connect(func(): _hot(true))
	mouse_exited.connect(func(): _hot(false))
	button_down.connect(func():
		plate.press()
		_bump(0.92))
	button_up.connect(func(): _bump(1.08 if is_hovered() else 1.0))

func _hot(on: bool) -> void:
	plate.set_hover(on)
	plate.face_color = P5Theme.RED if on else P5Theme.BLUE
	plate.queue_redraw()
	_bump(1.08 if on else 1.0)

func _bump(s: float) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.set_ignore_time_scale(true)
	_tw.tween_property(self, "scale", Vector2.ONE * s, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## r = 剩余冷却比例 0..1
func set_cooldown(r: float) -> void:
	cd_mask.size.y = 56.0 * r
	cd_mask.position.y = 8.0 + 56.0 * (1.0 - r)
