## Firing range dressing (D-111): the lit indoor-range look on top of ENV B's RangeBuilder level.
## Owner: ENV C. Called by FiringRange._ready (B's hook) right after RangeBuilder.build_level:
## `RangeDressing.build(layout, level)` adds a "Dressing" subtree and re-skins the kit floor / walls.
##
## Frame (RangeLayout): the shooting line is z = 0, lanes run toward -Z, x = 0 is the lane centre. The kit
## walls are 4 m tall and 0.2 m thick and extend -X / -Z from their origins, so the inner faces are
## x = -width/2, x = width/2 - 0.2, z = back_z - 0.2 and z = far_z.
##
## Lighting budget (Compatibility renderer): at most 8 omni / spot lights per mesh instance
## (rendering/limits/opengl/max_lights_per_object) and 32 per frame (max_renderable_lights), so the hall
## gets about 28 omni lights: one warm pair per 10 m bay (between the hanging baffles), a row over the
## shooting area, a few over the side target areas and one in the control booth. The continuous look of
## strip lighting comes from emissive fixtures, which cost no light slots. Big skins (ceiling) are tiled
## into 4 m meshes like the kit floor so no mesh is overlapped by more than 8 lights (test_range_dressing).
##
## Surfaces are texgen library materials (game/world/materials) duplicated as world triplanar at the
## style guide density, as the Shadow Ledger / Dockside Burn finishes do; resource_name `range_<key>_<lib>`
## resolves to a bullet surface through surface_map.json. Collision only on solid props (rack, lockers,
## booth, console, backstop), all outside the lanes, the walk strip behind the line and the sight lines.
class_name RangeDressing
extends RefCounted

const ROOT_NAME: String = "Dressing"
## viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER.
const VIEWMODEL_LIT_LAYER: int = 1 << 20
const MAT_DIR: String = "res://world/materials/"
const ENVIRONMENT_PATH: String = "res://world/range/range_environment.tres"
const TEXEL_PX_M: float = 512.0
## Kit pieces (RangeLayout greybox kit): wall height / thickness.
const WALL_H: float = 4.0
const WALL_T: float = 0.2
## Visual tile edge for the ceiling (matches the 4 m kit floor; see the lighting budget above).
const TILE: float = 4.0
## Hanging baffles: one every BAY m down range, starting BAY / 2 past the line.
const BAY: float = 10.0
const LAMP_COLOR: Color = Color(1.0, 0.84, 0.64)
const LAMP_Y: float = 3.1
const FIXTURE_Y: float = 3.28
## Control booth size (x along the back wall, roof height, z depth from the back wall) in the back-left corner.
const BOOTH_SIZE: Vector3 = Vector3(4.6, 2.6, 4.0)
const RACK_X: Vector2 = Vector2(2.0, 5.0)

## Finish key -> [library id, tint (albedo multiply; alpha < 1 = see-through) or null].
const FINISHES: Dictionary = {
	"floor": ["concrete", Color(0.9, 0.88, 0.85)],
	"wall": ["plaster_painted", Color(0.72, 0.74, 0.76)],
	"ceiling": ["concrete", Color(0.2, 0.2, 0.22)],
	"baffle": ["fabric_upholstery", Color(0.62, 0.62, 0.64)],
	"panel": ["fabric_upholstery", Color(0.4, 0.44, 0.5)],
	"steel_dark": ["metal_matte", Color(0.32, 0.32, 0.34)],
	"steel": ["metal_painted", Color(0.66, 0.68, 0.7)],
	"booth": ["metal_painted", Color(0.36, 0.42, 0.48)],
	"counter": ["wood_veneer_walnut", null],
	"rubber": ["rubber_black", null],
	"polymer": ["polymer_black", null],
	"line": ["paint_white", Color(1.0, 0.78, 0.12)],
	"glass": ["glass_clear", Color(0.75, 0.88, 0.95, 0.28)],
	"acrylic": ["glass_clear", Color(0.85, 0.9, 0.92, 0.18)],
	"ammo": ["paint_safety_orange", null],
}
## Emissive (untextured) materials: id -> [colour, energy].
const EMISSIVE: Dictionary = {
	"lamp": [Color(1.0, 0.88, 0.7), 2.6],
	"led_green": [Color(0.2, 1.0, 0.35), 2.0],
	"led_red": [Color(1.0, 0.18, 0.12), 2.0],
	"led_amber": [Color(1.0, 0.65, 0.1), 2.0],
}
const PROP_LOCKERS: String = "res://world/props/kitchen/prop_lockers.tscn"
const PROP_MONITOR: String = "res://world/props/office/prop_monitor.tscn"
const PROP_CHAIR: String = "res://world/props/office/prop_chair_task.tscn"

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


