extends Node3D
## G1 presentation layer: a readable, stylised river worksite.
##
## This node owns no gameplay state. Decorative meshes intentionally have no
## collision bodies; the existing arena bounds remain the authority for play.
const Effects = preload("res://scripts/native_effects.gd")
const RIVER = preload("res://effects/river_surface.gdshader")

const OLIVE := Color("#6f7f61")
const EARTH := Color("#b48658")
const EARTH_DARK := Color("#6e503d")
const WATER_DULL := Color("#356f79")
const WATER_LIVE := Color("#4caea7")
const NAVY := Color("#253d48")
const BONE := Color("#eee3c7")
const ALERT := Color("#df604e")
const REPAIR_GREEN := Color("#78d6a8")
const PIPE_METAL := Color("#718a88")

var green_zone: Node3D
var route_before: Node3D
var route_after: Node3D
var camera: Camera3D
var effects: Node3D
var river_material: ShaderMaterial
var shortcut_gate_mesh: Node3D
var terrain: MeshInstance3D
var flow_time := 0.0
var route_repaired := false
var environment: Environment
var light_warm: DirectionalLight3D
var current_biome := "river"

const BIOME_PALETTES := {
	"river": {"bg": Color("#152c37"), "fog": Color("#53717a"), "fog_energy": 0.22, "ambient": Color("#8399D4"), "light": Color("#FFE6C4")},
	"desert": {"bg": Color("#8a6a35"), "fog": Color("#c9974e"), "fog_energy": 0.5, "ambient": Color("#A08CC8"), "light": Color("#ffd9a0")},
	"swamp": {"bg": Color("#1c2a1d"), "fog": Color("#4f7050"), "fog_energy": 0.42, "ambient": Color("#7FA0B8"), "light": Color("#d9e8c8")},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_lighting()
	_build_camera()
	_build_ground()
	_build_river_worksite()
	_build_edge_landmarks()
	_build_shortcut_visual()
	_set_route_state(false)
	effects = Effects.new()
	add_child(effects)

func _build_lighting() -> void:
	var lights := RenderProfile.build_lights(self)
	var light: DirectionalLight3D = lights[0]
	var world := WorldEnvironment.new()
	var environment := RenderProfile.build_environment(Color("#152c37"), BIOME_PALETTES["river"]["ambient"])
	self.environment = environment
	light_warm = light
	world.environment = environment
	add_child(world)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "WorksiteCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23.0
	camera.near = 1.0
	camera.far = 220.0
	# A 55-degree starting angle exposes the cab, tool head and bank shapes.
	camera.position = Vector3(0, 25, 17)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0))

func _build_ground() -> void:
	# 碰撞仍是原来的地面盒与四面边界墙；有正式地表时这些盒子只负责碰撞、不显示。
	var authored := WorldDressing.has_terrain()
	var ground := box(self, Vector3(36, 1, 32), Vector3(0, -0.55, 0), EARTH, true)
	ground.visible = not authored
	for at in [Vector3(-18, 0.8, 0), Vector3(18, 0.8, 0), Vector3(0, 0.8, -16), Vector3(0, 0.8, 16)]:
		var size := Vector3(1, 2, 33) if absf(at.x) > 0 else Vector3(36, 2, 1)
		var wall := box(self, size, at, NAVY, true)
		wall.visible = not ProceduralRig.has_rig("prop_broken_wall")
	if authored:
		terrain = WorldDressing.build_terrain(self, Vector2(110, 96))
		_build_border_dressing()
		_build_scatter()
		return
	_disk(self, "CentralDustYard", Vector3(0, 0.035, 0.5), Vector3(11.5, 0.035, 15.8), Color("#bd9565"), 14)
	_disk(self, "OliveBackPatch", Vector3(-7.0, 0.04, -4.5), Vector3(6.4, 0.035, 6.8), OLIVE, 9)
	_disk(self, "OliveRepairPatch", Vector3(6.8, 0.045, -7.2), Vector3(5.2, 0.035, 4.5), Color("#788b67"), 10)
	_disk(self, "WarmScrapPatch", Vector3(-5.0, 0.05, 6.2), Vector3(5.8, 0.035, 2.2), Color("#d0a66f"), 8)
	_disk(self, "WarmPumpPatch", Vector3(4.2, 0.052, 6.1), Vector3(6.0, 0.035, 2.0), Color("#c99a66"), 8)
	box(self, Vector3(0.15, 0.06, 2.7), Vector3(-8.0, 0.07, 5.3), BONE)
	box(self, Vector3(0.15, 0.06, 2.7), Vector3(-7.45, 0.07, 5.3), BONE)
	for z in [-10.8, -7.2, 7.5, 11.0]:
		var strip := box(self, Vector3(2.3, 0.05, 0.12), Vector3(-8.6, 0.085, z), Color("#8e6d4f"))
		strip.rotation_degrees.y = 8.0 if z < 0.0 else -7.0

