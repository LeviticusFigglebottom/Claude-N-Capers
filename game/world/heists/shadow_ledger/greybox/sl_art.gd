## Shadow Ledger G2 art pass (SL-1, ENV C): the 02:10 overcast environment (city glow, rain haze, the LUT), the
## map-built light fixtures with catalog models, the lit city around the tower, merged railing visuals, reflection
## probes and occluders. Used by build_greybox.gd (`b` = the generator). Design: docs/design/heists/shadow_ledger.md
## §Audio/lighting (graphite and glass teal, cold-white LED accents; no sun or moon; low cloud lit orange-teal from
## below; LUT lut_shadow_ledger: cool, desaturated, teal mids, neutral whites).
extends RefCounted

const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095) = CrewView.VIEWMODEL_LIT_LAYER
const L: GDScript = preload("res://world/heists/shadow_ledger/greybox/shadow_ledger_layout.gd")
const LUT_PATH: String = "res://assets/luts/lut_shadow_ledger.png"
## Lit window grids on the neighbours' facades the glazing looks at (dim emissive, flush on the facade, merged per
## facade): [name, axis of the facade face, fixed (the face), from, to, y0, y1, outward sign]. Rows of 1 m windows
## every 3.6 m (a storey), 2 m wide with 1.2 m piers; floors dark, full or partly lit (fixed seed). The south / south-west / east
## skyline towers and their windows are sl_skyline.gd's (SL-1 polish).
const WINDOW_GRIDS: Array = [
	["ArdenEast", "z", -20.2, -28.0, 38.0, -40.0, 32.0, 1.0],
	["VantageWest", "z", 66.2, -6.0, 30.0, -60.0, -2.0, -1.0],
]

## RoofDressing pieces merged per prefix (merge_city): the crown fins and the helipad edge lights (housing, green lens).
const ROOF_MERGE: Array[String] = ["CrownFinN", "CrownFinS", "PadLightBase", "PadLightLens"]

## Seed of the facades' lit-window rolls (city_windows; plus the facade name's hash).
const WINDOW_SEED: int = 7_1704

## Rooms without a reflection probe: the exteriors, shafts, the stairs and the matte back-of-house rooms (corridors,
## storage, electrical, plant): nothing glossy there, and every probe is six scene renders on its first frame.
const PROBE_SKIP: Array[String] = ["exterior", "shaft", "elevator", "stair", "corridor", "storage", "electrical", "plant"]

var b: Object


func _init(builder: Object) -> void:
	b = builder


# --- Environment ---------------------------------------------------------------------------------

## 02:10, overcast, heavy rain (doc §Audio/lighting): a dark sky with the low cloud lit orange-teal from below by the
## city (horizon glow), a cool ambient so the unlit corners read, rain haze (fog), Filmic tonemap, glow for the LED
## coves / crown fins / helipad, SSAO, lut_shadow_ledger. No sun or moon: one dim directional stands for the city glow.
func environment(lighting: Node3D, root: Node) -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.set_script(load("res://world/lighting/heist_world_environment.gd"))  # brightness option (B5-01)
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_shadow_ledger"
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.035, 0.045, 0.06)
	sky_mat.sky_horizon_color = Color(0.25, 0.19, 0.15)
	sky_mat.sky_curve = 0.18
	sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.035)
	sky_mat.ground_horizon_color = Color(0.2, 0.17, 0.15)
	sky_mat.sky_energy_multiplier = 0.75
	sky_mat.sun_angle_max = 1.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.33, 0.37, 0.42)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.25
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.3, 0.31, 0.34)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.45
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_color_correction = load(LUT_PATH) as Texture
	we.environment = env
	lighting.add_child(we)
	we.owner = root
	var glow: DirectionalLight3D = DirectionalLight3D.new()
	glow.name = "CityGlow"
	glow.basis = Basis.looking_at(Vector3(-0.3, -0.45, 0.85).normalized(), Vector3.UP)
	glow.position = Vector3(18.0, 40.0, 12.0)
	glow.light_color = Color(0.86, 0.72, 0.58)
	glow.light_energy = 0.12
	glow.shadow_enabled = false
	glow.layers = 1 | VIEWMODEL_LIT_LAYER  # D-095 like every map light
	lighting.add_child(glow)
	glow.owner = root


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


