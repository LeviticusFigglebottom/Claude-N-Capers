## Ostrander Federal G2 lighting lane (OF-C2, ENV C): the final 15:10 environment (lut_ostrander_federal), the SW sun
## with its cloud-shadow energy curve, a VoxelGI per level band, a ReflectionProbe per room and the box occluders.
## Design: docs/design/heists/ostrander_federal.md §Audio/lighting (time, GI, LUT) and §Budgets (shadowed lights).
## Used by build_greybox.gd (`b` = the generator):
##   var gi: RefCounted = OF_GI.new(self)
##   gi.call(&"environment", n("Lighting"))      # WorldEnvironment + Sun (replaces the G1 greybox environment)
##   gi.call(&"build")                           # VoxelGI bands, probes, occluders (after the art passes)
## Everything here is visual only: Lighting/** holds no collider, so the navmesh (baked from Geometry colliders) and
## every gameplay node are unchanged. The VoxelGI data is baked separately by bake_gi.gd (under xvfb, see its header)
## into one .res per band; the generator only references those files (an empty VoxelGIData when one is missing).
extends RefCounted

const OUT_DIR: String = "res://world/heists/ostrander_federal/"
const LUT_PATH: String = "res://assets/luts/lut_ostrander_federal.png"
const SUN_SCRIPT: String = "res://world/lighting/sun_cloud_curve.gd"
const ENV_SCRIPT: String = "res://world/lighting/heist_world_environment.gd"
const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095)
const POLICY_SCRIPT: String = "res://world/lighting/render_budget_policy.gd"
## D-146 (<= 4,000 draws per view with the shadow passes): the sun's cascades re-draw every caster in their slices
## (indoors: every floor above the camera), so 2 splits over 30 m (was 4 over 90 m).
const SUN_SHADOW_MODE: DirectionalLight3D.ShadowMode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
const SUN_SHADOW_MAX_DISTANCE: float = 30.0
## RenderBudgetPolicy (D-146): dressing and small gameplay props inside the rooms cast no shadow (outside the hall,
## whose glazing and shadowed pendant draw them); dressing ranges outside the hall and the teller workroom are cut to
## 24 m (behind walls from anywhere further). Doors between two interior rooms cast none either; exterior doors, the
## shell and the finishes keep casting (no light leaks).
const POLICY_ROOTS: Array[String] = ["Props", "Gameplay/Loot", "Gameplay/Devices", "Gameplay/Containers"]
const POLICY_SMALL_ROOTS: Array[String] = ["Variants"]
const POLICY_DOOR_ROOTS: Array[String] = ["Gameplay/Doors"]
const POLICY_CAST_KEEP: Array[String] = ["BH"]
const POLICY_RANGE_KEEP: Array[String] = ["BH", "TW"]
const POLICY_RANGE_CAP: float = 24.0

## VoxelGI per level band (doc GI): [node name, data file, AABB min, AABB max, subdiv, interior]. The bands meet at the
## slabs (basement | ground + gallery + the hall to the executive slab | executive storey); the footprint plus 0.3 m.
## The basement has no window (interior: the sky never reaches it); the upper bands see the sky through the glazing.
const GI_BANDS: Array = [
	["VoxelGIBasement", "ostrander_federal_voxelgi_basement.res", Vector3(-0.3, -4.1, -0.3), Vector3(48.3, 0.0, 25.3),
		VoxelGI.SUBDIV_128, true],
	["VoxelGIGround", "ostrander_federal_voxelgi_ground.res", Vector3(-0.3, 0.0, -0.3), Vector3(48.3, 8.6, 36.3),
		VoxelGI.SUBDIV_128, false],
	["VoxelGIExecutive", "ostrander_federal_voxelgi_executive.res", Vector3(-0.3, 8.6, -0.3), Vector3(48.3, 12.3, 17.3),
		VoxelGI.SUBDIV_128, false],
]

## The hall's warm pool fills: [name, position, range]. Over the counter's centre (z 18.5) and the meridian line.
const HALL_POOLS: Array = [
	["PoolCounter", Vector3(24.0, 3.4, 19.5), 9.0],
	["PoolMeridian", Vector3(24.0, 3.8, 27.0), 10.0],
]

