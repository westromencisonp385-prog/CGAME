class_name CombatHUD
extends Control

## C17 战斗 HUD（P5 v2 视觉语言：切面板 + 番茄红强调 + 骨白字）：
##   Boss 血条   顶部居中：名字斜签 + 三段阶段刻度 + 红色血量 + 骨白「延迟扣血」尾巴（受击后 0.35s 才追上）
##   状态图标    左上状态牌下方：当前状态的色块签（灼烧/减速/眩晕/护盾/氮气/过热…）+ 剩余时间条
##   热量警告    热量 > 75% 时状态牌下出现闪烁「HEAT」签
##   任务追踪    右上工单下方：3 条进度最高的未完成任务（进度条）
##   招式喊话    Boss 出招 / 完美闪避时，屏幕上方斜签快速砸入再飞出
##   技能名      技能槽下方显示当前装备的模块名

var main: Node
var boss_root: Control
var boss_name: Label
var boss_fill: P5Plate
var boss_trail: P5Plate
var boss_pips: Array = []
var _trail_ratio := 1.0
var _shown_ratio := 1.0
var _trail_delay := 0.0
var status_row: HBoxContainer
var heat_tag: Control
var quest_box: VBoxContainer
var quest_rows: Array = []
var callout_holder: Control
var skill_names: Array = []
const BAR_W := 560.0

func setup(owner: Node) -> void:
	main = owner
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = P5Theme.build()
	_build_boss_bar()
	_build_status_row()
	_build_quests()
	callout_holder = Control.new()
	callout_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	callout_holder.position = Vector2(470, 118)
	add_child(callout_holder)

func _build_boss_bar() -> void:
	boss_root = Control.new()
	boss_root.position = Vector2(360, 34)
	boss_root.size = Vector2(BAR_W + 40, 70)
	boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_root.visible = false
	add_child(boss_root)
	var back := P5Plate.new()
	back.position = Vector2(0, 26)
	back.size = Vector2(BAR_W + 24, 30)
	back.face_color = P5Theme.INK
	back.accent_color = P5Theme.RED
	back.skew = 0.4
	back.cut = 0.0
	back.show_facet = false
	boss_root.add_child(back)
	boss_trail = P5Plate.new()
	boss_trail.position = Vector2(14, 32)
	boss_trail.size = Vector2(BAR_W, 18)
	boss_trail.face_color = P5Theme.BONE
	boss_trail.show_accent = false
	boss_trail.show_facet = false
	boss_trail.shadow_offset = Vector2.ZERO
	boss_trail.skew = 0.4
	boss_trail.cut = 0.0
	boss_trail.outline_width = 0.0
	boss_root.add_child(boss_trail)
	boss_fill = P5Plate.new()
	boss_fill.position = Vector2(14, 32)
	boss_fill.size = Vector2(BAR_W, 18)
	boss_fill.face_color = P5Theme.RED
	boss_fill.show_accent = false
	boss_fill.show_facet = false
	boss_fill.shadow_offset = Vector2.ZERO
	boss_fill.skew = 0.4
	boss_fill.cut = 0.0
	boss_fill.outline_width = 0.0
	boss_root.add_child(boss_fill)
	for k in [0.66, 0.33]:
		var pip := ColorRect.new()
		pip.color = P5Theme.INK
		pip.size = Vector2(4, 24)
		pip.position = Vector2(14 + BAR_W * k, 29)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_root.add_child(pip)
		boss_pips.append(pip)
	var tag := P5Theme.ransom_label("BOSS", 20, 0, P5Theme.RED)
	tag.position = Vector2(-8, -4)
	boss_root.add_child(tag)
	boss_name = Label.new()
	boss_name.add_theme_font_size_override("font_size", 20)
	boss_name.add_theme_color_override("font_color", P5Theme.BONE)
	boss_name.add_theme_color_override("font_outline_color", P5Theme.INK)
	boss_name.add_theme_constant_override("outline_size", 8)
	boss_name.position = Vector2(96, -2)
	boss_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_root.add_child(boss_name)