## 边界：栅栏围一圈，外侧树林 + 大石 + 灌木，挡住“世界尽头”
func _build_border_dressing() -> void:
	var border := Node3D.new()
	border.name = "BorderDressing"
	add_child(border)
	if ProceduralRig.has_rig("prop_broken_wall"):
		var seg := 4.0
		var x := -16.0
		var flip := false
		while x <= 16.0:
			WorldDressing.prop(border, "prop_broken_wall", Vector3(x, 0, -16.4), 0.0 if flip else 180.0)
			WorldDressing.prop(border, "prop_broken_wall", Vector3(x, 0, 16.4), 180.0 if flip else 0.0)
			x += seg
			flip = not flip
		var z := -14.0
		flip = false
		while z <= 14.0:
			WorldDressing.prop(border, "prop_broken_wall", Vector3(-18.4, 0, z), 90.0 if flip else -90.0)
			WorldDressing.prop(border, "prop_broken_wall", Vector3(18.4, 0, z), -90.0 if flip else 90.0)
			z += seg
			flip = not flip
		for c in [Vector3(-18.4, 0, -16.4), Vector3(18.4, 0, -16.4), Vector3(-18.4, 0, 16.4), Vector3(18.4, 0, 16.4)]:
			WorldDressing.prop(border, "prop_rock_large", c, c.x * 7.0, 1.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301
	var trees := []
	var bushes := []
	for i in 70:
		var side := i % 4
		var t := rng.randf_range(-1.0, 1.0)
		var d := rng.randf_range(1.6, 6.5)
		var p := Vector2(t * 22.0, -16.0 - d) if side == 0 else (Vector2(t * 22.0, 16.0 + d) if side == 1 else (Vector2(-18.0 - d, t * 19.0) if side == 2 else Vector2(18.0 + d, t * 19.0)))
		if absf(p.x - 9.0) < 3.0 and absf(p.y) > 15.0:
			continue  # 河道出入口留空
		var s := rng.randf_range(0.8, 1.3)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		var tf := Transform3D(basis, Vector3(p.x, 0, p.y))
		# C26：正交 45° 下，物体会往画面上方（远处）盖住 高度×1 米的地面。
		# 镜头一侧（南边 +Z）和左右两侧的南半段只放灌木（矮），高树留在北边与左右北半段——同原作“高物件不挡在玩家和镜头之间”
		var near_cam := side == 1 or (side >= 2 and p.y > 4.0)
		if i % 3 == 2 or near_cam:
			bushes.append(tf)
		else:
			trees.append(tf)
	var round_trees := trees.filter(func(_t): return rng.randf() < 0.6)
	var poplars := trees.filter(func(t): return not round_trees.has(t))
	WorldDressing.scatter(border, "prop_tree_round", round_trees)
	WorldDressing.scatter(border, "prop_tree_poplar", poplars)
	WorldDressing.scatter(border, "prop_bush", bushes)
	var rocks := WorldDressing.scatter_points(rng, 18, Rect2(-24, -22, 48, 44), Vector2(0.7, 1.4),
		func(p: Vector2): return (absf(p.x) < 18.6 and absf(p.y) < 16.6) or p.y > 15.0)
	WorldDressing.scatter(border, "prop_rock_large", rocks)

## 场内散布：草丛、小花、小石子，避开中央工地与河道，保证可读性
func _build_scatter() -> void:
	var scatter := Node3D.new()
	scatter.name = "GroundScatter"
	add_child(scatter)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4417
	var in_yard := func(p: Vector2) -> bool:
		var d := (p - Vector2(0, 0.5)) / Vector2(8.6, 12.0)
		return d.length_squared() < 1.0
	var in_river := func(p: Vector2) -> bool: return absf(p.x - 9.0) < 5.6
	var blocked := func(p: Vector2) -> bool: return bool(in_yard.call(p)) or bool(in_river.call(p))
	var area := Rect2(-17.5, -15.5, 35, 31)
	WorldDressing.scatter(scatter, "prop_grass_tuft", WorldDressing.scatter_points(rng, 150, area, Vector2(0.7, 1.25), blocked))
	WorldDressing.scatter(scatter, "prop_flowers", WorldDressing.scatter_points(rng, 34, area, Vector2(0.7, 1.1), blocked))
	WorldDressing.scatter(scatter, "prop_bush", WorldDressing.scatter_points(rng, 10, area, Vector2(0.6, 0.9), blocked))
	# 工地里只撒少量碎石，表现“被挖过”的地面
	WorldDressing.scatter(scatter, "prop_rock_cluster", WorldDressing.scatter_points(rng, 8, Rect2(-8, -11, 16, 23), Vector2(0.3, 0.5),
		func(p: Vector2): return not bool(in_yard.call(p)) or bool(in_river.call(p))))
	# 河岸芦苇（常驻，修复后再加一圈）
	WorldDressing.scatter(scatter, "prop_reeds", WorldDressing.scatter_points(rng, 14, Rect2(2.8, -15, 12.4, 30), Vector2(0.7, 1.1),
		func(p: Vector2): return absf(absf(p.x - 9.0) - 5.4) > 0.9))

func _build_river_worksite() -> void:
	# The dry channel is visible before repair; green_zone is the stateful overlay
	# toggled by main.gd after the pump is repaired.
	var dry := Node3D.new()
	dry.name = "DryRiverAndBanks"
	add_child(dry)
	if terrain == null:
		_disk(dry, "DryChannel", Vector3(9.0, 0.06, -2.2), Vector3(5.3, 0.045, 18.2), WATER_DULL, 14)
	var bank_rocks := []
	for z in [-10.0, -7.2, -4.3, -1.2, 2.0, 5.5, 8.2]:
		var a := Vector3(6.4 + fmod(z * 2.1, 1.0) * 0.3, 0.0, z)
		var b := Vector3(11.4 - fmod(z * 1.7, 1.0) * 0.35, 0.0, z + 0.9)
		bank_rocks.append(Transform3D(Basis(Vector3.UP, z * 1.3).scaled(Vector3.ONE * 0.9), a))
		bank_rocks.append(Transform3D(Basis(Vector3.UP, z * 2.1).scaled(Vector3.ONE * 0.75), b))
	if not WorldDressing.scatter(dry, "prop_rock_cluster", bank_rocks):
		for t in bank_rocks:
			_create_rock(dry, (t as Transform3D).origin + Vector3(0, 0.18, 0), 0.5, Color("#526f70"))

	green_zone = Node3D.new()
	green_zone.name = "RepairedRiverAndGrowth"
	add_child(green_zone)
	var reed_tf := []
	for index in range(18):
		var x := 7.0 + fmod(float(index * 17), 5.4)
		var z := -12.5 + fmod(float(index * 7), 16.0)
		reed_tf.append(Transform3D(Basis(Vector3.UP, float(index)).scaled(Vector3.ONE * (0.8 + 0.04 * (index % 5))), Vector3(x, 0.0, z)))
	if not WorldDressing.scatter(green_zone, "prop_reeds", reed_tf):
		for index in range(18):
			_create_reed_cluster(green_zone, (reed_tf[index] as Transform3D).origin + Vector3(0, 0.08, 0), index % 2 == 0)
	var flowing_water := _disk(green_zone, "FlowingWater", Vector3(9, 0.13, -2), Vector3(4.8, 0.045, 17.8), WATER_LIVE, 16)
	river_material = ShaderMaterial.new()
	river_material.shader = RIVER
	flowing_water.material_override = river_material
	green_zone.hide()
	_build_route_landmarks()

func _build_route_landmarks() -> void:
	# The route is a visual contract: before repair, the broken crossing and
	# leaking pipe explain the detour; after repair, the bridge and green guide
	# bands explain why the world has gained a shortcut. No child has collision.
	route_before = Node3D.new()
	route_before.name = "RouteBeforeRepair"
	add_child(route_before)
	_notice(route_before, Vector3(3.1, 0.0, -1.0), ALERT, "ROUTE CLOSED", 15.0)
	if not WorldDressing.prop(route_before, "prop_bridge_stub", Vector3(5.4, 0.0, -1.0), 90.0):
		box(route_before, Vector3(3.4, 0.28, 1.35), Vector3(5.4, 0.25, -1.0), EARTH_DARK)
	if not WorldDressing.prop(route_before, "prop_bridge_stub", Vector3(12.6, 0.0, -1.0), -90.0):
		box(route_before, Vector3(3.4, 0.28, 1.35), Vector3(12.6, 0.25, -1.0), EARTH_DARK)
	for at in [Vector3(4.1, 0.0, -1.0), Vector3(13.9, 0.0, -1.0)]:
		if not WorldDressing.prop(route_before, "prop_lamp_post", at, 0.0, 0.7):
			box(route_before, Vector3(0.18, 0.8, 0.18), at + Vector3(0, 0.58, 0), ALERT)
	if not WorldDressing.prop(route_before, "prop_pipe", Vector3(9.0, 0.0, 1.4), 0.0, 1.1):
		_pipe(route_before, Vector3(9.0, 0.26, 1.2), 7.0, Color("#a87856"))
		_pipe(route_before, Vector3(9.0, 0.28, 2.0), 5.2, PIPE_METAL)
	_notice(route_before, Vector3(14.0, 0.0, -1.0), ALERT, "DETOUR", -15.0)

	route_after = Node3D.new()
	route_after.name = "RouteAfterRepair"
	add_child(route_after)
	if not WorldDressing.prop(route_after, "prop_bridge", Vector3(9.0, 0.0, -1.0), 0.0):
		box(route_after, Vector3(10.8, 0.34, 1.7), Vector3(9.0, 0.34, -1.0), BONE)
		box(route_after, Vector3(10.8, 0.12, 0.38), Vector3(9.0, 0.56, -1.62), REPAIR_GREEN)
		box(route_after, Vector3(10.8, 0.12, 0.38), Vector3(9.0, 0.56, -0.38), REPAIR_GREEN)
		for x in [4.1, 6.0, 8.0, 10.0, 12.0, 13.9]:
			box(route_after, Vector3(0.16, 0.9, 0.16), Vector3(x, 0.76, -1.0), REPAIR_GREEN)
	_notice(route_after, Vector3(3.1, 0.0, -1.0), REPAIR_GREEN, "SHORTCUT OPEN", 15.0)
	_notice(route_after, Vector3(14.0, 0.0, -1.0), REPAIR_GREEN, "PUMP PASSED", -15.0)
	route_after.scale = Vector3.ZERO

func _notice(parent: Node3D, at: Vector3, color: Color, label: String, yaw: float) -> void:
	if not WorldDressing.prop(parent, "prop_sign", at, yaw):
		_create_route_notice(parent, at, color, label)

func _build_shortcut_visual() -> void:
	# 封路：三段红白栅栏横在河道上（正式资产）；缺失时回落红色长条
	var gate := Node3D.new()
	gate.name = "ShortcutClosedVisual"
	add_child(gate)
	var placed := false
	for x in [4.5, 6.3, 8.1, 9.9, 11.7, 13.5]:
		placed = WorldDressing.prop(gate, "prop_roadblock", Vector3(x, 0.0, -1.0), 0.0) != null or placed
	if not placed:
		box(gate, Vector3(10.8, 1.7, 0.7), Vector3(9.0, 0.85, -1.0), ALERT)
	shortcut_gate_mesh = gate

func _set_route_state(repaired: bool) -> void:
	if route_before == null or route_after == null:
		return
	route_repaired = repaired
	route_before.visible = not repaired
	route_after.visible = repaired
	if repaired:
		route_after.scale = Vector3(1.0, 0.12, 1.0)
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(route_after, "scale", Vector3.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		route_after.scale = Vector3.ZERO

func set_shortcut_open(open: bool) -> void:
	_set_route_state(open)
	if shortcut_gate_mesh != null:
		shortcut_gate_mesh.visible = not open

func is_shortcut_open() -> bool:
	return route_repaired

func _create_route_notice(parent: Node3D, at: Vector3, color: Color, _label: String) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	box(group, Vector3(0.12, 1.15, 0.12), Vector3(0, 0.58, 0), EARTH_DARK)
	box(group, Vector3(1.55, 0.56, 0.12), Vector3(0, 1.3, 0), color)
	box(group, Vector3(0.92, 0.08, 0.14), Vector3(0, 1.3, -0.08), BONE)
	# The short, high-contrast stripe is legible from the top-down camera even
	# without relying on tiny 3D text that would blur at gameplay scale.
	box(group, Vector3(0.14, 0.26, 0.14), Vector3(-0.45, 1.3, -0.09), color.darkened(0.35))
	box(group, Vector3(0.14, 0.26, 0.14), Vector3(0.45, 1.3, -0.09), color.darkened(0.35))

func _pipe(parent: Node3D, at: Vector3, length: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.13
	mesh.bottom_radius = 0.16
	mesh.height = length
	mesh.radial_segments = 8
	var pipe := MeshInstance3D.new()
	pipe.mesh = mesh
	pipe.position = at
	pipe.rotation_degrees.z = 90.0
	pipe.material_override = material(color)
	parent.add_child(pipe)

func _build_edge_landmarks() -> void:
	var landmarks := Node3D.new()
	landmarks.name = "EdgeLandmarks"
	add_child(landmarks)
	# A crooked civic arch and two warning pennants establish foreground/background
	# without turning the route into a collision maze.
	_landmark(landmarks, "prop_stone_arch", Vector3(-13.0, 0.0, -10.5), 10.0, func(): _create_arch(landmarks, Vector3(-13.0, 0.0, -10.5)))
	_landmark(landmarks, "prop_pennant", Vector3(13.2, 0.0, 10.5), 0.0, func(): _create_pennant(landmarks, Vector3(13.2, 0.0, 10.5), Color("#df604e")))
	_landmark(landmarks, "prop_pennant", Vector3(-12.5, 0.0, 10.0), 40.0, func(): _create_pennant(landmarks, Vector3(-12.5, 0.0, 10.0), Color("#e9ad38")))
	_landmark(landmarks, "prop_tree_round", Vector3(-12.6, 0.0, -3.0), 30.0, func(): _create_tree_cluster(landmarks, Vector3(-12.6, 0.0, -3.0)))
	_landmark(landmarks, "prop_tree_poplar", Vector3(-11.4, 0.0, -1.8), 0.0, func(): pass)
	_landmark(landmarks, "prop_tree_round", Vector3(13.1, 0.0, 4.2), -20.0, func(): _create_tree_cluster(landmarks, Vector3(13.1, 0.0, 4.2)))
	_landmark(landmarks, "prop_broken_wall", Vector3(-10.8, 0.0, 11.0), -12.0, func(): _create_broken_wall(landmarks, Vector3(-10.8, 0.0, 11.0), -12.0))
	_landmark(landmarks, "prop_rock_large", Vector3(-13.0, 0.0, 1.0), 25.0, func(): _create_rock(landmarks, Vector3(-13.0, 0.25, 1.0), 1.1, Color("#5d706d")))
	_landmark(landmarks, "prop_rock_large", Vector3(13.0, 0.0, -13.0), -60.0, func(): _create_rock(landmarks, Vector3(13.0, 0.23, -13.0), 0.9, Color("#6d7669")))
	_landmark(landmarks, "prop_sign", Vector3(5.6, 0.0, -7.0), -10.0, func(): _create_repair_sign(landmarks, Vector3(5.6, 0.0, -7.0)))
	_landmark(landmarks, "prop_lamp_post", Vector3(-3.6, 0.0, 9.2), 0.0, func(): pass)
	_landmark(landmarks, "prop_lamp_post", Vector3(3.2, 0.0, -11.6), 0.0, func(): pass)
	_landmark(landmarks, "prop_oil_drums", Vector3(-9.2, 0.0, 7.6), 35.0, func(): pass)
	_landmark(landmarks, "prop_oil_drums", Vector3(2.4, 0.0, 10.8), -20.0, func(): pass)
	_landmark(landmarks, "prop_cargo_crate", Vector3(-10.4, 0.0, 8.4), 12.0, func(): pass)
	# C13：Weaver 正式景物（拆件版带转子动画；缺失则跳过，不影响原地标）
	_place_formal_prop(landmarks, "wind_turbine", Vector3(-13.4, 0.0, -6.8), 20.0)
	_place_formal_prop(landmarks, "mountain_air_pump", Vector3(13.4, 0.0, -8.6), -30.0)
	_place_formal_prop(landmarks, "camp_board", Vector3(-9.6, 0.0, 12.6), 15.0)

func _landmark(parent: Node3D, slot: String, at: Vector3, yaw: float, fallback: Callable) -> void:
	if WorldDressing.prop(parent, slot, at, yaw) == null:
		fallback.call()

func _place_formal_prop(parent: Node3D, slot: String, at: Vector3, yaw_deg: float) -> void:
	var holder := Node3D.new()
	holder.name = "FormalProp_" + slot
	holder.position = at
	holder.rotation_degrees.y = yaw_deg
	parent.add_child(holder)
	var fit := Node3D.new()
	fit.name = "Fit"
	fit.transform = Transform3D(WorldDressing._fit_basis(slot), Vector3.ZERO)
	holder.add_child(fit)
	if ProceduralRig.attach(fit, slot) == null and FormalModelLibrary.attach(holder, slot, "FormalProp") == null:
		holder.queue_free()
		return
	WorldDressing.apply_world_height(fit, slot)

func _create_arch(parent: Node3D, at: Vector3) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	box(group, Vector3(0.6, 3.0, 0.6), Vector3(-1.1, 1.35, 0), NAVY)
	box(group, Vector3(0.6, 2.3, 0.6), Vector3(1.1, 1.05, 0), NAVY)
	box(group, Vector3(2.8, 0.5, 0.6), Vector3(0, 2.55, 0), BONE)
	box(group, Vector3(2.0, 0.18, 0.12), Vector3(0, 2.55, -0.34), Color("#df604e"))

func _create_pennant(parent: Node3D, at: Vector3, flag_color: Color) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	box(group, Vector3(0.12, 2.4, 0.12), Vector3(0, 1.15, 0), EARTH_DARK)
	box(group, Vector3(0.9, 0.55, 0.08), Vector3(0.36, 2.0, 0), flag_color)

func _create_repair_sign(parent: Node3D, at: Vector3) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	box(group, Vector3(0.12, 1.7, 0.12), Vector3(0, 0.84, 0), EARTH_DARK)
	box(group, Vector3(1.15, 0.7, 0.12), Vector3(0.42, 1.52, 0), Color("#58b7ac"))
	box(group, Vector3(0.68, 0.12, 0.12), Vector3(0.42, 1.52, -0.08), BONE)
	box(group, Vector3(0.12, 0.48, 0.12), Vector3(0.42, 1.52, -0.08), BONE)

func _create_tree_cluster(parent: Node3D, at: Vector3) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	for item in [[0.0, 0.0, 1.05], [0.8, 0.35, 0.82], [-0.7, 0.45, 0.74], [0.2, -0.65, 0.7]]:
		var crown := SphereMesh.new()
		crown.radius = float(item[2])
		crown.height = float(item[2]) * 1.15
		crown.radial_segments = 8
		crown.rings = 4
		var instance := MeshInstance3D.new()
		instance.mesh = crown
		instance.position = Vector3(float(item[0]), 0.72, float(item[1]))
		instance.material_override = material(Color("#667a56"))
		group.add_child(instance)
	box(group, Vector3(0.34, 0.9, 0.34), Vector3(0, 0.38, 0), EARTH_DARK)

func _create_broken_wall(parent: Node3D, at: Vector3, yaw: float) -> void:
	var group := Node3D.new()
	group.position = at
	group.rotation_degrees.y = yaw
	parent.add_child(group)
	for index in range(5):
		var height := 0.8 + float(index % 2) * 0.32
		box(group, Vector3(0.95, height, 0.34), Vector3((index - 2) * 0.9, height * 0.5, 0), Color("#5f6f70"))

func _create_reed_cluster(parent: Node3D, at: Vector3, warm: bool) -> void:
	var group := Node3D.new()
	group.position = at
	parent.add_child(group)
	var stem_color := Color("#6b915b") if warm else Color("#4f7c63")
	for index in range(3):
		var stem := CylinderMesh.new()
		stem.top_radius = 0.07
		stem.bottom_radius = 0.11
		stem.height = 0.75 + index * 0.12
		stem.radial_segments = 5
		var blade := MeshInstance3D.new()
		blade.mesh = stem
		blade.position = Vector3((index - 1) * 0.16, 0.4, (index % 2) * 0.12)
		blade.rotation_degrees.z = -12.0 + index * 10.0
		blade.material_override = material(stem_color)
		group.add_child(blade)

func _create_rock(parent: Node3D, at: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = radius * 0.55
	mesh.radial_segments = 6
	var rock := MeshInstance3D.new()
	rock.mesh = mesh
	rock.position = at
	rock.rotation_degrees = Vector3(0, fmod(at.z * 17.0, 30.0), 0)
	rock.material_override = material(color)
	parent.add_child(rock)

func _disk(parent: Node3D, node_name: String, at: Vector3, scale_value: Vector3, color: Color, segments := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.scale = scale_value
	instance.material_override = material(color)
	parent.add_child(instance)
	return instance

func _process(delta: float) -> void:
	flow_time += delta
	if river_material != null:
		river_material.set_shader_parameter("flow_time", flow_time)
	if green_zone != null and green_zone.visible != route_repaired:
		_set_route_state(green_zone.visible)

func set_vehicle(vehicle: Node3D) -> void:
	effects.set_vehicle(vehicle)

func apply_biome(biome_id: String) -> void:
	if not BIOME_PALETTES.has(biome_id):
		return
	current_biome = biome_id
	WorldDressing.apply_biome(terrain, biome_id)
	var palette: Dictionary = BIOME_PALETTES[biome_id]
	if environment != null:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_parallel(true)
		tween.tween_property(environment, "background_color", palette["bg"], 0.6)
		tween.tween_property(environment, "fog_light_color", palette["fog"], 0.6)
		tween.tween_property(environment, "fog_light_energy", float(palette["fog_energy"]), 0.6)
		tween.tween_property(environment, "ambient_light_color", palette["ambient"], 0.6)
	if light_warm != null:
		light_warm.light_color = palette["light"]

func set_effects_enabled(enabled: bool) -> void:
	effects.set_enabled(enabled)

func present_effect(kind: String, from: Vector3, to: Vector3) -> void:
	effects.play(kind, from, to)

func box(parent: Node3D, extent: Vector3, at: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = extent
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = material(color)
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.position = at
		var collider := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = extent
		collider.shape = collision
		body.add_child(collider)
		parent.add_child(body)
	return mesh

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	return mat
