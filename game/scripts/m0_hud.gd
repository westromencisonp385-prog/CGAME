extends CanvasLayer

## C23 HUD v3（精简版）。战斗中只常驻 4 样东西：
##   左上 耐久条（+ 载货格；热量 >5% 才出现热量条）
##   右上 当前目标一行 + 「菜单」按钮
##   底部 已装备的技能槽（真按钮，可点击施放；空槽不显示）
##   中下 反馈提示（4 秒自动淡出）
## 其余（操作说明、存读档、改装、重开、GM）全部收进 Esc / 菜单 弹出的暂停菜单。
## 规范：凡是按钮都能点；HUD 按钮不抢键盘焦点；点 UI 不会顺带触发车辆攻击。
## 公开接口保持不变：setup / feedback / refresh / close_modals / show_garage / show_result /
## refresh_gm_panel / is_gameplay_blocking_control / stamp_banner / pulse_skill / deny_skill / boss_callout。

const HELP_TEXT := "WASD 驾驶    鼠标 瞄准\n左键 咬合（连按三段）    右键 投掷货物\nShift 冲刺（无敌）    R 修理水泵\n1-4 技能（也可点技能槽）    5-7 召唤\nB 改装台    Esc 菜单\nF7 新模块 · F4 刷怪 · F8 Boss · F1 GM（测试用）"

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
var controls_box: Control
var menu_button: Button
var pause_menu: PanelContainer
var pause_help: Label
var target_slot := 0
var module_buttons: Array[Button] = []
var feedback_time := 0.0
var hint_time := 14.0
var hint_panel: Control
var root_ui: Control
var status_panel: Control
var mission_panel: Control
var skill_bar: HBoxContainer
var skill_cd_masks: Array[ColorRect] = []
var skill_slots: Array[SkillSlotButton] = []
var hp_fill: P5Plate
var heat_root: Control
var heat_fill: P5Plate
var cargo_pips: Array[ColorRect] = []
var result_stamp: P5Title
var banner: P5Title
var combat_hud: CombatHUD
var _top_layer: CanvasLayer
var _last_health := -1.0
var _last_ready: Array[bool] = [true, true, true, true]
var _feedback_box: Control
var _pause_shown := false

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

# ------------------------------------------------------------------ refresh

func refresh(delta: float) -> void:
	feedback_time = maxf(0.0, feedback_time - delta)
	if main == null or status_label == null:
		return
	var p = main.player
	var a = main.assembler
	target_slot = main.target_slot
	var max_hp := maxf(float(p.get("max_health") if p.get("max_health") != null else 100.0), 1.0)
	status_label.text = "%d" % int(ceil(p.health))
	P5Theme.set_bar(hp_fill, float(p.health) / max_hp)
	for i in cargo_pips.size():
		cargo_pips[i].visible = i < int(p.max_cargo)
		cargo_pips[i].color = P5Theme.OCHRE if i < int(p.cargo) else Color(P5Theme.INK, 0.55)
	var hot: bool = float(p.heat) > 5.0 or p.status.has("overheat")
	heat_root.visible = hot
	if hot:
		P5Theme.set_bar(heat_fill, float(p.heat) / 100.0)
		heat_root.modulate.a = 1.0 if float(p.heat) < 75.0 else 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))
	mission_label.text = _objective()
	# 操作提示：开局显示一段时间后淡出；暂停菜单里可随时再看
	if main.outcome == "active" and not get_tree().paused:
		hint_time = maxf(0.0, hint_time - delta)
	hint_panel.modulate.a = clampf(hint_time / 2.0, 0.0, 1.0)
	hint_panel.visible = hint_time > 0.0
	loadout_label.text = "核心   %s\n挂点 A  %s\n挂点 B  %s\n动力   %s\n结构阶段  %d" % [_display(a.core_id), _display(a.active_ids[0]), _display(a.active_ids[1]), _display(a.drive_id), a.stage]
	preview_label.text = a.get_preview_summary() if not a.preview_id.is_empty() else "点一个模块查看预览，再点「确认安装」。"
	confirm_button.modulate.a = 0.55 if a.preview_id.is_empty() else 1.0
	slot_button.text = "安装到 · 挂点 %s（点击切换）" % ("A" if target_slot == 0 else "B")
	feedback_label.modulate.a = minf(feedback_time, 1.0)
	_feedback_box.visible = feedback_time > 0.0 and not feedback_label.text.is_empty()
	if _last_health >= 0.0 and p.health < _last_health - 0.5 and status_panel != null and status_panel.is_inside_tree() and DisplayServer.get_name() != "headless":
		P5Motion.punch(status_label, 0.35)
		P5Motion.shake(status_panel, 5.0, 0.15)
	_last_health = p.health
	_refresh_skills()
	if main.outcome == "won":
		result_title.text = "河岸已重获生机"
	elif main.outcome == "failed":
		result_title.text = "工程车失去动力"
	_update_control_visibility()
	if combat_hud != null:
		combat_hud.refresh(delta)