## Dresses `parent` (the range level, holding B's Floor / Walls / Bench). Returns the Dressing root.
static func build(layout: RangeLayout, parent: Node3D) -> Node3D:
	var root: Node3D = _node(parent, ROOT_NAME)
	var hall: AABB = hall_box(layout)
	_skin_kit(parent)
	_build_ceiling(_node(root, "Ceiling"), hall)
	_build_firing_line(_node(root, "FiringLine"), hall)
	_build_baffles(_node(root, "Baffles"), hall)
	_build_wall_panels(_node(root, "WallPanels"), hall)
	_build_backstop(_node(root, "Backstop"), hall)
	_build_bench(_node(root, "Bench"), layout)
	_build_rack(_node(root, "Rack"), hall)
	_build_booth(_node(root, "Booth"), hall)
	_build_lights(_node(root, "Lights"), layout, hall)
	return root


## The indoor Environment preset (dark background, modest ambient, AgX, light glow, no fog). B's FiringRange
## puts it on its WorldEnvironment and hides the sun when this is non-null.
static func environment() -> Environment:
	return load(ENVIRONMENT_PATH) as Environment


## Inner hall volume (floor to wall top, between the inner wall faces).
static func hall_box(layout: RangeLayout) -> AABB:
	var mn: Vector3 = Vector3(-layout.width_m * 0.5, 0.0, layout.far_z_m)
	var mx: Vector3 = Vector3(layout.width_m * 0.5 - WALL_T, WALL_H, layout.back_z_m - WALL_T)
	return AABB(mn, mx - mn)


## Light rows / columns: [name, position, range, energy, key]. Key lights (near the line) carry viewmodel_lit.
static func light_plan(layout: RangeLayout) -> Array[Array]:
	var out: Array[Array] = []
	var hall: AABB = hall_box(layout)
	var lanes_w: float = layout.lane_width_m * float(layout.lane_count())
	var cols: Array[float] = [-lanes_w * 0.25, lanes_w * 0.25]
	# Shooting area (behind the line): a wide row, all key lights.
	var zs: float = (hall.end.z) * 0.5
	var shoot_x: Array[float] = [-lanes_w * 0.25 - 10.5, cols[0], cols[1], lanes_w * 0.25 + 10.5]
	for i: int in range(shoot_x.size()):
		out.append(["Shoot%d" % i, Vector3(shoot_x[i], LAMP_Y, zs), 10.0, 2.4, true])
	# One pair per bay, down to the backstop.
	var bay: int = 1
	while -BAY * float(bay) > hall.position.z + BAY * 0.5 - 0.01:
		var z: float = -BAY * float(bay)
		for c: int in range(cols.size()):
			out.append(["Bay%02d_%d" % [bay, c], Vector3(cols[c], LAMP_Y, z), 11.0, 3.0, bay == 1])
		bay += 1
	# Side target areas (extra lanes): one light per 20 m of the area, over its centre.
	for a: Array in _areas(layout):
		var x: float = (float(a[1]) + float(a[2])) * 0.5
		var d: float = float(a[3])
		var n: int = 0
		while d <= float(a[4]) + 0.01:
			out.append(["Area_%s%d" % [String(a[0]), n], Vector3(x, LAMP_Y, -_bay_centre(d)), 11.0, 2.8, false])
			d += BAY * 2.0
			n += 1
	return out


