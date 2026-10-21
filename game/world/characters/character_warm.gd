## Character render-warm (OF loud hitches, LEAD 2026-10-21: 90-115 ms frames on the RX 9070 XT when looks first
## appear). At heist load, draw every look the heist can spawn once, off-screen, so the GPU compiles their material /
## skinning / shadow pipelines during the load screen instead of on the first frame a police unit walks in.
## Owner: ENV D (the API); ENV A calls it from the heist load prewarm (HeistRuntime / WarmLoader) and supplies the unit
## looks per difficulty (NpcVisuals.def_scene_paths(def, difficulty) for every EnemyDef the director can spawn, the
## D-145.3 `_duty` variants included).
##
##   var paths: PackedStringArray = CharacterWarm.heist_cast_paths(&"ostrander_federal")
##   paths.append_array(<A: police / specials scene paths for this difficulty>)
##   var warmed: int = await CharacterWarm.warm(runtime_node, paths)
##
## How: one SubViewport sharing the main World3D (its environment, sun and the viewport's AA settings, so the pipeline
## variants match the game's), an orthographic camera over a grid of every look far below the map (WARM_ORIGIN), plus
## an omni light with shadows so the positional-shadow variants compile too. FRAMES frames with the full meshes, then
## FRAMES with the CrowdLod proxies (CrowdLod.force_level), then everything is freed.
class_name CharacterWarm
extends RefCounted

const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
const CAST_FILE: String = "res://world/characters/p5_cast.json"
## far under every map, outside every gameplay camera's view
const WARM_ORIGIN: Vector3 = Vector3(0.0, -2000.0, 0.0)
const SPACING: float = 1.2
const FRAMES: int = 3
const VIEWPORT_PX: int = 256


## Every character scene p5_cast.json lists for `heist` (its pools and its spawn-tag map), existing ones only, sorted,
## no duplicates.
static func heist_cast_paths(heist: StringName) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var f: FileAccess = FileAccess.open(CAST_FILE, FileAccess.READ)
	if f == null:
		return out
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return out
	var ids: Dictionary = {}
	for section: String in ["heists", "tag_map"]:
		var by_heist: Dictionary = (data as Dictionary).get(section, {}) as Dictionary
		var groups: Dictionary = by_heist.get(String(heist), {}) as Dictionary
		for k: Variant in groups:
			for id: Variant in (groups[k] as Array):
				ids[String(id)] = true
	for id: String in ids:
		var p: String = scene_path(id)
		if ResourceLoader.exists(p):
			out.append(p)
	out.sort()
	return out


## The character scene of character id `id` (world/characters/<id>/<id>.tscn, characters.md).
static func scene_path(id: String) -> String:
	return "res://world/characters/%s/%s.tscn" % [id, id]


## Draw every scene in `paths` (deduplicated) FRAMES frames at full detail and FRAMES as its CrowdLod proxy, off-screen,
## under `host` (any node in the heist's tree), then free them. Returns the number of looks drawn. A coroutine: await it.
static func warm(host: Node, paths: PackedStringArray, frames: int = FRAMES) -> int:
	if host == null or not host.is_inside_tree() or paths.is_empty():
		return 0
	var tree: SceneTree = host.get_tree()
	var main_vp: Viewport = host.get_viewport()
	var vp: SubViewport = SubViewport.new()
	vp.name = "CharacterWarm"
	vp.size = Vector2i(VIEWPORT_PX, VIEWPORT_PX)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = false
	vp.world_3d = main_vp.find_world_3d()
	vp.msaa_3d = main_vp.msaa_3d
	vp.screen_space_aa = main_vp.screen_space_aa
	vp.use_taa = main_vp.use_taa
	vp.scaling_3d_mode = main_vp.scaling_3d_mode
	host.add_child(vp)
	var grid: Node3D = Node3D.new()
	grid.name = "Looks"
	vp.add_child(grid)
	var seen: Dictionary = {}
	var bodies: Array[Node3D] = []
	for p: String in paths:
		if seen.has(p):
			continue
		seen[p] = true
		var ps: PackedScene = load(p) as PackedScene
		if ps == null:
			continue
		var body: Node3D = ps.instantiate() as Node3D
		if body == null:
			continue
		grid.add_child(body)
		bodies.append(body)
	var cols: int = maxi(1, ceili(sqrt(float(bodies.size()))))
	for i: int in bodies.size():
		bodies[i].position = WARM_ORIGIN + Vector3((i % cols) * SPACING, 0.0, (i / cols) * SPACING)
	var span: float = maxf(cols * SPACING, 2.0)
	var centre: Vector3 = WARM_ORIGIN + Vector3((cols - 1) * SPACING * 0.5, 0.9, (cols - 1) * SPACING * 0.5)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = span + 2.0
	cam.far = 200.0
	vp.add_child(cam)
	cam.look_at_from_position(centre + Vector3(0.0, 30.0, 0.01), centre, Vector3.UP)
	cam.current = true
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.omni_range = span * 2.0 + 6.0
	lamp.shadow_enabled = true
	vp.add_child(lamp)
	lamp.position = centre + Vector3(0.0, 4.0, 0.0)
	for lod2: bool in [false, true]:
		for b: Node3D in bodies:
			CrowdLod.force_level(b, lod2)
		for _i: int in frames + 1:   # (not frame_post_draw: it never fires on the headless dummy renderer)
			await tree.process_frame
	vp.queue_free()
	return bodies.size()
