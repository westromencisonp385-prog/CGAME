class_name SelectionUI
extends CanvasLayer

## 四套升级选择面板（对齐 ModuleSelection 四套选择流 + reroll）。纯展示层，提交走 option_chosen。
## C14 v2 视觉：参考 P5S 菜单/卡片——
##   打开：全屏红黑斜切转场 → 背景压暗 + 一道巨大的红色斜板 → 标题板刷出 → 三张卡依次翻入
##   卡片：程序绘制切面卡（石油蓝卡体 + 稀有度色错位板 + 骨白文字窗），稀有度色取主视觉色板
##   hover：卡片上浮 18px 放大 8%、错位板拉开、其他卡压暗退后（P5S 选中项弹出、其余退场）

signal option_chosen(kind: String, index: int)
signal reroll_requested(kind: String)
## 选中卡飞到目标后发出（headless 下立即发出）
signal pick_landed(kind: String)
## 返回飞卡目标屏幕坐标：func(kind: String) -> Vector2
var target_provider: Callable
var _outro_layer: CanvasLayer

const RARITY_NAMES: Array[String] = ["普通", "罕见", "稀有", "史诗"]
const KIND_TITLES := {
	"new_module": "选择新模块",
	"upgrade": "模块升级",
	"artifact": "选择神器",
	"artifact_rare": "选择稀有神器",
	"vehicle": "载具升级",
	"captain": "雇佣船长",
}
const KIND_BANNERS := {
	"new_module": "NEW MODULE",
	"upgrade": "UPGRADE",
	"artifact": "ARTIFACT",
	"artifact_rare": "RARE ARTIFACT",
	"vehicle": "EVOLVE",
	"captain": "CAPTAIN",
}
const CARD_SIZE := Vector2(236, 344)

var root: Control
var dim: ColorRect
var slab: P5Plate
var title_holder: Control
var title_label: Label
var cards_root: HBoxContainer
var reroll_button: Button
## 兼容旧引用
var panel: Control
var title_row: Control
var current_kind := ""
var current_options: Array = []
var _cards: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	_build_ui()

func _build_ui() -> void:
	root = Control.new()
	root.theme = P5Theme.build()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	dim = ColorRect.new()
	dim.color = Color(P5Theme.INK, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	# 背景大斜板（P5S 菜单背后的整块红色）
	slab = P5Plate.new()
	slab.face_color = P5Theme.RED
	slab.accent_color = P5Theme.BLUE
	slab.accent_offset = Vector2(-30, 26)
	slab.shadow_offset = Vector2.ZERO
	slab.show_facet = false
	slab.skew = 0.35
	slab.cut = 0.0
	slab.position = Vector2(-120, 150)
	slab.size = Vector2(1520, 400)
	slab.rotation = deg_to_rad(-6)
	root.add_child(slab)
	panel = slab
	title_holder = Control.new()
	title_holder.position = Vector2(470, 40)
	title_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_holder)
	title_row = title_holder
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", P5Theme.BONE)
	title_label.position = Vector2(500, 112)
	root.add_child(title_label)
	cards_root = HBoxContainer.new()
	cards_root.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_root.add_theme_constant_override("separation", 34)
	cards_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cards_root.offset_top = 176
	cards_root.offset_bottom = 176 + CARD_SIZE.y + 30
	root.add_child(cards_root)
	reroll_button = P5Button.new()
	reroll_button.text = "重掷  R"
	reroll_button.focus_mode = Control.FOCUS_NONE
	reroll_button.icon = P5Theme.tex("icon_reroll")
	reroll_button.expand_icon = true
	reroll_button.add_theme_constant_override("icon_max_width", 26)
	reroll_button.custom_minimum_size = Vector2(200, 46)
	reroll_button.position = Vector2(540, 600)
	reroll_button.pressed.connect(func(): reroll_requested.emit(current_kind))
	root.add_child(reroll_button)

