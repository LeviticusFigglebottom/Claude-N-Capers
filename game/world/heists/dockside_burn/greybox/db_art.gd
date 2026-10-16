## Dockside Burn G2 art pass (DB-C2, ENV C): the pre-dawn environment (fog, LUT, the moon), the map-built light
## fixtures with catalog models, the far skyline ring, merged railing visuals, reflection probes and occluders. Used by
## build_greybox.gd (`b` = the generator). Design: docs/design/heists/dockside_burn.md §Audio/lighting (05:10, harbour
## fog, sodium yard, cold-store LEDs; LUT lut_dockside_burn: cold blue-grey shadows, sodium-orange highlights).
extends RefCounted

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER
## The moon lights only visuals on this render layer (layer 3): the outside of the building and the site.
const MOON_LAYER: int = 1 << 2
const L: GDScript = preload("res://world/heists/dockside_burn/greybox/dockside_burn_layout.gd")
const D: GDScript = preload("res://world/heists/dockside_burn/greybox/dockside_burn_dressing.gd")
const LUT_PATH: String = "res://assets/luts/lut_dockside_burn.png"
## Far skyline ring, 280-400 m out, the harbour side at 340 m with its lights in front (bounds: no eye ray, diagonals
## included, travels 500 m into the void):
## [side, fixed, from, to, depth sign, min h, max h].
const SKYLINE: Array = [
	["N", -280.0, -320.0, 420.0, -1.0, 14.0, 42.0],
	["S", 340.0, -320.0, 420.0, 1.0, 10.0, 28.0],
	["W", -300.0, -280.0, 380.0, -1.0, 12.0, 36.0],
	["E", 400.0, -280.0, 380.0, 1.0, 14.0, 44.0],
]
## Exterior visual groups lit by the moon (Geometry paths; their MeshInstance3D descendants get MOON_LAYER).
const MOONLIT: Array[String] = ["Geometry/Site", "Geometry/Building/Coping", "Geometry/Building/Sheds",
	"Geometry/Building/Railings", "Geometry/Building/Stairs/FireStair"]
const ROOFS: Array[String] = ["RoofSlabA", "RoofSlabB", "HeadHouseRoof", "HallRoof", "WingRoof", "BayRoof"]

var b: Object


func _init(builder: Object) -> void:
	b = builder


# --- Environment ---------------------------------------------------------------------------------

## 05:10 pre-dawn (doc §Audio/lighting): a dark blue-grey procedural sky, lighter low in the east; the harbour fog
## (the lead's 2026-10-12 density; the mission thins it on `fog_lifts`); a cool ambient so unlit corners read; Filmic
## tonemap, glow for the sodium heads and LEDs; lut_dockside_burn. The moon (low SW, shadowless) lights only the
## outside (MOON_LAYER).
func environment(lighting: Node3D, root: Node) -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.set_script(load("res://world/lighting/heist_world_environment.gd"))  # brightness option (B5-01)
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_dockside_burn"
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.03, 0.045, 0.08)
	sky_mat.sky_horizon_color = Color(0.17, 0.19, 0.24)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.02, 0.025, 0.035)
	sky_mat.ground_horizon_color = Color(0.14, 0.15, 0.17)
	sky_mat.sky_energy_multiplier = 0.7
	sky_mat.sun_angle_max = 1.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.38, 0.46)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.25
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.34, 0.35, 0.39)
	# LEAD 2026-10-12 (D 20/40 m read): density 0.0035, height 2.0, height_density 0.015.
	env.fog_density = 0.0035
	env.fog_height = 2.0
	env.fog_height_density = 0.015
	env.fog_sky_affect = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_color_correction = load(LUT_PATH) as Texture
	we.environment = env
	lighting.add_child(we)
	we.owner = root
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	# low in the SW: light travels toward the NE and down (~20 deg altitude)
	moon.basis = Basis.looking_at(Vector3(0.62, -0.34, -0.7).normalized(), Vector3.UP)
	moon.position = Vector3(24.0, 40.0, 16.0)
	moon.light_color = Color(0.6, 0.68, 0.86)
	moon.light_energy = 0.22
	moon.shadow_enabled = false
	moon.light_cull_mask = MOON_LAYER
	moon.layers = 1 | VIEWMODEL_LIT_LAYER  # D-095 like every map light; its cull mask keeps it off the viewmodel anyway
	lighting.add_child(moon)
	moon.owner = root


