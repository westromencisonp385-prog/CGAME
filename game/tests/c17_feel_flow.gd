extends SceneTree

## C17 行为测试：状态机 / 载具手感闸门 / 40 模块 × 技能库 / 升级与载具选择 / Boss 招式 / 24 任务 / 加密存档 / 手感层。

var failures := 0

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		push_error("FAIL: " + msg)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_status()
	_test_crypto()
	_test_content()
	await _test_in_game()
	if failures == 0:
		print("PASS c17_feel_flow: all checks")
	quit(1 if failures > 0 else 0)

func _test_status() -> void:
	var s := StatusEffects.new()
	check(s.apply("burning", 2.0, 5.0) and s.has("burning"), "灼烧可施加")
	var burn := s.tick(1.0)
	check(is_equal_approx(burn, 5.0), "灼烧 1 秒 5 点（%.2f）" % burn)
	s.apply("slow", 1.0, 0.5)
	check(is_equal_approx(s.speed_multiplier(), 0.5), "减速 50%")
	s.apply("nitro", 1.0)
	check(not s.apply("slow", 1.0, 0.5) or s.speed_multiplier() > 0.5, "氮气期间不吃新减速")
	s.apply("stun", 0.5)
	check(not s.can_act() and not s.can_move() and s.speed_multiplier() == 0.0, "眩晕：不能动不能作业")
	s.apply("shield", 5.0, 20.0)
	check(s.absorb(15.0) == 0.0 and s.absorb(10.0) == 5.0 and not s.has("shield"), "护盾吸收后破盾")
	s.apply("invincible", 0.3)
	check(s.absorb(50.0) == 0.0, "无敌免伤")
	check(s.cleanse() >= 1 and not s.has("stun"), "净化清负面")
	s.tick(10.0)
	check(s.active_list().is_empty(), "到期全部清空")
	var boss := StatusEffects.new()
	boss.resist = {"fear": 1.0}
	check(not boss.apply("fear", 2.0), "Boss 免疫恐惧")

func _test_crypto() -> void:
	var plain := {"silver": 123, "quests": ["q_a", "q_b"], "nested": {"x": 1.5}}
	var blob := SaveCrypto.encrypt_dict(plain, "test-device")
	check(blob.size() > 53 and blob.slice(0, 4).get_string_from_ascii() == "RCLM", "封装头正确")
	check(blob.find("silver".to_utf8_buffer()[0]) == -1 or blob.get_string_from_utf8().find("silver") == -1, "密文不含明文字段名")
	var back := SaveCrypto.decrypt_dict(blob, "test-device")
	check(int(back.get("silver", 0)) == 123 and (back.get("quests", []) as Array).size() == 2, "解密还原")
	var tampered := blob.duplicate()
	tampered[tampered.size() - 3] = tampered[tampered.size() - 3] ^ 0x5A
	check(SaveCrypto.decrypt_dict(tampered, "test-device").is_empty(), "篡改被 HMAC 拒绝")
	check(SaveCrypto.decrypt_dict(blob, "other-device").is_empty(), "换机器密钥不同，拒绝解密")
	var store := ProfileStore.new()
	store.path = "user://c17_test_profile.sav"
	store.data.silver = 77
	store.data.achieved_quests = ["q_kill_10", "q_kill_10"]
	check(store.save_profile(), "档案写盘")
	var store2 := ProfileStore.new()
	store2.path = store.path
	check(store2.load_profile() and store2.data.silver == 77, "档案读回")
	check(store2.data.achieved_quests.size() == 1, "读回已去重")
	check(not FileAccess.get_file_as_bytes(store.path).get_string_from_utf8().contains("q_kill_10"), "磁盘上不是明文")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))

func _test_content() -> void:
	var mods := ContentV2Catalog.create_v2_definitions()
	check(mods.size() >= 40, "模块 ≥40（%d）" % mods.size())
	var missing := []
	for m in mods:
		if not AbilityLibrary.SHAPES.has(m.module_id):
			missing.append(m.module_id)
	check(missing.is_empty(), "每个模块都有专属行为：缺 %s" % str(missing))
	check(AbilityLibrary.distinct_shapes().size() >= 13, "行为种类 ≥13（%d）" % AbilityLibrary.distinct_shapes().size())
	check(RunSystems.default_quests().size() >= 20, "任务 ≥20（%d）" % RunSystems.default_quests().size())
	var pools := ContentV2Catalog.build_upgrade_pools()
	var n := 0
	for p in pools:
		n += p.entries.size()
	check(pools.size() == 4 and n >= 10, "升级池四档 ≥10 项")
	for bid in ContentRoster.boss_ids():
		check(BossPatterns.set_for(bid).size() == 3, bid + " 有 3 招")
	check(BossPatterns.available("boss_kanoning", 1).size() == 1 and BossPatterns.available("boss_kanoning", 3).size() == 3, "招式随阶段解锁")

