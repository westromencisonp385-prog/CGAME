class_name BossEntity
extends EnemyDummy

## C5+C9：Boss 阶段框架 + 花名册驱动（ContentRoster.BOSS_ROSTER 10 个）。
## 复用 EnemyDummy 的战斗协议（try_engineering_hit / defeated / hit_player），
## 叠加三阶段状态机与王冠/名牌呈现；不进存档布局（召唤制，不参与快照校验）。

signal phase_changed(phase: int)

const PHASE_TITLES := ["游荡威胁", "狂暴冲撞", "困兽之斗"]

var phase := 1
var boss_title := "Boss"

## roster_entry 对齐 ContentRoster.BOSS_ROSTER 值结构：{title, hp, phases, kind, scale}
func configure_boss(new_id: String, at: Vector3, roster_entry: Dictionary = {}) -> BossEntity:
	var title := str(roster_entry.get("title", "未知巨兽"))
	var hp := float(roster_entry.get("hp", 420.0))
	var phases: Array = roster_entry.get("phases", [0.9, 1.35, 1.75])
	boss_title = title
	configure(new_id, str(roster_entry.get("kind", "heavy")), hp, float(phases[0]), at)
	set_meta("phase_speeds", phases)
	set_meta("visual_scale", float(roster_entry.get("scale", 1.7)))
	return self

func _build_visual() -> void:
	var slot := FormalModelLibrary.boss_slot(enemy_id)
	if ProceduralRig.has_rig(slot):
		visual_root = Node3D.new()
		visual_root.name = "EnemyVisual"
		add_child(visual_root)
		shadow = _add_cylinder("ContactShadow", 1.1, 0.025, Vector3(0, 0.025, 0), Color("#344542"))
		rig = ProceduralRig.attach(visual_root, slot)
		rig.name = "BossFormalModel"
		position.y = maxf(position.y, 0.0)
		return
	if not FormalModelLibrary.has_model(slot):
		super._build_visual()
		return
	visual_root = Node3D.new()
	visual_root.name = "EnemyVisual"
	add_child(visual_root)
	shadow = _add_cylinder("ContactShadow", 1.1, 0.025, Vector3(0, 0.025, 0), Color("#344542"))
	FormalModelLibrary.attach(visual_root, slot, "BossFormalModel")
	position.y = maxf(position.y, 0.0)

func _ready() -> void:
	super._ready()
	if visual_root == null:
		return
	visual_root.scale = Vector3.ONE * float(get_meta("visual_scale", 1.7))
	var crown := ProceduralVisuals.load_visual("boss_crown.tscn", func(): return ProceduralVisuals.build_crown())
	crown.name = "BossCrown"
	crown.position = Vector3(0, height_for_kind(), 0)
	visual_root.add_child(crown)
	var label := Label3D.new()
	label.name = "BossNamePlate"
	label.text = boss_title
	label.font_size = 64
	label.pixel_size = 0.012
	label.outline_size = 6
	label.position = Vector3(0, height_for_kind() + 0.95, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	visual_root.add_child(label)

func _process(delta: float) -> void:
	super._process(delta)
	if dead:
		return
	var ratio := current_health / maxf(health, 1.0)
	var next_phase := 3 if ratio <= 0.33 else (2 if ratio <= 0.66 else 1)
	if next_phase != phase:
		phase = next_phase
		speed = float((get_meta("phase_speeds", [0.9, 1.35, 1.75]) as Array)[phase - 1])
		if rig != null:
			rig.set_phase_boost([1.0, 1.3, 1.7][phase - 1])
			rig.play_attack(0.7, true)
		phase_changed.emit(phase)
		_pattern_t = 1.2
		if is_inside_tree():
			SkillVfx.shock_wall(global_position, 8.0, VfxKit.RED, 0.55, 2.0)
			SkillVfx.pillar(global_position, 2.6, 9.0, VfxKit.RED, 0.8)
			SkillVfx.dust_ring(global_position, 5.0)
			VfxKit.burst(global_position + Vector3(0, 2.0, 0), "embers", VfxKit.RED, 2.2, 2.5)
			SkillVfx.callout(global_position + Vector3(0, 6.0, 0), PHASE_TITLES[clampi(phase - 1, 0, 2)], VfxKit.RED, 110)
		if GameFeel.instance != null and is_inside_tree():
			GameFeel.instance.shake(0.6)
			GameFeel.instance.screen_flash(Color("#D9412B"), 0.35, 0.3)
			GameFeel.instance.impact_ring(global_position, 6.0, Color("#D9412B"), 0.5)
	# C17 专属招式循环
	if vacuum_time > 0.0:
		vacuum_time -= delta
		_vac_fx -= delta
		if _vac_fx <= 0.0:
			_vac_fx = 0.4
			SkillVfx.vortex(global_position, 7.0, VfxKit.VIOLET, 0.45)
		if player != null and is_instance_valid(player) and player.has_method("apply_knock"):
			var to := global_position - player.global_position
			to.y = 0.0
			if to.length() > 1.5:
				player.apply_knock(to.normalized() * 22.0 * delta * 3.0)
	if player == null or not is_instance_valid(player) or not bool(player.get("gameplay_enabled")) or not is_inside_tree():
		return
	_pattern_t -= delta
	if _pattern_t <= 0.0:
		var pool := BossPatterns.available(enemy_id, phase)
		var attack: String = pool[_pattern_i % pool.size()] if phase == 1 else pool[randi() % pool.size()]
		_pattern_i += 1
		last_attack = attack
		pattern_started.emit(attack)
		BossPatterns.run(self, attack)
		_pattern_t = float(BossPatterns.INTERVALS[clampi(phase - 1, 0, 2)])

signal pattern_started(attack: String)
var summoner: Callable = Callable()
var vacuum_time := 0.0
var _vac_fx := 0.0
var last_attack := ""
var _pattern_t := 2.0
var _pattern_i := 0

func _init() -> void:
	status.resist = {"stun": 0.7, "fear": 1.0, "slow": 0.5}
	knock_resist = 0.85
