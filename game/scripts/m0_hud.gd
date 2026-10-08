extends CanvasLayer

## C14 HUD v2：P5S 构图 + 主视觉切面厚板。全部面板/按钮/条程序绘制（P5Plate/P5Button），无位图边框。
## 公开接口保持不变：setup / feedback / refresh / close_modals / show_garage / show_result /
## refresh_gm_panel / is_gameplay_blocking_control / stamp_banner。

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
var root_ui: Control
var status_panel: Control
var mission_panel: Control
var skill_bar: HBoxContainer
var skill_cd_masks: Array[ColorRect] = []
var skill_slots: Array[P5Plate] = []
var hp_fill: P5Plate
var cargo_fill: P5Plate
var heat_fill: P5Plate
var result_stamp: P5Title
var banner: P5Title
var _top_layer: CanvasLayer
var _last_health := -1.0
var _last_ready: Array[bool] = [true, true, true, true]
var _feedback_box: Control

func setup(owner: Node) -> void:
	main = owner
	_build()
	if main.gm != null and not main.gm.state_changed.is_connected(_on_gm_state_changed):
		main.gm.state_changed.connect(_on_gm_state_changed)

func feedback(message: String) -> void:
	if feedback_label == null:
		return
	var changed := feedback_label.text != message
	feedback_label.text = message
	feedback_time = 4.0
	if changed and _feedback_box != null and _feedback_box.is_inside_tree() and DisplayServer.get_name() != "headless":
		P5Motion.slide_flash(_feedback_box)

func refresh(delta: float) -> void:
	feedback_time = maxf(0.0, feedback_time - delta)
	if main == null or status_label == null:
		return
	var p = main.player
	var a = main.assembler
	target_slot = main.target_slot
	status_label.text = "%03d" % int(p.health)
	P5Theme.set_bar(hp_fill, float(p.health) / maxf(float(p.get("max_health") if p.get("max_health") != null else 100.0), 1.0))
	P5Theme.set_bar(cargo_fill, float(p.cargo) / maxf(float(p.max_cargo), 1.0))
	P5Theme.set_bar(heat_fill, float(p.heat) / 100.0)
	var route_status := "捷径已通" if main.repair_done else "封锁 · 绕行"
	var phase: String = str(main.get_contract_phase()) if main.has_method("get_contract_phase") else "复苏河岸"
	mission_label.text = "%s\n回收 %d/3   威胁 %d/5\n水泵 %s\n路线 %s   %02d:%02d" % [phase, main.collected, main.defeated, "已启动" if main.repair_done else "待修复", route_status, int(main.elapsed) / 60, int(main.elapsed) % 60]
	hint_label.text = "已暂停 · Esc 继续" if main.manual_pause else "WASD 驾驶 · 鼠标 瞄准 · 左键 作业 · 右键 投掷 · Shift 冲刺(无敌) · 1-4 技能 · 5-7 召唤 · F7 新模块 · F4 刷怪 · F8 Boss · G 群系"
	loadout_label.text = "核心   %s\n挂点 A  %s\n挂点 B  %s\n动力   %s\n结构阶段  %d" % [_display(a.core_id), _display(a.active_ids[0]), _display(a.active_ids[1]), _display(a.drive_id), a.stage]
	preview_label.text = a.get_preview_summary() if not a.preview_id.is_empty() else "选择一个模块查看幽灵预览。\n确认前不会改变实装、资源与冷却。"
	confirm_button.disabled = a.preview_id.is_empty()
	slot_button.text = "安装到 · 挂点 %s" % ("A" if target_slot == 0 else "B")
	feedback_label.modulate.a = minf(feedback_time, 1.0)
	if _last_health >= 0.0 and p.health < _last_health - 0.5 and status_panel != null and status_panel.is_inside_tree():
		P5Motion.punch(status_label, 0.35)
		P5Motion.shake(status_panel, 5.0, 0.15)
	_last_health = p.health
	if main.vehicle_progression != null and not skill_cd_masks.is_empty():
		var cds: Array = main.vehicle_progression.cooldowns()
		for i in mini(cds.size(), skill_cd_masks.size()):
			var entry: Variant = main.vehicle_progression.active_slots[i]
			var total := float(entry["def"].active_base_cooldown) if entry is Dictionary and not entry.is_empty() else 1.0
			var r := clampf(float(cds[i]) / maxf(total, 0.01), 0.0, 1.0)
			skill_cd_masks[i].size.y = 56.0 * r
			skill_cd_masks[i].position.y = 8.0 + 56.0 * (1.0 - r)
			var ready := r <= 0.0
			if ready and not _last_ready[i] and DisplayServer.get_name() != "headless":
				P5Motion.ready_pop(skill_slots[i])
			_last_ready[i] = ready
	if main.outcome == "won":
		result_title.text = "河岸已重获生机"
	elif main.outcome == "failed":
		result_title.text = "工程车失去动力"
	if combat_hud != null:
		combat_hud.refresh(delta)