# --- Kit skin ---------------------------------------------------------------------------------

## Material overrides on B's kit floor / wall pieces (their 4 m meshes already suit the light budget);
## their bodies get a surface tag when the kit left it empty.
static func _skin_kit(parent: Node3D) -> void:
	for group: String in ["Floor", "Walls"]:
		var g: Node = parent.get_node_or_null(NodePath(group))
		if g == null:
			continue
		for mi: Node in g.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			if m.mesh == null:
				continue
			for s: int in range(m.mesh.get_surface_count()):
				var base: Material = m.mesh.surface_get_material(s)
				var nm: String = base.resource_name if base != null else ""
				if nm.contains("floor"):
					m.set_surface_override_material(s, finish("floor"))
				elif nm.contains("wall"):
					m.set_surface_override_material(s, finish("wall"))
		for b: Node in g.find_children("*", "CollisionObject3D", true, false):
			if not b.has_meta(&"surface"):
				b.set_meta(&"surface", _surface("floor" if group == "Floor" else "wall"))


# --- Shell ------------------------------------------------------------------------------------

static func _build_ceiling(root: Node3D, hall: AABB) -> void:
	var nx: int = ceili(hall.size.x / TILE - 0.001)
	var nz: int = ceili(hall.size.z / TILE - 0.001)
	var tx: float = hall.size.x / float(nx)
	var tz: float = hall.size.z / float(nz)
	for i: int in range(nx):
		for j: int in range(nz):
			var mn: Vector3 = Vector3(hall.position.x + tx * i, WALL_H, hall.position.z + tz * j)
			_box(root, "Tile%02d_%02d" % [i, j], mn, mn + Vector3(tx, 0.12, tz), "ceiling")


## Painted firing line across the hall at z = 0 (just above B's lane lines).
static func _build_firing_line(root: Node3D, hall: AABB) -> void:
	var seg: float = 8.0
	var x: float = hall.position.x
	var i: int = 0
	while x < hall.end.x - 0.01:
		var x1: float = minf(x + seg, hall.end.x)
		_box(root, "Paint%02d" % i, Vector3(x, 0.0, -0.06), Vector3(x1, 0.012, 0.06), "line")
		x = x1
		i += 1


## Ballistic baffles hung across the hall every BAY m (tilted 30 deg, lower edge toward the line),
## visual only, split into 6 m pieces for the light budget.
static func _build_baffles(root: Node3D, hall: AABB) -> void:
	var k: int = 0
	var z: float = -BAY * 0.5
	var size_y: float = 0.7
	var tilt: float = deg_to_rad(30.0)
	while z > hall.position.z + 1.0:
		var nseg: int = ceili(hall.size.x / 6.0 - 0.001)
		var w: float = hall.size.x / float(nseg)
		for s: int in range(nseg):
			var mi: MeshInstance3D = _mesh_inst(root, "Baffle%02d_%d" % [k, s], Vector3(w, size_y, 0.06), "baffle")
			var b: Basis = Basis(Vector3.RIGHT, -tilt)
			mi.basis = b
			var top: Vector3 = Vector3(hall.position.x + w * (float(s) + 0.5), WALL_H, z)
			mi.position = top - b.y * (size_y * 0.5)
		# A steel hanger rail along the top edge.
		_box(root, "Rail%02d" % k, Vector3(hall.position.x, WALL_H - 0.08, z - 0.04),
			Vector3(hall.end.x, WALL_H, z + 0.04), "steel_dark")
		k += 1
		z -= BAY


