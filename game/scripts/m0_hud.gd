extends CanvasLayer

var main: Node
var status_label: Label
var mission_label: Label
var hint_label: Label
var feedback_label: Label
var loadout_label: Label
var preview_label: Label
var dock: PanelContainer
var result_box: PanelContainer
var result_title: Label
var confirm_button: Button
var slot_button: Button
var gm_panel: M0GMPanel
var controls_box: VBoxContainer
var target_slot := 0
var module_buttons: Array[Button] = []
var feedback_time := 0.0
var hint_panel: Control

func setup(owner: Node) -> void:
	main = owner
	_build()
	if main.gm != null and not main.gm.state_changed.is_connected(_on_gm_state_changed):
		main.gm.state_changed.connect(_on_gm_state_changed)

func feedback(message: String) -> void:
	if feedback_label != null:
		feedback_label.text = message
		feedback_time = 4.0

func refresh(delta: float) -> void:
	feedback_time = maxf(0.0, feedback_time - delta)
	if main == null or status_label == null:
		return
	var p = main.player
	var a = main.assembler
	target_slot = main.target_slot
	status_label.text = "耐久 %03d  载荷 %d/%d  热量 %02d" % [p.health, p.cargo, p.max_cargo, p.heat]
	mission_label.text = "01 复苏河岸\n回收 %d/3  威胁 %d/5\n水泵 %s  %02d:%02d" % [main.collected, main.defeated, "已启动" if main.repair_done else "待修复", int(main.elapsed) / 60, int(main.elapsed) % 60]
	hint_label.text = "已暂停 · Esc / Menu 继续" if main.manual_pause else "WASD/左摇杆 驾驶 · 鼠标/右摇杆 瞄准 · 左键/RT 作业 · 右键/LT 投掷 · Shift/LB 冲刺 · R/A 修复 · B/Y 改装"
	loadout_label.text = "核心  %s\n挂点 A  %s\n挂点 B  %s\n动力  %s\n结构阶段  %d" % [_display(a.core_id), _display(a.active_ids[0]), _display(a.active_ids[1]), _display(a.drive_id), a.stage]
	preview_label.text = a.get_preview_summary() if not a.preview_id.is_empty() else "选择一个模块查看幽灵预览。\n确认前不会改变实装、资源与冷却。"
	confirm_button.disabled = a.preview_id.is_empty()
	slot_button.text = "安装到：挂点 %s  ↔" % ("A" if target_slot == 0 else "B")
	feedback_label.modulate.a = minf(feedback_time, 1.0)
	if main.outcome == "won":
		result_title.text = "河岸已重获生机"
	elif main.outcome == "failed":
		result_title.text = "工程车失去动力"

func close_modals() -> void:
	if dock != null:
		dock.hide()
	if result_box != null:
		result_box.hide()
	_update_control_visibility()

func show_garage(open: bool) -> void:
	dock.visible = open
	_update_control_visibility()
	if open and not module_buttons.is_empty():
		module_buttons[0].grab_focus()

func show_result() -> void:
	result_box.show()
	_update_control_visibility()
	result_box.find_child("Retry", true, false).grab_focus()