var combat_hud: CombatHUD

func pulse_skill(slot: int) -> void:
	if slot >= 0 and slot < skill_slots.size() and DisplayServer.get_name() != "headless":
		P5Motion.punch(skill_slots[slot], 0.3)

func boss_callout(text: String, face := P5Theme.RED) -> void:
	if combat_hud != null:
		combat_hud.callout(text, face)

func close_modals() -> void:
	if dock != null:
		dock.hide()
	if result_box != null:
		result_box.hide()
	_update_control_visibility()

func show_garage(open: bool) -> void:
	if open and DisplayServer.get_name() != "headless" and _top_layer != null:
		# P5S：开菜单 = 全屏斜切转场，盖住那一帧再切出面板
		P5Wipe.run(_top_layer_root(), func():
			dock.visible = true
			_update_control_visibility()
			P5Motion.panel_flip_in(dock)
			if not module_buttons.is_empty():
				module_buttons[0].grab_focus())
		return
	dock.visible = open
	_update_control_visibility()
	if open and not module_buttons.is_empty():
		module_buttons[0].grab_focus()

func show_result() -> void:
	result_box.show()
	_update_control_visibility()
	result_box.find_child("Retry", true, false).grab_focus()
	if DisplayServer.get_name() != "headless":
		var won: bool = main.outcome == "won"
		result_stamp.setup("CLEAR!" if won else "DOWN", P5Theme.RED if won else P5Theme.INK, P5Theme.BONE if won else P5Theme.RED, 72)
		result_stamp.set_meta("home", result_box.position + Vector2(40, 8))
		P5Motion.panel_flip_in(result_box)
		result_stamp.play(3600.0)

func _top_layer_root() -> Control:
	return _top_layer.get_child(0) as Control

# ------------------------------------------------------------------ build

func _build() -> void:
	var ui := Control.new()
	ui.theme = P5Theme.build()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	root_ui = ui
	_build_status(ui)
	_build_mission(ui)
	_build_hint(ui)
	_build_skills(ui)
	_build_controls(ui)
	_build_garage(ui)
	_build_result(ui)
	_build_top_layer()
	combat_hud = CombatHUD.new()
	ui.add_child(combat_hud)
	combat_hud.setup(main)
	combat_hud.attach_skill_names(skill_slots)
	gm_panel = preload("res://scripts/gm_panel.gd").new()
	add_child(gm_panel)
	if main.gm != null:
		gm_panel.setup(main.gm)
	close_modals()
	_intro_animation()

