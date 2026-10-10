class_name LevelUpFx
extends RefCounted

## C24 升级表现层（只表现，不改数值）。三个层级，强度依次递增：
##   growth_orb  击杀 / 回收 → 一颗进化能量球沿弧线飞进车身（获得感）
##   power_up    选完卡（新模块 / 技能升级 / 神器 / 船长 / 底盘）→ 车身小跳 + 光柱 + 环 + 头顶字
##   level_up    进化等级提升 → 慢动作 → 压缩蓄力 → 跳起转身 → 砸地冲击波（推开周围敌人）+ 大光柱 + 头顶 LEVEL UP
## 节奏遵循动画 12 法则：预备（压缩）→ 动作（跳 / 爆）→ 跟随（冲击波外扩、粒子落下、弹簧回弹）。

const OCHRE := Color("#E3A52B")
const BONE := Color("#EFE3C8")
const RED := Color("#D9412B")
const VIOLET := Color("#9C8CC4")
const BLUE := Color("#5FA8C8")

const KIND_COLOR := {
	"new_module": BONE,
	"upgrade": OCHRE,
	"artifact": VIOLET,
	"artifact_rare": RED,
	"captain": BLUE,
	"vehicle": OCHRE,
}

static func color_for(kind: String) -> Color:
	return KIND_COLOR.get(kind, OCHRE)

static func _juice(player: Node) -> AnimJuice:
	if player == null or not is_instance_valid(player) or not player.has_method("_juice"):
		return null
	return player._juice()

## 进化能量球：from 处冒出 → 向上弹起 → 追着车飞进去；到达时回调 on_arrive
static func growth_orb(from: Vector3, player: Node3D, on_arrive: Callable = Callable(), color := OCHRE) -> void:
	var host := VfxKit.parent()
	if host == null or player == null or not is_instance_valid(player):
		if on_arrive.is_valid():
			on_arrive.call()
		return
	var orb := MeshInstance3D.new()
	orb.name = "VfxGrowthOrb"
	var sm := SphereMesh.new()
	sm.radius = 0.26
	sm.height = 0.52
	sm.radial_segments = 10
	sm.rings = 5
	orb.mesh = sm
	orb.material_override = VfxKit.flat_mat(Color(color, 0.95), true)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not VfxKit._add(orb, from + Vector3(0, 0.6, 0), 1.6):
		if on_arrive.is_valid():
			on_arrive.call()
		return
	var trail := VfxKit.emitter("embers", color, 0.5, 1.2)
	if trail != null:
		orb.add_child(trail)
	var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.8, 1.6)
	var start := orb.global_position
	var delay := randf_range(0.05, 0.22)
	var dur := randf_range(0.42, 0.58)
	# tween 绑在车上（特效层可能被 GM 冻结 / 不处理），球被提前回收也照样入账
	var tw := player.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(delay)
	tw.tween_method(func(t: float):
		if not is_instance_valid(player) or not is_instance_valid(orb):
			return
		var target := player.global_position + Vector3(0, 0.8, 0)
		# 先往外弹再收拢（ease-in 追踪 = 被吸进去的感觉）
		var k := t * t
		var mid := start + side + Vector3(0, 1.4, 0)
		var a := start.lerp(mid, t)
		var b := mid.lerp(target, k)
		orb.global_position = a.lerp(b, t)
		orb.scale = Vector3.ONE * (1.0 + sin(t * PI) * 0.5), 0.0, 1.0, dur)
	tw.tween_callback(func():
		if is_instance_valid(player):
			VfxKit.burst(player.global_position + Vector3(0, 0.8, 0), "stars", color, 0.5, 0.5)
		WanderburgAudio.hit("xp_tick", -18.0, 0.15)
		if on_arrive.is_valid():
			on_arrive.call()
		if is_instance_valid(orb):
			orb.queue_free())

