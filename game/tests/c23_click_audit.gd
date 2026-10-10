extends SceneTree

## C23 按钮点击审计：在每个界面状态下，找出所有可见按钮，用真实鼠标事件（移动 + 按下 + 抬起）点击其中心，
## 确认 pressed 信号触发且确实是该按钮收到（没有被别的控件盖住）。另外检查：
##   - 鼠标悬停时是否有 hover 状态（P5Button 的 hot 动效 / 系统 hover）
##   - 点击 HUD 按钮时不会顺带触发车辆咬合
##   - “看起来像按钮”的控件（P5Plate interactive / 技能槽）必须是真按钮
## 输出每个按钮的结果，失败的列出被谁挡住。
var failures: Array[String] = []
var main: Node
var report: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _center(c: Control) -> Vector2:
	var xf := c.get_global_transform_with_canvas()
	return xf * (c.size * 0.5)

func _visible_buttons() -> Array:
	var out := []
	for n in root.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b.is_visible_in_tree() and b.size.x > 4 and b.size.y > 4:
			out.append(b)
	return out

func _path(n: Node) -> String:
	var s := str(n.name)
	var p := n.get_parent()
	var k := 0
	while p != null and k < 3:
		s = str(p.name) + "/" + s
		p = p.get_parent()
		k += 1
	return s

func _label(b: BaseButton) -> String:
	var t := str(b.get("text")) if b.get("text") != null else ""
	return (t.replace("\n", " ").strip_edges() if not t.is_empty() else _path(b))

func _click(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv)
	await _frames(2)
	var dn := InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.pressed = true
	dn.position = at
	dn.global_position = at
	root.push_input(dn)
	await _frames(1)
	var up := dn.duplicate() as InputEventMouseButton
	up.pressed = false
	root.push_input(up)
	await _frames(2)

## 进入某个界面状态
func _enter(state: String) -> void:
	main.pending_selections.clear()
	main._deferred_selections.clear()
	# 先回到干净战场
	if main.selection_ui != null and main.selection_ui.visible:
		main.selection_ui.visible = false
	if main.garage_open:
		main.toggle_garage()
	if main.manual_pause:
		main.toggle_pause()
	if main.gm != null and main.gm.visible:
		main.gm.set_panel_visible(false)
		main.ui.refresh_gm_panel()
	if main.outcome != "active":
		main.reset_contract()
	await _frames(4)
	match state:
		"skills":
			await _equip_skill()
		"garage":
			main.toggle_garage()
			await create_timer(0.8, true, false, true).timeout
		"pause":
			main.toggle_pause()
		"gm":
			main.gm.set_panel_visible(true)
			main.ui.refresh_gm_panel()
		"selection":
			main.open_selection_flow("new_module")
			await create_timer(0.9, true, false, true).timeout
		"result":
			main.finish_contract("failed")
			await create_timer(0.6, true, false, true).timeout
	await _frames(6)

func _audit(state: String) -> void:
	await _enter(state)
	var buttons := _visible_buttons()
	print("--- state %s: %d buttons" % [state, buttons.size()])
	check(state == "hud" or buttons.size() > 0, "[%s] 界面里有可点按钮" % state)
	var keys := []
	for b in buttons:
		keys.append([_label(b), _path(b)])
	for i in keys.size():
		await _enter(state)
		var target: BaseButton = null
		for b in _visible_buttons():
			if _label(b) == keys[i][0] and _path(b) == keys[i][1]:
				target = b
		if target == null:
			continue
		if target.disabled:
			report.append("[%s] %s：禁用（灰显）" % [state, keys[i][0]])
			continue
		var p: Node = target.get_parent()
		while p != null:
			if p is ScrollContainer:
				(p as ScrollContainer).ensure_control_visible(target)
				await _frames(3)
				break
			p = p.get_parent()
		var at := _center(target)
		var on_screen := Rect2(Vector2.ZERO, Vector2(1280, 720)).has_point(at)
		check(on_screen, "[%s] 「%s」在屏幕内 (%s)" % [state, keys[i][0], at])
		var hit := [0]
		var cb := func(): hit[0] += 1
		target.pressed.connect(cb)
		var mv := InputEventMouseMotion.new()
		mv.position = at
		mv.global_position = at
		root.push_input(mv)
		await _frames(2)
		var hovered := root.gui_get_hovered_control()
		var hover_ok := hovered == target or (hovered != null and target.is_ancestor_of(hovered))
		var heat_before: float = main.player.heat
		await _click(at)
		if is_instance_valid(target) and target.pressed.is_connected(cb):
			target.pressed.disconnect(cb)
		var who := _path(hovered) if hovered != null else "无"
		var ok: bool = int(hit[0]) > 0
		check(ok, "[%s] 点击「%s」%s" % [state, keys[i][0], "有响应" if ok else "没反应 · 鼠标下是 " + who])
		if ok:
			check(hover_ok, "[%s] 悬停「%s」能被识别" % [state, keys[i][0]])
		if state == "hud" and ok:
			check(main.player.heat <= heat_before + 0.01, "[%s] 点「%s」不会顺带让车咬合" % [state, keys[i][0]])

