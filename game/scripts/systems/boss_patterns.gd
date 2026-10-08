class_name BossPatterns
extends RefCounted

## C17 Boss 专属招式表。每个 Boss 3 招：阶段 1 只用第 1 招，阶段 2 解锁第 2 招，阶段 3 全开且出招更快。
## 所有招式都先出地面预警（Telegraph）再结算 —— 能躲、要躲，冲刺无敌帧是核心解法。
##   slam        玩家脚下大圈 → 砸地（伤害 + 眩晕）
##   barrage     从 Boss 放射状弹幕
##   charge      直线预警 → Boss 沿线冲撞
##   mortar_rain 玩家周围 4 个落点依次轰炸
##   summon      召唤 3 只小怪
##   spin        螺旋弹幕（3 波错角）
##   shockwave   以 Boss 为心的大圈冲击波（冲刺穿过可免伤）
##   vacuum      吸力拉近 1.2s 后原地咬合

const SETS := {
	"boss_kanoning": ["slam", "barrage", "charge"],
	"boss_dredge_toad": ["vacuum", "mortar_rain", "summon"],
	"boss_cannon_phase": ["barrage", "mortar_rain", "spin"],
	"boss_club_king": ["slam", "shockwave", "charge"],
	"boss_davinci": ["spin", "summon", "barrage"],
	"boss_mortar": ["mortar_rain", "shockwave", "barrage"],
	"boss_pyramid": ["shockwave", "spin", "summon"],
	"boss_tank_spinner": ["spin", "charge", "barrage"],
	"boss_ramme_mortar": ["charge", "mortar_rain", "slam"],
	"boss_mouth": ["vacuum", "slam", "spin"],
	"boss_grave_cross": ["summon", "shockwave", "mortar_rain"],
}
const DEFAULT_SET := ["slam", "barrage", "charge"]
const NAMES := {"slam": "重砸", "barrage": "弹幕", "charge": "冲撞", "mortar_rain": "炮雨", "summon": "召唤", "spin": "螺旋弹幕", "shockwave": "冲击波", "vacuum": "吞吸"}
const INTERVALS := [4.2, 3.3, 2.5]

static func set_for(boss_id: String) -> Array:
	return SETS.get(boss_id, DEFAULT_SET)

static func available(boss_id: String, phase: int) -> Array:
	var s: Array = set_for(boss_id)
	return s.slice(0, clampi(phase, 1, 3))

static func _player(boss: BossEntity) -> Node3D:
	return boss.player if boss.player != null and is_instance_valid(boss.player) else null

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

static func _hurt_if_inside(boss: BossEntity, center: Vector3, r: float, dmg: float, stun := 0.0, knock := 0.0) -> bool:
	var p := _player(boss)
	if p == null:
		return false
	var v := _flat(p.global_position - center)
	if v.length() > r + 0.9:
		return false
	boss.hit_player.emit(dmg)
	if stun > 0.0 and p.get("status") != null:
		p.status.apply("stun", stun)
	if knock > 0.0 and p.has_method("apply_knock"):
		p.apply_knock(v.normalized() * knock)
	return true