## Puts the outside visuals (site, roofs, outer wall skins, sheds, coping, exterior railings) on MOON_LAYER too.
func moonlit(root: Node) -> void:
	var groups: Array[Node] = []
	for p: String in MOONLIT:
		var g: Node = root.get_node_or_null(p)
		if g != null:
			groups.append(g)
	for w: Node in root.get_node("Geometry/Building/ExteriorWalls").get_children():
		if String(w.name).contains("Out_"):
			groups.append(w)
	for s: Node in root.get_node("Geometry/Building/Slabs").get_children():
		if String(s.name).get_slice("_", 0) in ROOFS:
			groups.append(s)
	for g2: Node in groups:
		var ms: Array[Node] = g2.find_children("*", "MeshInstance3D", true, false)
		if g2 is MeshInstance3D:
			ms.append(g2)
		for m: Node in ms:
			if m.owner == root:
				(m as MeshInstance3D).layers = 1 | MOON_LAYER


# --- Map-built fixtures --------------------------------------------------------------------------

## A catalog fixture's glb model (no wrapper, no light) as child `Model` of a map-built light fixture node.
func fixture_model(parent: Node3D, asset: String, root: Node) -> void:
	var path: String = "res://assets/props/%s/%s.glb" % [asset, asset]
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		push_error("fixture model %s missing" % path)
		return
	var m: Node3D = ps.instantiate() as Node3D
	m.name = "Model"
	parent.add_child(m)
	m.owner = root


# --- Skyline -------------------------------------------------------------------------------------

## The far ring (400-500 m, in the fog): warehouse and terminal silhouettes of deterministic heights round the site, one
## merged mesh per side (meta distant: 256 px/m target), visual only. Closes every horizontal eye ray (bounds).
func skyline(site: Node3D, root: Node) -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "Skyline"
	site.add_child(holder)
	holder.owner = root
	var mat: Material = b.call(&"lib_mat", "brick_dark") as Material
	for s: Array in SKYLINE:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var along_x: bool = String(s[0]) in ["N", "S"]
		var fixed: float = float(s[1])
		var a: float = float(s[2])
		var i: int = 0
		while a < float(s[3]):
			var h: int = ((i * 7919 + int(fixed) * 31) % 97 + 97) % 97
			var w: float = 18.0 + float(h % 5) * 9.0
			var hgt: float = lerpf(float(s[5]), float(s[6]), float(h) / 96.0)
			var depth: float = 14.0 + float(h % 3) * 6.0
			var f0: float = fixed
			var f1: float = fixed + float(s[4]) * depth
			var lo: Vector3 = Vector3(a, -3.0, minf(f0, f1)) if along_x else Vector3(minf(f0, f1), -3.0, a)
			var hi: Vector3 = Vector3(minf(a + w, float(s[3])), hgt, maxf(f0, f1)) if along_x \
				else Vector3(maxf(f0, f1), hgt, minf(a + w, float(s[3])))
			_box_faces(st, lo, hi)
			a += w
			i += 1
		st.generate_tangents()
		st.set_material(mat)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Skyline" + String(s[0])
		mi.mesh = st.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta(&"distant", true)
		holder.add_child(mi)
		mi.owner = root


