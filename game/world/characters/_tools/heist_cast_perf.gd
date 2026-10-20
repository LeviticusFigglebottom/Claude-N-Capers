## Heist cast perf (LEAD items h + l, 2026-10-17): a heist launched as the game does (HeistLauncher, Cataclysm), from
## each of its worst-case views (VIEWS[heist]): the frame's draws / primitives / objects with the cast shown, with the
## cast's attached never-LOD geometry hidden (held weapons, hand props: no visibility_range_end), and with the cast
## hidden; plus per-NPC LOD tier (full mesh vs CrowdLod proxy, by the proxy's own switch distance) and AnimLod band.
## `--loud` raises the alarm after the spawns settle and waits `--seconds` (default 90) of game time for the police.
## OF forces its vip_client slot. Writes user://cast_perf_<heist>_<view>.png. Owner: ENV D.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --rendering-driver opengl3 \
##     --resolution 1280x720 --path game res://world/characters/_tools/heist_cast_perf.tscn -- \
##     --heist=ostrander_federal [--seed=1037] [--loud] [--seconds=90] [--detail] [--view=<name>]
## --detail adds per view: draws with every light's shadow off, the shadow proposals (cast shadows off / off beyond
## FAR_SHADOW_M, the sun at 2 splits / half distance), and each on-screen NPC's own draws (top 8).
extends Node