## 左上状态牌：红色名牌斜板压在石油蓝主板上（P5S 角色状态条构图）
func _build_status(ui: Control) -> void:
	var holder := Control.new()
	holder.position = Vector2(18, 16)
	holder.size = Vector2(430, 118)
	holder.rotation = deg_to_rad(-2.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(holder)
	status_panel = holder
	var main_plate := P5Plate.new()
	main_plate.position = Vector2(0, 22)
	main_plate.size = Vector2(430, 92)
	main_plate.face_color = P5Theme.BLUE
	main_plate.accent_color = P5Theme.RED
	main_plate.skew = 0.10
	main_plate.cut = 18.0
	holder.add_child(main_plate)
	var tag := P5Theme.ransom_label("RECLAIMER", 24)
	tag.position = Vector2(14, 0)
	holder.add_child(tag)
	var sub := _text(holder, "工单 01 · 抽水站恢复", 13, P5Theme.OCHRE)
	sub.position = Vector2(196, 8)
	# 耐久大数字 + 三条
	var hp_ic := P5Theme.icon_rect("icon_health", 34)
	hp_ic.position = Vector2(22, 46)
	holder.add_child(hp_ic)
	status_label = _text(holder, "100", 34, P5Theme.BONE)
	status_label.add_theme_font_override("font", P5Theme.title_font())
	status_label.position = Vector2(60, 38)
	var rows := [["icon_health", P5Theme.RED], ["icon_cargo", P5Theme.OCHRE], ["icon_heat", P5Theme.VIOLET]]
	var fills: Array[P5Plate] = []
	for i in rows.size():
		var bar: Array = P5Theme.bar(230.0, 13.0, rows[i][1])
		var root: Control = bar[0]
		root.position = Vector2(170 - i * 3, 46 + i * 20)
		holder.add_child(root)
		fills.append(bar[1])
		var ic := P5Theme.icon_rect(rows[i][0], 18)
		ic.position = Vector2(146 - i * 3, 43 + i * 20)
		holder.add_child(ic)
	hp_fill = fills[0]
	cargo_fill = fills[1]
	heat_fill = fills[2]

## 右上工单：骨白纸板 + 红色标签斜板（P5S 任务卡）
func _build_mission(ui: Control) -> void:
	var pc := P5Theme.plate_panel(P5Theme.BONE, P5Theme.BLUE, Vector4(26, 44, 30, 22), 0.05, 20.0)
	pc.position = Vector2(1000, 18)
	pc.custom_minimum_size = Vector2(258, 0)
	pc.rotation = deg_to_rad(1.5)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(pc)
	mission_panel = pc
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	pc.add_child(box)
	mission_label = _text(box, "", 15, P5Theme.INK)
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.custom_minimum_size = Vector2(200, 0)
	# 红色标签斜板压在纸板左上角（独立 holder，避免被 PanelContainer 排版）
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = Vector2(992, 4)
	holder.rotation = deg_to_rad(-3)
	ui.add_child(holder)
	holder.add_child(P5Theme.ransom_label("01 复苏河岸", 20))
	var ic := P5Theme.icon_rect("icon_quest", 30)
	ic.position = Vector2(176, 2)
	holder.add_child(ic)
	pc.set_meta("tab_holder", holder)

## 底部提示：一条细长石油蓝斜带 + 反馈红签（反馈变化时红签闪入）
func _build_hint(ui: Control) -> void:
	var holder := Control.new()
	holder.position = Vector2(16, 664)
	holder.size = Vector2(900, 44)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(holder)
	hint_panel = holder
	var strip := P5Plate.new()
	strip.size = Vector2(900, 30)
	strip.position = Vector2(0, 14)
	strip.face_color = P5Theme.BLUE_DEEP
	strip.show_accent = false
	strip.show_facet = false
	strip.skew = 0.5
	strip.cut = 0.0
	holder.add_child(strip)
	hint_label = _text(holder, "", 12, Color(P5Theme.BONE, 0.85))
	hint_label.position = Vector2(26, 19)
	_feedback_box = P5Theme.plate_panel(P5Theme.RED, P5Theme.INK, Vector4(16, 3, 22, 4), 0.25, 8.0)
	_feedback_box.position = Vector2(20, -16)
	_feedback_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P5Theme.plate_of(_feedback_box).show_facet = false
	holder.add_child(_feedback_box)
	feedback_label = _text(_feedback_box, "", 15, P5Theme.BONE)

## 技能栏：4 个倾斜方槽（就绪时赭黄外框弹一下）
func _build_skills(ui: Control) -> void:
	skill_bar = HBoxContainer.new()
	skill_bar.position = Vector2(380, 568)
	skill_bar.add_theme_constant_override("separation", 14)
	skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(skill_bar)
	var icons := ["skill_dig", "skill_magnet", "skill_water", "skill_dash"]
	for i in 4:
		var slot := P5Plate.new()
		slot.custom_minimum_size = Vector2(72, 72)
		slot.face_color = P5Theme.BLUE
		slot.accent_color = [P5Theme.RED, P5Theme.OCHRE, P5Theme.VIOLET, P5Theme.BONE][i]
		slot.skew = 0.12
		slot.cut = 12.0
		slot.accent_offset = Vector2(-5, 5)
		slot.rotation = deg_to_rad(-4.0)
		slot.pivot_offset = Vector2(36, 36)
		skill_bar.add_child(slot)
		skill_slots.append(slot)
		var ic := P5Theme.icon_rect(icons[i], 52)
		ic.position = Vector2(10, 10)
		slot.add_child(ic)
		var cd := ColorRect.new()
		cd.color = Color(P5Theme.INK, 0.66)
		cd.position = Vector2(8, 64)
		cd.size = Vector2(58, 0)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cd)
		skill_cd_masks.append(cd)
		var key := P5Theme.ransom_label(str(i + 1), 15, 0, P5Theme.INK)
		key.position = Vector2(-10, -12)
		slot.add_child(key)