## Acoustic panels on the side walls every 4 m (above B's wall-mounted distance signs), plus the back wall
## where the rack and booth leave room.
static func _build_wall_panels(root: Node3D, hall: AABB) -> void:
	var t: float = 0.05
	var z: float = hall.end.z - 2.0
	var k: int = 0
	while z - 1.2 > hall.position.z + 0.3:
		var z0: float = z - 1.2
		var z1: float = z + 1.2
		if z1 < hall.end.z - BOOTH_SIZE.z - 0.2:
			_box(root, "L%02d" % k, Vector3(hall.position.x, 1.35, z0), Vector3(hall.position.x + t, 3.45, z1), "panel")
		_box(root, "R%02d" % k, Vector3(hall.end.x - t, 1.35, z0), Vector3(hall.end.x, 3.45, z1), "panel")
		z -= 4.0
		k += 1
	var x: float = hall.position.x + BOOTH_SIZE.x + 1.6
	var i: int = 0
	while x + 2.4 < hall.end.x - 0.5:
		if x + 2.4 < RACK_X.x - 0.3 or x > RACK_X.y + 2.4:
			_box(root, "B%02d" % i, Vector3(x, 1.35, hall.end.z - t), Vector3(x + 2.4, 3.45, hall.end.z), "panel")
		x += 3.2
		i += 1


## Dark steel backstop angled up from the floor to the top of the far wall, a rubber trap berm at its foot.
static func _build_backstop(root: Node3D, hall: AABB) -> void:
	var run: float = 3.4
	var far: float = hall.position.z
	var d: Vector3 = Vector3(0.0, WALL_H - 0.02, -run)
	var length: float = d.length()
	var b: Basis = Basis(Vector3.RIGHT, atan2(-run, WALL_H))
	var thick: float = 0.12
	var centre_zy: Vector3 = Vector3(0.0, d.y * 0.5, far + run * 0.5) - b.z * (thick * 0.5)
	var body: StaticBody3D = _body(root, "Plate", "steel_dark")
	var nseg: int = ceili(hall.size.x / 6.0 - 0.001)
	var w: float = hall.size.x / float(nseg)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Collision"
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(hall.size.x, length, thick)
	shape.shape = bs
	shape.basis = b
	shape.position = centre_zy + Vector3(hall.get_center().x, 0.0, 0.0)
	body.add_child(shape)
	for s: int in range(nseg):
		var mi: MeshInstance3D = _mesh_inst(body, "Mesh%d" % s, Vector3(w, length, thick), "steel_dark")
		mi.basis = b
		mi.position = centre_zy + Vector3(hall.position.x + w * (float(s) + 0.5), 0.0, 0.0)
	for s: int in range(nseg):
		var x0: float = hall.position.x + w * float(s)
		_box(root, "Berm%d" % s, Vector3(x0, 0.0, far + run - 0.9), Vector3(x0 + w, 0.35, far + run + 0.25), "rubber")


# --- Shooting bench ---------------------------------------------------------------------------