## 选卡生效 / 小升级：小跳 + 光柱 + 地面环 + 头顶字
static func power_up(player: Node3D, text: String, kind := "upgrade") -> void:
	if player == null or not is_instance_valid(player):
		return
	var c := color_for(kind)
	var at := player.global_position
	var j := _juice(player)
	if j != null:
		j.snap_squash(0.3)
		j.after(0.06, func():
			j.snap_squash(-0.28)
			j.kick_lift(6.0)
			j.kick_yaw(6.0))
		j.after(0.32, func(): j.land(1.0))
	SkillVfx.pillar(Vector3(at.x, 0.0, at.z), 1.4, 7.0, c, 0.55)
	SkillVfx._ground_ring(Vector3(at.x, 0.05, at.z), 3.2, c, 0.5, true)
	VfxKit.burst(at + Vector3(0, 1.0, 0), "stars", c, 1.0, 1.5)
	VfxKit.burst(at + Vector3(0, 0.4, 0), "sparks", c, 0.8, 1.0)
	if not text.is_empty():
		SkillVfx.callout(at + Vector3(0, 3.2, 0), text, c, 56)
	if GameFeel.instance != null:
		GameFeel.instance.flash(player.get("visual_root"), c, 0.14)
		GameFeel.instance.shake(0.18)
	WanderburgAudio.hit("power_up", -10.0, 0.04)

## 进化等级提升：完整的升级演出（约 0.9s）
static func level_up(player: Node3D, rank: int, form_change := false) -> void:
	if player == null or not is_instance_valid(player):
		return
	var feel := GameFeel.instance
	var at := player.global_position
	var j := _juice(player)
	# 1) 预备：慢动作 + 压缩蓄力 + 能量向车身收拢
	if feel != null:
		feel.slowmo(0.35, 0.5)
	if j != null:
		j.snap_squash(0.45)
		j.hold_sq = 0.35
	SkillVfx.vortex(Vector3(at.x, 0.05, at.z), 3.6, OCHRE, 0.32)
	WanderburgAudio.hit("tier_up", -9.0, 0.0)
	# 2) 动作：起跳 + 空中转一圈
	var host := player as Node
	var tw := host.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(0.16)
	tw.tween_callback(func():
		if j != null:
			j.hold_sq = 0.0
			j.snap_squash(-0.35)
			j.kick_lift(10.0)
			j.kick_yaw(14.0)
		if is_instance_valid(player):
			VfxKit.burst(player.global_position, "dust", VfxKit.SAND, 1.4, 1.2))
	# 3) 落地：冲击波 + 光柱 + 推开敌人 + 头顶字
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		if not is_instance_valid(player):
			return
		var p := player.global_position
		var g := Vector3(p.x, 0.0, p.z)
		if j != null:
			j.land(1.6)
		SkillVfx.shock_wall(g, 7.0, OCHRE, 0.5, 1.6)
		SkillVfx.pillar(g, 2.0, 12.0, OCHRE, 0.8)
		SkillVfx._ground_ring(g + Vector3(0, 0.05, 0), 6.0, BONE, 0.6, true)
		VfxKit.burst(p + Vector3(0, 1.0, 0), "stars", OCHRE, 1.8, 2.5)
		VfxKit.burst(p + Vector3(0, 0.6, 0), "sparks", BONE, 1.4, 2.0)
		VfxKit.decal(g, 3.6, "crack", Color(OCHRE, 0.6), 2.5)
		SkillVfx.callout(p + Vector3(0, 4.0, 0), "LEVEL UP!" if not form_change else "EVOLVE!", OCHRE, 84)
		SkillVfx.callout(p + Vector3(0, 2.9, 0), "Lv.%d" % (rank + 1), BONE, 52)
		if feel != null:
			feel.shake(0.45)
			feel.screen_flash(OCHRE, 0.32, 0.28)
			feel.impact_ring(p, 6.0, OCHRE, 0.45)
			feel.hitstop(0.06, 0.05)
		_shove_enemies(player, 6.5, 14.0)
		WanderburgAudio.hit("level_up", -7.0, 0.0))

## 落地冲击把周围敌人推开（只位移，不伤害）——给玩家“喘口气”的空间，也让冲击波有物理后果
static func _shove_enemies(player: Node3D, radius: float, strength: float) -> void:
	if not player.is_inside_tree():
		return
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if not (e is EnemyDummy) or e.dead or e.packed:
			continue
		var d: Vector3 = (e as Node3D).global_position - player.global_position
		d.y = 0.0
		var dist := d.length()
		if dist > radius or dist < 0.01:
			continue
		if e.has_method("apply_knockback"):
			e.apply_knockback(d / dist, strength * (1.0 - dist / radius * 0.6))