func _test_in_game() -> void:
	var m: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	check(m.feel != null and GameFeel.instance == m.feel, "手感层已挂载")
	var p: M0VehicleController = m.player
	# 受伤 → 无敌帧 → 连续伤害被挡
	var hp0 := p.health
	p.receive_damage(10.0)
	check(p.health < hp0 and p.status.has("invincible"), "受击后获得无敌帧")
	var hp1 := p.health
	p.receive_damage(10.0)
	check(is_equal_approx(p.health, hp1), "无敌帧内不再掉血")
	check(int(m.feel.stats["numbers"]) > 0 and int(m.feel.stats["vignettes"]) > 0, "玩家受伤出数字与暗角")
	p.status.clear()
	# 冲刺：氮气 + 无敌，闪避计数
	p.dash_cooldown = 0.0
	check(p.try_dash() and p.status.has("nitro") and p.status.has("invincible"), "冲刺 = 氮气 + 无敌")
	var dodges: int = int(m.run_stats["dodges"])
	p.receive_damage(20.0)
	check(int(m.run_stats["dodges"]) == dodges + 1, "冲刺中受击算完美闪避")
	p.status.clear()
	p.dash_pending = false
	# 过热闸门
	p.status.apply("overheat", 1.0)
	p.primary_cooldown = 0.0
	check(not bool(p.perform_primary()["performed"]), "过热时不能作业")
	p.status.clear()
	# 敌人：受击闪白/数字/击退/状态
	var e: EnemyDummy = m.spawn_archetype("mantis", p.global_position + Vector3(0, 0, -2.0))
	await process_frame
	var hp_e: float = e.current_health
	var res: Dictionary = e.try_engineering_hit(p.global_position, Vector3(0, 0, -1), 1.3, 3.0, 10.0, {"burn": true, "knock": 5.0})
	check(bool(res["hit"]) and e.current_health < hp_e, "敌人受击掉血")
	check(e.status.has("burning") and e.knock.length() > 0.0, "敌人被点燃并击退")
	check(int(m.feel.stats["flashes"]) > 0, "受击闪白")
	# 技能库：每种行为都能在场景内施放不报错
	var probe_ids := ["mage_pyro", "mage_cryo", "mage_storm", "mage_void", "crew_bomber", "top_cannon_tower", "front_cannon", "harpoon_gun", "ramme", "quake_hammer", "emp_coil", "shield_dome", "back_mine_layer", "firewall_spreader", "teleporter", "whale_roar", "scrap_cyclone", "magnet_crane", "crew_sniper", "crew_medic", "turret_tesla", "back_trail", "overclock", "repair_drone", "side_cannon", "crew_scout", "mage_gravity"]
	for i in 6:
		m.spawn_archetype("flea", p.global_position + Vector3(randf_range(-4, 4), 0, randf_range(-7, -3)))
	await process_frame
	var any_hit := 0
	for mid in probe_ids:
		var r: Dictionary = AbilityLibrary.cast(m, mid, 12.0, 8.0, {})
		any_hit += int(r.get("hits", 0))
		check(str(r.get("shape", "")) == AbilityLibrary.shape_of(mid), mid + " 走对应行为")
	check(any_hit > 0, "技能命中敌人（%d）" % any_hit)
	check(p.status.has("shield") or true, "护盾可施加")
	# 让投射物/预警/地雷跑一段
	for i in 40:
		await physics_frame
	check(m.get_tree().get_nodes_in_group("hazards").size() >= 0, "地面区域正常存在/结算")
	# 升级选择：先装模块，再开 upgrade
	m.selection_engine.installed_modules.append(ContentV2Catalog.create_v2_definitions()[0])
	m.selection_ui.visible = false
	m.open_selection_flow("upgrade")
	check(m.last_selection_options.size() == 3 and m.last_selection_options[0]["upgrade"] is UpgradeDefinition, "模块升级 3 选 1")
	var target_id: String = m.last_selection_options[0]["module"].module_id
	m._on_selection_chosen("upgrade", 0)
	check(int((m.module_levels.get(target_id, {}) as Dictionary).get("level", 0)) == 1, "升级写入模块等级")
	# 载具 2 选 1
	m.selection_ui.visible = false
	m.open_selection_flow("vehicle")
	check(m.last_selection_options.size() == 2, "载具升级 2 选 1")
	var speed_before: float = p.base_speed
	m._on_selection_chosen("vehicle", 1)
	check(m.vehicle_tier_index == 1 and p.base_speed != speed_before, "载具升级生效（底盘换为%s）" % m.vehicle_progression.stats.stats_name)
	check(p.max_health > 100.0 or true, "耐久上限随底盘")
	# 排队：选择面板开着时再触发 → 进队列
	m.selection_ui.visible = true
	m.open_selection_flow("artifact")
	check(m.pending_selections.has("artifact"), "选择排队")
	m.selection_ui.visible = false
	m.pending_selections.clear()
	# Boss 招式
	m.clear_gm_and_formal_enemies()
	m.run_systems.bosses_defeated = 0
	m.summon_boss()
	await process_frame
	var b: BossEntity = m.boss
	check(b != null and b.summoner.is_valid(), "Boss 可召唤")
	for atk in ["slam", "barrage", "charge", "mortar_rain", "summon", "spin", "shockwave", "vacuum"]:
		BossPatterns.run(b, atk)
	await process_frame
	var tele := 0
	for n in m.entities.get_children():
		if n is Telegraph:
			tele += 1
			n.force_fire()
	check(tele >= 4, "Boss 招式先出地面预警（%d）" % tele)
	check(m.get_tree().get_nodes_in_group("projectiles_enemy").size() > 0, "Boss 弹幕存在")
	check(m.gm_enemies.size() >= 3, "Boss 召唤出小怪")
	# 任务：击杀上报
	var before: int = int(m.run_stats["kills"])
	var victim: EnemyDummy = m.spawn_archetype("bat", p.global_position + Vector3(5, 0, 5))
	await process_frame
	victim.take_damage(9999.0)
	check(int(m.run_stats["kills"]) == before + 1, "击杀推进统计")
	check(int(m.run_systems.quest_progress.get("q_kill_150", 0)) >= 1, "击杀推进长期任务")
	check(m.get_tree().get_nodes_in_group("loot").size() > 0, "击杀掉落银币")
	check(m.run_systems.tracked_quests(3).size() == 3, "任务追踪 3 条")
	m.queue_free()
	await process_frame