## Dresses B's bench (a box over all lanes, z bench_z +- depth / 2, top at bench_height): a walnut counter
## and a steel kick plate per lane, and an acrylic divider with steel posts on every lane boundary. The
## dividers stand behind the counter's front edge and are visual only (crew walk through the line).
static func _build_bench(root: Node3D, layout: RangeLayout) -> void:
	var n: int = layout.lane_count()
	if n == 0:
		return
	var w: float = layout.lane_width_m
	var x0: float = layout.lane_x(0) - w * 0.5
	var zf: float = layout.bench_z_m - layout.bench_depth_m * 0.5   # front (down range) face
	var zb: float = layout.bench_z_m + layout.bench_depth_m * 0.5
	var top: float = layout.bench_height_m
	for i: int in range(n):
		var a: float = x0 + w * float(i)
		_box(root, "Counter%d" % i, Vector3(a + 0.04, top, zf - 0.06), Vector3(a + w - 0.04, top + 0.05, zb + 0.08), "counter")
		_box(root, "Kick%d" % i, Vector3(a + 0.02, 0.04, zf - 0.04), Vector3(a + w - 0.02, top - 0.02, zf), "steel_dark")
	var back: float = zb + 0.65
	for i: int in range(n + 1):
		var x: float = x0 + w * float(i)
		var p: Node3D = _node(root, "Divider%d" % i)
		_box(p, "PostFront", Vector3(x - 0.03, 0.0, zb - 0.03), Vector3(x + 0.03, 1.9, zb + 0.03), "steel_dark")
		_box(p, "PostBack", Vector3(x - 0.03, 0.0, back - 0.06), Vector3(x + 0.03, 1.9, back), "steel_dark")
		_box(p, "Rail", Vector3(x - 0.03, 1.86, zb - 0.03), Vector3(x + 0.03, 1.92, back), "steel_dark")
		_box(p, "Panel", Vector3(x - 0.012, top + 0.08, zb + 0.03), Vector3(x + 0.012, 1.86, back - 0.06), "acrylic")


# --- Props ------------------------------------------------------------------------------------

## Weapon rack against the back wall (steel cabinet, pegboard, six long guns, ammo cans) and two lockers.
static func _build_rack(root: Node3D, hall: AABB) -> void:
	var zw: float = hall.end.z
	var d: float = 0.45
	var x0: float = RACK_X.x
	var x1: float = RACK_X.y
	var body: StaticBody3D = _body(root, "RackBody", "steel_dark")
	_shape(body, Vector3(x0, 0.0, zw - d), Vector3(x1, 2.1, zw))
	_box(body, "Cabinet", Vector3(x0, 0.0, zw - d), Vector3(x1, 0.9, zw), "steel_dark")
	_box(body, "Top", Vector3(x0 - 0.02, 0.9, zw - d - 0.02), Vector3(x1 + 0.02, 0.94, zw), "counter")
	_box(body, "Board", Vector3(x0, 0.94, zw - 0.05), Vector3(x1, 2.1, zw), "steel")
	_box(body, "SideL", Vector3(x0, 0.94, zw - d), Vector3(x0 + 0.04, 2.1, zw), "steel_dark")
	_box(body, "SideR", Vector3(x1 - 0.04, 0.94, zw - d), Vector3(x1, 2.1, zw), "steel_dark")
	_box(body, "Shelf", Vector3(x0, 2.06, zw - d), Vector3(x1, 2.1, zw), "steel_dark")
	_box(body, "Bar", Vector3(x0, 1.45, zw - 0.2), Vector3(x1, 1.48, zw - 0.17), "steel_dark")
	for g: int in range(6):
		var x: float = x0 + 0.45 + 0.42 * float(g)
		var gun: Node3D = _node(body, "Gun%d" % g)
		_box(gun, "Stock", Vector3(x - 0.035, 0.94, zw - 0.22), Vector3(x + 0.035, 1.22, zw - 0.1), "polymer")
		_box(gun, "Receiver", Vector3(x - 0.03, 1.22, zw - 0.2), Vector3(x + 0.03, 1.5, zw - 0.12), "polymer")
		_box(gun, "Mag", Vector3(x - 0.025, 1.3, zw - 0.27), Vector3(x + 0.025, 1.42, zw - 0.2), "polymer")
		_box(gun, "Barrel", Vector3(x - 0.012, 1.5, zw - 0.17), Vector3(x + 0.012, 1.86, zw - 0.15), "steel_dark")
	for c: int in range(4):
		var cx: float = x0 + 0.3 + 0.7 * float(c)
		_box(body, "Ammo%d" % c, Vector3(cx, 2.1, zw - 0.32), Vector3(cx + 0.3, 2.28, zw - 0.14), "ammo")
	for l: int in range(2):
		var lk: Node3D = _prop(root, PROP_LOCKERS, "Lockers%d" % l)
		if lk != null:
			lk.position = Vector3(x1 + 0.6 + 0.92 * float(l), 0.0, zw - 0.27)
			lk.rotation.y = PI


