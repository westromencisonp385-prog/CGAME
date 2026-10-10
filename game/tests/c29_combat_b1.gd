extends SceneTree

## B1 战斗验收（docs/design/combat-v1.md §3.1 / §3.2）
## 1. 40 个模块都有自动攻击配置
## 2. 槽位朝向：车头 / 两舷 / 车尾只打各自弧内的敌人；顶置会转过去打背后的敌人
## 3. 乘员狙击打血最多的；辅助类在需要时生效
## 4. 统一伤害管线：护甲减免、来源记账、主动技能归到 cast:<id>
## 5. 真实关卡里打 40 秒：「其他」来源占比很低，自动攻击确实在输出
var failures: Array[String] = []
var main: Node
var p

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failures.append(msg)

func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout

func def_of(id: String) -> ModuleDefinitionV2:
	for pool in main.selection_engine.new_module_pools:
		for entry in pool.entries:
			if entry["item"].module_id == id:
				return entry["item"]
	return null

func equip(ids: Array) -> void:
	main.selection_engine.installed_modules.clear()
	for id in ids:
		var d := def_of(id)
		check(d != null, "模块定义存在 %s" % id)
		if d != null:
			main.selection_engine.installed_modules.append(d)
	main._sync_equipped_abilities()
	main.auto_weapons.reset()

func clear_field() -> void:
	main.gm.execute("clear_enemies")
	for n in main.get_tree().get_nodes_in_group("enemies"):
		if n is EnemyDummy and not n.dead:
			n.global_position = Vector3(40.0, n.global_position.y, 40.0)
			n.dead = true
			n.visible = false
	for t in main.get_tree().get_nodes_in_group("engineering_targets"):
		if t is EngineeringTarget and t.target_kind != "repair":
			t.global_position = Vector3(45.0, t.global_position.y, -40.0)

## 在玩家坐标系里放一个打不死、不会动的敌人（right / forward 米）
func dummy(right: float, forward: float, hp := 9999.0) -> EnemyDummy:
	main.gm.execute("spawn", {"kind": "light", "count": 1})
	var e: EnemyDummy = main.gm_enemies[main.gm_enemies.size() - 1]
	var h: Vector3 = AutoWeapons._flat(p.heading)
	var r: Vector3 = h.cross(Vector3.UP)
	var at: Vector3 = p.global_position + r * right + h * forward
	e.global_position = Vector3(at.x, e.global_position.y, at.z)
	e.health = hp
	e.current_health = hp
	main.set_gm_ai_frozen(true)
	return e

func shots(id: String) -> int:
	return int(main.auto_weapons.shots_fired.get(id, 0))

func _profiles() -> void:
	var missing := []
	var bad_slot := []
	for d in ContentV2Catalog.DEFS:
		var prof := AutoWeapons.profile_of(str(d[0]))
		if prof.is_empty():
			missing.append(d[0])
		elif not ["front", "side", "back", "top", "crew"].has(str(prof.slot)):
			bad_slot.append(d[0])
	check(missing.is_empty(), "40 个模块都有自动攻击（缺 %s）" % ", ".join(missing))
	check(bad_slot.is_empty(), "槽位合法（%s）" % ", ".join(bad_slot))
	var slots := {}
	for id in AutoWeapons.PROFILES:
		slots[str(AutoWeapons.PROFILES[id].slot)] = true
	check(slots.size() == 5, "五种槽位都有模块（%s）" % ", ".join(slots.keys()))

func _arc(id: String, inside: Vector2, outside: Vector2, label: String) -> void:
	clear_field()
	equip([id])
	var e_out := dummy(outside.x, outside.y)
	await wait(3.2)
	var miss := shots(id)
	check(miss == 0, "%s：弧外（%s）不开火（%d 次）" % [label, str(outside), miss])
	clear_field()
	main.auto_weapons.reset()
	var e_in := dummy(inside.x, inside.y)
	var hp0 := e_in.current_health
	await wait(3.2)
	check(shots(id) >= 1, "%s：弧内（%s）自动开火（%d 次）" % [label, str(inside), shots(id)])
	await wait(0.8)
	check(e_in.current_health < hp0, "%s：弧内敌人受到伤害（%.0f → %.0f）" % [label, hp0, e_in.current_health])
	check(float(DamagePipeline.ledger.get("auto:" + id, 0.0)) > 0.0, "%s：伤害记在 auto:%s 下" % [label, id])

func _top_turns() -> void:
	clear_field()
	equip(["mage_storm"])
	var st0 := Time.get_ticks_msec()
	dummy(0.0, -7.0)
	await wait(2.5)
	check(shots("mage_storm") >= 1, "顶置炮塔会转向打车尾方向的敌人（%d 次）" % shots("mage_storm"))
	var yaw: Vector3 = main.auto_weapons._state["mage_storm"].yaw
	check(yaw.dot(-AutoWeapons._flat(p.heading)) > 0.9, "顶置炮塔朝向转到了目标（dot=%.2f）" % yaw.dot(-AutoWeapons._flat(p.heading)))

func _crew() -> void:
	clear_field()
	equip(["crew_sniper"])
	var small := dummy(-4.0, 3.0, 200.0)
	var big := dummy(4.0, 3.0, 5000.0)
	await wait(4.0)
	check(big.current_health < 5000.0 and is_equal_approx(small.current_health, 200.0), "狙击手打血最多的目标（大 %.0f / 小 %.0f）" % [big.current_health, small.current_health])
	clear_field()
	equip(["crew_engineer"])
	p.health = 50.0
	await wait(6.0)
	check(p.health > 50.0, "随车工程师在掉血时自动修车（%.1f）" % p.health)
	p.health = p.max_health
	main.auto_weapons.reset()
	await wait(6.0)
	check(shots("crew_engineer") == 0, "满血时工程师不空放")