## options 元素：模块/神器为 Resource；升级为 {module, upgrade}；载具为 {stats, title, bonus_lines}。
func open_selection(kind: String, options: Array, subtitle := "") -> void:
	current_kind = kind
	current_options = options
	title_label.text = KIND_TITLES.get(kind, kind) + (("  ·  " + subtitle) if not subtitle.is_empty() else "")
	for c in title_holder.get_children():
		c.queue_free()
	var banner := P5Theme.ransom_label(KIND_BANNERS.get(kind, "PICK ONE"), 52, 0, P5Theme.INK)
	title_holder.add_child(banner)
	_rebuild_cards(options)
	visible = true
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	_play_open(banner)
	# C27 不用鼠标：卡片入场后把焦点给第一张（A/D 切换、空格 / 回车确认）
	await get_tree().create_timer(0.3, true, false, true).timeout
	if visible and not _cards.is_empty() and is_instance_valid(_cards[0]):
		_cards[0].grab_focus()

## C27 键盘 / 手柄选卡：1 2 3 直接选、R 重掷；左右切换和确认交给焦点系统（WASD 已加进 ui_*）
func _input(event: InputEvent) -> void:
	if not visible or outro_running() or not (event is InputEventKey) or not event.pressed or (event as InputEventKey).echo:
		return
	var code := (event as InputEventKey).physical_keycode
	var idx := [KEY_1, KEY_2, KEY_3, KEY_4].find(code)
	if idx >= 0 and idx < _cards.size():
		get_viewport().set_input_as_handled()
		_choose(idx)
	elif code == KEY_R and reroll_button.visible and not reroll_button.disabled:
		get_viewport().set_input_as_handled()
		reroll_requested.emit(current_kind)
	elif _cards.size() > 0 and get_viewport().gui_get_focus_owner() == null and (event.is_action("ui_left") or event.is_action("ui_right") or event.is_action("ui_accept")):
		get_viewport().set_input_as_handled()
		_cards[0].grab_focus()