static func run(boss: BossEntity, attack: String) -> void:
	if not boss.is_inside_tree() or boss.dead:
		return
	var parent := boss.get_parent()
	var p := _player(boss)
	if p == null:
		return
	var feel := GameFeel.instance
	var bpos := _flat(boss.global_position)
	var ppos := _flat(p.global_position)
	var mult: float = [1.0, 1.15, 1.35][clampi(boss.phase - 1, 0, 2)]
	if boss.rig != null:
		boss.rig.play_attack(0.8)
	match attack:
		"slam":
			Telegraph.circle(parent, ppos, 3.2, 0.95, func(c: Vector3):
				if not is_instance_valid(boss) or boss.dead:
					return
				_hurt_if_inside(boss, c, 3.2, 14.0 * mult, 0.45, 8.0)
				if feel != null:
					feel.shake(0.55)
					feel.impact_ring(c, 3.6, Color("#D9412B"), 0.4)
				boss.action_effect.emit("dash_hit", c, c))
		"barrage":
			var count: int = [10, 14, 18][clampi(boss.phase - 1, 0, 2)]
			for i in count:
				var a: float = TAU * i / count
				var pr := Projectile.fire(parent, bpos, Vector3(sin(a), 0, cos(a)), 7.5, 7.0 * mult, "enemy", Color("#D9412B"))
				pr.lifetime = 3.2
			if feel != null:
				feel.shake(0.2)
		"spin":
			for wave in 3:
				var wtw := boss.create_tween()
				wtw.tween_interval(0.28 * wave + 0.001)
				wtw.tween_callback(func():
					if not is_instance_valid(boss) or boss.dead:
						return
					var origin := _flat(boss.global_position)
					for i in 8:
						var a := TAU * i / 8.0 + wave * 0.26
						var pr := Projectile.fire(parent, origin, Vector3(sin(a), 0, cos(a)), 8.0, 6.0 * mult, "enemy", Color("#8C7BA8"))
						pr.lifetime = 3.0)
		"charge":
			var dir := (ppos - bpos).normalized()
			var length := clampf((ppos - bpos).length() + 4.0, 6.0, 16.0)
			Telegraph.line(parent, bpos, dir, length, 3.2, 0.9, func(_c: Vector3):
				if not is_instance_valid(boss) or boss.dead:
					return
				var start := _flat(boss.global_position)
				var end := start + dir * length
				var tw := boss.create_tween()
				tw.tween_property(boss, "global_position", Vector3(end.x, boss.global_position.y, end.z), 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
				# 判定：玩家在冲撞路径带内
				var pl := _player(boss)
				if pl != null:
					var v := _flat(pl.global_position - start)
					var along := v.dot(dir)
					if along >= -1.0 and along <= length + 1.0 and (v - dir * along).length() <= 2.5:
						boss.hit_player.emit(16.0 * mult)
						if pl.has_method("apply_knock"):
							pl.apply_knock((Vector3(-dir.z, 0, dir.x) * (1.0 if (v - dir * along).dot(Vector3(-dir.z, 0, dir.x)) >= 0.0 else -1.0) + dir * 0.5).normalized() * 14.0)
				if feel != null:
					feel.shake(0.6)
					feel.fov_punch(6.0), Color("#D9412B"))
		"mortar_rain":
			for i in 4:
				var off := Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5)) if i > 0 else Vector3.ZERO
				Telegraph.circle(parent, ppos + off, 2.3, 0.9 + i * 0.22, func(c: Vector3):
					if not is_instance_valid(boss) or boss.dead:
						return
					_hurt_if_inside(boss, c, 2.3, 10.0 * mult, 0.0, 6.0)
					if feel != null:
						feel.shake(0.25)
						feel.impact_ring(c, 2.6, Color("#E3A52B"), 0.3)
					boss.action_effect.emit("dash_hit", c, c), Color("#E3A52B"))
		"summon":
			if boss.summoner.is_valid():
				var ids := EnemyArchetypes.ids_of_tier("minion")
				for i in 3:
					var a := TAU * i / 3.0
					boss.summoner.call(ids[randi() % ids.size()], bpos + Vector3(cos(a), 0, sin(a)) * 3.0)
			if feel != null:
				feel.impact_ring(bpos, 4.0, Color("#8C7BA8"), 0.45)
		"shockwave":
			Telegraph.circle(parent, bpos, 6.5, 1.1, func(c: Vector3):
				if not is_instance_valid(boss) or boss.dead:
					return
				_hurt_if_inside(boss, c, 6.5, 12.0 * mult, 0.0, 12.0)
				if feel != null:
					feel.shake(0.7)
					feel.impact_ring(c, 7.5, Color("#EFE3C8"), 0.5), Color("#D9412B"))
		"vacuum":
			boss.vacuum_time = 1.2
			Telegraph.circle(parent, bpos, 3.4, 1.3, func(c: Vector3):
				if not is_instance_valid(boss) or boss.dead:
					return
				_hurt_if_inside(boss, _flat(boss.global_position), 3.4, 18.0 * mult, 0.3, 6.0)
				if feel != null:
					feel.shake(0.5)
				boss.action_effect.emit("whale_release", c, c), Color("#D9412B"))
