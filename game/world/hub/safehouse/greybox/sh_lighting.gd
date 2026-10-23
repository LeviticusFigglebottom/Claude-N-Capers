## Safehouse lighting lane (C4-03; safehouse.md §Lighting and mood). Owner: ENV C. Copy-adapted from Rolling
## Thunder's rt_gi.gd (D-147): the final night environment + lut_safehouse, the catalog fixtures (Light overrides,
## shadow casters, the modelled-but-off high-bays), the map-built lights (LIVE FIRE lamp, jukebox glow), one VoxelGI
## (baked by bake_safehouse_gi.gd), a ReflectionProbe per room and box occluders on the walls and roofs.
## Called by build_safehouse.gd before the navmesh bake.
extends RefCounted

const L: GDScript = preload("res://world/hub/safehouse/greybox/safehouse_layout.gd")
const OUT_DIR: String = "res://world/hub/safehouse/"
const LUT_PATH: String = "res://assets/luts/lut_safehouse.png"
const ENV_SCRIPT: String = "res://world/lighting/heist_world_environment.gd"
const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095)

var b: Object
var root: Node
var errors: PackedStringArray = PackedStringArray()


func _init(builder: Object) -> void:
	b = builder
	root = b.get(&"map_root")


## Night, ~23:30, light rain: a moonless overcast sky with an orange city glow (seen only through the rooflights), a
## low warm ambient so the shell stays readable on the Compatibility path (no GI bounce there), AgX, SSAO, subtle
## bloom (the jukebox and the pendants), lut_safehouse (warm mids, green-tinted shadows).
func environment(lighting: Node3D) -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.set_script(load(ENV_SCRIPT))  # brightness option (B5-01)
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_safehouse"
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.03, 0.03, 0.04)
	sky_mat.sky_horizon_color = Color(0.22, 0.12, 0.06)
	sky_mat.sky_curve = 0.2
	sky_mat.sky_energy_multiplier = 1.0
	sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.02)
	sky_mat.ground_horizon_color = Color(0.22, 0.12, 0.06)
	sky_mat.sun_angle_max = 0.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.52, 0.47)
	env.ambient_light_energy = 0.45
	# the dim night sky (not disabled): metals outside a probe, or before theirs first renders, keep a reflection
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_color_correction = load(LUT_PATH) as Texture
	we.environment = env
	_add(lighting, we)


## Fixtures, map-built lights, GI, probes and occluders. Returns the counts line.
func build() -> String:
	var lighting: Node3D = root.get_node("Lighting") as Node3D
	var fx: Node3D = _add(lighting, _node3d("Fixtures")) as Node3D
	var n_fix: int = fixtures(fx)
	var n_map: int = map_lights(fx)
	voxel_gi(lighting)
	var n_probe: int = reflection_probes(_add(lighting, _node3d("ReflectionProbes")) as Node3D)
	var n_occ: int = occluders(_add(lighting, _node3d("Occluders")) as Node3D)
	return "%d fixtures, %d map lights, 1 VoxelGI, %d probes, %d occluders" % [n_fix, n_map, n_probe, n_occ]


## Catalog fixtures (L.FIXTURES), anchored as the dressing passes do: ceiling fixtures 2 mm under the ceiling plane,
## wall ones centred on the anchor height 2 mm proud of the face, the rest standing on their surface.
func fixtures(parent: Node3D) -> int:
	for f: Array in L.FIXTURES:
		var asset: String = String(f[1])
		var e: Dictionary = PropCatalog.entry(StringName(asset))
		var ps: PackedScene = load(String(e.get("scene", ""))) as PackedScene if e.has("scene") else null
		if ps == null:
			errors.append("fixture %s: catalog asset %s has no scene" % [f[0], asset])
			continue
		var n: Node3D = ps.instantiate() as Node3D
		n.name = String(f[0])
		n.transform = _anchor(e, b.call(&"v3", f[2]), float(f[3]))
		_add(parent, n)
		var lt: Light3D = n.get_node_or_null("Light") as Light3D
		if lt == null:
			errors.append("fixture %s (%s) has no Light" % [f[0], asset])
			continue
		root.set_editable_instance(n, true)
		var ov: Dictionary = f[4]
		for k: String in ov:
			if not (k in lt):
				errors.append("fixture %s: Light has no `%s`" % [f[0], k])
				continue
			lt.set(StringName(k), ov[k])
		lt.shadow_enabled = bool(f[5])
		lt.visible = bool(f[6])
		lt.layers = lt.layers | VIEWMODEL_LIT_LAYER
	return L.FIXTURES.size()


func _anchor(e: Dictionary, pos: Vector3, yaw: float) -> Transform3D:
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw))
	var p: Vector3 = pos
	var mount: String = String(e.get("mount", ""))
	if mount == "wall":
		var a: Array = e.get("aabb", [0, 0, 0, 0, 0, 0])
		p -= Vector3.UP * (float(a[1]) + float(a[4]) * 0.5)
		p += basis * Vector3(0.0, 0.0, -0.002)
	elif mount == "ceiling":
		p.y -= 0.002
	return Transform3D(basis, p)


