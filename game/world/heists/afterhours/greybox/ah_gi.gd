## Afterhours G2 lighting lane (AH-C2, ENV C): copy-adapted from rolling_thunder/greybox/rt_gi.gd (D-147 reuse-first;
## the RT chain is not shared code). Design: docs/design/heists/afterhours.md §Audio/lighting (00:40, no sun or moon,
## an overcast sky lit orange from below; the club's two hall states are Lighting/ClubLights, the generator's) and
## §Budgets (<= 8 shadowed lights in any shot). The night environment and lut_afterhours, the shadowed key lights (the
## LEAD's rule: the DJ / stage key, the bar backs, the office lamp; never the fills), one VoxelGI over the club, a
## ReflectionProbe per interior room, the box occluders and the render-budget policy.
## Used by build_greybox.gd (`b` = the generator):
##   var gi: RefCounted = AH_GI.new(self)
##   gi.call(&"environment", n("Lighting"))      # WorldEnvironment (replaces the G1 greybox environment)
##   gi.call(&"build")                           # shadowed fixtures, VoxelGI, probes, occluders, policy
## Everything here is visual only: the navmesh and every gameplay node are unchanged. The VoxelGI data is baked
## separately (an empty VoxelGIData until then).
extends RefCounted

const OUT_DIR: String = "res://world/heists/afterhours/"
const LUT_PATH: String = "res://assets/luts/lut_afterhours.png"
const ENV_SCRIPT: String = "res://world/lighting/heist_world_environment.gd"
const POLICY_SCRIPT: String = "res://world/lighting/render_budget_policy.gd"
const VIEWMODEL_LIT_LAYER: int = 1 << 20  # viewmodel_lit (visual_slots v1.2, D-095)
## The street haze (depth fog): clear to HAZE_BEGIN_M, HAZE_MAX opacity at HAZE_END_M (the far blocks).
const HAZE_BEGIN_M: float = 30.0
const HAZE_END_M: float = 200.0
const HAZE_MAX: float = 0.25

## RenderBudgetPolicy (D-146): dressing and small gameplay props inside the interior rooms cast no shadow (the shell,
## finishes and exterior doors keep casting). The hall, the bars and the balcony keep their 24 m+ ranges (long views
## across the hall); dressing elsewhere is cut to 24 m.
const POLICY_ROOTS: Array[String] = ["Props", "Gameplay/Loot", "Gameplay/Devices", "Gameplay/Containers"]
const POLICY_SMALL_ROOTS: Array[String] = ["Variants"]
const POLICY_DOOR_ROOTS: Array[String] = ["Gameplay/Doors"]
const POLICY_OPEN: Array[String] = ["exterior", "roof"]
const POLICY_RANGE_KEEP: Array[String] = ["G6", "G7", "U1", "U2"]
const POLICY_RANGE_CAP: float = 24.0

## Night: every fixture is on. [holder, fixture name prefix] rows whose Light is hidden (none).
const LAMPS_OFF: Array = []
## The shadowed fixtures of the dressing (Crale's desk lamp in U9, the office kit's; the hall's key lights are
## Lighting/ClubLights'): [fixture path]. Every other fixture light stays unshadowed.
const SHADOW_FIXTURES: Array[String] = ["Props/Dress/U9/DeskLamp_1"]

## VoxelGI (doc GI: the club interior; the hall lights in DYNAMIC bake mode, so the house-lights switch re-lights GI
## without a re-bake): [node name, data file, AABB min, AABB max, subdiv, interior]. The footprint plus 0.3 m. Not
## `interior` (as RT's volumes): an interior volume drops the environment's ambient inside it, so every surface out of
## a fixture's cone went black (the LEAD's G2 review: scalloped black bands at the wall tops under black ceilings in the
## BOH rooms, the kit downlights' cone edges; gone with the volume hidden, unchanged without SSAO).
## G3 (LEAD r313): three volumes, split inside the walls between the club and the BOH (z 7.0 the hall's north wall,
## x 26.0 its east wall), so the hall's light no longer bleeds into the BOH corridors and the count room (the OF band
## approach; one volume over all 37 m gave ~0.3 m cells, coarser than the 0.4 m walls).
const GI_VOLUMES: Array = [
	["VoxelGIClub", "afterhours_voxelgi_club.res", Vector3(-0.5, -0.3, 7.0), Vector3(26.0, 8.9, 28.5),
		VoxelGI.SUBDIV_128, false],
	["VoxelGIBackN", "afterhours_voxelgi_back_n.res", Vector3(-0.5, -0.3, -0.5), Vector3(36.5, 8.9, 7.0),
		VoxelGI.SUBDIV_128, false],
	["VoxelGIBackE", "afterhours_voxelgi_back_e.res", Vector3(26.0, -0.3, 7.0), Vector3(36.5, 8.9, 28.5),
		VoxelGI.SUBDIV_128, false],
]

