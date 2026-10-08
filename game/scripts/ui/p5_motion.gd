class_name P5Motion
extends RefCounted

## C12 UI 动效（规格对齐 Wanderburg UI 类 + P5 转场语言）：
## - UIBounceOnEnable：hopHeight/hopDuration/rotationAmount/squashAmount —— 出现时弹跳挤压
## - SelectorAnimation：distance/speed —— 选中项左右往复指示
## - HighlightAnimation：IntroGlimmer / HoverGlimmer —— 高光扫过
## - P5 slam：面板从屏外斜飞入、过冲、定格抖动；卡片翻入；数值跳动 punch
## 全部基于 Tween，不依赖额外插件。

## P5S 面板翻入：先压成一条竖线（scale.x≈0）倾斜进入 → 弹开 → 轻微过冲回正；内部 Plate 同步「刷开」
static func panel_flip_in(c: Control, delay := 0.0) -> Tween:
	c.pivot_offset = Vector2(c.size.x * 0.5, c.size.y * 0.5)
	c.scale = Vector2(0.04, 1.08)
	c.rotation = deg_to_rad(-8)
	c.modulate.a = 0.0
	var plate := P5Theme.plate_of(c)
	if plate != null:
		plate.reveal_t = 0.0
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "rotation", 0.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if plate != null:
		tw.tween_method(plate.set_reveal, 0.0, 1.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return tw

## 反馈签：从左滑入 + 轻微过冲（每次文字变化触发）
static func slide_flash(c: Control) -> Tween:
	var home: Vector2 = c.get_meta("home", c.position)
	c.set_meta("home", home)
	c.position = home + Vector2(-60, 0)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "position", home, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.08)
	return tw

## 技能就绪：方槽放大回弹 + 一次高光扫过
static func ready_pop(c: Control) -> void:
	if c == null:
		return
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * 1.18, 0.07)
	tw.tween_property(c, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	glimmer(c)

## P5 式斜切飞入：从 from_offset 方向带旋转飞进来，过冲回弹，结束时轻微抖动
static func slam_in(c: Control, from_offset := Vector2(-520, 0), delay := 0.0, tilt := -9.0) -> Tween:
	var target_pos := c.position
	var target_rot := c.rotation
	c.position = target_pos + from_offset
	c.rotation = deg_to_rad(tilt * 2.2)
	c.modulate.a = 0.0
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(c, "position", target_pos, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "rotation", target_rot, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	tw.set_parallel(false)
	return tw

## SimpleShaker 移植到 UI：衰减抖动
static func shake(c: Control, amp := 8.0, dur := 0.2) -> Tween:
	var base := c.position
	var tw := c.create_tween()
	var steps := 6
	for i in steps:
		var k := 1.0 - float(i) / steps
		tw.tween_property(c, "position", base + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)) * k, dur / steps)
	tw.tween_property(c, "position", base, dur / steps)
	return tw

## UIBounceOnEnable：hop + squash（出现一次）
static func bounce_on_enable(c: Control, hop := 18.0, dur := 0.38, squash := 0.18, rot := 6.0) -> Tween:
	c.pivot_offset = Vector2(c.size.x * 0.5, c.size.y)
	var base := c.position
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.0 + squash, 1.0 - squash), dur * 0.18)
	tw.set_parallel(true)
	tw.tween_property(c, "position:y", base.y - hop, dur * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2(1.0 - squash * 0.5, 1.0 + squash * 0.6), dur * 0.4)
	tw.tween_property(c, "rotation", deg_to_rad(rot), dur * 0.4)
	tw.set_parallel(false)
	tw.set_parallel(true)
	tw.tween_property(c, "position:y", base.y, dur * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "rotation", 0.0, dur * 0.3)
	tw.set_parallel(false)
	tw.tween_property(c, "scale", Vector2(1.0 + squash * 0.6, 1.0 - squash * 0.6), dur * 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, dur * 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tw

## 卡片翻入（3 选 1）：从 scale.x=0 翻开 + 轻微旋转回正（不改 position，容器排版安全）
static func card_flip_in(c: Control, delay := 0.0) -> Tween:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.0, 1.12)
	c.rotation = deg_to_rad(-10)
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.08)
	return tw

## 悬停：放大 + 歪头 + 高光扫过（P5Button 自带 hover，不要再叠加此函数）
static func hover_pop(c: Control, on: bool) -> void:
	if c is P5Button:
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE * (1.07 if on else 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "rotation", deg_to_rad(-2.5 if on else 0.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if on:
		glimmer(c)

## HighlightAnimation：一道骨白斜光扫过（用 Polygon2D，不裁剪父节点）
static func glimmer(c: Control) -> void:
	var g := Polygon2D.new()
	var h := c.size.y
	g.polygon = PackedVector2Array([Vector2(0, 0), Vector2(18, 0), Vector2(18 - h * 0.35, h), Vector2(-h * 0.35, h)])
	g.color = Color(1, 1, 1, 0.38)
	g.position = Vector2(-30, 0)
	c.add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "position:x", c.size.x + h * 0.4, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(g.queue_free)

## 数值变化 punch（耐久/银币跳动）
static func punch(c: Control, strength := 0.22) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + strength), 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## SelectorAnimation：指示器左右往复（循环）
static func selector_loop(c: Control, distance := 10.0, speed := 0.45) -> Tween:
	var base := c.position.x
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "position:x", base + distance, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "position:x", base, speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

## 大字标题砸入（CLEAR!/WARNING/UPGRADE）：从巨大缩小砸下 + 抖屏 + 停留后斜切飞出
static func title_stamp(c: Control, hold := 1.1) -> Tween:
	if c.has_meta("p5_stamp_tw"):
		var old: Tween = c.get_meta("p5_stamp_tw")
		if old != null and old.is_valid():
			old.kill()
	var home: Vector2 = c.get_meta("p5_home", c.position)
	c.set_meta("p5_home", home)
	c.position = home
	c.visible = true
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * 2.6
	c.rotation = deg_to_rad(-14)
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "rotation", deg_to_rad(-6), 0.22)
	tw.tween_property(c, "modulate:a", 1.0, 0.1)
	tw.set_parallel(false)
	tw.tween_callback(func(): shake(c, 14.0, 0.22))
	tw.tween_interval(hold)
	tw.set_parallel(true)
	tw.tween_property(c, "position:x", home.x + 1400, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "rotation", deg_to_rad(8), 0.28)
	tw.set_parallel(false)
	tw.tween_callback(func(): c.visible = false)
	c.set_meta("p5_stamp_tw", tw)
	return tw