## heist -> [[view name, eye, look-at]]: the biggest live crowd in one view.
const VIEWS: Dictionary = {
	"ostrander_federal": [
		["hall_south_eye", Vector3(24.0, 1.7, 35.5), Vector3(24.0, 1.2, 17.0)],
		["hall_south_high", Vector3(24.0, 4.2, 35.8), Vector3(24.0, 0.8, 18.0)],
		["hall_west_diag", Vector3(9.0, 1.7, 34.5), Vector3(36.0, 1.0, 18.0)],
	],
	"gallery_night": [
		["gala_south_eye", Vector3(22.0, 1.7, 25.5), Vector3(22.0, 1.2, 9.0)],
		["gala_balcony_high", Vector3(22.0, 6.0, 25.8), Vector3(22.0, 0.5, 12.0)],
	],
	"shadow_ledger": [
		["reception_eye", Vector3(18.0, 5.3, 9.5), Vector3(18.0, 4.6, 2.0)],
		["reception_wide", Vector3(26.0, 5.4, 9.0), Vector3(12.0, 4.4, 3.0)],
	],
	"night_deposit": [
		["hall_east_eye", Vector3(20.5, 1.7, 14.0), Vector3(0.5, 1.2, 14.0)],
		["hall_diag", Vector3(20.5, 3.5, 17.8), Vector3(1.0, 0.8, 10.5)],
	],
	"dockside_burn": [
		["yard_north_high", Vector3(27.0, 4.0, -1.5), Vector3(27.0, 0.0, -30.0)],
		["yard_west_eye", Vector3(-6.0, 1.7, -17.0), Vector3(60.0, 1.0, -17.0)],
	],
}
## NOTE: the view coordinates come from each heist's greybox layout (room bounds); re-check them when a map moves.
## --detail proposal check: the render layer the cast moves to (2 = bit value 2)
const CAST_LAYER: int = 2
const CAST_LAYER_BIT: int = 1 << (CAST_LAYER - 1)
## --detail shadow proposal: cast geometry beyond this distance (m) from the camera casts no shadow.
const FAR_SHADOW_M: float = 15.0
const FORCE: Dictionary = {"ostrander_federal": {"vip": ["vip_in"]}}
var _heist: String = "ostrander_federal"
var _seed: int = 1037
var _loud: bool = false
var _seconds: float = 90.0
var _detail: bool = false
var _view: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		match kv[0]:
			"heist": _heist = kv[1]
			"seed": _seed = int(kv[1])
			"loud": _loud = true
			"seconds": _seconds = float(kv[1])
			"detail": _detail = true
			"view": _view = kv[1]
	var opts: Dictionary = {"ai_teammates": 0}
	if FORCE.has(_heist):
		opts["preplan"] = {"force_variants": FORCE[_heist]}
	var rt: HeistRuntime = await HeistLauncher.launch(StringName(_heist), _seed, Enums.Difficulty.CATACLYSM, self, opts)
	if rt == null:
		print("[CASTPERF] %s launch failed" % _heist)
		get_tree().quit(1)
		return
	for _i: int in 180:
		await get_tree().physics_frame
	if _loud:
		rt.stealth.raise_alarm(&"d_cast_perf")
		for _i: int in int(_seconds * Engine.physics_ticks_per_second):
			await get_tree().physics_frame
	var npcs: Array[Node] = rt.npcs()
	var by_role: Dictionary = {}
	for n: Node in npcs:
		var nb: NpcBase = n as NpcBase
		by_role[String(nb.role)] = int(by_role.get(String(nb.role), 0)) + 1
	print("[CASTPERF] heist=%s seed=%d loud=%s npcs=%d by_role=%s" % [_heist, _seed, _loud, npcs.size(), by_role])
	var cam := Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.current = true
	for v: Array in VIEWS.get(_heist, []):
		if _view != "" and String(v[0]) != _view:
			continue
		cam.look_at_from_position(v[1], v[2], Vector3.UP)
		for _i: int in 20:
			await get_tree().process_frame
		var shown: Array = _info()
		var tiers: Dictionary = {"full": 0, "proxy": 0, "offscreen": 0}
		var bands: Dictionary = {}
		var tris_full: int = 0
		for n: Node in npcs:
			var nb: NpcBase = n as NpcBase
			var p: Vector3 = nb.global_position + Vector3(0, 1.0, 0)
			var on: bool = cam.is_position_in_frustum(p)
			var d: float = cam.global_position.distance_to(p)
			var sw: float = _switch(nb)
			if not on:
				tiers["offscreen"] += 1
			elif d < sw:
				tiers["full"] += 1
			else:
				tiers["proxy"] += 1
			var drv: AnimDriver = AnimDriver.of(nb)
			var b: String = "none"
			if drv != null and drv.lod != null:
				b = AnimLod.Band.keys()[drv.lod.band]
			bands[b] = int(bands.get(b, 0)) + 1
		var extras: Array[GeometryInstance3D] = []
		var extra_tris: int = 0
		var extra_nodes: int = 0
		for n2: Node in npcs:
			for m: Node in n2.find_children("*", "GeometryInstance3D", true, false):
				var gi: GeometryInstance3D = m as GeometryInstance3D
				if gi.visibility_range_end <= 0.0 and String(gi.name) != "CrowdLod" and gi.is_visible_in_tree():
					extras.append(gi)
					extra_nodes += 1
					if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
						var mm: Mesh = (gi as MeshInstance3D).mesh
						for si: int in mm.get_surface_count():
							var ia: PackedInt32Array = mm.surface_get_arrays(si)[Mesh.ARRAY_INDEX]
							extra_tris += ia.size() / 3 if ia.size() > 0 else (mm.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		for gi: GeometryInstance3D in extras:
			gi.visible = false
		for _i: int in 10:
			await get_tree().process_frame
		var no_extras: Array = _info()
		for gi: GeometryInstance3D in extras:
			gi.visible = true
		print("[CASTPERF] view=%s attached never-LOD geometry: %d nodes, %d tris; hiding it: draws %d -> %d, prims %d -> %d"
				% [v[0], extra_nodes, extra_tris, shown[0], no_extras[0], shown[1], no_extras[1]])
		var by_name: Dictionary = {}
		for gi: GeometryInstance3D in extras:
			by_name[String(gi.name)] = int(by_name.get(String(gi.name), 0)) + 1
		var names: Array = by_name.keys()
		names.sort_custom(func(x: String, y: String) -> bool: return int(by_name[x]) > int(by_name[y]))
		var top: PackedStringArray = []
		for nm: String in names.slice(0, 10):
			top.append("%s x%d" % [nm, by_name[nm]])
		print("[CASTPERF] view=%s never-LOD nodes by name: %s" % [v[0], ", ".join(top)])
		if _detail:
			await _detail_report(String(v[0]), npcs, cam, shown)
		_set_cast_visible(npcs, false)
		for _i: int in 10:
			await get_tree().process_frame
		var hidden: Array = _info()
		_set_cast_visible(npcs, true)
		for _i: int in 10:
			await get_tree().process_frame
		print("[CASTPERF] view=%s draws=%d (map %d, cast %d) prims=%d (cast %d) objects=%d (cast %d) tiers=%s anim_bands=%s"
				% [v[0], shown[0], hidden[0], shown[0] - hidden[0], shown[1], shown[1] - hidden[1], shown[2],
				shown[2] - hidden[2], tiers, bands])
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("user://cast_perf_%s_%s.png" % [_heist, v[0]]))
	get_tree().quit(0)


