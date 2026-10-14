## D-111: firing range dressing (RangeDressing, game/world/range). Builds B's range level from
## range_layout.tres and dresses it, then checks: lights on layer 1 with viewmodel_lit on the key lights near
## the shooting line, a fixture for every light, the Compatibility light budget (32 per frame, 8 per mesh on
## the kit floor and ceiling tiles), no dressing collision inside a lane volume or the walk strip behind the
## line, surface tags on every body, the indoor Environment, and a deterministic build. Owner: ENV C.
extends TestCase

const LAYOUT_PATH: String = "res://content/data/range/range_layout.tres"
const TWEAK_PATH: String = "res://content/data/range/range_tweak.tres"
const VIEWMODEL_LIT_LAYER: int = 1 << 20
const MAX_LIGHTS_FRAME: int = 32
const MAX_LIGHTS_MESH: int = 8
## Lane volume height band (m) and the walk strip depth behind the line.
const LANE_Y: Vector2 = Vector2(0.3, 2.0)
const WALK_DEPTH_M: float = 1.5

var layout: RangeLayout = null


func before_all() -> void:
	layout = load(LAYOUT_PATH) as RangeLayout


func _build() -> Node3D:
	var level: Node3D = Node3D.new()
	level.name = "Level"
	RangeBuilder.build_level(layout, load(TWEAK_PATH) as RangeTweak, level)
	RangeDressing.build(layout, level)
	return level


## Transform of `n` relative to `top` (the level is not in the tree).
func _xf(n: Node, top: Node) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != top:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


func _lights(level: Node3D) -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	for n: Node in level.get_node("Dressing").find_children("*", "Light3D", true, false):
		assert_true(n is OmniLight3D, "%s: range lights are omni lights" % n.name)
		if n is OmniLight3D:
			out.append(n as OmniLight3D)
	return out


func test_lights_layers_and_fixtures() -> void:
	var level: Node3D = _build()
	var lights: Array[OmniLight3D] = _lights(level)
	assert_true(lights.size() >= 20, "range lights built (%d)" % lights.size())
	assert_true(lights.size() <= MAX_LIGHTS_FRAME, "%d lights within the Compatibility per-frame budget" % lights.size())
	var fixtures: Array[Vector3] = []
	for n: Node in level.get_node("Dressing").find_children("*", "", true, false):
		if n.has_meta(&"fixture"):
			fixtures.append(_xf(n, level).origin)
	var keys_near_line: int = 0
	var behind_line: int = 0
	for l: OmniLight3D in lights:
		var p: Vector3 = _xf(l, level).origin
		assert_true((l.layers & 1) != 0, "%s on render layer 1" % l.name)
		assert_false(l.shadow_enabled, "%s: no shadows (Compatibility budget)" % l.name)
		if l.has_meta(&"key_light") and absf(p.z) <= 12.0:
			keys_near_line += 1
			assert_true((l.layers & VIEWMODEL_LIT_LAYER) != 0, "key light %s carries viewmodel_lit" % l.name)
			if p.z > 0.0:
				behind_line += 1
		var near: float = INF
		for f: Vector3 in fixtures:
			near = minf(near, f.distance_to(p))
		assert_true(near <= 0.6, "%s has a fixture (nearest %.2f m)" % [l.name, near])
	assert_true(keys_near_line >= 4, "key lights near the shooting line (%d)" % keys_near_line)
	assert_true(behind_line >= 2, "key lights over the shooting area (%d)" % behind_line)
	level.free()


## No floor tile or ceiling tile is touched by more than 8 lights (else some go black in Compatibility).
func test_light_budget_per_mesh() -> void:
	var level: Node3D = _build()
	var boxes: Array[AABB] = []
	for l: OmniLight3D in _lights(level):
		var p: Vector3 = _xf(l, level).origin
		var r: float = l.omni_range
		boxes.append(AABB(p - Vector3(r, r, r), Vector3(r, r, r) * 2.0))
	var checked: int = 0
	for group: NodePath in [^"Floor", ^"Dressing/Ceiling"]:
		for n: Node in level.get_node(group).find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			var ab: AABB = _xf(mi, level) * mi.get_aabb()
			var hits: int = 0
			for b: AABB in boxes:
				if b.intersects(ab):
					hits += 1
			checked += 1
			if hits > MAX_LIGHTS_MESH:
				fail("%s/%s at %s is touched by %d lights (max %d)" % [group, mi.name, ab.get_center(), hits, MAX_LIGHTS_MESH])
	assert_true(checked > 300, "floor and ceiling tiles checked (%d)" % checked)
	level.free()


