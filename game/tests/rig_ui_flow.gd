extends SceneTree
## C11/C12 资产完整性测试（headless）：拆件 rig 清单、部件命名、UI 资产在盘、主题可构建、动画状态机可驱动。

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	_test_rig_manifest()
	_test_rig_runtime()
	_test_ui_assets()
	await _test_theme()
	if failures.is_empty():
		print("PASS rig_ui_flow: all checks")
	else:
		print("FAIL rig_ui_flow: %d checks" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _test_rig_manifest() -> void:
	var m := ProceduralRig.load_manifest()
	check(m.size() >= 20, "rig 清单应 >=20 项，实际 %d" % m.size())
	for slot in ["enemy_light_v1", "enemy_light_v2", "enemy_ranged_v1", "boss_01_kanoning", "boss_02", "boss_03", "biome_gate", "wind_turbine"]:
		check(ProceduralRig.has_rig(slot), "rig 资产应在盘: " + slot)
	check((m["enemy_light_v1"]["parts"] as Array).any(func(p): return str(p).begins_with("Leg_")), "步行敌人应拆出 Leg_ 部件")
	check((m["boss_03"]["parts"] as Array).has("Ring_L"), "极性环猎手应拆出 Ring_L")
	check((m["biome_gate"]["parts"] as Array).has("Door"), "锁门应拆出 Door")

func _test_rig_runtime() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var rig := ProceduralRig.attach(holder, "enemy_light_v1")
	check(rig != null, "步行敌人 rig 可实例化")
	if rig == null:
		return
	check(rig.legs.size() >= 4, "应索引到 >=4 条腿，实际 %d" % rig.legs.size())
	check(rig.leg_groups.size() == 2 and not rig.leg_groups[0].is_empty() and not rig.leg_groups[1].is_empty(), "腿应分成两组交替")
	var leg: Node3D = rig.legs[0]
	var rest_basis := leg.transform.basis
	rig.set_speed(2.0)
	for i in 20:
		rig._process(0.016)
	check(not leg.transform.basis.is_equal_approx(rest_basis) or not rig.legs[1].transform.basis.is_equal_approx(rig.rest[rig.legs[1]].basis), "行走时腿姿态应变化")
	rig.play_attack(0.3)
	check(rig._tool_t >= 0.0, "攻击动作应进入播放")
	rig.play_death(0.5)
	check(rig.is_dying(), "死亡动作应进入播放")
	holder.free()

func _test_ui_assets() -> void:
	var needed := ["icon_health", "icon_cargo", "icon_heat", "icon_silver", "icon_gold", "icon_quest", "icon_boss", "icon_artifact", "icon_captain", "icon_key", "icon_module", "icon_reroll", "skill_dig", "skill_magnet", "skill_water", "skill_arc", "skill_dash", "skill_turret", "skill_emp", "skill_camp"]
	for id in needed:
		check(FileAccess.file_exists("res://assets/ui/v2/%s.png" % id), "UI v2 图标应在盘: " + id)

func _test_theme() -> void:
	var th := P5Theme.build()
	check(th.default_font != null, "主题字体已设置")
	check(P5Theme.tex("icon_artifact") != null, "v2 图标可加载")
	var title := P5Theme.ransom_label("WARNING", 30)
	check(P5Theme.plate_of(title) != null, "标题为程序化斜板")
	title.free()
	var btn := P5Button.new()
	btn.text = "TEST"
	root.add_child(btn)
	await process_frame
	check(btn.plate != null, "P5Button 自带程序化底板")
	btn._set_hot(true)
	await process_frame
	check(btn.plate._hover, "P5Button hover 态生效")
	btn.free()
	var t := P5Title.new()
	t.size = Vector2(400, 100)
	t.setup("CLEAR!")
	t.setup("DOWN")
	check(t.letters.size() == 4, "P5Title 可重复 setup")
	t.free()
	await process_frame