## Range-control booth in the back-left corner behind the line: steel lower panels, glazing, roof, a door
## gap toward the shooting area, a console with LEDs and monitors facing the range, a chair and its own lamp.
static func _build_booth(root: Node3D, hall: AABB) -> void:
	var x0: float = hall.position.x
	var x1: float = x0 + BOOTH_SIZE.x
	var z1: float = hall.end.z
	var z0: float = z1 - BOOTH_SIZE.z
	var t: float = 0.08
	var sill: float = 1.05
	var head: float = 2.4
	var h: float = BOOTH_SIZE.y
	var door: Vector2 = Vector2(z1 - 1.3, z1 - 0.3)
	var frame: StaticBody3D = _body(root, "Frame", "booth")
	var glass: StaticBody3D = _body(root, "Glass", "glass")
	# Front (faces the range) and side (faces the walk area, door near the back wall).
	_solid(frame, "FrontLow", Vector3(x0, 0.0, z0), Vector3(x1, sill, z0 + t), "booth")
	_solid(frame, "FrontHead", Vector3(x0, head, z0), Vector3(x1, h, z0 + t), "booth")
	_solid(glass, "FrontPane", Vector3(x0, sill, z0 + 0.03), Vector3(x1 - t, head, z0 + 0.05), "glass")
	_solid(frame, "SideLow", Vector3(x1 - t, 0.0, z0), Vector3(x1, sill, door.x), "booth")
	_solid(frame, "SideHead", Vector3(x1 - t, head, z0), Vector3(x1, h, z1), "booth")
	_solid(glass, "SidePane", Vector3(x1 - 0.05, sill, z0 + t), Vector3(x1 - 0.03, head, door.x), "glass")
	_solid(frame, "Jamb", Vector3(x1 - t, 0.0, door.x), Vector3(x1, head, door.x + 0.08), "booth")
	_solid(frame, "PostBack", Vector3(x1 - t, 0.0, door.y), Vector3(x1, head, z1), "booth")
	_solid(frame, "Corner", Vector3(x1 - t, 0.0, z0), Vector3(x1, head, z0 + t), "booth")
	_solid(frame, "Roof", Vector3(x0, h, z0), Vector3(x1, h + 0.08, z1), "steel_dark")
	# Console along the front glass.
	var console: StaticBody3D = _body(root, "Console", "steel_dark")
	var cz: float = z0 + t
	_solid(console, "Desk", Vector3(x0 + 0.2, 0.0, cz), Vector3(x1 - 0.5, 0.82, cz + 0.7), "steel_dark")
	_box(console, "Top", Vector3(x0 + 0.18, 0.82, cz), Vector3(x1 - 0.48, 0.86, cz + 0.74), "counter")
	var panel: MeshInstance3D = _mesh_inst(console, "Panel", Vector3(x1 - x0 - 1.1, 0.04, 0.34), "steel")
	panel.basis = Basis(Vector3.RIGHT, deg_to_rad(18.0))
	panel.position = Vector3((x0 + x1) * 0.5 - 0.15, 0.92, cz + 0.52)
	var leds: Array[String] = ["led_green", "led_green", "led_amber", "led_red", "led_green", "led_amber", "led_green", "led_red"]
	for i: int in range(leds.size()):
		var led: MeshInstance3D = _mesh_inst(panel, "Led%d" % i, Vector3(0.05, 0.02, 0.05), leds[i])
		led.position = Vector3(-0.9 + 0.26 * float(i), 0.03, -0.06 + 0.1 * float(i % 2))
	for m: int in range(2):
		var mon: Node3D = _prop(console, PROP_MONITOR, "Monitor%d" % m)
		if mon != null:
			mon.position = Vector3(x0 + 1.3 + 1.5 * float(m), 0.86, cz + 0.12)
	var chair: Node3D = _prop(root, PROP_CHAIR, "Chair")
	if chair != null:
		chair.position = Vector3(x0 + 2.0, 0.0, cz + 1.25)
		chair.rotation.y = PI
	# Lamp: a panel under the roof and its light.
	_box(root, "LampPanel", Vector3(x0 + 1.6, h - 0.03, z0 + 1.6), Vector3(x0 + 3.0, h, z0 + 2.4), "lamp").set_meta(&"fixture", true)


