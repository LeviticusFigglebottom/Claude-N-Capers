## Rolling Thunder G2 lighting lane (RT-C2, ENV C): the final 16:50 environment (lut_rolling_thunder, the dust haze),
## the low WSW sun, the daylight state of the fixtures (street lamps off, the shadowed few), a VoxelGI for the car park
## and the diner, a ReflectionProbe per interior room, the box occluders and the render-budget policy.
## Copy-adapted from Ostrander Federal's of_gi.gd (D-147 reuse). Design: docs/design/heists/rolling_thunder.md
## §Audio/lighting (time, zones, GI, LUT) and §Budgets (<= 8 shadowed lights per shot, one height fog, no FogVolumes).
## Used by build_greybox.gd (`b` = the generator):
##   var gi: RefCounted = RT_GI.new(self)
##   gi.call(&"environment", n("Lighting"))      # WorldEnvironment + Sun (replaces the G1 greybox environment)
##   gi.call(&"build")                           # fixtures, VoxelGI, probes, occluders, policy (after the art passes)
## Everything here is visual only: Lighting/** holds no collider and the fixtures keep their bodies, so the navmesh
## (baked from Geometry colliders) and every gameplay node are unchanged. The VoxelGI data is baked separately by
## bake_gi.gd (under xvfb, see its header) into one .res per volume; the generator only references those files (an
## empty VoxelGIData when one is missing).
extends RefCounted

const OUT_DIR: String = "res://world/heists/rolling_thunder/"
const LUT_PATH: String = "res://assets/luts/lut_rolling_thunder.png"
const ENV_SCRIPT: String = "res://world/lighting/heist_world_environment.gd"
const POLICY_SCRIPT: String = "res://world/lighting/render_budget_policy.gd"
const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095)
## The sun (doc: azimuth 245 deg, elevation 9 deg, 3800 K). D-146: its cascades re-draw every caster in their slices,
## so 2 splits; 60 m (not OF's 30) because the long low shadows down Tannery are the look of the street views.
const SUN_AZ_DEG: float = 245.0
const SUN_EL_DEG: float = 9.0
const SUN_COLOR: Color = Color(1.0, 0.8, 0.62)
const SUN_ENERGY: float = 1.8
const SUN_SHADOW_MODE: DirectionalLight3D.ShadowMode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
const SUN_SHADOW_MAX_DISTANCE: float = 60.0
## The dust haze (depth fog): clear to HAZE_BEGIN_M, HAZE_MAX opacity at HAZE_END_M (the far ring of towers).
const HAZE_BEGIN_M: float = 35.0
const HAZE_END_M: float = 320.0
const HAZE_MAX: float = 0.3

## RenderBudgetPolicy (D-146; GPU-21: rc_diner_dining drew 3,313 sun-shadow draws): dressing and small gameplay props
## inside the interior rooms cast no shadow (the diner's tables and chairs among them; the shell, finishes and exterior
## doors keep casting, so no light leaks). The car park decks are open-sided (the sun's stripes on the parked cars),
## so they count as open like the exteriors. Dressing ranges outside the diner's dining room and the decks are cut to
## 24 m (behind walls from anywhere further).
const POLICY_ROOTS: Array[String] = ["Props", "Gameplay/Loot", "Gameplay/Devices", "Gameplay/Containers"]
const POLICY_SMALL_ROOTS: Array[String] = ["Variants"]
const POLICY_DOOR_ROOTS: Array[String] = ["Gameplay/Doors"]
const POLICY_OPEN: Array[String] = ["exterior", "car_park", "roof"]
const POLICY_RANGE_KEEP: Array[String] = ["DR", "U1", "CP-G", "CP-2"]
const POLICY_RANGE_CAP: float = 24.0

## Daylight (doc zones): the street, plaza and roof-deck lamp posts are off. Their fixture props stay; only the Light
## is hidden. [holder, fixture name prefix ("" = every fixture under the holder, at any depth)].
const LAMPS_OFF: Array = [["Props/Dress/Streets", ""], ["Props/Dress/Direct", "RoofLamp"],
	["Props/Dress/Direct", "PlazaLamp"]]
## The shadowed fixtures (§Budgets: the sun, 2 underpass battens, 1 per car-park deck, 1 diner = 6 <= 8): [fixture
## path]. Every other fixture light stays unshadowed.
const SHADOW_FIXTURES: Array[String] = [
	"Props/Dress/Direct/UnderpassBatten0", "Props/Dress/Direct/UnderpassBatten1",
	"Props/Dress/CPG/LightFixture_7", "Props/Dress/CP2/LightFixture_7", "Props/Dress/DR/LightFixture_9",
]

