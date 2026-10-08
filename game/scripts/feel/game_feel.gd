class_name GameFeel
extends Node

## C17 手感层（game feel）。所有「打击感」集中在这里，玩法代码只发事件：
##   hitstop     顿帧：命中瞬间时间几乎停住 30-90ms（越重越久），让打击有「咬合」
##   shake       震屏：trauma 模型（trauma² 映射幅度，指数衰减），走 Camera3D.h/v_offset，不和跟随相机打架
##   fov_punch   视野冲击：冲刺/重击时 FOV 瞬间拉大再回弹
##   number      伤害数字：弹出放大 → 上浮 → 淡出；暴击更大更黄、玩家受伤为红
##   flash       受击闪白：material_overlay 叠一层白，60ms 内淡掉
##   knock       击退：给目标一个衰减速度（宿主每帧消费）
##   vignette    受伤暗角：屏幕四周红色径向渐变闪一下
##   slowmo      慢动作：击杀精英/Boss、升级时 0.3-0.6s
## headless（测试）下 hitstop/slowmo 自动关闭，保证测试时序稳定；其余表现照常创建可被断言。

static var instance: GameFeel

var camera: Camera3D
var world_parent: Node3D
var overlay_layer: CanvasLayer
var vignette: TextureRect
var flash_rect: ColorRect
var enabled := true
var time_effects := true
var base_fov := 0.0

var _trauma := 0.0
var _shake_t := 0.0
var _stop_until := 0
var _slow_until := 0
var _slow_scale := 1.0
var _base_time_scale := 1.0
var _fov_kick := 0.0
var _numbers_alive := 0
var _overlay_mat_cache: Dictionary = {}
var stats := {"hitstops": 0, "shakes": 0, "numbers": 0, "flashes": 0, "slowmos": 0, "vignettes": 0}

const MAX_NUMBERS := 40
const NUMBER_COLORS := {
	"normal": Color("#EFE3C8"), "crit": Color("#E3A52B"), "player": Color("#D9412B"),
	"burn": Color("#E3A52B"), "frost": Color("#7FD3E0"), "shock": Color("#C9B8F0"), "heal": Color("#8FD694"), "shield": Color("#7FD3E0"),
}

func setup(cam: Camera3D, parent3d: Node3D) -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = cam
	world_parent = parent3d
	base_fov = cam.fov if cam != null else 60.0
	time_effects = DisplayServer.get_name() != "headless"
	_build_overlay()

func _exit_tree() -> void:
	if instance == self:
		instance = null
	if _stop_until > 0 or _slow_until > 0:
		Engine.time_scale = _base_time_scale

func _build_overlay() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 14
	add_child(overlay_layer)
	vignette = TextureRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.25, 0.17, 0.0))
	g.set_color(1, Color(0.85, 0.25, 0.17, 0.85))
	g.add_point(0.55, Color(0.85, 0.25, 0.17, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	vignette.texture = tex
	vignette.modulate.a = 0.0
	overlay_layer.add_child(vignette)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	overlay_layer.add_child(flash_rect)

# ------------------------------------------------------------ time

## 顿帧：duration 为真实时间（毫秒级），scale 为停顿期间时间流速
func hitstop(duration := 0.05, scale := 0.04) -> void:
	stats["hitstops"] += 1
	if not enabled or not time_effects:
		return
	var now := Time.get_ticks_msec()
	if _stop_until <= now and _slow_until <= now:
		_base_time_scale = Engine.time_scale
	_stop_until = maxi(_stop_until, now + int(clampf(duration, 0.0, 0.16) * 1000.0))
	Engine.time_scale = minf(Engine.time_scale, maxf(scale, 0.01))

func slowmo(scale := 0.3, duration := 0.45) -> void:
	stats["slowmos"] += 1
	if not enabled or not time_effects:
		return
	var now := Time.get_ticks_msec()
	if _stop_until <= now and _slow_until <= now:
		_base_time_scale = Engine.time_scale
	_slow_until = maxi(_slow_until, now + int(duration * 1000.0))
	_slow_scale = scale
	Engine.time_scale = minf(Engine.time_scale, scale)

# ------------------------------------------------------------ camera

func shake(trauma := 0.3) -> void:
	stats["shakes"] += 1
	_trauma = clampf(_trauma + trauma, 0.0, 1.0)

func fov_punch(amount := 6.0) -> void:
	_fov_kick = maxf(_fov_kick, amount)

func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.001)
	var now := Time.get_ticks_msec()
	if _stop_until > 0 and now >= _stop_until:
		_stop_until = 0
		Engine.time_scale = _slow_scale if _slow_until > now else _base_time_scale
	if _slow_until > 0 and now >= _slow_until:
		_slow_until = 0
		if _stop_until == 0:
			Engine.time_scale = _base_time_scale
	if camera == null or not is_instance_valid(camera):
		return
	_shake_t += real_dt
	var amp := _trauma * _trauma
	camera.h_offset = (sin(_shake_t * 47.0) + sin(_shake_t * 31.0 + 1.3) * 0.6) * amp * 0.55
	camera.v_offset = (cos(_shake_t * 43.0) + sin(_shake_t * 29.0 + 2.1) * 0.6) * amp * 0.55
	_trauma = maxf(0.0, _trauma - real_dt * 1.6)
	_fov_kick = move_toward(_fov_kick, 0.0, real_dt * 28.0)
	camera.fov = base_fov + _fov_kick

# ------------------------------------------------------------ world feedback

func number(at: Vector3, amount: float, kind := "normal") -> Label3D:
	if not enabled or world_parent == null or not is_instance_valid(world_parent) or _numbers_alive >= MAX_NUMBERS:
		return null
	stats["numbers"] += 1
	var crit := kind == "crit"
	var lbl := Label3D.new()
	lbl.name = "DamageNumber"
	lbl.text = ("+" if kind == "heal" else "") + str(int(round(amount))) + ("!" if crit else "")
	lbl.font = P5Theme.title_font()
	lbl.font_size = 96 if crit else (60 if kind != "player" else 72)
	lbl.outline_size = 18
	lbl.modulate = NUMBER_COLORS.get(kind, NUMBER_COLORS["normal"])
	lbl.outline_modulate = Color("#1B1B1D")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.012
	var jitter := Vector3(randf_range(-0.45, 0.45), 0, randf_range(-0.2, 0.2))
	lbl.position = at + Vector3(0, 1.9, 0) + jitter
	lbl.scale = Vector3.ONE * 0.2
	world_parent.add_child(lbl)
	_numbers_alive += 1
	var tw := lbl.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.tween_property(lbl, "scale", Vector3.ONE * (1.55 if crit else 1.25), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.08)
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y + 1.3, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(lbl, "outline_modulate:a", 0.0, 0.22)
	tw.tween_callback(func():
		_numbers_alive -= 1
		lbl.queue_free())
	return lbl

## 受击闪白：给目标下所有网格叠一层可淡出的覆盖材质
func flash(target: Node, color := Color.WHITE, duration := 0.09) -> void:
	if not enabled or target == null or not is_instance_valid(target):
		return
	stats["flashes"] += 1
	var mat: StandardMaterial3D = _overlay_mat_cache.get(target.get_instance_id())
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color, 0.0)
		_overlay_mat_cache[target.get_instance_id()] = mat
		for n in target.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).name != "ContactShadow":
				(n as GeometryInstance3D).material_overlay = mat
	mat.albedo_color = Color(color, 0.85)
	var tw := target.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)