# --- City ----------------------------------------------------------------------------------------

## Lit office floors on the neighbours the glazing looks at (WINDOW_GRIDS): one merged mesh per facade, 1 cm proud of
## its face, the lit-window emissive (meta distant: far texel target), visual only.
func city_windows(site: Node3D, root: Node) -> int:
	var holder: Node3D = Node3D.new()
	holder.name = "CityWindows"
	site.add_child(holder)
	holder.owner = root
	var mat: Material = b.call(&"lib_mat", "city_lights") as Material
	var n: int = 0
	for g: Array in WINDOW_GRIDS:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var along_x: bool = String(g[1]) == "x"
		var face: float = float(g[2]) + float(g[7]) * 0.01
		var nrm: Vector3 = (Vector3.BACK if along_x else Vector3.RIGHT) * float(g[7])
		# SL-1 polish: a local generator with a fixed seed per facade (never the global one): each floor is dark, fully
		# lit or partly lit at the facade's occupancy (the old hash lit a regular two-in-three grid)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = WINDOW_SEED + String(g[0]).hash()
		var occupancy: float = rng.randf_range(0.25, 0.55)
		var y: float = float(g[5])
		var quads: int = 0
		while y + 0.9 <= float(g[6]):
			var roll: float = rng.randf()
			var p: float = 0.0 if roll < 0.28 else (1.0 if roll < 0.4 else occupancy)
			var a: float = float(g[3])
			while a + 1.8 <= float(g[4]):
				if rng.randf() < p:
					var lo: Vector3 = Vector3(a, y, face) if along_x else Vector3(face, y, a)
					var hi: Vector3 = Vector3(a + 1.8, y + 0.9, face) if along_x else Vector3(face, y + 0.9, a + 1.8)
					_quad(st, lo, hi, nrm, along_x)
					quads += 1
				a += 3.2
			y += 3.6
		if quads == 0:
			continue
		st.set_material(mat)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = String(g[0])
		mi.mesh = st.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta(&"distant", true)
		holder.add_child(mi)
		mi.owner = root
		n += quads
	return n


## One flat rectangle facing `nrm` (clockwise as seen from that side).
static func _quad(st: SurfaceTool, lo: Vector3, hi: Vector3, nrm: Vector3, along_x: bool) -> void:
	var a: Vector3 = lo
	var c: Vector3 = hi
	var bb: Vector3 = Vector3(hi.x, lo.y, lo.z) if along_x else Vector3(lo.x, lo.y, hi.z)
	var d: Vector3 = Vector3(lo.x, hi.y, lo.z) if along_x else Vector3(lo.x, hi.y, lo.z)
	var pts: Array = [a, d, c, a, c, bb]
	var tri_n: Vector3 = (d - a).cross(c - a)
	if tri_n.dot(nrm) > 0.0:  # Godot front faces wind clockwise: flip when the cross product points outward
		pts = [a, c, d, a, bb, c]
	for p: Vector3 in pts:
		st.set_normal(nrm)
		st.set_uv(Vector2(p.x + p.z, p.y))
		st.add_vertex(p)


## SurfaceTool.append_from with an index on every source: a non-indexed surface (box caps, slab tiles) appended after
## an indexed one adds its vertices but no indices, and its triangles vanish from the merged mesh.
static func append_indexed(st: SurfaceTool, mesh: Mesh, surface: int, xf: Transform3D) -> void:
	var tmp: SurfaceTool = SurfaceTool.new()
	tmp.create_from(mesh, surface)
	tmp.index()
	st.append_from(tmp.commit(), 0, xf)


# --- Railings ------------------------------------------------------------------------------------