## VoxelGI (doc GI: the car park and the diner interiors): [node name, data file, AABB min, AABB max, subdiv,
## interior]. The footprints plus 0.3 m; both see the sky (the decks' open sides, the diner's glazing). The diner is
## 20 m across, so 64 subdivisions give about the car park's 0.3 m cells.
const GI_VOLUMES: Array = [
	["VoxelGICarPark", "rolling_thunder_voxelgi_carpark.res", Vector3(15.7, -0.3, -50.3), Vector3(52.3, 10.3, -13.7),
		VoxelGI.SUBDIV_128, false],
	["VoxelGIDiner", "rolling_thunder_voxelgi_diner.res", Vector3(13.7, -0.3, 13.7), Vector3(34.3, 7.2, 32.3),
		VoxelGI.SUBDIV_64, false],
]

## Sun-skip rooms (LEAD r309, rc_diner_office): windowless rooms the low sun (9 deg) still reaches through the walls,
## a stippled soft-shadow cone over the office's east wall (gone with the sun hidden; GI, SSIL and the probe ruled
## out). Their interior finish (Geometry/Finish/Visual_R_<room>: the inner wall faces, floor and ceiling) moves from
## render layer 1 to SUN_SKIP_LAYER, which the sun's light_cull_mask leaves out: the fixtures still light it, the sun
## cannot (it still casts the sun's shadows: shadow_caster_mask is untouched). Layer 5 as OF's of_gi.SUN_SKIP_LAYER.
const SUN_SKIP_ROOMS: Array[String] = ["OF"]
const SUN_SKIP_LAYER: int = 1 << 4

## Rooms (purposes) without a reflection probe: the exteriors and the roof deck (sky), the stairs, ramps and the lift
## shaft (no box to project into), the electrical and janitor closets (matte, small).
const PROBE_SKIP: Array[String] = ["exterior", "roof", "stair", "elevator", "electrical", "janitor"]

## Occluder sources (doc GI: the car park, the diner block, the hoarding, Ashby House and the Skyway deck, plus the
## cabins and the neighbour blocks): Geometry paths whose StaticBody3D box colliders become BoxOccluder3D (inset 5 cm).
## Walls need a solid stretch (>= 2.5 m long, >= 2.4 m tall), slabs an area (>= 4 m²); the blocks are taken whole.
const OCC_WALLS: Array[String] = ["Geometry/Building/Walls/WallsD", "Geometry/Building/Walls/WallsCP",
	"Geometry/Building/Walls/WallsS", "Geometry/Site/Hoarding"]
const OCC_SLABS: Array[String] = ["Geometry/Building/Slabs"]
const OCC_BLOCKS: Array[String] = ["Geometry/Site/Neighbours"]
const OCC_SKYWAY: String = "Geometry/Site/Skyway/Deck"
const WALL_MIN_LEN: float = 2.5
const WALL_MIN_H: float = 2.4
const SLAB_MIN_AREA: float = 4.0
const BLOCK_MIN_VOL: float = 20.0

var b: Object
var counts: Dictionary = {}


func _init(builder: Object) -> void:
	b = builder


# --- Environment ---------------------------------------------------------------------------------