func _build_status_row() -> void:
	status_row = HBoxContainer.new()
	status_row.position = Vector2(30, 140)
	status_row.add_theme_constant_override("separation", 6)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_row)
	heat_tag = P5Theme.ransom_label("HEAT!", 18, 0, P5Theme.RED)
	heat_tag.position = Vector2(330, 132)
	heat_tag.visible = false
	add_child(heat_tag)

func _build_quests() -> void:
	quest_box = VBoxContainer.new()
	quest_box.position = Vector2(1010, 168)
	quest_box.add_theme_constant_override("separation", 4)
	quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quest_box)
	var head := P5Theme.ransom_label("QUESTS", 16, 0, P5Theme.BLUE)
	quest_box.add_child(head)
	for i in 3:
		var row := Control.new()
		row.custom_minimum_size = Vector2(250, 30)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quest_box.add_child(row)
		var bg := P5Plate.new()
		bg.size = Vector2(240, 26)
		bg.face_color = P5Theme.BLUE
		bg.accent_color = P5Theme.OCHRE
		bg.skew = 0.25
		bg.cut = 6.0
		bg.show_facet = false
		bg.accent_offset = Vector2(-3, 3)
		row.add_child(bg)
		var fill := ColorRect.new()
		fill.color = Color(P5Theme.OCHRE, 0.55)
		fill.position = Vector2(10, 20)
		fill.size = Vector2(0, 4)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(fill)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", P5Theme.BONE)
		lbl.position = Vector2(14, 2)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)
		quest_rows.append({"row": row, "fill": fill, "label": lbl})

## 技能名：挂在 m0_hud 的技能槽下
func attach_skill_names(slots: Array) -> void:
	for s in slots:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", P5Theme.BONE)
		l.add_theme_color_override("font_outline_color", P5Theme.INK)
		l.add_theme_constant_override("outline_size", 6)
		l.position = Vector2(-2, 72)
		l.size = Vector2(80, 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(s as Control).add_child(l)
		skill_names.append(l)

func refresh(delta: float) -> void:
	if main == null:
		return
	_refresh_boss(delta)
	_refresh_status()
	_refresh_quests()
	_refresh_skill_names()

func _refresh_boss(delta: float) -> void:
	var b = main.boss
	var on: bool = b != null and is_instance_valid(b) and not b.dead
	if on != boss_root.visible:
		boss_root.visible = on
		if on:
			_trail_ratio = 1.0
			_shown_ratio = 1.0
			if DisplayServer.get_name() != "headless":
				P5Motion.slam_in(boss_root, Vector2(0, -120), 0.0, 0.0)
	if not on:
		return
	boss_name.text = "%s  ·  阶段 %d" % [b.boss_title, b.phase]
	var ratio: float = clampf(b.current_health / maxf(b.health, 1.0), 0.0, 1.0)
	if ratio < _shown_ratio - 0.001:
		_trail_delay = 0.35
		if DisplayServer.get_name() != "headless":
			P5Motion.shake(boss_root, 4.0, 0.1)
	_shown_ratio = ratio
	_trail_delay = maxf(0.0, _trail_delay - delta)
	if _trail_delay <= 0.0:
		_trail_ratio = move_toward(_trail_ratio, ratio, delta * 0.8)
	_trail_ratio = maxf(_trail_ratio, ratio)
	boss_fill.size.x = BAR_W * ratio
	boss_trail.size.x = BAR_W * _trail_ratio
	boss_fill.queue_redraw()
	boss_trail.queue_redraw()

func _refresh_status() -> void:
	var p = main.player
	if p == null:
		return
	var active: Array = p.status.active_list()
	var want := active.size()
	while status_row.get_child_count() > want:
		var c := status_row.get_child(status_row.get_child_count() - 1)
		status_row.remove_child(c)
		c.queue_free()
	for i in want:
		var k: String = active[i]
		var chip: Control
		if i < status_row.get_child_count():
			chip = status_row.get_child(i)
		else:
			chip = _make_chip()
			status_row.add_child(chip)
			if DisplayServer.get_name() != "headless":
				P5Motion.ready_pop(chip)
		if chip.get_meta("kind", "") != k:
			chip.set_meta("kind", k)
			(chip.get_node("Plate") as P5Plate).face_color = StatusEffects.COLORS.get(k, P5Theme.BONE)
			var lbl := chip.get_node("Label") as Label
			lbl.text = StatusEffects.LABELS.get(k, k)
			lbl.add_theme_color_override("font_color", P5Theme.INK if k in ["stun", "invincible", "burning"] else P5Theme.BONE)
		var bar := chip.get_node("Time") as ColorRect
		bar.size.x = 52.0 * clampf(p.status.remaining(k) / 3.0, 0.0, 1.0)
	heat_tag.visible = p.heat > 75.0 or p.status.has("overheat")
	if heat_tag.visible:
		heat_tag.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))

