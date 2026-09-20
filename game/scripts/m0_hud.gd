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
var target_slot := 0
var module_buttons: Array[Button] = []
var feedback_time := 0.0

func setup(owner: Node) -> void:
	main = owner
	_build()

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
	status_label.text = "耐久 %03d    载荷 %d/%d    热量 %02d" % [p.health, p.cargo, p.max_cargo, p.heat]
	mission_label.text = "01 / 复苏河岸\n回收 %d / 3    威胁 %d / 5\n水泵：%s   |   %02d:%02d" % [main.collected, main.defeated, "已启动" if main.repair_done else "待修复", int(main.elapsed) / 60, int(main.elapsed) % 60]
	hint_label.text = "已暂停 · Esc / Menu 继续" if main.manual_pause else "WASD / 左摇杆 驾驶 · 鼠标 / 右摇杆 瞄准\n左键 / RT 作业 · 右键 / LT 投掷 · Shift / LB 冲刺\nR / A 修复 · B / Y 改装 · F5 保存 · F9 读取 · F6 重试"
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

func show_garage(open: bool) -> void:
	dock.visible = open
	if open and not module_buttons.is_empty():
		module_buttons[0].grab_focus()

func show_result() -> void:
	result_box.show()
	result_box.find_child("Retry", true, false).grab_focus()

func _build() -> void:
	var theme := Theme.new()
	theme.default_font_size = 17
	var ui := Control.new()
	ui.theme = theme
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	var top := _panel(ui, Vector2(24, 22), Vector2(545, 112))
	_text(top, "RECLAIMER  /  回收者", 25, Color("#f4c96c"))
	_text(top, "幻想工程车 · M0 组合试验场", 14, Color("#a4bcc4"))
	status_label = _text(top, "", 17, Color("#edf1e9"))
	var objective := _panel(ui, Vector2(944, 22), Vector2(312, 128))
	mission_label = _text(objective, "", 18, Color("#b9ebd0"))
	var bottom := _panel(ui, Vector2(24, 574), Vector2(760, 124))
	hint_label = _text(bottom, "", 15, Color("#afc5ca"))
	feedback_label = _text(bottom, "", 16, Color("#f4c96c"))
	var controls := _panel(ui, Vector2(1015, 545), Vector2(241, 150))
	_button(controls, "改装 / B / Y", func(): main.toggle_garage())
	_button(controls, "暂停 / Esc", func(): main.toggle_pause())
	_button(controls, "读取检查点 / F9", func(): main.load_snapshot())
	dock = _panel_container(ui, Vector2(815, 166), Vector2(440, 532))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	dock.add_child(box)
	_text(box, "改装台  /  BUILD LAB", 21, Color("#f4c96c"))
	loadout_label = _text(box, "", 15, Color("#b7d7e0"))
	slot_button = _button(box, "", func(): target_slot = 1 - target_slot)
	var row := GridContainer.new()
	row.columns = 2
	box.add_child(row)
	for id in ["wide_bucket", "magnet", "water_cannon", "electric_arc", "inertia_flywheel", "basic_bucket"]:
		var button := _button(row, _display(id), func(): main.request_preview(id))
		module_buttons.append(button)
	preview_label = _text(box, "", 15, Color("#d6e7dd"))
	preview_label.custom_minimum_size = Vector2(390, 95)
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_button = _button(box, "确认安装", func(): main.confirm_loadout())
	_button(box, "取消并返回战场", func(): main.toggle_garage())
	result_box = _panel_container(ui, Vector2(435, 225), Vector2(410, 235))
	var result_content := VBoxContainer.new()
	result_box.add_child(result_content)
	result_title = _text(result_content, "", 27, Color("#f4c96c"))
	_text(result_content, "换一种装配，再试一次。\nM0 检查点保留已保存的世界状态。", 17, Color("#b8d2d8"))
	var retry := _button(result_content, "重新出击 / 换构筑", func(): main.reset_contract())
	retry.name = "Retry"
	_button(result_content, "恢复检查点", func(): main.load_snapshot())
	close_modals()

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
	style.bg_color = Color(0.035, 0.075, 0.09, 0.93)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color("#31505b")
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
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