## 16:50, a low autumn sun down Tannery (doc §Audio/lighting; style guide §3 row): a clear procedural sky (blue
## overhead, a bright amber horizon, a visible low sun disc), a neutral daylight ambient so no shade goes black, sky
## reflections, AgX, SSAO + SSIL, the one depth-fog dust haze (no volumetric fog, no FogVolumes, §Budgets) whose sun
## scatter catches the light down Tannery, a strong glow on the sun axis (glare as bloom only, D-149 ruling 7) and
## lut_rolling_thunder (amber highlights, teal-green shadows, a lifted floor).
func environment(lighting: Node3D) -> void:
	var root: Node = b.get(&"map_root")
	var we: WorldEnvironment = WorldEnvironment.new()
	we.set_script(load(ENV_SCRIPT))  # brightness option (B5-01)
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_rolling_thunder"
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.45, 0.68)
	sky_mat.sky_horizon_color = Color(0.86, 0.7, 0.5)
	sky_mat.sky_curve = 0.1
	sky_mat.sky_energy_multiplier = 1.0
	sky_mat.ground_bottom_color = Color(0.2, 0.18, 0.16)
	sky_mat.ground_horizon_color = Color(0.62, 0.55, 0.45)
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.1
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# the shade under the Skyway and in the decks reads teal-cool against the amber sun (the LUT pushes it further);
	# 0.7 so the shade keeps its detail on the Compatibility path too (no SSAO / SSIL / VoxelGI bounce there: at 0.42
	# the Skyway's shadow went near black in the r279 opengl3 review shots)
	env.ambient_light_color = Color(0.62, 0.68, 0.72)
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.2
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.5
	# the dust haze (the LEAD's review, r277: the height-falloff fog washed every exterior to beige and filled the
	# diner): DEPTH fog, none within HAZE_BEGIN_M (the rooms, a character at 10 m), rising to HAZE_MAX at HAZE_END_M
	# so only the far blocks and the skyline soften; no height term (it thickened everything near the ground, indoors
	# too). Both renderers draw depth fog (Forward+ and the Compatibility path).
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = HAZE_BEGIN_M
	env.fog_depth_end = HAZE_END_M
	env.fog_depth_curve = 1.4
	env.fog_density = HAZE_MAX
	env.fog_light_color = Color(0.8, 0.72, 0.62)
	env.fog_height_density = 0.0
	env.fog_sun_scatter = 0.2
	env.fog_sky_affect = 0.2
	env.fog_aerial_perspective = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.06
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_color_correction = load(LUT_PATH) as Texture
	we.environment = env
	lighting.add_child(we)
	we.owner = root
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	# from azimuth 245 deg (WSW), 9 deg up: the light travels toward the ENE and slightly down (north = -z, east = +x)
	var az: float = deg_to_rad(SUN_AZ_DEG)
	var alt: float = deg_to_rad(SUN_EL_DEG)
	var to_sun: Vector3 = Vector3(sin(az) * cos(alt), sin(alt), -cos(az) * cos(alt))
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	sun.position = Vector3(0.0, 60.0, 0.0)
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.light_angular_distance = 0.5
	sun.light_cull_mask = 0xFFFFFFFF & ~SUN_SKIP_LAYER
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = SUN_SHADOW_MODE
	sun.directional_shadow_max_distance = SUN_SHADOW_MAX_DISTANCE
	sun.layers = 1 | VIEWMODEL_LIT_LAYER  # D-095 like every map light
	lighting.add_child(sun)
	sun.owner = root
	counts["environment"] = 1


# --- Fixtures, GI, probes, occluders, policy -----------------------------------------------------

## Call after the art passes (rt_dress, rt_finish, rt_skyline), before the navmesh bake.
func build() -> void:
	var root: Node = b.get(&"map_root")
	var lighting: Node3D = root.get_node("Lighting") as Node3D
	counts["lamps_off"] = lamps_off(root)
	counts["shadowed"] = shadow_fixtures(root)
	counts["voxelgi"] = voxel_gi(lighting, root)
	counts["probes"] = reflection_probes(_holder(lighting, "ReflectionProbes", root), root)
	counts["occluders"] = occluders(_holder(lighting, "Occluders", root), root)
	counts["sun_skip"] = sun_skip(root)
	_render_budget_policy(lighting, root)
	print("rt_gi: %d lamps off, %d shadowed fixtures, %d VoxelGI, %d reflection probes, %d occluders, %d sun-skip rooms" % [
		counts["lamps_off"], counts["shadowed"], counts["voxelgi"], counts["probes"], counts["occluders"],
		counts["sun_skip"]])


## SUN_SKIP_ROOMS: each room's finish off the sun's layer (the sun's light_cull_mask is set in environment()).
func sun_skip(root: Node) -> int:
	var n: int = 0
	for rid: String in SUN_SKIP_ROOMS:
		var fin: GeometryInstance3D = root.get_node_or_null("Geometry/Finish/Visual_R_" + rid) as GeometryInstance3D
		if fin == null:
			_err("sun-skip finish Visual_R_%s missing" % rid)
			continue
		fin.layers = (fin.layers & ~1) | SUN_SKIP_LAYER
		n += 1
	return n


static func _holder(parent: Node3D, nm: String, root: Node) -> Node3D:
	var h: Node3D = Node3D.new()
	h.name = nm
	parent.add_child(h)
	h.owner = root
	return h


func _err(msg: String) -> void:
	var errs: PackedStringArray = b.get(&"errors")
	errs.append("rt_gi: " + msg)
	b.set(&"errors", errs)


## Every LAMPS_OFF fixture: its Light hidden (daylight). Returns the count.
func lamps_off(root: Node) -> int:
	var n: int = 0
	for row: Array in LAMPS_OFF:
		var holder: Node = root.get_node_or_null(String(row[0]))
		if holder == null:
			_err("no %s" % row[0])
			continue
		var stem: String = String(row[1])
		var src: Array[Node] = holder.find_children("*", "", true, false) if stem == "" else holder.get_children()
		for c: Node in src:
			var light: Light3D = c.get_node_or_null("Light") as Light3D
			if light == null or not String(c.name).begins_with(stem):
				continue
			root.set_editable_instance(c, true)
			light.visible = false
			n += 1
	return n