func _make_chip() -> Control:
	var chip := Control.new()
	chip.custom_minimum_size = Vector2(62, 30)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := P5Plate.new()
	plate.name = "Plate"
	plate.size = Vector2(60, 24)
	plate.skew = 0.25
	plate.cut = 5.0
	plate.show_facet = false
	plate.accent_color = P5Theme.INK
	plate.accent_offset = Vector2(-3, 3)
	chip.add_child(plate)
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.position = Vector2(10, 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(lbl)
	var t := ColorRect.new()
	t.name = "Time"
	t.color = Color(P5Theme.INK, 0.7)
	t.position = Vector2(6, 26)
	t.size = Vector2(52, 3)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(t)
	return chip

func _refresh_quests() -> void:
	var rows: Array = main.run_systems.tracked_quests(3)
	for i in quest_rows.size():
		var r: Dictionary = quest_rows[i]
		var vis := i < rows.size()
		(r["row"] as Control).visible = vis
		if not vis:
			continue
		var q: Dictionary = rows[i]
		(r["label"] as Label).text = "%s  %d/%d" % [q["name"], mini(int(q["progress"]), int(q["target"])), int(q["target"])]
		(r["fill"] as ColorRect).size.x = 222.0 * clampf(float(q["ratio"]), 0.0, 1.0)

func _refresh_skill_names() -> void:
	if main.vehicle_progression == null:
		return
	for i in mini(skill_names.size(), 4):
		var e: Variant = main.vehicle_progression.active_slots[i]
		var text := ""
		if e is Dictionary and not e.is_empty():
			text = e["def"].module_name
			var lv := int((main.module_levels.get(e["def"].module_id, {}) as Dictionary).get("level", 0))
			if lv > 0:
				text += " +%d" % lv
		(skill_names[i] as Label).text = text

## 招式喊话：斜签砸入，0.9s 后飞出
func callout(text: String, face := P5Theme.RED) -> void:
	if DisplayServer.get_name() == "headless" or callout_holder == null:
		return
	for c in callout_holder.get_children():
		c.queue_free()
	var tag := P5Theme.ransom_label(text, 34, 0, face)
	callout_holder.add_child(tag)
	if face == P5Theme.BONE or face == Color("#EFE3C8"):
		var lb := tag.get_child(tag.get_child_count() - 1)
		if lb is Label:
			(lb as Label).add_theme_color_override("font_color", P5Theme.INK)
	P5Motion.slam_in(tag, Vector2(-420, 0), 0.0, -6.0)
	var tw := tag.create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(tag, "position:x", tag.position.x + 600.0, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tag, "modulate:a", 0.0, 0.18)
	tw.tween_callback(tag.queue_free)