## A closed box's six outward faces (clockwise front faces), world UVs.
static func _box_faces(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var mid: Vector3 = (lo + hi) * 0.5
	var h: Vector3 = (hi - lo) * 0.5
	var faces: Array = [[Vector3.LEFT, Vector3.UP, Vector3.BACK], [Vector3.RIGHT, Vector3.BACK, Vector3.UP],
		[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP], [Vector3.BACK, Vector3.UP, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.BACK, Vector3.RIGHT], [Vector3.UP, Vector3.RIGHT, Vector3.BACK]]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c: Vector3 = mid + n * h
		var hu: Vector3 = u * absf(u.dot(h))
		var hv: Vector3 = v * absf(v.dot(h))
		var q: Array = [c - hu - hv, c + hu - hv, c + hu + hv, c - hu + hv]
		for k: int in [0, 1, 2, 0, 2, 3]:
			var p: Vector3 = q[k]
			st.set_normal(n)
			st.set_uv(Vector2(p.dot(u), p.dot(v)))
			st.add_vertex(p)


# --- Railings ------------------------------------------------------------------------------------

## Every railing's top rail, mid rail and posts become one mesh (one draw instead of up to 42). Visual only: the
## railing body, its ridged collider and kind meta are unchanged.
func merge_railings(root: Node) -> int:
	var saved: int = 0
	for body: Node in root.find_children("*", "StaticBody3D", true, false):
		if String(body.get_meta(&"kind", "")) != "railing" or body.owner != root:
			continue
		var parts: Array[MeshInstance3D] = []
		for c: Node in body.get_children():
			if c is MeshInstance3D:
				parts.append(c as MeshInstance3D)
		if parts.size() < 2:
			continue
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mat: Material = null
		for mi: MeshInstance3D in parts:
			st.append_from(mi.mesh, 0, mi.transform)
			mat = mi.mesh.surface_get_material(0)
		st.set_material(mat)
		var merged: MeshInstance3D = MeshInstance3D.new()
		merged.name = "RailMesh"
		merged.mesh = st.commit()
		for mi2: MeshInstance3D in parts:
			body.remove_child(mi2)
			mi2.free()
		body.add_child(merged)
		merged.owner = root
		saved += parts.size() - 1
	return saved


# --- Probes and occluders ------------------------------------------------------------------------

## One interior ReflectionProbe per room box (box projection, updated once).
func reflection_probes(parent: Node3D, root: Node) -> int:
	var n: int = 0
	for r: Array in L.ROOMS:
		if String(r[1]) == "exterior":
			continue
		var i: int = 0
		for bb: Variant in r[4]:
			var a: Array = bb
			var lo: Vector3 = Vector3(float(a[0]), float(a[1]), float(a[2]))
			var hi: Vector3 = Vector3(float(a[3]), float(a[4]), float(a[5]))
			var probe: ReflectionProbe = ReflectionProbe.new()
			probe.name = "Probe%s%s" % [String(r[0]), "" if i == 0 else str(i)]
			probe.position = (lo + hi) * 0.5
			probe.size = hi - lo + Vector3(0.2, 0.1, 0.2)
			probe.box_projection = true
			probe.interior = true
			probe.update_mode = ReflectionProbe.UPDATE_ONCE
			probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
			probe.max_distance = maxf(probe.size.x, probe.size.z) * 1.5
			parent.add_child(probe)
			probe.owner = root
			i += 1
			n += 1
	return n


## Box occluders: the solid runs (>= 3 m, no openings) of the building's exterior walls, the tall site blocks
## (Bellweather, the Ferro St backs, the Pier 10 stacks) and the yard containers.
func occluders(parent: Node3D, root: Node) -> int:
	var rows: Array = []
	var k: int = 0
	for w: Array in L.EXT_WALLS:
		var axis: String = String(w[1])
		var fixed: float = float(w[2])
		var ops: Array = (w[8] as Array).duplicate()
		ops.append_array(b.call(&"_openings", axis, fixed, float(w[3]), float(w[4]), float(w[5]), float(w[6]), L.EXT_T))
		for run: Vector2 in _solid_runs(float(w[3]), float(w[4]), ops):
			if run.y - run.x < 3.0:
				continue
			var y0: float = float(w[5]) + 0.05
			var y1: float = float(w[6]) - 0.05
			var lo: Vector3 = Vector3(run.x + 0.05, y0, fixed - 0.1) if axis == "x" else Vector3(fixed - 0.1, y0, run.x + 0.05)
			var hi: Vector3 = Vector3(run.y - 0.05, y1, fixed + 0.1) if axis == "x" else Vector3(fixed + 0.1, y1, run.y - 0.05)
			rows.append(["Wall%02d" % k, lo, hi])
			k += 1
	for bl: Array in L.BLOCKS:
		var bb: Array = bl[1]
		var lo2: Vector3 = Vector3(float(bb[0]), float(bb[1]), float(bb[2]))
		var hi2: Vector3 = Vector3(float(bb[3]), float(bb[4]), float(bb[5]))
		var sz: Vector3 = hi2 - lo2
		if sz.y >= 5.0 and minf(sz.x, sz.z) >= 1.5 and lo2.y < 1.0:
			rows.append([String(bl[0]), lo2 + Vector3(0.05, 0.05, 0.05), hi2 - Vector3(0.05, 0.05, 0.05)])
	for p: Array in L.PROPS:
		if String(p[4]) != "container":
			continue
		var base: Vector3 = p[1]
		var s: Vector3 = p[2]
		rows.append([String(p[0]), base - Vector3(s.x * 0.5 - 0.1, -0.05, s.z * 0.5 - 0.1),
			base + Vector3(s.x * 0.5 - 0.1, s.y - 0.05, s.z * 0.5 - 0.1)])
	for r: Array in rows:
		var occ: OccluderInstance3D = OccluderInstance3D.new()
		occ.name = "Occluder" + String(r[0])
		var a: Vector3 = r[1]
		var c: Vector3 = r[2]
		occ.position = (a + c) * 0.5
		var bo: BoxOccluder3D = BoxOccluder3D.new()
		bo.size = (c - a).max(Vector3(0.02, 0.02, 0.02))
		occ.occluder = bo
		parent.add_child(occ)
		occ.owner = root
	return rows.size()


## [a0, a1] minus the openings ([along0, along1, y0, y1], 0.1 m margin): the solid runs.
static func _solid_runs(a0: float, a1: float, ops: Array) -> Array[Vector2]:
	var cuts: Array = []
	for o: Array in ops:
		cuts.append(Vector2(float(o[0]) - 0.1, float(o[1]) + 0.1))
	cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var out: Array[Vector2] = []
	var cur: float = a0
	for c: Vector2 in cuts:
		if c.x > cur:
			out.append(Vector2(cur, minf(c.x, a1)))
		cur = maxf(cur, c.y)
	if a1 > cur:
		out.append(Vector2(cur, a1))
	return out
