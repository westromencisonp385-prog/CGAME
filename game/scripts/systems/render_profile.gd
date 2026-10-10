class_name RenderProfile
extends RefCounted

## C25 渲染配置（画面清晰度 + 景深层次 + 边缘光）。所有画面参数集中在这里。
## 诊断出的“糊”的来源与对策：
##   1. 全场景均匀距离雾：正交俯视相机离地 ~65m，雾密度 0.006 → 每个像素都被盖上 ~30% 灰蓝 → 发灰发闷
##      对策：关掉距离雾（正交镜头下距离雾不产生前后层次，只会整体蒙一层）
##   2. 无抗锯齿：墨线描边和模型边缘全是锯齿、移动时闪
##      对策：MSAA 4x（不用 TAA / FXAA，它们会让画面更糊）
##   3. 地面贴图 45° 斜看只用 2x 各向异性 → 地表一片模糊
##      对策：16x 各向异性 + 地面着色器改用各向异性采样
##   4. 环境光太强（0.65）+ toon 粗糙度 1（明暗交界拉成大渐变）→ 物体没有体积、阴影浅
##      对策：主光更亮、环境光压低并偏冷（暖光冷影）、toon 交界变锐、SSAO 做接地接触阴影
##   5. Mobile 渲染器不支持 SSAO → 改 Forward+
##   6. 物体和地面同明度、没有轮廓分离 → 加边缘光（按阵营分色）

## 主光（暖）
const KEY_COLOR := Color("#FFE6C4")
const KEY_ENERGY := 1.55
const KEY_ROT := Vector3(-52, -32, 0)
## 背光（冷）：从背面打，给物体顶部 / 背面一道冷色轮廓
const BACK_COLOR := Color("#9FC8E0")
const BACK_ENERGY := 0.55
const BACK_ROT := Vector3(-28, 148, 0)
## 环境光（冷，压低）：阴影里偏蓝，和暖色受光面拉开
const AMBIENT_ENERGY := 0.38

## 边缘光三类：自己人（暖骨白）、敌人（番茄红）、场景（冷、很弱，只做轮廓分离）
const RIM := {
	"hero": {"color": Color("#FFE3B0"), "strength": 1.25, "power": 2.6},
	"foe": {"color": Color("#FF5A3C"), "strength": 1.35, "power": 2.6},
	"world": {"color": Color("#D6E8F2"), "strength": 0.45, "power": 2.6},
}

static func rim_class_for(slot: String) -> String:
	if slot.begins_with("enemy_") or slot.begins_with("boss_0"):
		return "foe"
	if slot.begins_with("player_") or slot.begins_with("module_") or slot.begins_with("summon_"):
		return "hero"
	return "world"

## 主光方向（世界空间，指向光源）
static func key_dir() -> Vector3:
	var b := Basis.from_euler(Vector3(deg_to_rad(KEY_ROT.x), deg_to_rad(KEY_ROT.y), 0))
	return (b * Vector3(0, 0, 1)).normalized()

static func build_lights(parent: Node3D) -> Array:
	var key := DirectionalLight3D.new()
	key.name = "WarmWorklight"
	key.rotation_degrees = KEY_ROT
	key.light_color = KEY_COLOR
	key.light_energy = KEY_ENERGY
	key.shadow_enabled = true
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.2
	key.shadow_blur = 0.6
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_max_distance = 110.0
	key.directional_shadow_split_1 = 0.55
	key.directional_shadow_blend_splits = true
	key.light_angular_distance = 0.0
	parent.add_child(key)
	var back := DirectionalLight3D.new()
	back.name = "CoolRimFill"
	back.rotation_degrees = BACK_ROT
	back.light_color = BACK_COLOR
	back.light_energy = BACK_ENERGY
	back.shadow_enabled = false
	back.light_specular = 0.0
	parent.add_child(back)
	return [key, back]

static func build_environment(bg: Color, ambient: Color) -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambient
	e.ambient_light_energy = AMBIENT_ENERGY
	e.fog_enabled = false
	# ACES：比 Filmic 对比更清楚、颜色不发灰
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.95
	e.tonemap_white = 6.0
	# 接地接触阴影：物体落脚处一圈暗，立刻“站”在地上
	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 2.2
	e.ssao_power = 1.6
	e.ssao_detail = 0.6
	e.ssao_horizon = 0.06
	e.ssao_sharpness = 0.98
	e.ssao_light_affect = 0.25
	e.ssao_ao_channel_affect = 0.0
	# 轻微提对比与饱和度（调色，不模糊）
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.08
	e.adjustment_brightness = 1.0
	return e