## Rooms (purposes) without a reflection probe: the exteriors, the open stairs and the lift shaft (no box to project
## into), the electrical and janitor closets (matte, 3 x 4-7 m).
const PROBE_SKIP: Array[String] = ["exterior", "stair", "elevator", "electrical", "janitor"]
## Rooms split into several probes (doc GI: the hall gets 2): room id -> [[x0, z0, x1, z1], ...] (world, metres; the
## height comes from the room's tallest box). The hall's west and east halves, each over its counter and its bay.
const PROBE_SPLITS: Dictionary = {"BH": [[8.0, 17.0, 24.0, 36.0], [24.0, 17.0, 40.0, 36.0]]}

## Occluder sources (doc GI: the shell, the Corvino and Belmont facades, the parking structure, the Assay Office):
## Geometry paths whose StaticBody3D box colliders become BoxOccluder3D (inset 5 cm).
## [path, min horizontal extent (m), min height (m)]; walls need a solid stretch, slabs an area.
const OCC_WALLS: Array[String] = ["Geometry/Building/Walls/FloorB", "Geometry/Building/Walls/FloorG",
	"Geometry/Building/Walls/FloorM", "Geometry/Building/Walls/FloorE", "Geometry/Building/Walls/FloorR"]
const OCC_SLABS: String = "Geometry/Building/Slabs"
const OCC_CLOSURES: Array[String] = ["CorvinoLower", "CorvinoTower", "BelmontArms", "ParkingStructure", "AssayOffice"]
const WALL_MIN_LEN: float = 2.5
const WALL_MIN_H: float = 2.4
const SLAB_MIN_AREA: float = 4.0

var b: Object
var counts: Dictionary = {}


func _init(builder: Object) -> void:
	b = builder


# --- Environment ---------------------------------------------------------------------------------

## 15:10 Friday, broken cloud, the sun low in the SW (doc §Audio/lighting; style guide §3 row): a clear afternoon
## procedural sky (hazy warm horizon, a visible sun disc), a neutral daylight ambient so no interior corner goes black,
## sky reflections, AgX with soft contrast, SSAO + SSIL, a light city haze, subtle glow, lut_ostrander_federal (warm
## highlights, neutral-cool shadows, no crushed black). The sun is shadowed and carries the cloud-shadow curve.
func environment(lighting: Node3D) -> void:
	var root: Node = b.get(&"map_root")
	var we: WorldEnvironment = WorldEnvironment.new()
	we.set_script(load(ENV_SCRIPT))  # brightness option (B5-01)
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_ostrander_federal"
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.29, 0.44, 0.67)
	sky_mat.sky_horizon_color = Color(0.73, 0.73, 0.72)
	sky_mat.sky_curve = 0.14
	sky_mat.sky_energy_multiplier = 1.0
	sky_mat.ground_bottom_color = Color(0.2, 0.19, 0.18)
	sky_mat.ground_horizon_color = Color(0.52, 0.5, 0.47)
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 24.0
	sky_mat.sun_curve = 0.12
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# PO (hall flat-lit): a low, slightly cool ambient so the sun shafts and the warm pools carry the hall and its
	# perimeter falls darker; the VoxelGI bounce (Forward+) lifts the shadow side
	env.ambient_light_color = Color(0.6, 0.64, 0.7)
	env.ambient_light_energy = 0.36
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.2
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.74, 0.78)
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.2
	env.fog_aerial_perspective = 0.3
	# sun shafts (Forward+): a thin volumetric haze the shadowed sun cuts into beams through the south windows and the
	# lantern oculus; GI-lit so the hall's warm bounce tints it
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.95, 0.92, 0.86)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.03
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_color_correction = load(LUT_PATH) as Texture
	we.environment = env
	lighting.add_child(we)
	we.owner = root
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.set_script(load(SUN_SCRIPT))
	sun.name = "Sun"
	# azimuth ~220 deg (SW), 24 deg high: light travels NE and down (north = -z, east = +x)
	sun.basis = Basis.looking_at(Vector3(0.587, -0.407, -0.7).normalized(), Vector3.UP)
	sun.position = Vector3(24.0, 40.0, 18.0)
	sun.light_color = Color(1.0, 0.9, 0.77)
	sun.light_energy = 2.0
	sun.set(&"base_energy", 2.0)
	sun.light_volumetric_fog_energy = 1.6
	sun.set(&"depth", 0.55)
	sun.light_angular_distance = 0.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = SUN_SHADOW_MODE
	sun.directional_shadow_max_distance = SUN_SHADOW_MAX_DISTANCE
	sun.layers = 1 | VIEWMODEL_LIT_LAYER  # D-095 like every map light
	lighting.add_child(sun)
	sun.owner = root
	counts["environment"] = 1
	_hall_pools(lighting, root)
	_render_budget_policy(lighting, root)