## --detail: the frame's draws with every light's shadow off, the shadow-casting lights, and the draws each on-screen
## NPC costs (hidden one at a time; the top 8).
func _detail_report(view: String, npcs: Array[Node], cam: Camera3D, shown: Array) -> void:
	var lit: Array[Light3D] = []
	var kinds: Dictionary = {}
	for l: Node in get_tree().root.find_children("*", "Light3D", true, false):
		var li: Light3D = l as Light3D
		if li.shadow_enabled and li.is_visible_in_tree():
			lit.append(li)
			kinds[li.get_class()] = int(kinds.get(li.get_class(), 0)) + 1
	for li: Light3D in lit:
		li.shadow_enabled = false
	for _i: int in 10:
		await get_tree().process_frame
	var no_shadow: Array = _info()
	for li: Light3D in lit:
		li.shadow_enabled = true
	print("[CASTPERF] view=%s shadowed lights %s; all shadows off: draws %d -> %d" % [view, kinds, shown[0], no_shadow[0]])
	await _shadow_proposals(view, npcs, cam, lit, shown)
	# proposal check: the cast on its own render layer (CAST_LAYER), excluded from the positional lights' shadow casters
	# (the sun keeps casting them): moving bodies no longer re-render those lights' shadow maps
	var saved_layers: Dictionary = {}
	for n: Node in npcs:
		for g: Node in n.find_children("*", "GeometryInstance3D", true, false):
			var gi: GeometryInstance3D = g as GeometryInstance3D
			saved_layers[gi] = gi.layers
			gi.layers = CAST_LAYER_BIT
	var saved_masks: Dictionary = {}
	for li: Light3D in lit:
		if not (li is DirectionalLight3D):
			saved_masks[li] = li.shadow_caster_mask
			li.shadow_caster_mask = li.shadow_caster_mask & ~CAST_LAYER_BIT
	for _i: int in 10:
		await get_tree().process_frame
	var split: Array = _info()
	for gi: GeometryInstance3D in saved_layers:
		gi.layers = saved_layers[gi]
	for li: Light3D in saved_masks:
		li.shadow_caster_mask = saved_masks[li]
	print("[CASTPERF] view=%s cast on render layer %d, excluded from %d positional lights' shadow casters: draws %d -> %d"
			% [view, CAST_LAYER, saved_masks.size(), shown[0], split[0]])
	var rows: Array = []
	for n: Node in npcs:
		var nb: NpcBase = n as NpcBase
		var vr: Node3D = nb.get("visual_root") as Node3D
		if vr == null or not cam.is_position_in_frustum(nb.global_position + Vector3(0, 1.0, 0)):
			continue
		for _i: int in 4:
			await get_tree().process_frame
		var a: int = _info()[0]
		vr.visible = false
		for _i: int in 4:
			await get_tree().process_frame
		var b: int = _info()[0]
		vr.visible = true
		var scene: String = nb.visual_scene.resource_path.get_file().get_basename() if nb.visual_scene != null else "?"
		rows.append([a - b, scene, cam.global_position.distance_to(nb.global_position)])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var out: PackedStringArray = []
	for r: Array in rows.slice(0, 8):
		out.append("%s %d @%.0fm" % [r[1], r[0], r[2]])
	print("[CASTPERF] view=%s per-NPC draws (top 8 of %d on screen): %s" % [view, rows.size(), ", ".join(out)])


## Shadow proposals (LEAD 2026-10-20), each measured alone and restored: the cast casts no shadows; the cast casts
## shadows only within FAR_SHADOW_M of the camera; the sun at 2 cascades; the sun at half its shadow distance.
func _shadow_proposals(view: String, npcs: Array[Node], cam: Camera3D, lit: Array[Light3D], shown: Array) -> void:
	var cast: Array[GeometryInstance3D] = []
	for n: Node in npcs:
		for g: Node in n.find_children("*", "GeometryInstance3D", true, false):
			cast.append(g as GeometryInstance3D)
	var saved: Dictionary = {}
	for gi: GeometryInstance3D in cast:
		saved[gi] = gi.cast_shadow
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var off_all: int = await _draws()
	for gi: GeometryInstance3D in cast:
		var far: bool = cam.global_position.distance_to(gi.global_position) > FAR_SHADOW_M
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far else saved[gi]
	var off_far: int = await _draws()
	for gi: GeometryInstance3D in cast:
		gi.cast_shadow = saved[gi]
	print("[CASTPERF] view=%s cast shadows off: draws %d -> %d; off beyond %.0f m only: -> %d" % [view, shown[0], off_all,
			FAR_SHADOW_M, off_far])
	for li: Light3D in lit:
		if not (li is DirectionalLight3D):
			continue
		var sun: DirectionalLight3D = li as DirectionalLight3D
		var mode: DirectionalLight3D.ShadowMode = sun.directional_shadow_mode
		var dist: float = sun.directional_shadow_max_distance
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		var two: int = await _draws()
		sun.directional_shadow_mode = mode
		sun.directional_shadow_max_distance = dist * 0.5
		var half: int = await _draws()
		sun.directional_shadow_max_distance = dist
		print("[CASTPERF] view=%s sun %s mode=%d max_distance=%.0f m: 2 splits -> %d draws; max_distance %.0f m -> %d draws"
				% [view, sun.name, mode, dist, two, dist * 0.5, half])


func _draws() -> int:
	for _i: int in 10:
		await get_tree().process_frame
	return int(_info()[0])


func _info() -> Array:
	var rs := RenderingServer
	return [rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)]


func _switch(nb: NpcBase) -> float:
	for m: Node in nb.find_children("CrowdLod", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.visibility_range_begin > 0.0:
			return mi.visibility_range_begin
	return 1e9


func _set_cast_visible(npcs: Array[Node], on: bool) -> void:
	for n: Node in npcs:
		var vr: Node = (n as NpcBase).get("visual_root")
		if vr is Node3D:
			(vr as Node3D).visible = on
