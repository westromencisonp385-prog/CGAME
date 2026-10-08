class_name P5Title
extends Control

## C14 程序化大字标题（替代 v1 的 AI 生成 WARNING/CLEAR 位图，那批有毛边与噪声）。
## 构成：倾斜红色长板（P5Plate）+ 墨黑错位底 + Anton 大字（骨白，逐字轻微错位，非随机剪报）。
## 动效（参考 P5S 菜单切换）：长板从左向右「刷」出 → 文字逐字由大缩入 → 停留 → 整体向右斜切飞出。

var plate: P5Plate
var letters: Array[Label] = []
var text := ""
var font_size := 96

func setup(t: String, face := Color("#D9412B"), accent := Color("#EFE3C8"), size_px := 96) -> P5Title:
	text = t
	font_size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in get_children():
		remove_child(c)
		c.queue_free()
	letters.clear()
	plate = P5Plate.new()
	plate.face_color = face
	plate.accent_color = accent
	plate.outline_color = Color("#1B1B1D")
	plate.skew = 0.18
	plate.cut = 22.0
	plate.tab_cut = 18.0
	plate.accent_offset = Vector2(-14, 12)
	plate.shadow_offset = Vector2(12, 14)
	add_child(plate)
	var row := HBoxContainer.new()
	row.name = "Letters"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for i in t.length():
		var l := Label.new()
		l.text = t[i]
		l.add_theme_font_override("font", P5Theme.title_font())
		l.add_theme_font_size_override("font_size", size_px)
		l.add_theme_color_override("font_color", Color("#EFE3C8") if i % 4 != 2 else Color("#1B1B1D"))
		l.add_theme_color_override("font_outline_color", Color("#1B1B1D"))
		l.add_theme_constant_override("outline_size", 10 if i % 4 != 2 else 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 有规律的高低错位（不是随机）：保持 P5 的节奏感但不乱
		l.position.y = [0, -6, 4, -2][i % 4]
		row.add_child(l)
		letters.append(l)
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	_layout()
	return self

func _layout() -> void:
	if plate == null:
		return
	plate.position = Vector2(0, size.y * 0.18)
	plate.size = Vector2(size.x, size.y * 0.64)
	var row := get_node_or_null("Letters") as Control
	if row != null:
		row.position = Vector2(0, 0)
		row.size = size

## 播放：刷出 → 逐字缩入 → 停留 hold 秒 → 飞出
func play(hold := 1.0) -> Tween:
	visible = true
	modulate.a = 1.0
	rotation = deg_to_rad(-5)
	pivot_offset = size * 0.5
	var home: Vector2 = get_meta("home", position)
	set_meta("home", home)
	position = home
	plate.reveal_t = 0.0
	for l in letters:
		l.scale = Vector2.ONE * 2.2
		l.modulate.a = 0.0
		l.pivot_offset = l.size * 0.5
	var tw := create_tween()
	tw.tween_method(plate.set_reveal, 0.0, 1.0, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for i in letters.size():
		var l := letters[i]
		var st := tw.parallel()
		st.tween_property(l, "scale", Vector2.ONE, 0.16).set_delay(0.08 + i * 0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(l, "modulate:a", 1.0, 0.06).set_delay(0.08 + i * 0.03)
	tw.tween_interval(hold)
	tw.set_parallel(true)
	tw.tween_property(self, "position:x", home.x + size.x * 1.6, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", deg_to_rad(4), 0.26)
	tw.set_parallel(false)
	tw.tween_callback(func(): visible = false)
	return tw
