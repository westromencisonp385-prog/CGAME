extends SceneTree
## C7 行为测试：群系锁钥 + 技能召唤分支。headless 运行。

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	_test_biome_definitions()
	_test_lock_and_key()
	_test_switch_flow()
	_test_snapshot()
	_test_weather_visual()
	_test_summon_lifecycle()
	_test_gate_visual()
	if failures.is_empty():
		print("PASS biome_flow: all checks")
	else:
		print("FAIL biome_flow: %d checks" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _test_biome_definitions() -> void:
	var biomes := BiomeSystem.define_biomes()
	check(biomes.size() == 3, "应定义 3 个群系（河谷/沙漠/沼泽）")
	for id in ["river", "desert", "swamp"]:
		check(biomes.has(id), "群系目录应有 " + id)
		var b: Dictionary = biomes[id]
		check(str(b["id"]) == id and not str(b["name"]).is_empty(), "%s 应有 id 与名字" % id)
	check(int(biomes["desert"]["difficulty"]) > int(biomes["river"]["difficulty"]), "沙漠难度应高于河谷")
	check(float(biomes["swamp"]["silver_factor"]) > float(biomes["river"]["silver_factor"]), "沼泽银币系数应更高")
	check(str(biomes["desert"]["required_key"]) == BiomeSystem.KEY_DESERT, "沙漠应要求沙漠钥匙")
	check(str(biomes["swamp"]["required_key"]) == BiomeSystem.KEY_SWAMP, "沼泽应要求沼泽钥匙")

func _test_lock_and_key() -> void:
	var sys := BiomeSystem.new()
	check(sys.can_enter("river"), "河谷应始终可进入")
	check(not sys.can_enter("desert"), "沙漠初始锁定")
	check(not sys.can_enter("swamp"), "沼泽初始锁定")
	check(sys.locked_biome_ids().size() == 2, "初始应锁两个群系")
	var deny := sys.switch_to("desert")
	check(not bool(deny["switched"]) and str(deny["reason"]) == "locked", "无钥匙切换沙漠应被拒并给 locked 原因")
	check(sys.current_id == "river", "被拒后应留在河谷")
	var unknown := sys.switch_to("volcano")
	check(not bool(unknown["switched"]) and str(unknown["reason"]) == "unknown_biome", "未知群系应拒绝")
	var grant := sys.grant_key(BiomeSystem.KEY_DESERT)
	check(bool(grant["granted"]), "授予沙漠钥匙应成功")
	check(sys.can_enter("desert"), "持钥匙后沙漠可进入")
	check(sys.is_unlocked("desert"), "持钥匙应永久解锁沙漠（对齐 TryApplyKey 语义）")
	check(not sys.can_enter("swamp"), "沙漠钥匙不应解锁沼泽")
	var again := sys.grant_key(BiomeSystem.KEY_DESERT)
	check(not bool(again["granted"]) and str(again["reason"]) == "already_holding", "重复持钥匙应拒绝")
	var bad := sys.grant_key("key_volcano")
	check(not bool(bad["granted"]) and str(bad["reason"]) == "unknown_key", "未知钥匙应拒绝")
	check(sys.unlocked_biome_ids.has("river"), "解锁表应始终含河谷")

func _test_switch_flow() -> void:
	var sys := BiomeSystem.new()
	var changed_holder := [0]
	sys.biome_changed.connect(func(_id: String): changed_holder[0] += 1)
	sys.grant_key(BiomeSystem.KEY_DESERT)
	var to_desert := sys.switch_to("desert")
	check(bool(to_desert["switched"]), "持钥匙应切到沙漠")
	check(changed_holder[0] == 1, "切换应发 1 次 biome_changed")
	check(sys.silver_factor() > 1.0, "沙漠银币系数应大于 1")
	var env := sys.environment_effect()
	check(env["speed_factor"] < 1.0 and str(env["weather"]) == "sandstorm", "沙漠应有减速与沙暴天气")
	var stay := sys.switch_to("desert")
	check(not bool(stay["switched"]) and str(stay["reason"]) == "already_there", "同群系切换应拒绝")
	sys.grant_key(BiomeSystem.KEY_SWAMP)
	check(bool(sys.switch_to("swamp")["switched"]), "持沼泽钥匙应切到沼泽")
	var swamp_env := sys.environment_effect()
	check(str(swamp_env["weather"]) == "bubbles", "沼泽应为气泡天气")
	var back := sys.switch_to("river")
	check(bool(back["switched"]), "应可回到河谷")
	check(sys.environment_effect()["speed_factor"] == 1.0, "河谷无速度惩罚")
	sys.reset_state()
	check(sys.current_id == "river" and not sys.is_unlocked("desert"), "reset_state 应恢复初始")

func _test_snapshot() -> void:
	var sys := BiomeSystem.new()
	sys.grant_key(BiomeSystem.KEY_DESERT)
	sys.switch_to("desert")
	var snap := sys.get_snapshot()
	var other := BiomeSystem.new()
	check(other.restore_snapshot(snap), "快照应可完整恢复")
	check(other.current_id == "desert" and other.is_unlocked("desert"), "恢复后应保持沙漠与解锁状态")
	check(int(other.keys.get(BiomeSystem.KEY_DESERT, 0)) == 1, "恢复后应保持持钥匙状态")
	check(not other.restore_snapshot({"schema": 2}), "错误 schema 应拒绝")
	check(not other.restore_snapshot({"schema": 1, "keys": {"bad_key": 1}, "unlocked": [], "current": "river"}), "未知钥匙应拒绝恢复")
	check(not other.restore_snapshot({"schema": 1, "keys": {}, "unlocked": ["volcano"], "current": "river"}), "未知群系解锁应拒绝恢复")
	check(not other.restore_snapshot({"schema": 1, "keys": {}, "unlocked": [], "current": "nowhere"}), "未知当前群系应拒绝恢复")

func _test_weather_visual() -> void:
	var weather := BiomeWeather.new()
	weather.apply_biome("desert")
	check(weather.biome_id == "desert", "天气层应切到沙漠")
	weather.apply_biome("swamp")
	check(weather.biome_id == "swamp", "天气层应切到沼泽")
	weather.apply_biome("volcano")
	check(weather.biome_id == "swamp", "未知群系不应改变天气")
	weather.free()

func _test_summon_lifecycle() -> void:
	var turret := SummonEntity.new().configure(SummonEntity.SummonKind.TURRET, Vector3(2, 0, 3), 4.0)
	check(turret.summon_kind == SummonEntity.SummonKind.TURRET, "炮塔召唤物应构造成功")
	check(turret.remaining_lifetime() > 0.0, "炮塔应有限寿命")
	var effects: Array = []
	turret.action_effect.connect(func(kind: String, _o: Vector3, _e: Vector3): effects.append(kind))
	turret._process(0.5)
	check(effects.has("turret_fire"), "炮塔应周期开火")
	var emp := SummonEntity.new().configure(SummonEntity.SummonKind.EMP, Vector3.ZERO, 6.0)
	check(is_equal_approx(emp.reach, 9.0), "EMP 应有脉冲半径")
	var camp := SummonEntity.new().configure(SummonEntity.SummonKind.CAMP, Vector3.ZERO, 4.0)
	check(is_equal_approx(float(camp.heal_per_pulse), 5.0), "营地应按脉冲治疗")
	turret.free()
	emp.free()
	camp.free()

func _test_gate_visual() -> void:
	var gate := BiomeGate.new().configure("gate_test", BiomeSystem.KEY_DESERT, Vector3.ZERO)
	check(gate.required_key == BiomeSystem.KEY_DESERT, "门应记录所需钥匙")
	check(not gate.try_unlock([]), "无钥匙不解锁")
	check(not gate.try_unlock(["key_swamp"]), "错钥匙不解锁")
	check(gate.try_unlock(["key_swamp", "key_desert"]), "持正确钥匙应解锁")
	check(gate.is_unlocked, "解锁状态应记录")
	check(gate.try_unlock([]), "已解锁的门重复验证应直接放行")
	gate.free()
