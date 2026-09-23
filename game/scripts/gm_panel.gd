class_name M0GMPanel
extends PanelContainer
## Debug-only Chinese test workbench. It remains usable while the game tree is paused.

var gm: M0GMController
var status_label: Label
var feedback_label: Label
var toggle_button: Button
var spawn_kind: OptionButton
var spawn_count: SpinBox
var first_button: Button

func setup(controller: M0GMController) -> void:
	gm = controller
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	if not gm.state_changed.is_connected(_on_state_changed):
		gm.state_changed.connect(_on_state_changed)
	_on_state_changed(gm.get_state())

func _build() -> void:
	position = Vector2(24, 150)
	size = Vector2(350, 500)
	add_theme_stylebox_override("panel", _style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	var title := Label.new()
	title.text = "GM 测试工作台  /  F1"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#f4c96c"))
	box.add_child(title)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(315, 80)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(status_label)
	var preset_row := HBoxContainer.new()
	box.add_child(preset_row)
	first_button = _add_button(preset_row, "磁吸", func(): _run("preset", {"name": "magnet"}))
	_add_button(preset_row, "风暴", func(): _run("preset", {"name": "storm"}))
	_add_button(preset_row, "冲撞", func(): _run("preset", {"name": "ram"}))
	_add_button(box, "鲸口拍摄台 → 关闭面板后左键打包 / 右键投掷", func(): _run("whale_demo"))
	var demo_note := Label.new()
	demo_note.text = "三拍：聚拢 → 压缩 → 旗子落地。F1 可重复布置。"
	demo_note.add_theme_font_size_override("font_size", 12)
	demo_note.add_theme_color_override("font_color", Color("#a9c4c8"))
	demo_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demo_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(demo_note)
	var action_row := HBoxContainer.new()
	box.add_child(action_row)
	_add_button(action_row, "补血", func(): _run("heal"))
	_add_button(action_row, "补充", func(): _run("refill"))
	toggle_button = _add_button(action_row, "无敌", func(): _run("invulnerable", {"enabled": not gm.invulnerable}))
	var stage_row := HBoxContainer.new()
	box.add_child(stage_row)
	_add_button(stage_row, "阶段 1", func(): _run("stage", {"value": 1}))
	_add_button(stage_row, "阶段 2", func(): _run("stage", {"value": 2}))
	_add_button(stage_row, "修复水泵", func(): _run("repair"))
	var ai_row := HBoxContainer.new()
	box.add_child(ai_row)
	_add_button(ai_row, "冻结 AI", func(): _run("freeze_ai", {"enabled": not gm.freeze_ai}))
	_add_button(ai_row, "恢复 1x", func(): _run("time_scale", {"value": 1.0}))
	_add_button(ai_row, "慢速 0.5x", func(): _run("time_scale", {"value": 0.5}))
	var spawn_row := HBoxContainer.new()
	box.add_child(spawn_row)
	spawn_kind = OptionButton.new()
	spawn_kind.add_item("轻型")
	spawn_kind.set_item_metadata(0, "light")
	spawn_kind.add_item("重型")
	spawn_kind.set_item_metadata(1, "heavy")
	spawn_kind.add_item("远程")
	spawn_kind.set_item_metadata(2, "ranged")
	spawn_kind.custom_minimum_size = Vector2(90, 28)
	spawn_row.add_child(spawn_kind)
	spawn_count = SpinBox.new()
	spawn_count.min_value = 1
	spawn_count.max_value = 12
	spawn_count.value = 1
	spawn_count.custom_minimum_size = Vector2(62, 28)
	spawn_row.add_child(spawn_count)
	_add_button(spawn_row, "生成敌人", func(): _run("spawn", {"kind": spawn_kind.get_selected_metadata(), "count": int(spawn_count.value)}))
	var save_row := HBoxContainer.new()
	box.add_child(save_row)
	_add_button(save_row, "清敌", func(): _run("clear_enemies"))
	_add_button(save_row, "保存 GM", func(): _run("save"))
	_add_button(save_row, "读取 GM", func(): _run("load"))
	_add_button(save_row, "重置训练场", func(): _run("reset_training"))
	var campaign_row := HBoxContainer.new()
	box.add_child(campaign_row)
	_add_button(campaign_row, "局外进度", func(): _run("campaign_status"))
	_add_button(campaign_row, "清空蓝图", func(): _run("campaign_reset"))
	var scale_row := HBoxContainer.new()
	box.add_child(scale_row)
	_add_button(scale_row, "2x", func(): _run("time_scale", {"value": 2.0}))
	_add_button(scale_row, "0.25x", func(): _run("time_scale", {"value": 0.25}))
	_add_button(scale_row, "切换 VFX", func(): _run("vfx", {"enabled": not gm.main.world.effects.enabled}))
	_add_button(box, "关闭 GM / 返回测试", func(): _run("panel", {"open": false}))
	feedback_label = Label.new()
	feedback_label.add_theme_color_override("font_color", Color("#f4c96c"))
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(feedback_label)
	hide()

func _run(command: String, args: Dictionary = {}) -> void:
	if gm == null:
		return
	var result := gm.execute(command, args)
	if bool(result.get("ok", false)):
		feedback_label.text = "✓ %s" % command
	else:
		feedback_label.text = "✕ %s" % str(result.get("error", "未知错误"))
	_on_state_changed(gm.get_state())

func _on_state_changed(state: Dictionary) -> void:
	if status_label == null:
		return
	var was_visible := visible
	visible = bool(state.get("enabled", false)) and bool(state.get("visible", false))
	if visible and not was_visible and first_button != null:
		first_button.grab_focus()
	status_label.text = "状态：%s   时间 %.2fx\n耐久 %.0f  载荷 %d  蓄势 %.0f\n阶段 %d  正式敌人 %d  GM 敌人 %d\n路线：%s  蓝图：%d\n装配：%s / %s" % ["GM暂停 / AI可动" if not state.get("freeze_ai", false) else "GM暂停 / AI冻结", float(state.get("time_scale", 1.0)), float(state.get("health", 0.0)), int(state.get("cargo", 0)), float(state.get("charge", 0.0)), int(state.get("stage", 0)), int(state.get("formal_enemies", 0)), int(state.get("gm_enemies", 0)), "捷径已开" if state.get("shortcut_open", false) else "需修复", state.get("unlocked_blueprints", []).size(), _slot(state, 0), _slot(state, 1)]
	if toggle_button != null:
		toggle_button.text = "取消无敌" if bool(state.get("invulnerable", false)) else "无敌"

func _slot(state: Dictionary, index: int) -> String:
	var loadout: Dictionary = state.get("loadout", {})
	var active: Array = loadout.get("active_ids", ["", ""])
	return str(active[index]) if active.size() > index else ""

func _add_button(parent: Control, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(callback)
	button.custom_minimum_size = Vector2(0, 28)
	parent.add_child(button)
	return button

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.07, 0.97)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color("#6c5666")
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
