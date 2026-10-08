class_name P5Theme
extends RefCounted

## C14 UI v2 主题层：「P5S 的构图与动效 + 主视觉的切面厚板语言」。
## v1（assets/ui/p5，AI 位图破边框）已废弃：毛边、半调网点、警示条噪声与主视觉冲突。
## v2 规则：
##   - 面板 / 按钮 / 卡框 / 条 / 标题全部程序绘制（P5Plate / P5Button / P5Title），边缘绝对干净；
##   - 只有「图标内容」用 TiMi 生成（assets/ui/v2，切面低多边形，硬边抠图）；
##   - 色板严格取主视觉六色：石油蓝主面、骨白纸面、番茄红强调/选中、赭黄次强调、橡胶黑描边、灰紫点缀；
##   - 字体：Anton（拉丁标题）+ 得意黑（中文），均 OFL。

const DIR := "res://assets/ui/v2"
const LEGACY_DIR := "res://assets/ui/p5"
const BLUE := Color("#23394A")
const BLUE_DEEP := Color("#182A37")
const RED := Color("#D9412B")
const INK := Color("#1B1B1D")
const BONE := Color("#EFE3C8")
const OCHRE := Color("#E3A52B")
const VIOLET := Color("#8C7BA8")
const PETROL := BLUE
## 稀有度：普通 骨白 / 罕见 赭黄 / 稀有 灰紫 / 史诗 番茄红（全部在主视觉色板内）
const RARITY := [BONE, OCHRE, VIOLET, RED]

static var _cache: Dictionary = {}
static var _title_font: Font
static var _body_font: Font

static func title_font() -> Font:
	if _title_font != null:
		return _title_font
	var cjk: Font = load("res://assets/fonts/SmileySans-Oblique.ttf") if ResourceLoader.exists("res://assets/fonts/SmileySans-Oblique.ttf") else null
	var latin: FontFile = load("res://assets/fonts/Anton-Regular.ttf") if ResourceLoader.exists("res://assets/fonts/Anton-Regular.ttf") else null
	if latin != null and cjk != null:
		latin.fallbacks = [cjk]
		_title_font = latin
	elif cjk != null:
		_title_font = cjk
	else:
		_title_font = body_font()
	return _title_font

static func body_font() -> Font:
	if _body_font != null:
		return _body_font
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	sys.font_weight = 700
	var cjk: FontFile = load("res://assets/fonts/SmileySans-Oblique.ttf") if ResourceLoader.exists("res://assets/fonts/SmileySans-Oblique.ttf") else null
	if cjk != null:
		var v := FontVariation.new()
		v.base_font = cjk
		v.fallbacks = [sys]
		_body_font = v
	else:
		_body_font = sys
	return _body_font

## 图标：优先 v2；v1 只作缺失兜底（迁移期）
static func tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var t: Texture2D = null
	for d in [DIR]:
		var path := "%s/%s.png" % [d, id]
		if ResourceLoader.exists(path):
			t = load(path)
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img != null:
				t = ImageTexture.create_from_image(img)
		if t != null:
			break
	_cache[id] = t
	return t

static func pad(l := 22.0, t := 14.0, r := 26.0, b := 14.0) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = l
	sb.content_margin_top = t
	sb.content_margin_right = r
	sb.content_margin_bottom = b
	return sb

## 程序化面板：返回一个 PanelContainer（内容区），背后挂 P5Plate 自动跟随尺寸
static func plate_panel(face := BLUE, accent := RED, content := Vector4(28, 18, 32, 20), skew := 0.06, cut := 18.0) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", pad(content.x, content.y, content.z, content.w))
	var plate := P5Plate.new()
	plate.name = "Plate"
	plate.face_color = face
	plate.accent_color = accent
	plate.skew = skew
	plate.cut = cut
	plate.show_behind_parent = true
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(plate)
	pc.sort_children.connect(func():
		plate.position = Vector2.ZERO
		plate.size = pc.size)
	pc.set_meta("plate", plate)
	return pc

static func plate_of(c: Control) -> P5Plate:
	return c.get_meta("plate") if c != null and c.has_meta("plate") else null

## 兼容旧调用（v1 位图面板）：映射到程序化面板的 StyleBox（无毛边）
static func whole(id: String, content := Vector4(30, 8, 40, 8)) -> StyleBox:
	return pad(content.x, content.y, content.z, content.w)

static func box(_id: String, _m := Vector4.ZERO, content := Vector4(26, 16, 26, 16)) -> StyleBox:
	return pad(content.x, content.y, content.z, content.w)

static func flat(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.skew = Vector2(-0.12, 0)
	sb.anti_aliasing = true
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func build() -> Theme:
	var th := Theme.new()
	th.default_font_size = 18
	th.default_font = body_font()
	th.set_color("font_color", "Label", BONE)
	th.set_color("font_outline_color", "Label", INK)
	th.set_constant("outline_size", "Label", 0)
	th.set_stylebox("panel", "PanelContainer", pad())
	# 普通 Button（非 P5Button，比如 OptionButton/SpinBox 等少量控件）也走干净斜切 flat
	th.set_stylebox("normal", "Button", flat(BLUE, INK))
	th.set_stylebox("hover", "Button", flat(RED, INK))
	th.set_stylebox("focus", "Button", flat(RED, INK))
	th.set_stylebox("pressed", "Button", flat(OCHRE, INK))
	th.set_stylebox("disabled", "Button", flat(BLUE_DEEP, INK))
	th.set_color("font_color", "Button", BONE)
	th.set_color("font_hover_color", "Button", INK)
	th.set_color("font_focus_color", "Button", INK)
	return th

## 标题字：v2 不再用随机剪报块；改为一块干净的红色斜板 + Anton 字（与 P5S 菜单项一致）
static func ransom_label(text: String, size := 30, _seed := 7, face := RED) -> PanelContainer:
	var pc := plate_panel(face, INK, Vector4(16, 2, 22, 4), 0.22, 8.0)
	var pl := plate_of(pc)
	pl.accent_offset = Vector2(-5, 4)
	pl.shadow_offset = Vector2(4, 4)
	pl.show_facet = false
	pc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", BONE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(l)
	pc.rotation = deg_to_rad(-3)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc

static func icon_rect(id: String, px := 40) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(id)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## 程序化进度条（耐久/载荷）：斜切槽 + 填充，返回 [root, fill]
static func bar(width := 180.0, height := 12.0, fill_color := RED) -> Array:
	var root := Control.new()
	root.custom_minimum_size = Vector2(width, height)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := P5Plate.new()
	back.face_color = BLUE_DEEP
	back.show_accent = false
	back.show_facet = false
	back.skew = 0.6
	back.cut = 0.0
	back.shadow_offset = Vector2(2, 2)
	back.outline_width = 1.5
	back.size = Vector2(width, height)
	root.add_child(back)
	var fill := P5Plate.new()
	fill.face_color = fill_color
	fill.show_accent = false
	fill.show_facet = false
	fill.skew = 0.6
	fill.cut = 0.0
	fill.shadow_offset = Vector2.ZERO
	fill.outline_width = 0.0
	fill.position = Vector2(3, 2)
	fill.size = Vector2(width - 6, height - 4)
	fill.set_meta("full_width", width - 6)
	root.add_child(fill)
	return [root, fill]

static func set_bar(fill: P5Plate, ratio: float) -> void:
	var full: float = fill.get_meta("full_width", fill.size.x)
	var target := maxf(2.0, full * clampf(ratio, 0.0, 1.0))
	if absf(fill.size.x - target) > 0.5:
		var tw := fill.create_tween()
		tw.tween_property(fill, "size:x", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
