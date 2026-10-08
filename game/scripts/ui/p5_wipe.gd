class_name P5Wipe
extends Control

## C14 全屏斜切转场（参考 P5S 菜单开合：一道红色斜板横扫全屏 → 墨黑斜板跟进 → 面板翻入）。
## 用法：P5Wipe.run(parent_canvas, on_covered_callable)。on_covered 在屏幕被盖住的那一帧调用，
## 在这里切换面板可见性，揭开时新界面已就位。

var t := 0.0
var _colors := [Color("#D9412B"), Color("#1B1B1D")]

static func run(parent: Node, on_covered: Callable = Callable(), dur := 0.42) -> P5Wipe:
	var w := P5Wipe.new()
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	w.z_index = 100
	parent.add_child(w)
	var tw := w.create_tween()
	tw.tween_method(w._set_t, 0.0, 0.5, dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if on_covered.is_valid():
			on_covered.call())
	tw.tween_method(w._set_t, 0.5, 1.0, dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(w.queue_free)
	return w

func _set_t(v: float) -> void:
	t = v
	queue_redraw()

func _draw() -> void:
	var W := size.x
	var H := size.y
	var slant := H * 0.45
	for i in 2:
		# 两道板，第二道（墨黑）晚 0.08 出发，早 0.08 离开；0..0.5 覆盖，0.5..1 从左往右揭开
		var lag := 0.08 * i
		var cover := clampf((t - lag) / (0.5 - lag), 0.0, 1.0) if t < 0.5 else 1.0
		var leave := clampf((t - 0.5) / (0.5 - lag), 0.0, 1.0) if t >= 0.5 else 0.0
		var right_edge := lerpf(-slant, W + slant, ease(cover, 0.6))
		var left_edge := lerpf(-slant, W + slant, ease(leave, 1.6))
		if right_edge <= left_edge:
			continue
		var band := 0.0 if i == 0 else 24.0
		var poly := PackedVector2Array([
			Vector2(left_edge + slant + band, 0), Vector2(right_edge + slant - band, 0),
			Vector2(right_edge - band, H), Vector2(left_edge + band, H)])
		draw_colored_polygon(poly, _colors[i])