## SHADOW_FIXTURES' Lights cast shadows. Returns the count.
func shadow_fixtures(root: Node) -> int:
	var n: int = 0
	for p: String in SHADOW_FIXTURES:
		var fx: Node = root.get_node_or_null(p)
		var light: Light3D = fx.get_node_or_null("Light") as Light3D if fx != null else null
		if light == null:
			_err("shadow fixture %s missing" % p)
			continue
		root.set_editable_instance(fx, true)
		light.shadow_enabled = true
		n += 1
	return n


## One VoxelGI per GI_VOLUMES row; its data is the baked file (bake_gi.gd), an empty VoxelGIData until baked.
func voxel_gi(lighting: Node3D, root: Node) -> int:
	for vol: Array in GI_VOLUMES:
		var path: String = OUT_DIR + String(vol[1])
		if not ResourceLoader.exists(path):
			var empty: VoxelGIData = VoxelGIData.new()
			empty.interior = bool(vol[5])
			ResourceSaver.save(empty, path)
		var lo: Vector3 = vol[2]
		var hi: Vector3 = vol[3]
		var vg: VoxelGI = VoxelGI.new()
		vg.name = String(vol[0])
		vg.position = (lo + hi) * 0.5
		vg.size = hi - lo
		vg.subdiv = vol[4]
		vg.data = load(path) as VoxelGIData
		lighting.add_child(vg)
		vg.owner = root
	return GI_VOLUMES.size()


## One interior ReflectionProbe per room (its largest box), box projection, updated once, no ambient (the VoxelGI and
## the environment ambient light the room).
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
		var probe: ReflectionProbe = ReflectionProbe.new()
		probe.name = "Probe%s" % String(room.room_id).replace("-", "")
		probe.position = best.get_center()
		probe.size = best.size + Vector3(0.2, 0.1, 0.2)
		probe.box_projection = true
		probe.interior = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		probe.max_distance = maxf(probe.size.x, probe.size.z) * 1.5
		parent.add_child(probe)
		probe.owner = root
		n += 1
	return n


## Box occluders from the colliders: the solid wall pieces (the pieces between the openings) and the hoarding, the
## slabs (the decks and storeys hide each other), the neighbour blocks and the Skyway deck. Glass is never an occluder.
func occluders(parent: Node3D, root: Node) -> int:
	var rows: Array = []
	for wp: String in OCC_WALLS:
		_collect(root, wp, "wall", rows)
	for sp: String in OCC_SLABS:
		_collect(root, sp, "slab", rows)
	for bp: String in OCC_BLOCKS:
		_collect(root, bp, "block", rows)
	var deck: Node3D = root.get_node_or_null(OCC_SKYWAY) as Node3D
	if deck == null:
		_err("no %s" % OCC_SKYWAY)
	else:
		_row(deck, "slab", rows)
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
		_err("no %s" % path)
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
	elif kind == "block":
		ok = sz.x * sz.y * sz.z >= BLOCK_MIN_VOL
	if not ok:
		return
	var c: Vector3 = xf.origin + cs.position
	var inset: Vector3 = Vector3(0.05, 0.05, 0.05).min(sz * 0.25)
	rows.append([String(body.name), c - sz * 0.5 + inset, c + sz * 0.5 - inset])


## The policy node. RT does not opt in to levelcheck's enforced perf budgets (meta perf_d146): D-146 addendum 6 judges
## them on Forward+ on the GPU box; the Compatibility model stays report-only, as an early warning.
func _render_budget_policy(lighting: Node3D, root: Node) -> void:
	var pol: Node = Node.new()
	pol.set_script(load(POLICY_SCRIPT))
	pol.name = "RenderBudgetPolicy"
	pol.set(&"roots", PackedStringArray(POLICY_ROOTS))
	pol.set(&"small_roots", PackedStringArray(POLICY_SMALL_ROOTS))
	pol.set(&"door_roots", PackedStringArray(POLICY_DOOR_ROOTS))
	pol.set(&"open_purposes", PackedStringArray(POLICY_OPEN))
	pol.set(&"range_keep_rooms", PackedStringArray(POLICY_RANGE_KEEP))
	pol.set(&"range_cap", POLICY_RANGE_CAP)
	lighting.add_child(pol)
	pol.owner = root