# --- Lights -----------------------------------------------------------------------------------

static func _build_lights(root: Node3D, layout: RangeLayout, hall: AABB) -> void:
	var fixtures: Node3D = _node(root, "Fixtures")
	for p: Array in light_plan(layout):
		var pos: Vector3 = p[1]
		var key: bool = bool(p[4])
		var l: OmniLight3D = OmniLight3D.new()
		l.name = String(p[0])
		l.position = pos
		l.omni_range = float(p[2])
		l.omni_attenuation = 0.6
		l.light_energy = float(p[3])
		l.light_color = LAMP_COLOR
		l.shadow_enabled = false
		l.layers = 1 | (VIEWMODEL_LIT_LAYER if key else 0)
		if key:
			l.set_meta(&"key_light", true)
		root.add_child(l)
		# Strip fixture: a steel housing with an emissive diffuser, 4 m along the lane over the light.
		var len_m: float = 2.4 if pos.z > 0.0 else 4.0
		var f: Node3D = _node(fixtures, "Fx_" + String(p[0]))
		f.position = Vector3(pos.x, FIXTURE_Y, pos.z)
		f.set_meta(&"fixture", true)
		_box(f, "Housing", Vector3(-0.14, 0.0, -len_m * 0.5), Vector3(0.14, 0.09, len_m * 0.5), "steel_dark")
		_box(f, "Diffuser", Vector3(-0.1, -0.025, -len_m * 0.5 + 0.05), Vector3(0.1, 0.0, len_m * 0.5 - 0.05), "lamp")
		# Hung below the baffles' lower edge so the strips read all the way down range.
		for hz: int in range(2):
			var z: float = (float(hz) - 0.5) * len_m * 0.6
			_box(f, "Hanger%d" % hz, Vector3(-0.012, 0.09, z - 0.012), Vector3(0.012, WALL_H - FIXTURE_Y, z + 0.012), "steel_dark")
	# The booth lamp.
	var bl: OmniLight3D = OmniLight3D.new()
	bl.name = "Booth"
	bl.position = Vector3(hall.position.x + BOOTH_SIZE.x * 0.5, BOOTH_SIZE.y - 0.3, hall.end.z - BOOTH_SIZE.z * 0.5)
	bl.omni_range = 4.5
	bl.light_energy = 1.4
	bl.light_color = LAMP_COLOR
	bl.shadow_enabled = false
	bl.layers = 1
	root.add_child(bl)


## Extra-lane areas: [area, min x, max x, min distance, max distance], sorted by area id.
static func _areas(layout: RangeLayout) -> Array[Array]:
	var by: Dictionary = {}
	for def: RangeLaneDef in layout.extra_lanes:
		var a: Array = by.get(def.area, [def.area, def.x_m, def.x_m, def.distance_m, def.distance_m])
		by[def.area] = [def.area, minf(a[1], def.x_m - def.track_half_m), maxf(a[2], def.x_m + def.track_half_m),
			minf(a[3], def.distance_m), maxf(a[4], def.distance_m)]
	var keys: Array = by.keys()
	keys.sort_custom(func(p: StringName, q: StringName) -> bool: return String(p) < String(q))
	var out: Array[Array] = []
	for k: StringName in keys:
		out.append(by[k])
	return out