## 屏幕四周红色暗角（玩家受伤）
func hurt_vignette(strength := 0.8) -> void:
	stats["vignettes"] += 1
	if vignette == null:
		return
	vignette.modulate.a = clampf(strength, 0.0, 1.0)
	var tw := vignette.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(vignette, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## 全屏白闪（Boss 击杀 / 进化）
func screen_flash(color := Color(1, 1, 1), alpha := 0.55, duration := 0.25) -> void:
	if flash_rect == null:
		return
	flash_rect.color = Color(color, alpha)
	var tw := flash_rect.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(flash_rect, "color:a", 0.0, duration)

## 地面冲击环（命中/击杀/落地）：一圈快速扩散的扁环
func impact_ring(at: Vector3, radius := 1.6, color := Color("#EFE3C8"), duration := 0.28) -> void:
	if not enabled or world_parent == null or not is_instance_valid(world_parent):
		return
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	ring.material_override = m
	ring.position = at + Vector3(0, 0.08, 0)
	ring.scale = Vector3(radius * 0.25, 0.05, radius * 0.25)
	world_parent.add_child(ring)
	var tw := ring.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius, 0.05, radius), duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, duration).set_delay(duration * 0.35)
	tw.chain().tween_callback(ring.queue_free)

# ------------------------------------------------------------ combat presets（玩法统一调用这几个）

## 玩家打中敌人
func on_enemy_hit(target: Node3D, amount: float, kind := "normal", heavy := false) -> void:
	if target == null or not is_instance_valid(target):
		return
	number(target.global_position, amount, kind)
	var vis: Node = target.get("visual_root") if target.get("visual_root") != null else target
	flash(vis)
	var crit := kind == "crit"
	if crit:
		stats["crits"] = int(stats.get("crits", 0)) + 1
	hitstop(0.075 if crit or heavy else 0.035, 0.03)
	shake(0.22 if crit or heavy else 0.08)
	if crit:
		impact_ring(target.global_position, 1.8, Color("#E3A52B"))

## 击杀
func on_enemy_killed(target: Node3D, tier := "minion") -> void:
	if target == null:
		return
	var at := target.global_position
	match tier:
		"boss":
			hitstop(0.14, 0.0)
			slowmo(0.25, 0.9)
			shake(0.9)
			screen_flash(Color("#EFE3C8"), 0.6, 0.35)
			impact_ring(at, 7.0, Color("#D9412B"), 0.6)
			impact_ring(at, 4.0, Color("#EFE3C8"), 0.45)
		"elite":
			hitstop(0.1, 0.02)
			slowmo(0.35, 0.5)
			shake(0.55)
			impact_ring(at, 4.5, Color("#D9412B"), 0.45)
		_:
			shake(0.14)
			impact_ring(at, 2.2, Color("#EFE3C8"), 0.3)

## 玩家受伤
func on_player_hurt(player: Node3D, amount: float) -> void:
	if player == null:
		return
	number(player.global_position, amount, "player")
	var vis: Node = player.get("visual_root") if player.get("visual_root") != null else player
	flash(vis, Color("#D9412B"), 0.14)
	hurt_vignette(clampf(0.35 + amount / 25.0, 0.35, 1.0))
	shake(clampf(0.18 + amount / 30.0, 0.18, 0.7))
	hitstop(0.05 if amount >= 8.0 else 0.0, 0.08)