func _objective() -> String:
	var t := "%02d:%02d" % [int(main.elapsed) / 60, int(main.elapsed) % 60]
	var goal := ""
	if int(main.collected) < 3:
		goal = "咬碎废料堆  %d/3" % int(main.collected)
	elif int(main.defeated) < 5:
		goal = "清除威胁  %d/5" % int(main.defeated)
	elif not bool(main.repair_done):
		goal = "去水泵旁按 R 修理"
	else:
		goal = "河岸已恢复 · 继续探索"
	return "%s    %s" % [goal, t]

func _refresh_skills() -> void:
	if main.vehicle_progression == null:
		return
	var slots: Array = main.vehicle_progression.active_slots
	var cds: Array = main.vehicle_progression.cooldowns()
	for i in skill_slots.size():
		var entry: Variant = slots[i] if i < slots.size() else null
		var has := entry is Dictionary and not (entry as Dictionary).is_empty()
		var s := skill_slots[i]
		s.visible = has
		if not has:
			continue
		s.tooltip_text = "%s（%d 键 / 点击施放）" % [entry["def"].module_name, i + 1]
		var total := maxf(float(entry["def"].active_base_cooldown), 0.01)
		var r := clampf(float(cds[i]) / total, 0.0, 1.0) if i < cds.size() else 0.0
		s.set_cooldown(r)
		var ready := r <= 0.0
		if ready and not _last_ready[i] and DisplayServer.get_name() != "headless":
			P5Motion.ready_pop(s)
		_last_ready[i] = ready

func pulse_skill(slot: int) -> void:
	if slot >= 0 and slot < skill_slots.size() and DisplayServer.get_name() != "headless":
		P5Motion.punch(skill_slots[slot], 0.3)