## Centre of the bay holding distance `d` (bays sit between the baffles).
static func _bay_centre(d: float) -> float:
	return maxf(1.0, roundf(d / BAY)) * BAY


# --- Helpers ----------------------------------------------------------------------------------

## A library finish duplicated as world triplanar (style guide texel density), tinted; cached.
static func finish(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if EMISSIVE.has(key):
		var e: StandardMaterial3D = StandardMaterial3D.new()
		e.resource_name = "range_" + key + "_emit"
		e.set_meta(&"untextured_ok", true)
		e.albedo_color = EMISSIVE[key][0]
		e.emission_enabled = true
		e.emission = EMISSIVE[key][0]
		e.emission_energy_multiplier = float(EMISSIVE[key][1])
		m = e
	else:
		var row: Array = FINISHES[key]
		var lib: String = String(row[0])
		var base: BaseMaterial3D = load(MAT_DIR + lib + ".tres") as BaseMaterial3D
		var bm: BaseMaterial3D = base.duplicate() as BaseMaterial3D
		bm.resource_name = "range_%s_%s" % [key, lib]
		if row[1] != null:
			var tint: Color = row[1]
			bm.albedo_color = base.albedo_color * tint
			if tint.a < 1.0:
				bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		var uv: float = 1.0 / float(base.get_meta(&"uv_tile_m", 2.0))
		if base.albedo_texture != null:
			var native: float = float(base.albedo_texture.get_width()) * uv
			if native < TEXEL_PX_M * 0.75 or native > TEXEL_PX_M * 1.5:
				uv = TEXEL_PX_M / float(base.albedo_texture.get_width())
		bm.uv1_triplanar = true
		bm.uv1_world_triplanar = true
		bm.uv1_scale = Vector3(uv, uv, uv)
		m = bm
	_mats[key] = m
	return m


## Bullet surface id for a finish key (surface_map.json through its library id).
static func _surface(key: String) -> StringName:
	if FINISHES.has(key):
		return SurfaceTags.for_id(String(FINISHES[key][0]))
	return &"metal"


static func _node(parent: Node, nm: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = nm
	parent.add_child(n)
	return n


static func _mesh_inst(parent: Node, nm: String, size: Vector3, key: String) -> MeshInstance3D:
	var mk: String = "%s|%.3f|%.3f|%.3f" % [key, size.x, size.y, size.z]
	if not _meshes.has(mk):
		var bm: BoxMesh = BoxMesh.new()
		bm.size = size
		bm.material = finish(key)
		_meshes[mk] = bm
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	mi.mesh = _meshes[mk]
	parent.add_child(mi)
	return mi


## Visual box from parent-local min / max corners.
static func _box(parent: Node, nm: String, mn: Vector3, mx: Vector3, key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = _mesh_inst(parent, nm, mx - mn, key)
	mi.position = (mn + mx) * 0.5
	return mi


## A static world body (layer 1, like the heist generators) tagged with the finish's bullet surface.
static func _body(parent: Node, nm: String, key: String) -> StaticBody3D:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.name = nm
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.set_meta(&"surface", _surface(key))
	parent.add_child(sb)
	return sb


static func _shape(body: StaticBody3D, mn: Vector3, mx: Vector3) -> CollisionShape3D:
	var c: CollisionShape3D = CollisionShape3D.new()
	c.name = "Shape%d" % body.get_child_count()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = mx - mn
	c.shape = bs
	c.position = (mn + mx) * 0.5
	body.add_child(c)
	return c


## Visual box plus a matching collision box on `body`.
static func _solid(body: StaticBody3D, nm: String, mn: Vector3, mx: Vector3, key: String) -> void:
	_box(body, nm, mn, mx, key)
	_shape(body, mn, mx)


static func _prop(parent: Node, path: String, nm: String) -> Node3D:
	var ps: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	n.name = nm
	parent.add_child(n)
	return n