func _volumes() -> Array[AABB]:
	var out: Array[AABB] = []
	var h: float = LANE_Y.y - LANE_Y.x
	for i: int in range(layout.lane_count()):
		var d: float = layout.lane_target_distances[i]
		out.append(AABB(Vector3(layout.lane_x(i) - layout.lane_width_m * 0.5, LANE_Y.x, -d), Vector3(layout.lane_width_m, h, d)))
	for def: RangeLaneDef in layout.extra_lanes:
		var hw: float = def.track_half_m + layout.lane_width_m * 0.5
		out.append(AABB(Vector3(def.x_m - hw, LANE_Y.x, -def.distance_m), Vector3(hw * 2.0, h, def.distance_m)))
	# The walk strip behind the line, across every lane and the side areas.
	var x0: float = minf(layout.lane_x(0) - layout.lane_width_m * 0.5, -layout.width_m * 0.5 + 5.0)
	out.append(AABB(Vector3(x0, LANE_Y.x, 0.0), Vector3(-x0 * 2.0, h, WALK_DEPTH_M)))
	return out


func test_collision_clear_of_lanes() -> void:
	var level: Node3D = _build()
	var vols: Array[AABB] = _volumes()
	var bodies: Array[Node] = level.get_node("Dressing").find_children("*", "CollisionObject3D", true, false)
	assert_true(bodies.size() >= 4, "solid props have collision (%d bodies)" % bodies.size())
	var shapes: int = 0
	for b: Node in bodies:
		assert_true(SurfaceTags.is_id(StringName(b.get_meta(&"surface", &""))),
			"%s tagged with a bullet surface (%s)" % [b.name, b.get_meta(&"surface", "")])
		for c: Node in b.find_children("*", "CollisionShape3D", true, false):
			var cs: CollisionShape3D = c as CollisionShape3D
			var ab: AABB = _xf(cs, level) * cs.shape.get_debug_mesh().get_aabb()
			shapes += 1
			for v: AABB in vols:
				if v.intersects(ab):
					fail("%s/%s %s intersects lane / walk volume %s" % [b.name, cs.name, ab, v])
	assert_true(shapes >= 4, "collision shapes checked (%d)" % shapes)
	level.free()


func test_environment_preset() -> void:
	var env: Environment = RangeDressing.environment()
	assert_true(env != null, "range environment preset loads")
	if env == null:
		return
	assert_eq(env.background_mode, Environment.BG_COLOR, "indoor: colour background, no sky")
	assert_true(env.background_color.get_luminance() < 0.05, "dark background")
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_AGX, "AgX tonemap")
	assert_true(env.glow_enabled, "light glow")
	assert_false(env.fog_enabled, "no fog")
	assert_true(env.ambient_light_energy > 0.0 and env.ambient_light_energy < 0.6, "modest ambient")


func _snapshot(level: Node3D) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for n: Node in level.get_node("Dressing").find_children("*", "", true, false):
		var line: String = String(level.get_path_to(n)) if n.is_inside_tree() else _rel(n, level)
		if n is Node3D:
			line += " " + str(_xf(n, level))
		out.append(line)
	return out


func _rel(n: Node, top: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var c: Node = n
	while c != null and c != top:
		parts.append(String(c.name))
		c = c.get_parent()
	parts.reverse()
	return "/".join(parts)


func test_deterministic() -> void:
	var a: Node3D = _build()
	var b: Node3D = _build()
	var sa: PackedStringArray = _snapshot(a)
	var sb: PackedStringArray = _snapshot(b)
	assert_true(sa.size() > 500, "dressing nodes built (%d)" % sa.size())
	assert_eq(sa.size(), sb.size(), "same node count")
	var diff: int = 0
	for i: int in range(mini(sa.size(), sb.size())):
		if sa[i] != sb[i]:
			diff += 1
			if diff <= 3:
				fail("build differs: %s vs %s" % [sa[i], sb[i]])
	assert_eq(diff, 0, "two builds give the same names and transforms")
	a.free()
	b.free()