## The policy node, and the map's opt-in to levelcheck's enforced D-146 budgets (meta perf_d146).
func _render_budget_policy(lighting: Node3D, root: Node) -> void:
	root.set_meta(&"perf_d146", true)
	var pol: Node = Node.new()
	pol.set_script(load(POLICY_SCRIPT))
	pol.name = "RenderBudgetPolicy"
	pol.set(&"roots", PackedStringArray(POLICY_ROOTS))
	pol.set(&"small_roots", PackedStringArray(POLICY_SMALL_ROOTS))
	pol.set(&"door_roots", PackedStringArray(POLICY_DOOR_ROOTS))
	pol.set(&"cast_keep_rooms", PackedStringArray(POLICY_CAST_KEEP))
	pol.set(&"range_keep_rooms", PackedStringArray(POLICY_RANGE_KEEP))
	pol.set(&"range_cap", POLICY_RANGE_CAP)
	lighting.add_child(pol)
	pol.owner = root


## The hall's warm pools (PO: the hall read flat-lit): two warm 3000 K fill lights (level_standards §3.7 fill: energy
## <= 0.3, no shadows, <= 2 per room) low over the counter's centre and the meridian line, so the middle of the hall
## glows warm against its darker perimeter. The 4 shadowed bronze pendants are the hall dressing lane's.
func _hall_pools(lighting: Node3D, root: Node) -> void:
	var h: Node3D = _holder(lighting, "HallPools", root)
	for r: Array in HALL_POOLS:
		var light: OmniLight3D = OmniLight3D.new()
		light.name = String(r[0])
		light.position = r[1]
		light.light_color = Color(1.0, 0.78, 0.55)
		light.light_energy = 0.29  # the fill cap is 0.3 (float32: 0.3 itself reads as > 0.3)
		light.omni_range = float(r[2])
		light.omni_attenuation = 1.6
		light.shadow_enabled = false
		light.layers = 1 | VIEWMODEL_LIT_LAYER
		light.set_meta(&"fill", true)
		h.add_child(light)
		light.owner = root


# --- GI, probes, occluders -----------------------------------------------------------------------

## The VoxelGI bands, the reflection probes and the occluders (call after the art passes, before the navmesh bake).
func build() -> void:
	var root: Node = b.get(&"map_root")
	var lighting: Node3D = root.get_node("Lighting") as Node3D
	counts["voxelgi"] = voxel_gi(lighting, root)
	var probes: Node3D = _holder(lighting, "ReflectionProbes", root)
	counts["probes"] = reflection_probes(probes, root)
	var occ: Node3D = _holder(lighting, "Occluders", root)
	counts["occluders"] = occluders(occ, root)
	print("of_gi: %d VoxelGI, %d reflection probes, %d occluders" % [counts["voxelgi"], counts["probes"],
		counts["occluders"]])


static func _holder(parent: Node3D, nm: String, root: Node) -> Node3D:
	var h: Node3D = Node3D.new()
	h.name = nm
	parent.add_child(h)
	h.owner = root
	return h


## One VoxelGI per GI_BANDS row; its data is the band's baked file (bake_gi.gd), an empty VoxelGIData until baked.
func voxel_gi(lighting: Node3D, root: Node) -> int:
	for band: Array in GI_BANDS:
		var path: String = OUT_DIR + String(band[1])
		if not ResourceLoader.exists(path):
			var empty: VoxelGIData = VoxelGIData.new()
			empty.interior = bool(band[5])
			ResourceSaver.save(empty, path)
		var lo: Vector3 = band[2]
		var hi: Vector3 = band[3]
		var vg: VoxelGI = VoxelGI.new()
		vg.name = String(band[0])
		vg.position = (lo + hi) * 0.5
		vg.size = hi - lo
		vg.subdiv = band[4]
		vg.data = load(path) as VoxelGIData
		lighting.add_child(vg)
		vg.owner = root
	return GI_BANDS.size()