## Rooms (purposes) without a reflection probe: the exteriors and the roof (sky), the stairs, the electrical and
## The back of house off the club rig (G3, the LEAD's review: magenta / violet on the count room, the upper and east
## corridors): the hall's unshadowed washes and fills reach through the walls, so these rooms' finishes and dressing
## move from render layer 1 to CLUB_SKIP_LAYER, which every Lighting/ClubLights light's light_cull_mask leaves out (as
## rt_gi.gd's SUN_SKIP_LAYER; their own fixtures still light them). [room id; the staff stair U7 is G22's volume]
const CLUB_SKIP_ROOMS: Array[String] = ["G10", "G11", "G12", "G13", "G14", "G15", "G16", "G20", "G21", "G22", "G23",
	"G24", "G25", "G26", "G27", "U5", "U6", "U6b", "U9", "U10", "U12", "U13"]
const CLUB_SKIP_LAYER: int = 1 << 4
## The LEAD's G3 step 2: a weak unshadowed fill under the ceiling (validate lights' fill rule: meta fill, energy <= 0.3)
## in the rooms whose upper walls still scalloped under the panel cones in the G3 frames (16 U5, 24 G11, 25 G12,
## 27 G24): [room id]. Neutral BOH white; range the room's half diagonal x 1.6.
const CEILING_FILLS: Array[String] = ["U5", "G11", "G12", "G24"]
const FILL_ENERGY: float = 0.29   # under the fill rule's 0.3 (float32 0.3 reads 0.30000001)
const FILL_DROP: float = 0.35

## janitor closets (matte, small).
const PROBE_SKIP: Array[String] = ["exterior", "roof", "stair", "elevator", "electrical", "janitor", "void"]

## Occluder sources: Geometry paths whose StaticBody3D box colliders become BoxOccluder3D (inset 5 cm).
const OCC_WALLS: Array[String] = ["Geometry/Building/Walls/WallsG", "Geometry/Building/Walls/WallsU"]
const OCC_SLABS: Array[String] = ["Geometry/Building/Slabs"]
const OCC_BLOCKS: Array[String] = ["Geometry/Site/Neighbours"]
const WALL_MIN_LEN: float = 2.5
const WALL_MIN_H: float = 2.4
const SLAB_MIN_AREA: float = 4.0
const BLOCK_MIN_VOL: float = 20.0

var b: Object
var counts: Dictionary = {}


func _init(builder: Object) -> void:
	b = builder


# --- Environment ---------------------------------------------------------------------------------

## 00:40 (doc §Audio/lighting): no sun or moon; an overcast sky lit orange from below by the city (a dark procedural
## sky, sodium-orange at the horizon), a low violet-grey ambient (the rooms are lit by their fixtures and the club rig),
## sky reflections, AgX, SSAO + SSIL, the street haze (depth fog), glow for the neon and the rig, lut_afterhours.
func environment(lighting: Node3D) -> void:
	var root: Node = b.get(&"map_root")
	var we: WorldEnvironment = WorldEnvironment.new()
	we.set_script(load(ENV_SCRIPT))  # brightness option (B5-01)
	we.name = "WorldEnvironment"
	var env: Environment = Environment.new()
	env.resource_name = "env_afterhours"
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.03, 0.028, 0.045)
	sky_mat.sky_horizon_color = Color(0.3, 0.15, 0.08)
	sky_mat.sky_curve = 0.06
	sky_mat.sky_energy_multiplier = 1.0
	sky_mat.ground_bottom_color = Color(0.03, 0.025, 0.025)
	sky_mat.ground_horizon_color = Color(0.22, 0.12, 0.07)
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 0.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# low, so the club reads dark between its pools; enough that no corner goes black on the Compatibility path
	env.ambient_light_color = Color(0.5, 0.46, 0.6)
	env.ambient_light_energy = 0.35
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
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = HAZE_BEGIN_M
	env.fog_depth_end = HAZE_END_M
	env.fog_depth_curve = 1.4
	env.fog_density = HAZE_MAX
	env.fog_light_color = Color(0.32, 0.2, 0.14)
	env.fog_height_density = 0.0
	env.fog_sky_affect = 0.3
	env.fog_aerial_perspective = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_color_correction = load(LUT_PATH) as Texture
	we.environment = env
	lighting.add_child(we)
	we.owner = root
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
	counts["club_skip"] = club_skip(root)
	counts["fills"] = ceiling_fills(_holder(lighting, "CeilingFills", root), root)
	_render_budget_policy(lighting, root)
	print("ah_gi: %d lamps off, %d shadowed fixtures, %d VoxelGI, %d reflection probes, %d occluders, %d club-skip rooms, %d fills"
		% [counts["lamps_off"], counts["shadowed"], counts["voxelgi"], counts["probes"], counts["occluders"],
		counts["club_skip"], counts["fills"]])


