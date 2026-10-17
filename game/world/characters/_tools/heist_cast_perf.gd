## Heist cast perf (LEAD items h + l, 2026-10-17): a heist launched as the game does (HeistLauncher, Cataclysm), from
## each of its worst-case views (VIEWS[heist]): the frame's draws / primitives / objects with the cast shown, with the
## cast's attached never-LOD geometry hidden (held weapons, hand props: no visibility_range_end), and with the cast
## hidden; plus per-NPC LOD tier (full mesh vs CrowdLod proxy, by the proxy's own switch distance) and AnimLod band.
## `--loud` raises the alarm after the spawns settle and waits `--seconds` (default 90) of game time for the police.
## OF forces its vip_client slot. Writes user://cast_perf_<heist>_<view>.png. Owner: ENV D.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --rendering-driver opengl3 \
##     --resolution 1280x720 --path game res://world/characters/_tools/heist_cast_perf.tscn -- \
##     --heist=ostrander_federal [--seed=1037] [--loud] [--seconds=90]
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
const FORCE: Dictionary = {"ostrander_federal": {"vip": ["vip_in"]}}
var _heist: String = "ostrander_federal"
var _seed: int = 1037
var _loud: bool = false
var _seconds: float = 90.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		match kv[0]:
			"heist": _heist = kv[1]
			"seed": _seed = int(kv[1])
			"loud": _loud = true
			"seconds": _seconds = float(kv[1])
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