## One interior ReflectionProbe per room (its largest box; PROBE_SPLITS rooms get one per listed rect), box
## projection, updated once, no ambient (the VoxelGI and the environment ambient light the room).
func reflection_probes(parent: Node3D, root: Node) -> int:
	var n: int = 0
	for rv: Node in root.get_node("Rooms").get_children():
		var room: RoomVolume = rv as RoomVolume
		if room == null or String(room.purpose) in PROBE_SKIP:
			continue
		var best: AABB = AABB()
		var rxf: Transform3D = b.call(&"global_xform", room)
		for c: Node in room.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D):
				continue
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			var bx: AABB = AABB(rxf * cs.position - sz * 0.5, sz)
			if bx.size.x * bx.size.z > best.size.x * best.size.z:
				best = bx
		if best.size == Vector3.ZERO:
			continue
		var rid: String = String(room.room_id)
		var boxes: Array[AABB] = [best]
		if PROBE_SPLITS.has(rid):
			boxes.clear()
			for r: Array in PROBE_SPLITS[rid]:
				boxes.append(AABB(Vector3(float(r[0]), best.position.y, float(r[1])),
					Vector3(float(r[2]) - float(r[0]), best.size.y, float(r[3]) - float(r[1]))))
		for i: int in range(boxes.size()):
			var bx2: AABB = boxes[i]
			var probe: ReflectionProbe = ReflectionProbe.new()
			probe.name = "Probe%s%s" % [rid, "" if i == 0 else str(i)]
			probe.position = bx2.get_center()
			probe.size = bx2.size + Vector3(0.2, 0.1, 0.2)
			probe.box_projection = true
			probe.interior = true
			probe.update_mode = ReflectionProbe.UPDATE_ONCE
			probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
			probe.max_distance = maxf(probe.size.x, probe.size.z) * 1.5
			parent.add_child(probe)
			probe.owner = root
			n += 1
	return n


## Box occluders from the colliders: every solid wall piece of the shell and the interior partitions >= 2.5 m long and
## >= 2.4 m tall (the pieces between the openings), every slab piece >= 4 m² (the storeys hide each other), and the
## neighbour closures (Corvino, Belmont, the parking structure, the Assay Office). The glass is never an occluder.
func occluders(parent: Node3D, root: Node) -> int:
	var rows: Array = []
	for wp: String in OCC_WALLS:
		_collect(root, wp, "wall", rows)
	_collect(root, OCC_SLABS, "slab", rows)
	var closures: Node = root.get_node_or_null("Geometry/Site/Closures")
	for nm: String in OCC_CLOSURES:
		var body: Node3D = closures.get_node_or_null(nm) as Node3D if closures != null else null
		if body == null:
			var errs: PackedStringArray = b.get(&"errors")
			errs.append("of_gi: closure %s missing" % nm)
			b.set(&"errors", errs)
			continue
		_row(body, "closure", rows)
	for k: int in range(rows.size()):
		var r: Array = rows[k]
		var occ: OccluderInstance3D = OccluderInstance3D.new()
		occ.name = "Occ%03d%s" % [k, String(r[0])]
		var a: Vector3 = r[1]
		var e: Vector3 = r[2]
		occ.position = (a + e) * 0.5
		var bo: BoxOccluder3D = BoxOccluder3D.new()
		bo.size = (e - a).max(Vector3(0.02, 0.02, 0.02))
		occ.occluder = bo
		parent.add_child(occ)
		occ.owner = root
	return rows.size()


func _collect(root: Node, path: String, kind: String, rows: Array) -> void:
	var g: Node = root.get_node_or_null(path)
	if g == null:
		return
	for c: Node in g.get_children():
		if c is StaticBody3D:
			_row(c as Node3D, kind, rows)


## Appends [name, min, max] for `body`'s axis-aligned box collider when it passes the `kind` size rule.
func _row(body: Node3D, kind: String, rows: Array) -> void:
	var cs: CollisionShape3D = body.get_node_or_null("Collision") as CollisionShape3D
	if cs == null or not (cs.shape is BoxShape3D):
		return
	var xf: Transform3D = b.call(&"global_xform", body)
	if not xf.basis.is_equal_approx(Basis.IDENTITY) or not cs.basis.is_equal_approx(Basis.IDENTITY):
		return
	var sz: Vector3 = (cs.shape as BoxShape3D).size
	var ok: bool = true
	if kind == "wall":
		ok = maxf(sz.x, sz.z) >= WALL_MIN_LEN and sz.y >= WALL_MIN_H
	elif kind == "slab":
		ok = sz.x * sz.z >= SLAB_MIN_AREA
	if not ok:
		return
	var c: Vector3 = xf.origin + cs.position
	var inset: Vector3 = Vector3(0.05, 0.05, 0.05).min(sz * 0.25)
	rows.append([String(body.name), c - sz * 0.5 + inset, c + sz * 0.5 - inset])