func _pipeline() -> void:
	clear_field()
	equip([])
	var e := dummy(0.0, 30.0, 100.0)
	e.armor = 5.0
	e.take_damage(10.0, "normal", "test")
	check(is_equal_approx(e.current_health, 95.0), "护甲每次减固定值（100 - (10-5) = %.1f）" % e.current_health)
	e.armor = 20.0
	e.take_damage(10.0, "normal", "test")
	check(is_equal_approx(e.current_health, 93.0), "护甲最多减到 20%%（95 - 2 = %.1f）" % e.current_health)
	e.armor = 0.0
	e.damage_taken_mult = 1.5
	e.take_damage(10.0, "normal", "test")
	check(is_equal_approx(e.current_health, 78.0), "受伤倍率生效（93 - 15 = %.1f）" % e.current_health)
	check(is_equal_approx(float(DamagePipeline.ledger.get("test", 0.0)), 22.0), "来源记账按实际伤害（%.1f）" % float(DamagePipeline.ledger.get("test", 0.0)))
	e.damage_taken_mult = 1.0
	e.take_damage(999.0, "normal", "test")
	check(is_equal_approx(float(DamagePipeline.ledger.get("test", 0.0)), 100.0), "溢出伤害不记账（%.1f）" % float(DamagePipeline.ledger.get("test", 0.0)))
	check(int(DamagePipeline.kill_count.get("test", 0)) == 1, "击杀记在来源下")
	# 主动技能归 cast:<id>
	clear_field()
	equip(["mage_pyro"])
	main.auto_weapons.enabled = false
	var t := dummy(0.0, 6.0)
	p.aim_direction = AutoWeapons._flat(p.heading)
	main._try_cast(0)
	for k in 20:
		if float(DamagePipeline.ledger.get("cast:mage_pyro", 0.0)) > 0.0:
			break
		await wait(0.1)
	main.auto_weapons.enabled = true
	check(float(DamagePipeline.ledger.get("cast:mage_pyro", 0.0)) > 0.0, "主动技能伤害记在 cast:mage_pyro（%.1f）" % float(DamagePipeline.ledger.get("cast:mage_pyro", 0.0)))
	var rows := DamagePipeline.summary(func(k): return k)
	var merged := false
	for r in rows:
		if r.key == "mage_pyro":
			merged = true
	check(merged, "汇总时自动 + 主动合并到同一张卡")

func _live_run() -> void:
	main.gm.execute("invulnerable", {"enabled": true})
	main.start_campaign(1, 4242)
	await wait(0.5)
	DamagePipeline.reset()
	equip(["front_cannon", "side_cannon", "mage_storm", "crew_scout", "back_mine_layer", "crew_bomber"])
	main.set_gm_ai_frozen(false)
	var t0 := Time.get_ticks_msec()
	var dirs := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
	var i := 0
	while Time.get_ticks_msec() - t0 < 40000:
		var d: Vector2 = dirs[i % 4]
		Input.action_release("move_left"); Input.action_release("move_right"); Input.action_release("move_up"); Input.action_release("move_down")
		if d.x > 0: Input.action_press("move_right")
		if d.x < 0: Input.action_press("move_left")
		if d.y > 0: Input.action_press("move_down")
		if d.y < 0: Input.action_press("move_up")
		await wait(2.5)
		if i % 2 == 0:
			main._try_cast(i % 4)
		i += 1
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	var total := DamagePipeline.total()
	var other := float(DamagePipeline.ledger.get("other", 0.0))
	var split := DamagePipeline.channel_split()
	var fired := 0
	for k in main.auto_weapons.shots_fired:
		fired += int(main.auto_weapons.shots_fired[k])
	print("B1 LEDGER ", JSON.stringify(DamagePipeline.ledger))
	print("B1 SPLIT ", JSON.stringify(split), " shots=", JSON.stringify(main.auto_weapons.shots_fired))
	check(total > 300.0, "40 秒实战造成了伤害（%.0f）" % total)
	check(other / maxf(total, 1.0) < 0.05, "未标来源的伤害 < 5%%（%.1f%%）" % (other / maxf(total, 1.0) * 100.0))
	check(fired >= 30, "自动攻击在实战中持续开火（%d 次）" % fired)
	var auto_mods := 0.0
	for k in DamagePipeline.ledger:
		if str(k).begins_with("auto:"):
			auto_mods += float(DamagePipeline.ledger[k])
	check(auto_mods / maxf(total, 1.0) > 0.25, "模块自动攻击占总伤害 > 25%%（%.0f%%）" % (auto_mods / maxf(total, 1.0) * 100.0))
	check(float(split.auto) > float(split.active), "自动输出 > 主动技能（%.0f / %.0f）" % [split.auto, split.active])

func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await wait(1.5)
	p = main.player
	if main.director != null:
		main.director.stop()
	main.gm.execute("invulnerable", {"enabled": true})
	p.status.apply("invincible", 900.0)
	_profiles()
	await _arc("front_cannon", Vector2(0, 7), Vector2(0, -7), "车头主炮")
	await _arc("side_cannon", Vector2(6, 0.5), Vector2(0, 7), "舷侧炮")
	await _arc("teleporter", Vector2(0.5, -5), Vector2(0, 6), "车尾电弧")
	await _top_turns()
	await _crew()
	await _pipeline()
	await _live_run()
	print("B1 COMBAT %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	main.queue_free()
	quit(0 if failures.is_empty() else 1)