## 按了但放不出：槽位左右抖并闪红
func deny_skill(slot: int) -> void:
	if slot < 0 or slot >= skill_slots.size() or DisplayServer.get_name() == "headless":
		return
	var c: Control = skill_slots[slot]
	if not c.visible:
		return
	var x0 := c.position.x
	var tw := c.create_tween()
	tw.set_ignore_time_scale(true)
	c.modulate = Color(1.0, 0.55, 0.5)
	for off in [-7.0, 6.0, -4.0, 2.0, 0.0]:
		tw.tween_property(c, "position:x", x0 + off, 0.035)
	tw.parallel().tween_property(c, "modulate", Color.WHITE, 0.2)

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
		# 开菜单 = 全屏斜切转场，盖住那一帧再切出面板；转场途中又关掉了就不再打开
		P5Wipe.run(_top_layer_root(), func():
			if not main.garage_open:
				return
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
	combat_hud = CombatHUD.new()
	ui.add_child(combat_hud)
	combat_hud.setup(main)
	_build_status(ui)
	_build_mission(ui)
	_build_hint(ui)
	_build_skills(ui)
	combat_hud.attach_skill_names(skill_slots)
	_build_pause_menu(ui)
	_build_garage(ui)
	_build_result(ui)
	_build_top_layer()
	gm_panel = preload("res://scripts/gm_panel.gd").new()
	add_child(gm_panel)
	if main.gm != null:
		gm_panel.setup(main.gm)
	close_modals()
	_intro_animation()

## 左上：耐久大数字 + 血条，下面一排载货格；热量条只在发热时出现
func _build_status(ui: Control) -> void:
	var holder := Control.new()
	holder.name = "StatusPanel"
	holder.position = Vector2(18, 16)
	holder.size = Vector2(300, 84)
	holder.rotation = deg_to_rad(-2.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(holder)
	status_panel = holder
	var plate := P5Plate.new()
	plate.size = Vector2(290, 60)
	plate.face_color = P5Theme.BLUE
	plate.accent_color = P5Theme.RED
	plate.skew = 0.10
	plate.cut = 14.0
	holder.add_child(plate)
	var hp_ic := P5Theme.icon_rect("icon_health", 30)
	hp_ic.position = Vector2(16, 14)
	holder.add_child(hp_ic)
	status_label = _text(holder, "100", 30, P5Theme.BONE)
	status_label.add_theme_font_override("font", P5Theme.title_font())
	status_label.position = Vector2(52, 8)
	var bar: Array = P5Theme.bar(170.0, 14.0, P5Theme.RED)
	(bar[0] as Control).position = Vector2(108, 14)
	holder.add_child(bar[0])
	hp_fill = bar[1]
	for i in 8:
		var pip := ColorRect.new()
		pip.size = Vector2(16, 8)
		pip.position = Vector2(110 + i * 20, 38)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(pip)
		cargo_pips.append(pip)
	heat_root = Control.new()
	heat_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_root.position = Vector2(108, 64)
	holder.add_child(heat_root)
	var hb: Array = P5Theme.bar(150.0, 10.0, P5Theme.VIOLET)
	heat_root.add_child(hb[0])
	heat_fill = hb[1]
	var hl := _text(heat_root, "热量", 11, P5Theme.BONE)
	hl.position = Vector2(156, -3)
	heat_root.visible = false

## 右上：一行当前目标 + 菜单按钮
func _build_mission(ui: Control) -> void:
	var pc := P5Theme.plate_panel(P5Theme.BONE, P5Theme.BLUE, Vector4(22, 10, 26, 10), 0.05, 12.0)
	pc.name = "ObjectivePanel"
	pc.position = Vector2(820, 20)
	pc.custom_minimum_size = Vector2(300, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(pc)
	mission_panel = pc
	mission_label = _text(pc, "", 16, P5Theme.INK)
	menu_button = _button(ui, "菜单  Esc", func(): main.toggle_pause())
	menu_button.name = "MenuButton"
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.position = Vector2(1134, 18)
	menu_button.custom_minimum_size = Vector2(130, 40)
	menu_button.add_theme_font_size_override("font_size", 15)
	controls_box = menu_button

## 开局操作提示（14 秒后淡出）
func _build_hint(ui: Control) -> void:
	var holder := Control.new()
	holder.name = "HintPanel"
	holder.position = Vector2(18, 560)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(holder)
	hint_panel = holder
	var bg := P5Theme.plate_panel(P5Theme.BLUE_DEEP, P5Theme.INK, Vector4(16, 8, 18, 8), 0.04, 8.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	hint_label = _text(bg, HELP_TEXT, 13, Color(P5Theme.BONE, 0.92))
	# 反馈提示：底部居中（技能栏上方）
	_feedback_box = P5Theme.plate_panel(P5Theme.RED, P5Theme.INK, Vector4(18, 5, 24, 6), 0.2, 8.0)
	_feedback_box.name = "FeedbackToast"
	_feedback_box.position = Vector2(470, 520)
	_feedback_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	P5Theme.plate_of(_feedback_box).show_facet = false
	ui.add_child(_feedback_box)
	feedback_label = _text(_feedback_box, "", 17, P5Theme.BONE)
	_feedback_box.visible = false
	_feedback_box.resized.connect(func(): _feedback_box.position.x = 640.0 - _feedback_box.size.x * 0.5)

## 底部技能槽：真按钮，点击 = 按数字键
func _build_skills(ui: Control) -> void:
	skill_bar = HBoxContainer.new()
	skill_bar.name = "SkillBar"
	skill_bar.add_theme_constant_override("separation", 14)
	skill_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_bar.position = Vector2(340, 600)
	skill_bar.size = Vector2(600, 80)
	ui.add_child(skill_bar)
	var icons := ["skill_dig", "skill_magnet", "skill_water", "skill_dash"]
	var accents := [P5Theme.RED, P5Theme.OCHRE, P5Theme.VIOLET, P5Theme.BONE]
	for i in 4:
		var slot := SkillSlotButton.new()
		slot.setup(i, icons[i], accents[i])
		var idx := i
		slot.pressed.connect(func(): main._try_cast(idx))
		skill_bar.add_child(slot)
		skill_slots.append(slot)
		skill_cd_masks.append(slot.cd_mask)
		slot.visible = false

## 暂停菜单：Esc / 菜单按钮打开。所有不常用的功能都在这里
func _build_pause_menu(ui: Control) -> void:
	pause_menu = P5Theme.plate_panel(P5Theme.INK, P5Theme.RED, Vector4(40, 30, 40, 30), 0.04, 22.0)
	pause_menu.name = "PauseMenu"
	pause_menu.position = Vector2(440, 50)
	pause_menu.custom_minimum_size = Vector2(400, 0)
	pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(pause_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pause_menu.add_child(box)
	box.add_child(P5Theme.ransom_label("PAUSE", 30))
	var items := [
		["继续游戏", func(): _resume()],
		["改装台", func():
			_resume()
			main.toggle_garage()],
		["保存检查点", func(): main.save_snapshot()],
		["读取检查点", func():
			if main.load_snapshot():
				_resume()],
		["重新开始本局", func():
			_resume()
			main.reset_contract()],
		["操作说明", func(): pause_help.visible = not pause_help.visible],
		["GM 测试台", func():
			_resume()
			_toggle_gm()],
	]
	for it in items:
		var b := _button(box, it[0], it[1])
		b.name = "Pause_" + str(it[0])
		b.custom_minimum_size = Vector2(300, 42)
		b.add_theme_font_size_override("font_size", 17)
	pause_help = _text(box, HELP_TEXT, 14, Color(P5Theme.BONE, 0.9))
	pause_help.visible = false
	pause_menu.visible = false

func _resume() -> void:
	if main.manual_pause:
		main.toggle_pause()

func _toggle_gm() -> void:
	if main.gm != null:
		main.gm.toggle_panel()
		refresh_gm_panel()

## 改装台：右侧大面板
func _build_garage(ui: Control) -> void:
	dock = P5Theme.plate_panel(P5Theme.INK, P5Theme.RED, Vector4(40, 30, 40, 30), 0.04, 26.0)
	dock.name = "GarageDock"
	P5Theme.plate_of(dock).accent_offset = Vector2(-16, 14)
	P5Theme.plate_of(dock).shadow_offset = Vector2(0, 0)
	dock.position = Vector2(790, 70)
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
		target_slot = main.target_slot
		main.assembler.clear_preview())
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
	confirm_button = _button(layout, "确认安装", func():
		if main.assembler.preview_id.is_empty():
			feedback("先点上面一个模块，再确认安装")
			if DisplayServer.get_name() != "headless":
				P5Motion.shake(confirm_button, 6.0, 0.15)
			WanderburgAudio.hit("deny", -12.0, 0.0)
			return
		main.confirm_loadout())
	confirm_button.custom_minimum_size = Vector2(250, 46)
	confirm_button.tooltip_text = "先点上面一个模块"
	var cancel := _button(layout, "返回战场  B", func(): main.toggle_garage())
	cancel.custom_minimum_size = Vector2(210, 40)

func _build_result(ui: Control) -> void:
	result_box = P5Theme.plate_panel(P5Theme.BLUE, P5Theme.RED, Vector4(44, 150, 44, 34), 0.05, 26.0)
	result_box.name = "ResultBox"
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

## 顶层：全屏大字 + 转场（独立 CanvasLayer，不拦截鼠标）
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

func _intro_animation() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	var order := [[status_panel, Vector2(-420, 0)], [mission_panel, Vector2(480, 0)], [menu_button, Vector2(300, 0)], [hint_panel, Vector2(-500, 0)]]
	for i in order.size():
		var c: Control = order[i][0]
		if c != null and c.visible:
			P5Motion.slam_in(c, order[i][1], i * 0.06, c.rotation_degrees)

## 全屏大字只留给真正的大事（Boss / 进化 / 胜负）；任务、连杀、精英改成小喊话，不再盖住画面
func stamp_banner(id: String) -> void:
	if banner == null or DisplayServer.get_name() == "headless":
		return
	var small := {"title_quest": ["任务完成！", P5Theme.OCHRE], "title_multikill": ["COMBO!", P5Theme.RED], "title_elite": ["精英出现", P5Theme.RED]}
	if small.has(id):
		boss_callout(small[id][0], small[id][1])
		return
	var spec: Array = {
		"title_boss": ["WARNING", P5Theme.RED, P5Theme.INK],
		"title_levelup": ["EVOLVE!", P5Theme.OCHRE, P5Theme.INK],
		"title_victory": ["CLEAR!", P5Theme.RED, P5Theme.BONE],
		"title_defeat": ["DOWN", P5Theme.INK, P5Theme.RED],
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

func _selection_open() -> bool:
	var s = main.get("selection_ui")
	return s != null and is_instance_valid(s) and s.visible

## 同一时间只有一层可交互：弹窗打开时，下面的 HUD 按钮隐藏（不会出现“看得见点不了”）
func _update_control_visibility() -> void:
	if main == null or menu_button == null:
		return
	var gm_open: bool = main.gm != null and main.gm.visible
	var modal: bool = main.garage_open or gm_open or _selection_open() or main.outcome != "active"
	var paused_menu: bool = main.manual_pause and not modal
	if paused_menu and not _pause_shown and DisplayServer.get_name() != "headless":
		P5Motion.panel_flip_in(pause_menu)
	if paused_menu != _pause_shown:
		pause_help.visible = false
	_pause_shown = paused_menu
	pause_menu.visible = paused_menu
	menu_button.visible = not modal and not paused_menu
	skill_bar.visible = not modal and not paused_menu
	if modal or paused_menu:
		_feedback_box.visible = false
	mission_panel.visible = not gm_open
	status_panel.visible = not gm_open

## 鼠标在这些控件上时，车辆不响应左键攻击（点按钮不会顺带咬一口）
func is_gameplay_blocking_control(control: Control) -> bool:
	var n: Node = control
	while n != null:
		if n is BaseButton or n == gm_panel or n == dock or n == result_box or n == pause_menu:
			return true
		if n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP and n != root_ui:
			return true
		n = n.get_parent()
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
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _display(id: String) -> String:
	return main.definitions[id].display_name if main.definitions.has(id) else "空"