func _equip_skill() -> void:
	var vp = main.vehicle_progression
	for i in 6:
		var has := false
		for e in vp.active_slots:
			if e is Dictionary and not (e as Dictionary).is_empty():
				has = true
		if has:
			return
		main.open_selection_flow("new_module")
		await _frames(3)
		if main.selection_ui.visible:
			main.selection_ui._choose(0)
		await _frames(6)

func _click_named(name: String) -> bool:
	var target: BaseButton = null
	for b in _visible_buttons():
		if str(b.name) == name or _label(b) == name:
			target = b
	if target == null:
		return false
	await _click(_center(target))
	return true

func _functional() -> void:
	print("--- functional")
	await _enter("hud")
	check(await _click_named("MenuButton"), "HUD 有「菜单」按钮")
	await _frames(4)
	check(main.manual_pause and main.ui.pause_menu.visible, "点「菜单」→ 暂停并弹出菜单")
	check(await _click_named("Pause_继续游戏"), "暂停菜单有「继续游戏」")
	await _frames(4)
	check(not main.manual_pause and not main.ui.pause_menu.visible, "点「继续游戏」→ 恢复战斗")
	main.toggle_pause()
	await _frames(4)
	await _click_named("Pause_改装台")
	await create_timer(0.8, true, false, true).timeout
	check(main.garage_open and main.ui.dock.visible, "暂停菜单点「改装台」→ 打开改装台")
	await _click_named("返回战场  B")
	await _frames(4)
	check(not main.garage_open and not main.ui.dock.visible, "改装台点「返回战场」→ 关闭")
	main.toggle_pause()
	await _frames(4)
	await _click_named("Pause_操作说明")
	await _frames(3)
	check(main.ui.pause_help.visible, "点「操作说明」→ 显示操作说明")
	main.toggle_pause()
	# 快速开关改装台：转场回调不应把已关闭的面板重新打开
	main.toggle_garage()
	await _frames(2)
	main.toggle_garage()
	await create_timer(0.9, true, false, true).timeout
	check(not main.ui.dock.visible, "快速按两次 B：改装台不会残留在屏幕上")
	# 技能槽
	await _enter("skills")
	await _equip_skill()
	await _frames(6)
	var slot: Control = main.ui.skill_slots[0]
	check(slot.visible, "装了技能后技能槽出现")
	var casts: int = int(main.run_stats.get("casts", 0))
	if main.vehicle_progression.active_slots[0] is Dictionary:
		main.vehicle_progression.active_slots[0]["cooldown"] = 0.0
	await _click(_center(slot))
	await _frames(4)
	check(int(main.run_stats.get("casts", 0)) > casts, "点技能槽 → 施放技能")
	# 空槽不显示（看得见就一定能点）
	var hidden_ok := true
	for i in 4:
		var e = main.vehicle_progression.active_slots[i]
		var empty: bool = not (e is Dictionary) or (e as Dictionary).is_empty()
		if empty and main.ui.skill_slots[i].visible:
			hidden_ok = false
	check(hidden_ok, "空技能槽不显示")
	# HUD 精简：常驻元素数量
	await _enter("hud")
	main.ui.hint_time = 0.0
	await _frames(4)
	var hud_buttons := _visible_buttons().size()
	check(hud_buttons <= 5, "战斗中可见按钮 ≤ 5（菜单 + 技能槽，现在 %d）" % hud_buttons)

func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(1.5, true, false, true).timeout
	main.get("gm").execute("invulnerable", {"enabled": true})
	main.get("gm").execute("freeze_ai", {"enabled": true})
	# 像按钮的非按钮
	for n in root.find_children("*", "P5Plate", true, false):
		var pl := n as P5Plate
		if pl.is_visible_in_tree() and pl.interactive and not (pl.get_parent() is BaseButton):
			check(false, "「%s」有按钮动效但不是按钮" % _path(pl))
	for st in ["hud", "skills", "garage", "pause", "gm", "selection", "result"]:
		await _audit(st)
	await _functional()
	for r in report:
		print("INFO " + r)
	print("C23 CLICK %s: %d failed" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
