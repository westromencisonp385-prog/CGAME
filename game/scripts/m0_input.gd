class_name M0Input
extends RefCounted

## C27 键位 = Wanderburg 原作 Vehicle 动作表（data.unity3d 里的 InputActionAsset，docs/research/wanderburg-controls.md）：
##   移动 WASD / 左摇杆；4 个主动技能 Q E R 空格 / 手柄 Y B A X；加速（我们是冲刺）Shift / LT；
##   攻击全部自动，不用鼠标。方向键也能开车；右摇杆可选手动瞄准（原作 Aim）。
## 召唤 3 个不常用：Z X C（数字 5 6 7 也行）/ 手柄十字键左 上 右。数字 1-4 也能放技能。
const SKILL_KEYS := [[KEY_Q, KEY_1], [KEY_E, KEY_2], [KEY_R, KEY_3], [KEY_SPACE, KEY_4]]
const SKILL_PADS := [JOY_BUTTON_Y, JOY_BUTTON_B, JOY_BUTTON_A, JOY_BUTTON_X]
const SUMMON_KEYS := [[KEY_Z, KEY_5], [KEY_X, KEY_6], [KEY_C, KEY_7]]
const SUMMON_PADS := [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT]
const SKILL_LABELS := ["Q", "E", "R", "空格"]
const SUMMON_LABELS := ["Z", "X", "C"]

static func _reset(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_erase_events(action)

static func _key(action: String, code: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	InputMap.action_add_event(action, key)

static func _pad(action: String, button: JoyButton) -> void:
	var b := InputEventJoypadButton.new()
	b.button_index = button
	InputMap.action_add_event(action, b)

static func _axis(action: String, axis: JoyAxis, value: float) -> void:
	var a := InputEventJoypadMotion.new()
	a.axis = axis
	a.axis_value = value
	InputMap.action_add_event(action, a)

static func configure() -> void:
	var move := {"move_left": [KEY_A, KEY_LEFT, JOY_AXIS_LEFT_X, -1.0], "move_right": [KEY_D, KEY_RIGHT, JOY_AXIS_LEFT_X, 1.0],
		"move_up": [KEY_W, KEY_UP, JOY_AXIS_LEFT_Y, -1.0], "move_down": [KEY_S, KEY_DOWN, JOY_AXIS_LEFT_Y, 1.0]}
	for action in move:
		_reset(action)
		_key(action, move[action][0])
		_key(action, move[action][1])
		_axis(action, move[action][2], move[action][3])
	# 手动瞄准只留右摇杆（可选覆盖自动瞄准）
	var aim := {"aim_left": [JOY_AXIS_RIGHT_X, -1.0], "aim_right": [JOY_AXIS_RIGHT_X, 1.0], "aim_up": [JOY_AXIS_RIGHT_Y, -1.0], "aim_down": [JOY_AXIS_RIGHT_Y, 1.0]}
	for action in aim:
		_reset(action)
		_axis(action, aim[action][0], aim[action][1])
	for i in 4:
		var action := "skill_%d" % (i + 1)
		_reset(action)
		for k in SKILL_KEYS[i]:
			_key(action, k)
		_pad(action, SKILL_PADS[i])
	for i in 3:
		var action := "summon_%d" % (i + 1)
		_reset(action)
		for k in SUMMON_KEYS[i]:
			_key(action, k)
		_pad(action, SUMMON_PADS[i])
	_reset("dash")
	_key("dash", KEY_SHIFT)
	_axis("dash", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_pad("dash", JOY_BUTTON_LEFT_SHOULDER)
	_reset("pause")
	_key("pause", KEY_ESCAPE)
	_pad("pause", JOY_BUTTON_START)
	_reset("garage")
	_key("garage", KEY_B)
	_pad("garage", JOY_BUTTON_BACK)
	# 攻击 / 投掷 / 修理全自动：动作保留（代码兼容），不绑任何键和鼠标
	for action in ["primary", "throw_cargo", "interact"]:
		_reset(action)
	# 菜单导航：WASD 也能在按钮之间移动（方向键、手柄十字键、Enter / 空格确认是引擎默认）
	var nav := {"ui_left": KEY_A, "ui_right": KEY_D, "ui_up": KEY_W, "ui_down": KEY_S}
	for action in nav:
		var has := false
		for e in InputMap.action_get_events(action):
			if e is InputEventKey and (e as InputEventKey).physical_keycode == nav[action]:
				has = true
		if not has:
			_key(action, nav[action])
