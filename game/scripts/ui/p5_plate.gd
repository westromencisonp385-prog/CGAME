class_name P5Plate
extends Control

## C14 UI v2 核心组件：程序绘制的「切面纸板」。
## 设计依据：P5S 菜单（参考 BV1c54y1j7Gk）= 硬边斜切色块 + 错位底板 + 选中项弹出放大；
## 主视觉（style-anchor-industrial-folk-v1）= 厚板切面、哑光色块、细墨线、无噪声。
## 所以：不用位图边框（AI 图的毛边/噪声去不掉），全部用多边形 + 抗锯齿描边绘制，
## 任意尺寸边缘都干净，且每个角点都能独立做动效。
##
## 结构（从下到上）：shadow（墨黑偏移）→ accent（强调色错位板）→ face（主面）→ facet（一条暗切面）→ outline。

signal hovered_changed(on: bool)

@export var face_color := Color("#23394A"):
	set(v):
		face_color = v
		queue_redraw()
@export var accent_color := Color("#D9412B")
@export var outline_color := Color("#1B1B1D")
@export var skew := 0.12            ## 平行四边形斜率（相对高度）
@export var cut := 14.0             ## 右上角斜切大小（px）
@export var tab_cut := 0.0          ## 左下角斜切（0 = 无）
@export var accent_offset := Vector2(-8, 7)
@export var shadow_offset := Vector2(6, 8)
@export var show_accent := true
@export var show_facet := true
@export var outline_width := 2.0
@export var interactive := false    ## true 时自带 hover/press 动效

## 动效状态（0..1），由 P5Motion 或自身 hover 驱动
var hover_t := 0.0
var press_t := 0.0
var reveal_t := 1.0                 ## 0 = 收成一条线，1 = 完全展开（开场动画用）
var jitter := 0.0                   ## 角点轻微抖动幅度（P5 选中项的「活」感）
var _time := 0.0
var _hover := false
var _hover_tw: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	if interactive:
		mouse_entered.connect(func(): set_hover(true))
		mouse_exited.connect(func(): set_hover(false))
		focus_entered.connect(func(): set_hover(true))
		focus_exited.connect(func(): set_hover(false))
	resized.connect(queue_redraw)

func set_hover(on: bool) -> void:
	if _hover == on:
		return
	_hover = on
	if _hover_tw != null and _hover_tw.is_valid():
		_hover_tw.kill()
	_hover_tw = create_tween()
	# 进：快速过冲（P5 选中项「弹出」）；出：平滑收回
	if on:
		_hover_tw.tween_method(_set_hover_t, hover_t, 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_hover_tw.tween_method(_set_hover_t, hover_t, 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hovered_changed.emit(on)

func _set_hover_t(v: float) -> void:
	hover_t = v
	queue_redraw()

func press() -> void:
	var tw := create_tween()
	tw.tween_method(_set_press_t, 0.0, 1.0, 0.05)
	tw.tween_method(_set_press_t, 1.0, 0.0, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _set_press_t(v: float) -> void:
	press_t = v
	queue_redraw()

func set_reveal(v: float) -> void:
	reveal_t = v
	queue_redraw()

func _process(delta: float) -> void:
	if jitter > 0.0 or hover_t > 0.01:
		_time += delta
		queue_redraw()

## 主面多边形（局部坐标）：平行四边形 + 右上斜切 + 可选左下斜切
func face_polygon(grow := 0.0) -> PackedVector2Array:
	var w := size.x
	var h := size.y
	var s := skew * h
	var c := cut
	var t := tab_cut
	var pts := PackedVector2Array([
		Vector2(s - grow, -grow),
		Vector2(w - c + grow, -grow),
		Vector2(w + grow, c - grow * 0.4),
		Vector2(w - s + grow, h + grow),
	])
	if t > 0.0:
		pts.append(Vector2(t - grow, h + grow))
		pts.append(Vector2(-grow, h - t + grow * 0.4))
	else:
		pts.append(Vector2(-grow, h + grow))
	# 开场：从中线横向展开（P5 的「刷出来」）
	if reveal_t < 1.0:
		var cx := w * 0.5
		var k := ease(clampf(reveal_t, 0.0, 1.0), 0.35)
		for i in pts.size():
			pts[i].x = cx + (pts[i].x - cx) * k
			pts[i].y = h * 0.5 + (pts[i].y - h * 0.5) * minf(1.0, k * 1.6)
	if jitter > 0.0:
		for i in pts.size():
			pts[i] += Vector2(sin(_time * 7.0 + i * 1.7), cos(_time * 6.0 + i * 2.3)) * jitter
	return pts

func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0 or reveal_t <= 0.0:
		return
	var hv := hover_t
	var pr := press_t
	# hover：整体右上微移 + 错位板拉开 + 强调色加深；press：下压
	var lift := Vector2(4, -3) * hv + Vector2(-2, 3) * pr
	var acc_off := accent_offset * (1.0 + hv * 0.9)
	draw_set_transform(lift)
	var face := face_polygon()
	# shadow
	draw_colored_polygon(_offset(face, shadow_offset * (1.0 + hv * 0.5)), Color(outline_color, 0.85))
	# accent plate
	if show_accent:
		draw_colored_polygon(_offset(face_polygon(2.0), acc_off), accent_color)
	# face
	var fc := face_color.lerp(accent_color, 0.0)
	draw_colored_polygon(face, fc)
	# facet：沿底边一条暗切面，给「厚板」体积（主视觉的三档明暗）
	if show_facet:
		var h := size.y
		var band := minf(h * 0.22, 14.0)
		var bottom := PackedVector2Array([
			face[face.size() - 1] if tab_cut <= 0.0 else face[face.size() - 2],
			face[3],
			face[3] + Vector2(-skew * band, -band),
			(face[face.size() - 1] if tab_cut <= 0.0 else face[face.size() - 2]) + Vector2(-skew * band, -band),
		])
		draw_colored_polygon(bottom, fc.darkened(0.22))
		# 顶边一条亮切线
		draw_line(face[0] + Vector2(2, 2), face[1] + Vector2(-2, 2), fc.lightened(0.16), 2.0, true)
	# outline
	var loop := face.duplicate()
	loop.append(face[0])
	draw_polyline(loop, outline_color, outline_width, true)
	draw_set_transform(Vector2.ZERO)

func _offset(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out