func _play_open(banner: Control) -> void:
	dim.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.12)
	slab.reveal_t = 0.0
	tw.parallel().tween_method(slab.set_reveal, 0.0, 1.0, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	P5Motion.slam_in(banner, Vector2(-500, 0), 0.08, -3.0)
	title_label.modulate.a = 0.0
	tw.parallel().tween_property(title_label, "modulate:a", 1.0, 0.2).set_delay(0.18)
	for i in _cards.size():
		P5Motion.card_flip_in(_cards[i], 0.16 + i * 0.07)
	reroll_button.modulate.a = 0.0
	tw.parallel().tween_property(reroll_button, "modulate:a", 1.0, 0.18).set_delay(0.4)

func _rebuild_cards(options: Array) -> void:
	for child in cards_root.get_children():
		cards_root.remove_child(child)
		child.queue_free()
	_cards.clear()
	for i in options.size():
		var c := _make_card(i, options[i])
		cards_root.add_child(c)
		_cards.append(c)

func _make_card(index: int, option: Variant) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.flat = true
	card.focus_mode = Control.FOCUS_ALL
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		card.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var rarity := clampi(_rarity_of(option), 0, 3)
	var rc: Color = P5Theme.RARITY[rarity]
	# 卡体
	var body := P5Plate.new()
	body.name = "Body"
	body.size = CARD_SIZE
	body.face_color = P5Theme.BLUE
	body.accent_color = rc
	body.accent_offset = Vector2(-10, 10)
	body.shadow_offset = Vector2(8, 10)
	body.skew = 0.05
	body.cut = 26.0
	body.tab_cut = 18.0
	card.add_child(body)
	# 插画窗：深一档的切面块 + 图标
	var win := P5Plate.new()
	win.position = Vector2(26, 34)
	win.size = Vector2(CARD_SIZE.x - 48, 150)
	win.face_color = P5Theme.BLUE_DEEP
	win.show_accent = false
	win.shadow_offset = Vector2.ZERO
	win.skew = 0.05
	win.cut = 14.0
	win.outline_width = 1.5
	card.add_child(win)
	var art := P5Theme.icon_rect(_icon_of(option), 124)
	art.position = Vector2((CARD_SIZE.x - 124) * 0.5, 46)
	art.size = Vector2(124, 124)
	art.name = "Art"
	card.add_child(art)
	# 稀有度签
	var badge := P5Theme.ransom_label(RARITY_NAMES[rarity], 16, 0, rc)
	badge.position = Vector2(12, 4)
	card.add_child(badge)
	if rarity == 0 or rarity == 1:
		(badge.get_child(1) as Label).add_theme_color_override("font_color", P5Theme.INK)
	# 文字窗：骨白纸面
	var paper := P5Plate.new()
	paper.position = Vector2(18, 200)
	paper.size = Vector2(CARD_SIZE.x - 34, 122)
	paper.face_color = P5Theme.BONE
	paper.show_accent = false
	paper.show_facet = false
	paper.shadow_offset = Vector2(4, 4)
	paper.skew = 0.04
	paper.cut = 12.0
	paper.outline_width = 1.5
	card.add_child(paper)
	var lines := _describe(option)
	var title := Label.new()
	title.text = str(lines[0])
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", P5Theme.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.position = Vector2(30, 208)
	title.size = Vector2(CARD_SIZE.x - 58, 30)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)
	var rule := ColorRect.new()
	rule.color = rc if rarity >= 2 else P5Theme.RED
	rule.position = Vector2(CARD_SIZE.x * 0.5 - 30, 240)
	rule.size = Vector2(60, 3)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rule)
	var desc := Label.new()
	desc.text = "\n".join(lines.slice(1))
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color("#3B4650"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.position = Vector2(30, 248)
	desc.size = Vector2(CARD_SIZE.x - 58, 68)
	desc.clip_text = true
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(desc)
	for c in card.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.pressed.connect(func(): _choose(index))
	card.mouse_entered.connect(func(): _hover(card, true))
	card.mouse_exited.connect(func(): if not card.has_focus(): _hover(card, false))
	card.focus_entered.connect(func(): _hover(card, true))
	card.focus_exited.connect(func(): _hover(card, false))
	return card

## P5S 选中卡弹出、其余退后
func _hover(card: Button, on: bool) -> void:
	var body := card.get_node("Body") as P5Plate
	body.set_hover(on)
	card.pivot_offset = CARD_SIZE * 0.5
	var tw := card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE * (1.08 if on else 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "rotation", deg_to_rad(-2.5 if on else 0.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var art := card.get_node("Art") as Control
	tw.tween_property(art, "scale", Vector2.ONE * (1.12 if on else 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	art.pivot_offset = art.size * 0.5
	tw.tween_property(body, "face_color", P5Theme.BLUE.lightened(0.08) if on else P5Theme.BLUE, 0.12)
	if on:
		P5Motion.glimmer(card)
	for other in _cards:
		if other != card:
			other.create_tween().tween_property(other, "modulate", Color(0.62, 0.62, 0.66) if on else Color.WHITE, 0.14)

func _icon_of(option: Variant) -> String:
	if option is ArtifactDefinition:
		return "icon_artifact"
	if option is CaptainDefinition:
		return "icon_captain"
	if option is ModuleDefinitionV2:
		var id: String = option.module_id
		if id.begins_with("turret") or id == "top_cannon_tower" or id == "barracks":
			return "skill_turret"
		if id == "mage_storm":
			return "skill_arc"
		if id == "mage_cryo":
			return "skill_water"
		if id.begins_with("crew_medic") or id == "crew_engineer":
			return "skill_camp"
		if id == "arms_dealer":
			return "icon_gold"
		return "icon_module"
	if option is Dictionary and option.has("stats"):
		return "icon_cargo"
	return "icon_module"

func _choose(index: int) -> void:
	var kind := current_kind
	var headless := DisplayServer.get_name() == "headless"
	if not headless and index >= 0 and index < _cards.size() and is_inside_tree():
		_play_pick_outro(kind, index)
	visible = false
	current_options = []
	current_kind = ""
	option_chosen.emit(kind, index)
	if headless or _outro_layer == null:
		pick_landed.emit(kind)

func outro_running() -> bool:
	return _outro_layer != null and is_instance_valid(_outro_layer)

## P5S 式“选定”：选中卡放大 + 闪白 + 盖章；其余卡往下掉并淡出；背景退场；
## 选中卡停 0.2s 后缩小旋转着飞进目标（技能槽 / 车身），落地那一刻 pick_landed
func _play_pick_outro(kind: String, index: int) -> void:
	if outro_running():
		_outro_layer.queue_free()
	_outro_layer = CanvasLayer.new()
	_outro_layer.name = "PickOutro"
	_outro_layer.layer = 21
	_outro_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().add_child(_outro_layer)
	var layer := _outro_layer
	var o_root := Control.new()
	o_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o_root.theme = root.theme
	layer.add_child(o_root)
	var ghost_dim := ColorRect.new()
	ghost_dim.color = dim.color
	ghost_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ghost_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o_root.add_child(ghost_dim)
	var cards := _cards.duplicate()
	_cards.clear()
	var chosen: Button = null
	for i in cards.size():
		var c: Button = cards[i]
		c.pivot_offset = CARD_SIZE * 0.5
		var xf := c.get_global_transform_with_canvas()
		var piv := c.pivot_offset
		var gp := xf.origin - piv + xf.basis_xform(piv)
		var sc := c.scale
		var rot := c.rotation
		c.get_parent().remove_child(c)
		o_root.add_child(c)
		c.position = gp
		c.scale = sc
		c.rotation = rot
		c.disabled = true
		c.focus_mode = Control.FOCUS_NONE
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == index:
			chosen = c
		else:
			var tw := c.create_tween().set_parallel(true)
			tw.set_ignore_time_scale(true)
			tw.tween_property(c, "position:y", c.position.y + 420.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_property(c, "rotation", c.rotation + deg_to_rad(-14.0 if i < index else 14.0), 0.32)
			tw.tween_property(c, "modulate:a", 0.0, 0.3)
	o_root.move_child(chosen, -1)
	WanderburgAudio.hit("card_pick", -8.0, 0.0)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o_root.add_child(flash)
	var stamp := P5Theme.ransom_label("GET!", 40, 0, P5Theme.RED)
	stamp.position = chosen.position + Vector2(CARD_SIZE.x * 0.5 - 50, -36)
	stamp.pivot_offset = Vector2(50, 24)
	stamp.scale = Vector2.ONE * 2.2
	stamp.modulate.a = 0.0
	stamp.rotation = deg_to_rad(-10)
	o_root.add_child(stamp)
	chosen.pivot_offset = CARD_SIZE * 0.5
	var body := chosen.get_node_or_null("Body") as P5Plate
	var t := chosen.create_tween()
	t.set_ignore_time_scale(true)
	# 1) 选定：砸大 + 闪白 + 盖章
	t.tween_property(chosen, "scale", Vector2.ONE * 1.22, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(chosen, "rotation", deg_to_rad(3.0), 0.09)
	t.parallel().tween_property(flash, "color:a", 0.45, 0.05)
	t.parallel().tween_property(stamp, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(stamp, "modulate:a", 1.0, 0.06)
	if body != null:
		body.set_hover(true)
	t.tween_property(flash, "color:a", 0.0, 0.16)
	t.parallel().tween_property(chosen, "scale", Vector2.ONE * 1.12, 0.16)
	t.parallel().tween_property(ghost_dim, "color:a", 0.0, 0.35)
	# 2) 停顿（让玩家看清选了什么）
	t.tween_interval(0.12)
	# 3) 预备：往反方向一缩 → 飞向目标
	t.tween_property(chosen, "scale", Vector2.ONE * 1.2, 0.07)
	t.parallel().tween_property(stamp, "modulate:a", 0.0, 0.1)
	t.tween_callback(func():
		var target := Vector2(640, 420)
		if target_provider.is_valid():
			target = target_provider.call(kind)
		var start := chosen.position + CARD_SIZE * 0.5
		var fly := chosen.create_tween().set_parallel(true)
		fly.set_ignore_time_scale(true)
		fly.tween_method(func(u: float):
			var k := u * u
			var mid := start.lerp(target, 0.5) + Vector2(0, -160)
			var p := start.lerp(mid, u).lerp(mid.lerp(target, u), u)
			chosen.position = p - CARD_SIZE * 0.5
			chosen.scale = Vector2.ONE * lerpf(1.2, 0.12, k)
			chosen.rotation = lerpf(deg_to_rad(3.0), deg_to_rad(-200.0), k), 0.0, 1.0, 0.34)
		fly.chain().tween_callback(func():
			pick_landed.emit(kind)
			_landing_burst(o_root, target)
			var end := layer.create_tween()
			end.set_ignore_time_scale(true)
			end.tween_interval(0.35)
			end.tween_callback(layer.queue_free)
			chosen.visible = false))

## 落点：一圈骨白斜线火花（2D）
func _landing_burst(parent: Control, at: Vector2) -> void:
	for i in 10:
		var r := ColorRect.new()
		r.color = P5Theme.BONE if i % 2 == 0 else P5Theme.OCHRE
		r.size = Vector2(22, 5)
		r.pivot_offset = Vector2(0, 2.5)
		r.position = at
		var a := TAU * float(i) / 10.0
		r.rotation = a
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(r)
		var tw := r.create_tween().set_parallel(true)
		tw.set_ignore_time_scale(true)
		tw.tween_property(r, "position", at + Vector2(cos(a), sin(a)) * 64.0, 0.26).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(r, "scale:x", 0.1, 0.26)
		tw.tween_property(r, "modulate:a", 0.0, 0.26)

func _rarity_of(option: Variant) -> int:
	if option is ModuleDefinitionV2:
		return _rarity_from_weight(option.rarity)
	if option is ArtifactDefinition:
		return 3 if option.rare else 1
	if option is Dictionary and option.has("upgrade"):
		return clampi(int(option["upgrade"].rarity_index), 0, 3)
	return 0

func _rarity_from_weight(weight: float) -> int:
	if weight >= 3.0:
		return 0
	if weight >= 2.0:
		return 1
	if weight >= 1.0:
		return 2
	return 3

func _describe(option: Variant) -> Array:
	if option is ModuleDefinitionV2:
		return [option.module_name, option.module_description]
	if option is ArtifactDefinition:
		return [option.display_name, option.description]
	if option is CaptainDefinition:
		return ["船长 · %s" % option.display_name, option.description, "雇佣 60 银币"]
	if option is Dictionary and option.has("upgrade"):
		var upgrade: UpgradeDefinition = option["upgrade"]
		var module: ModuleDefinitionV2 = option["module"]
		return ["%s · %s" % [module.module_name, upgrade.display_name], upgrade.description]
	if option is Dictionary and option.has("stats"):
		return [option["title"], "\n".join(PackedStringArray(option["bonus_lines"]))]
	return ["?", ""]

## 演示钩子：接 SelectionEngine 跑一轮完整选择流（供 F7 触发与测试）。
static func run_demo(engine: SelectionEngine, _ui: SelectionUI, kind: String) -> Array:
	match kind:
		"new_module":
			return engine.generate_new_modules()
		"artifact":
			return engine.generate_artifacts(false)
		"vehicle":
			return engine.generate_vehicle_upgrades(engine.vehicle_tiers[0] if not engine.vehicle_tiers.is_empty() else VehicleStats.new())
		"upgrade":
			return engine.generate_upgrades()
	return []
