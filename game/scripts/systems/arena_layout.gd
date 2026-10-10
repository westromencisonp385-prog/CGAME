class_name ArenaLayout
extends RefCounted

## C28 场地布局：唯一的场地尺寸与兴趣点真源（docs/design/level-v1.md）。
## 原作刷怪在镜头外（waveSpawnDistance 120~250，MapEdgePadding 15）；我们的镜头一屏约 34×27 米，
## 场地扩到 104×92 米，中心保留河道工地，四周放敌巢 / 废料场 / Boss 场，土路连起来。

const HALF := Vector2(52.0, 46.0)        # 可玩区半宽（x）/ 半深（z）
const WALL_INSET := 0.4                   # 围墙在边界外多少米
const EDGE_PAD := 3.0                     # 刷怪 / 摆放离墙至少多少米
const PLAYER_START := Vector3(0, 0.5, 7)
const RIVER_X := 9.0
const RIVER_HALF_W := 5.3

## 兴趣点（xz）。nest = 敌巢，scrap = 废料场，boss = Boss 场中心，yard = 中央工地
const NESTS := [Vector2(-34, -28), Vector2(32, -30), Vector2(-33, 27)]
const SCRAP_FIELDS := [Vector2(-40, 2), Vector2(38, 8), Vector2(-6, 34), Vector2(24, 30)]
const BOSS_ARENA := Vector2(-4, -32)
const YARD := Vector2(0, 0.5)

## 土路：从工地连到各兴趣点（a.xy → b.xy，宽度在 shader 里统一）
static func roads() -> Array:
	var out := []
	for p in NESTS + SCRAP_FIELDS:
		out.append([YARD, p])
	out.append([YARD, BOSS_ARENA])
	return out

## 空地（地表铺土 + 不撒草）：中心 + 半径
static func clearings() -> Array:
	var out := []
	for p in NESTS:
		out.append([p, 7.5])
	for p in SCRAP_FIELDS:
		out.append([p, 6.5])
	out.append([BOSS_ARENA, 10.0])
	return out

static func clamp_inside(p: Vector3, pad := EDGE_PAD) -> Vector3:
	return Vector3(clampf(p.x, -HALF.x + pad, HALF.x - pad), p.y, clampf(p.z, -HALF.y + pad, HALF.y - pad))

static func inside(p: Vector3, pad := 0.0) -> bool:
	return absf(p.x) <= HALF.x - pad and absf(p.z) <= HALF.y - pad

## 镜头可见范围的半宽 / 半深（正交 45°：size 是竖向世界高度，地面深度 = size / sin45）
static func view_half(cam_size: float, aspect := 16.0 / 9.0) -> Vector2:
	return Vector2(cam_size * aspect * 0.5, cam_size / sin(deg_to_rad(45.0)) * 0.5)

## 屏幕外刷怪距离：视野对角半径 + 余量
static func offscreen_radius(cam_size: float, margin := 4.0) -> float:
	var vh := view_half(cam_size)
	return maxf(vh.x, vh.y) + margin

## 点是否在当前视野内（以 focus 为中心）
static func in_view(p: Vector3, focus: Vector3, cam_size: float, shrink := 0.0) -> bool:
	var vh := view_half(cam_size)
	return absf(p.x - focus.x) < vh.x - shrink and absf(p.z - focus.z) < vh.y - shrink

## 是否离兴趣点 / 工地太近（散布避让用）
static func near_poi(p: Vector2, extra := 0.0) -> bool:
	for c in clearings():
		if p.distance_to(c[0]) < float(c[1]) + extra:
			return true
	return false

static func on_road(p: Vector2, half_w := 1.8) -> bool:
	for r in roads():
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if p.distance_to(a + ab * t) < half_w:
			return true
	return false