func _build() -> void:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Button", Color("#eee3c7"))
	theme.set_color("font_hover_color", "Button", Color("#152c37"))
	theme.set_color("font_pressed_color", "Button", Color("#152c37"))
	theme.set_stylebox("normal", "Button", _button_style(Color("#253d48"), Color("#49636b")))
	theme.set_stylebox("hover", "Button", _button_style(Color("#e9ad38"), Color("#f4c96c")))
	theme.set_stylebox("pressed", "Button", _button_style(Color("#58b7ac"), Color("#eee3c7")))
	theme.set_stylebox("disabled", "Button", _button_style(Color("#25343a"), Color("#3e5359")))
	var ui := Control.new()
	ui.theme = theme
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var top := _panel(ui, Vector2(20, 18), Vector2(350, 96))
	_text(top, "RECLAIMER / 回收者", 18, Color("#f4c96c"))
	_text(top, "工单 01 · 抽水站恢复 / 施工中", 12, Color("#a4bcc4"))
	status_label = _text(top, "", 14, Color("#edf1e9"))
	var objective := _panel(ui, Vector2(1010, 18), Vector2(246, 118))
	_text(objective, "现场工单", 13, Color("#f4c96c"))
	mission_label = _text(objective, "", 15, Color("#b9ebd0"))
	var bottom := _panel(ui, Vector2(20, 638), Vector2(940, 60))
	hint_panel = bottom.get_parent()
	hint_label = _text(bottom, "", 12, Color("#afc5ca"))
	feedback_label = _text(bottom, "", 13, Color("#f4c96c"))
	controls_box = _panel(ui, Vector2(1010, 560), Vector2(246, 132))
	_button(controls_box, "改装 / B / Y", func(): main.toggle_garage())
	_button(controls_box, "暂停 / Esc", func(): main.toggle_pause())
	_button(controls_box, "读取检查点 / F9", func(): main.load_snapshot())
	_button(controls_box, "GM 工作台 / F1", func():
		if main.gm != null:
			main.gm.toggle_panel()
			refresh_gm_panel()
	)
	dock = _panel_container(ui, Vector2(815, 166), Vector2(440, 532))
	var dock_layout := VBoxContainer.new()
	dock.add_child(dock_layout)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(408, 410)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	dock_layout.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 7)
	scroll.add_child(box)
	_text(box, "改装台  /  BUILD LAB", 21, Color("#f4c96c"))
	loadout_label = _text(box, "", 15, Color("#b7d7e0"))
	var card_path := "res://assets/generated/magnet-build-card.png"
	if ResourceLoader.exists(card_path):
		var card := TextureRect.new()
		card.texture = load(card_path)
		card.custom_minimum_size = Vector2(160, 96)
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(card)
		_text(box, "磁暴鲸口 · 概念插画 / 非实机模型", 12, Color("#93a9b4"))
	slot_button = _button(box, "", func():
		main.target_slot = 1 - main.target_slot
		target_slot = main.target_slot
	)
	var row := GridContainer.new()
	row.columns = 2
	box.add_child(row)
	for id in ["wide_bucket", "magnet", "water_cannon", "electric_arc", "inertia_flywheel", "basic_bucket"]:
		var button := _button(row, _display(id), func(): main.request_preview(id))
		module_buttons.append(button)
	preview_label = _text(box, "", 15, Color("#d6e7dd"))
	preview_label.custom_minimum_size = Vector2(390, 95)
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_button = _button(dock_layout, "确认安装", func(): main.confirm_loadout())
	_button(dock_layout, "取消并返回战场", func(): main.toggle_garage())
	result_box = _panel_container(ui, Vector2(435, 225), Vector2(410, 235))
	var result_content := VBoxContainer.new()
	result_box.add_child(result_content)
	result_title = _text(result_content, "", 27, Color("#f4c96c"))
	_text(result_content, "换一种装配，再试一次。\nM0 检查点保留已保存的世界状态。", 17, Color("#b8d2d8"))
	var retry := _button(result_content, "重新出击 / 换构筑", func(): main.reset_contract())
	retry.name = "Retry"
	_button(result_content, "恢复检查点", func(): main.load_snapshot())
	gm_panel = preload("res://scripts/gm_panel.gd").new()
	add_child(gm_panel)
	if main.gm != null:
		gm_panel.setup(main.gm)
	close_modals()

func refresh_gm_panel() -> void:
	if gm_panel != null and main.gm != null:
		gm_panel._on_state_changed(main.gm.get_state())
	_update_control_visibility()

func _on_gm_state_changed(_state: Dictionary) -> void:
	refresh_gm_panel()

func _update_control_visibility() -> void:
	if hint_panel != null:
		hint_panel.visible = not (main.gm != null and main.gm.visible)
	if controls_box != null:
		var visible: bool = not main.garage_open and not (main.gm != null and main.gm.visible) and main.outcome == "active"
		controls_box.visible = visible
		if controls_box.get_parent() is Control:
			(controls_box.get_parent() as Control).visible = visible

func is_gameplay_blocking_control(control: Control) -> bool:
	if control == null:
		return false
	if gm_panel != null and (control == gm_panel or gm_panel.is_ancestor_of(control)):
		return true
	if dock != null and (control == dock or dock.is_ancestor_of(control)):
		return true
	if result_box != null and (control == result_box or result_box.is_ancestor_of(control)):
		return true
	return false

func _panel(parent: Control, at: Vector2, extent: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.size = extent
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style())
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box

func _panel_container(parent: Control, at: Vector2, extent: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.size = extent
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style())
	parent.add_child(panel)
	return panel

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.09, 0.78)
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = Color("#657d7e")
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 5
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _text(parent: Control, value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Control, value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _display(id: String) -> String:
	return main.definitions[id].display_name if main.definitions.has(id) else "空"