## Every railing's top rail and posts become one mesh (one draw instead of up to 41); the glass pane stays its own
## mesh. Visual only: the railing body, its ridged collider and kind meta are unchanged.
func merge_railings(root: Node) -> int:
	var saved: int = 0
	for body: Node in root.find_children("*", "StaticBody3D", true, false):
		if String(body.get_meta(&"kind", "")) != "railing" or body.owner != root:
			continue
		var parts: Array[MeshInstance3D] = []
		for c: Node in body.get_children():
			if c is MeshInstance3D and (String(c.name) == "TopRail" or String(c.name).begins_with("Post")):
				parts.append(c as MeshInstance3D)
		if parts.size() < 2:
			continue
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mat: Material = null
		for mi: MeshInstance3D in parts:
			append_indexed(st, mi.mesh, 0, mi.transform)
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


## The lit window boxes of one band (Geometry/Site/CityLights/<band>_NN), the crown fins (RoofDressing/CrownFin<N|S>NN)
## and the helipad's edge lights / markings (RoofDressing/<ROOF_MERGE prefix>NN) become one mesh each (one draw per
## band instead of one per piece). Visual only; the fins and lights keep their fixture meta.
func merge_city(root: Node) -> int:
	var saved: int = 0
	for grp: Array in [["Geometry/Site/CityLights", "_"], ["Geometry/Site/RoofDressing", "CrownFin"]]:
		var holder: Node = root.get_node_or_null(String(grp[0]))
		if holder == null:
			continue
		var bands: Dictionary = {}  # band name -> [MeshInstance3D]
		var order: Array[String] = []
		for c: Node in holder.get_children():
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi == null:
				continue
			var nm: String = String(mi.name)
			var band: String
			if String(grp[1]) == "_":
				band = nm.get_slice("_", 0)
			else:
				for pf: String in ROOF_MERGE:
					if nm.begins_with(pf):
						band = pf
						break
				if band == "":
					continue
			if not bands.has(band):
				bands[band] = []
				order.append(band)
			(bands[band] as Array).append(mi)
		for band: String in order:
			var parts: Array = bands[band]
			if parts.size() < 2:
				continue
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var mat: Material = null
			var fixture: bool = false
			for p: Variant in parts:
				var mi2: MeshInstance3D = p
				append_indexed(st, mi2.mesh, 0, mi2.transform)
				mat = mi2.mesh.surface_get_material(0)
				fixture = fixture or mi2.has_meta(&"fixture")
			st.set_material(mat)
			var merged: MeshInstance3D = MeshInstance3D.new()
			merged.name = band + ("s" if String(grp[1]) != "_" else "Windows")
			merged.mesh = st.commit()
			merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if fixture:
				merged.set_meta(&"fixture", true)
			for p2: Variant in parts:
				holder.remove_child(p2 as Node)
				(p2 as Node).free()
			holder.add_child(merged)
			merged.owner = root
			saved += parts.size() - 1
	return saved