static func _holder(parent: Node3D, nm: String, root: Node) -> Node3D:
	var h: Node3D = Node3D.new()
	h.name = nm
	parent.add_child(h)
	h.owner = root
	return h


func _err(msg: String) -> void:
	var errs: PackedStringArray = b.get(&"errors")
	errs.append("ah_gi: " + msg)
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
		var best: AABB = _room_box(room)
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


## A room's largest box (world), from its colliders; AABB() when it has none.
func _room_box(room: RoomVolume) -> AABB:
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
	return best


## CLUB_SKIP_ROOMS off the club rig: each room's finish and its dressing (Props/Dress/<room>) move from layer 1 to
## CLUB_SKIP_LAYER, and every ClubLights light leaves that layer out of its light_cull_mask. Returns the room count.
func club_skip(root: Node) -> int:
	var n: int = 0
	for rid: String in CLUB_SKIP_ROOMS:
		var fin: GeometryInstance3D = root.get_node_or_null("Geometry/Finish/Visual_R_" + rid) as GeometryInstance3D
		if fin == null:
			_err("club-skip finish Visual_R_%s missing" % rid)
			continue
		fin.layers = (fin.layers & ~1) | CLUB_SKIP_LAYER
		var dress: Node = root.get_node_or_null("Props/Dress/" + rid)
		if dress != null:
			for g: Node in dress.find_children("*", "GeometryInstance3D", true, false):
				var gi: GeometryInstance3D = g as GeometryInstance3D
				gi.layers = (gi.layers & ~1) | CLUB_SKIP_LAYER
		n += 1
	for c: Node in root.get_node("Lighting/ClubLights").get_children():
		if c is Light3D:
			(c as Light3D).light_cull_mask = 0xFFFFFFFF & ~CLUB_SKIP_LAYER
	return n


## CEILING_FILLS: one weak unshadowed omni (meta fill) under each room's ceiling, centred. Returns the count.
func ceiling_fills(parent: Node3D, root: Node) -> int:
	var n: int = 0
	for rid: String in CEILING_FILLS:
		var room: RoomVolume = null
		for rv: Node in root.get_node("Rooms").get_children():
			if rv is RoomVolume and String((rv as RoomVolume).room_id) == rid:
				room = rv as RoomVolume
		var box: AABB = _room_box(room) if room != null else AABB()
		if box.size == Vector3.ZERO:
			_err("ceiling fill: room %s missing" % rid)
			continue
		var om: OmniLight3D = OmniLight3D.new()
		om.name = "Fill" + rid
		om.position = Vector3(box.get_center().x, box.end.y - FILL_DROP, box.get_center().z)
		om.omni_range = Vector2(box.size.x, box.size.z).length() * 0.5 * 1.6
		om.omni_attenuation = 1.0
		om.light_energy = FILL_ENERGY
		om.light_color = Color(0.95, 0.97, 1.0)
		om.shadow_enabled = false
		om.light_bake_mode = Light3D.BAKE_DISABLED
		om.layers = 1 | VIEWMODEL_LIT_LAYER
		om.set_meta(&"fill", true)
		parent.add_child(om)
		om.owner = root
		n += 1
	return n


## Box occluders from the colliders: the solid wall pieces (the pieces between the openings), the
## slabs (the storeys hide each other) and the neighbour blocks. Glass is never an occluder.
func occluders(parent: Node3D, root: Node) -> int:
	var rows: Array = []
	for wp: String in OCC_WALLS:
		_collect(root, wp, "wall", rows)
	for sp: String in OCC_SLABS:
		_collect(root, sp, "slab", rows)
	for bp: String in OCC_BLOCKS:
		_collect(root, bp, "block", rows)
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


## The policy node. AH does not opt in to levelcheck's enforced perf budgets (meta perf_d146): D-146 addendum 6 judges
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