func _build_controls(ui: Control) -> void:
	controls_box = VBoxContainer.new()
	controls_box.position = Vector2(1060, 520)
	controls_box.add_theme_constant_override("separation", 6)
	ui.add_child(controls_box)
	var labels := ["改装  B", "暂停  Esc", "读档  F9", "GM  F1"]
	var actions := [func(): main.toggle_garage(), func(): main.toggle_pause(), func(): main.load_snapshot(), _toggle_gm]
	for i in labels.size():
		var b := _button(controls_box, labels[i], actions[i])
		b.custom_minimum_size = Vector2(190, 40)
		b.add_theme_font_size_override("font_size", 16)

func _toggle_gm() -> void:
	if main.gm != null:
		main.gm.toggle_panel()
		refresh_gm_panel()

## 改装台：右侧大面板（P5S 装备菜单：墨黑主板 + 红色错位板 + 列表选中项弹出）
func _build_garage(ui: Control) -> void:
	dock = P5Theme.plate_panel(P5Theme.INK, P5Theme.RED, Vector4(40, 30, 40, 30), 0.04, 26.0)
	P5Theme.plate_of(dock).accent_offset = Vector2(-16, 14)
	P5Theme.plate_of(dock).shadow_offset = Vector2(0, 0)
	dock.position = Vector2(790, 96)
	dock.custom_minimum_size = Vector2(470, 600)
	dock.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(dock)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	dock.add_child(layout)
	layout.add_child(P5Theme.ransom_label("BUILD LAB", 30))
	loadout_label = _text(layout, "", 15, P5Theme.BONE)
	slot_button = _button(layout, "", func():
		main.target_slot = 1 - main.target_slot
		target_slot = main.target_slot)
	slot_button.custom_minimum_size = Vector2(250, 40)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	layout.add_child(grid)
	for id in ["wide_bucket", "magnet", "water_cannon", "electric_arc", "inertia_flywheel", "basic_bucket"]:
		var button := _button(grid, _display(id), func(): main.request_preview(id))
		button.custom_minimum_size = Vector2(186, 44)
		module_buttons.append(button)
	preview_label = _text(layout, "", 14, Color(P5Theme.BONE, 0.85))
	preview_label.custom_minimum_size = Vector2(390, 92)
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_button = _button(layout, "确认安装", func(): main.confirm_loadout())
	confirm_button.custom_minimum_size = Vector2(250, 46)
	var cancel := _button(layout, "返回战场", func(): main.toggle_garage())
	cancel.custom_minimum_size = Vector2(210, 40)