## The opaque curtain-wall visuals of one storey (Geometry/Building/Facade/<level>: spandrels, bands, mullions, sills)
## become one mesh per material (the exterior views drew every facade box: perf). Visual only: the bodies keep their
## colliders and metas; the glass panes (transparent) stay whole and separate. Runs after the occluders (colliders).
func merge_facade(root: Node) -> int:
	var saved: int = 0
	var holder: Node = root.get_node_or_null("Geometry/Building/Facade")
	if holder == null:
		return 0
	for lvl: Node in holder.get_children():
		var lxf: Transform3D = (b.call(&"global_xform", lvl) as Transform3D).affine_inverse()
		var groups: Dictionary = {}  # "<material id>|<shadow>" -> [SurfaceTool, Material, ShadowCastingSetting]
		var order: Array[String] = []
		var parts: Array[MeshInstance3D] = []
		for c: Node in lvl.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi.mesh == null or mi.get_child_count() > 0 or mi.owner != root or not mi.get_meta_list().is_empty():
				continue
			var opaque: bool = true
			for s: int in range(mi.mesh.get_surface_count()):
				var bm: BaseMaterial3D = mi.get_active_material(s) as BaseMaterial3D
				opaque = opaque and bm != null and bm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			if not opaque:
				continue
			var xf: Transform3D = lxf * (b.call(&"global_xform", mi) as Transform3D)
			for s2: int in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(s2)
				var key: String = "%d|%d" % [mat.get_instance_id(), mi.cast_shadow]
				if not groups.has(key):
					var st: SurfaceTool = SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					groups[key] = [st, mat, mi.cast_shadow]
					order.append(key)
				append_indexed(groups[key][0] as SurfaceTool, mi.mesh, s2, xf)
			parts.append(mi)
		if parts.size() < 2:
			continue
		for k: int in range(order.size()):
			var g: Array = groups[order[k]]
			var st2: SurfaceTool = g[0]
			st2.set_material(g[1])
			var merged: MeshInstance3D = MeshInstance3D.new()
			merged.name = "FacadeMesh%02d" % k
			merged.mesh = st2.commit()
			merged.cast_shadow = g[2]
			lvl.add_child(merged)
			merged.owner = root
		for mi2: MeshInstance3D in parts:
			mi2.get_parent().remove_child(mi2)
			mi2.free()
		saved += parts.size() - order.size()
	return saved


# --- Probes and occluders ------------------------------------------------------------------------

## One interior ReflectionProbe per room box (box projection, updated once); PROBE_SKIP rooms get none.
func reflection_probes(parent: Node3D, root: Node) -> int:
	var n: int = 0
	for rv: Node in root.get_node("Rooms").get_children():
		var room: RoomVolume = rv as RoomVolume
		if room == null or String(room.purpose) in PROBE_SKIP:
			continue
		var i: int = 0
		for c: Node in room.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D):
				continue
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			var probe: ReflectionProbe = ReflectionProbe.new()
			probe.name = "Probe%s%s" % [String(room.room_id), "" if i == 0 else str(i)]
			probe.position = cs.position
			probe.size = sz + Vector3(0.2, 0.1, 0.2)
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


## Box occluders: the floor slabs (they hide the other storeys from every interior view), the solid L40 facade, the
## plant block roof and every solid interior wall piece >= 2.5 m long and >= 2.4 m tall (the core walls, the BOH
## partitions).
func occluders(parent: Node3D, root: Node) -> int:
	var rows: Array = []
	var bld: Node = root.get_node("Geometry/Building")
	for grp: String in ["Slabs", "Facade/L40", "InteriorWalls"]:
		var g: Node = bld.get_node_or_null(grp)
		if g == null:
			continue
		for body: Node in g.find_children("*", "StaticBody3D", true, false):
			var cs: CollisionShape3D = body.get_node_or_null("Collision") as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D) or not (body as Node3D).basis.is_equal_approx(Basis.IDENTITY):
				continue
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			var c: Vector3 = b.call(&"global_xform", body).origin + cs.position
			var big: bool
			if grp == "Slabs":
				big = sz.x * sz.z >= 4.0 and String(body.name).begins_with("Slab")
			else:
				big = maxf(sz.x, sz.z) >= 2.5 and sz.y >= 2.4
			if not big:
				continue
			var inset: Vector3 = Vector3(0.05, 0.05, 0.05).min(sz * 0.25)
			rows.append([String(body.name), c - sz * 0.5 + inset, c + sz * 0.5 - inset])
	for k: int in range(rows.size()):
		var r: Array = rows[k]
		var occ: OccluderInstance3D = OccluderInstance3D.new()
		occ.name = "Occluder%03d%s" % [k, String(r[0])]
		var a: Vector3 = r[1]
		var e: Vector3 = r[2]
		occ.position = (a + e) * 0.5
		var bo: BoxOccluder3D = BoxOccluder3D.new()
		bo.size = (e - a).max(Vector3(0.02, 0.02, 0.02))
		occ.occluder = bo
		parent.add_child(occ)
		occ.owner = root
	return rows.size()