## L.MAP_LIGHTS: an OmniLight3D each; its fixture node gets meta fixture (levelcheck `lights`).
func map_lights(parent: Node3D) -> int:
	for m: Array in L.MAP_LIGHTS:
		var host: Node = root.get_node_or_null(String(m[5]))
		if host == null:
			errors.append("map light %s: no fixture node %s" % [m[0], m[5]])
			continue
		host.set_meta(&"fixture", true)
		var o: OmniLight3D = OmniLight3D.new()
		o.name = String(m[0])
		o.position = b.call(&"v3", m[1])
		o.light_color = m[2]
		o.light_energy = float(m[3])
		o.omni_range = float(m[4])
		o.shadow_enabled = false
		o.layers = 1 | VIEWMODEL_LIT_LAYER
		_add(parent, o)
	for a: Array in L.ART_LIGHTS:
		var marker: Node3D = root.get_node_or_null(String(a[1])) as Node3D
		if marker == null:
			errors.append("art light %s: no marker %s" % [a[0], a[1]])
			continue
		var host: Node = marker
		while host != null and not host.has_meta(&"art_asset"):
			host = host.get_parent()
		if host != null:   # as MAP_LIGHTS' hosts: the art carrying the lamp is the light's fixture
			host.set_meta(&"fixture", true)
		var al: OmniLight3D = OmniLight3D.new()
		al.name = String(a[0])
		al.position = (b.call(&"global_xform", marker) as Transform3D).origin
		al.light_color = a[2]
		al.light_energy = float(a[3])
		al.omni_range = float(a[4])
		al.shadow_enabled = false
		al.layers = 1 | VIEWMODEL_LIT_LAYER
		_add(parent, al)
	return L.MAP_LIGHTS.size() + L.ART_LIGHTS.size()


## The building's VoxelGI; its data is the baked file (bake_safehouse_gi.gd), an empty VoxelGIData until baked.
func voxel_gi(lighting: Node3D) -> void:
	var path: String = OUT_DIR + String(L.GI_VOLUME[1])
	if not ResourceLoader.exists(path):
		var empty: VoxelGIData = VoxelGIData.new()
		empty.interior = true
		ResourceSaver.save(empty, path)
	var lo: Vector3 = L.GI_VOLUME[2]
	var hi: Vector3 = L.GI_VOLUME[3]
	var vg: VoxelGI = VoxelGI.new()
	vg.name = String(L.GI_VOLUME[0])
	vg.position = (lo + hi) * 0.5
	vg.size = hi - lo
	vg.subdiv = VoxelGI.SUBDIV_128
	vg.data = load(path) as VoxelGIData
	_add(lighting, vg)


## One interior box-projected ReflectionProbe per room, updated once, no ambient.
func reflection_probes(parent: Node3D) -> int:
	var n: int = 0
	for r: Array in L.ROOMS:
		if String(r[1]) in L.PROBE_SKIP:
			continue
		var bx: Array = r[3]
		var mn: Vector3 = Vector3(float(bx[0]), float(bx[1]), float(bx[2]))
		var mx: Vector3 = Vector3(float(bx[3]), float(bx[4]), float(bx[5]))
		var probe: ReflectionProbe = ReflectionProbe.new()
		probe.name = "Probe%s" % String(r[0])
		probe.position = (mn + mx) * 0.5
		probe.size = mx - mn + Vector3(0.2, 0.1, 0.2)
		probe.box_projection = true
		probe.interior = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		probe.max_distance = maxf(probe.size.x, probe.size.z) * 1.5
		_add(parent, probe)
		n += 1
	return n


## Box occluders (inset 5 cm) from the solid wall pieces and the roof slabs. Glass and the fills never occlude.
func occluders(parent: Node3D) -> int:
	var rows: Array = []
	for path: String in ["Geometry/Building/Walls", "Geometry/Building/Roofs"]:
		var g: Node = root.get_node_or_null(path)
		if g == null:
			errors.append("no %s" % path)
			continue
		for c: Node in g.get_children():
			var body: StaticBody3D = c as StaticBody3D
			var cs: CollisionShape3D = body.get_node_or_null("Collision") as CollisionShape3D if body != null else null
			if cs == null or not (cs.shape is BoxShape3D):
				continue
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			var ok: bool = sz.x * sz.z >= L.OCC_SLAB_MIN_AREA if path.ends_with("Roofs") \
				else maxf(sz.x, sz.z) >= L.OCC_WALL_MIN_LEN and sz.y >= L.OCC_WALL_MIN_H
			if ok:
				rows.append([String(body.name), body.position - sz * 0.5, body.position + sz * 0.5, sz])
	for k: int in range(rows.size()):
		var r: Array = rows[k]
		var inset: Vector3 = Vector3(0.05, 0.05, 0.05).min((r[3] as Vector3) * 0.25)
		var occ: OccluderInstance3D = OccluderInstance3D.new()
		occ.name = "Occ%03d%s" % [k, String(r[0])]
		occ.position = ((r[1] as Vector3) + (r[2] as Vector3)) * 0.5
		var bo: BoxOccluder3D = BoxOccluder3D.new()
		bo.size = ((r[2] as Vector3) - (r[1] as Vector3) - inset * 2.0).max(Vector3(0.02, 0.02, 0.02))
		occ.occluder = bo
		_add(parent, occ)
	return rows.size()


func _add(parent: Node, c: Node) -> Node:
	parent.add_child(c)
	c.owner = root
	return c


static func _node3d(nm: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = nm
	return n