func _build_result(ui: Control) -> void:
	result_box = P5Theme.plate_panel(P5Theme.BLUE, P5Theme.RED, Vector4(44, 150, 44, 34), 0.05, 26.0)
	result_box.position = Vector2(380, 160)
	result_box.custom_minimum_size = Vector2(520, 380)
	result_box.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(result_box)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	result_box.add_child(content)
	result_title = _text(content, "", 26, P5Theme.OCHRE)
	_text(content, "换一种装配，再试一次。", 16, P5Theme.BONE)
	var retry := _button(content, "重新出击 / 换构筑", func(): main.reset_contract())
	retry.name = "Retry"
	retry.custom_minimum_size = Vector2(300, 46)
	var back := _button(content, "恢复检查点", func(): main.load_snapshot())
	back.custom_minimum_size = Vector2(260, 42)
	result_stamp = P5Title.new()
	result_stamp.size = Vector2(440, 130)
	result_stamp.setup("CLEAR!", P5Theme.RED, P5Theme.BONE, 72)
	result_stamp.visible = false
	ui.add_child(result_stamp)
	result_box.visibility_changed.connect(func():
		if not result_box.visible:
			result_stamp.visible = false)

## 顶层：全屏大字 + 转场（独立 CanvasLayer，不被任何面板遮挡）
func _build_top_layer() -> void:
	_top_layer = CanvasLayer.new()
	_top_layer.layer = 30
	add_child(_top_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_layer.add_child(root)
	banner = P5Title.new()
	banner.size = Vector2(820, 170)
	banner.position = Vector2(230, 250)
	banner.setup("WARNING")
	banner.visible = false
	root.add_child(banner)

## 开场：各块依次斜切滑入（P5S HUD 进场节奏：快、错开 60ms、过冲）
func _intro_animation() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	var tab_holder: Control = mission_panel.get_meta("tab_holder") if mission_panel.has_meta("tab_holder") else null
	var order := [[status_panel, Vector2(-480, 0)], [mission_panel, Vector2(420, 0)], [tab_holder, Vector2(420, 0)], [hint_panel, Vector2(0, 120)], [skill_bar, Vector2(0, 160)], [controls_box, Vector2(320, 0)]]
	for i in order.size():
		var c: Control = order[i][0]
		if c != null and c.visible:
			P5Motion.slam_in(c, order[i][1], i * 0.06, c.rotation_degrees)

## 全屏大字：title_boss / title_levelup / title_victory / title_defeat
func stamp_banner(id: String) -> void:
	if banner == null or DisplayServer.get_name() == "headless":
		return
	var spec: Array = {
		"title_boss": ["WARNING", P5Theme.RED, P5Theme.INK],
		"title_elite": ["ELITE!", P5Theme.BONE, P5Theme.RED],
		"title_levelup": ["EVOLVE!", P5Theme.OCHRE, P5Theme.INK],
		"title_victory": ["CLEAR!", P5Theme.RED, P5Theme.BONE],
		"title_defeat": ["DOWN", P5Theme.INK, P5Theme.RED],
		"title_quest": ["QUEST!", P5Theme.OCHRE, P5Theme.INK],
		"title_multikill": ["COMBO!", P5Theme.RED, P5Theme.BONE],
	}.get(id, ["!", P5Theme.RED, P5Theme.INK])
	banner.setup(spec[0], spec[1], spec[2], 110)
	banner.set_meta("home", Vector2(230, 250))
	banner.play(0.9)

# ------------------------------------------------------------------ misc

func refresh_gm_panel() -> void:
	if gm_panel != null and main.gm != null:
		gm_panel._on_state_changed(main.gm.get_state())
	_update_control_visibility()

func _on_gm_state_changed(_state: Dictionary) -> void:
	refresh_gm_panel()

func _update_control_visibility() -> void:
	var gm_open: bool = main.gm != null and main.gm.visible
	if hint_panel != null:
		hint_panel.visible = not gm_open
	if controls_box != null:
		controls_box.visible = not main.garage_open and not gm_open and main.outcome == "active"
	if skill_bar != null:
		skill_bar.visible = main.outcome == "active" and not main.garage_open

func is_gameplay_blocking_control(control: Control) -> bool:
	if control == null:
		return false
	for c in [gm_panel, dock, result_box]:
		if c != null and (control == c or c.is_ancestor_of(control)):
			return true
	return false

func _text(parent: Node, value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Control, value: String, callback: Callable) -> Button:
	var button := P5Button.new()
	button.text = value
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _display(id: String) -> String:
	return main.definitions[id].display_name if main.definitions.has(id) else "空"
