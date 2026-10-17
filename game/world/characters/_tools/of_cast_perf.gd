extends Node

## OF Cataclysm cast perf (LEAD item h, 2026-10-17): Ostrander Federal launched as the game does (HeistLauncher,
## Cataclysm, the vip_client slot forced), three banking-hall views; per view the frame's draws / primitives / objects
## with the cast shown, with the cast's attached never-LOD geometry hidden (held weapons, hand props: no
## visibility_range_end), and with the cast hidden; plus the per-NPC LOD tier (full mesh vs CrowdLod proxy, by the
## proxy's own switch distance) and AnimLod band. Writes user://of_perf_<view>.png. Owner: ENV D.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --rendering-driver opengl3 \
##     --resolution 1280x720 --path game res://world/characters/_tools/of_cast_perf.tscn -- [--seed=1037]
const VIEWS: Array = [
	["hall_south_eye", Vector3(24.0, 1.7, 35.5), Vector3(24.0, 1.2, 17.0)],
	["hall_south_high", Vector3(24.0, 4.2, 35.8), Vector3(24.0, 0.8, 18.0)],
	["hall_west_diag", Vector3(9.0, 1.7, 34.5), Vector3(36.0, 1.0, 18.0)],
]
var _seed: int = 1037


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			_seed = int(a.substr(7))
	var rt: HeistRuntime = await HeistLauncher.launch(&"ostrander_federal", _seed, Enums.Difficulty.CATACLYSM, self,
			{"ai_teammates": 0, "preplan": {"force_variants": {"vip": ["vip_in"]}}})
	if rt == null:
		print("[OFPERF] launch failed")
		get_tree().quit(1)
		return
	for _i: int in 180:
		await get_tree().physics_frame
	var npcs: Array[Node] = rt.npcs()
	var by_role: Dictionary = {}
	for n: Node in npcs:
		var nb: NpcBase = n as NpcBase
		by_role[String(nb.role)] = int(by_role.get(String(nb.role), 0)) + 1
	print("[OFPERF] seed=%d npcs=%d by_role=%s variants=%s" % [_seed, npcs.size(), by_role, rt.variants])
	var cam := Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.current = true
	for v: Array in VIEWS:
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
		print("[OFPERF] view=%s attached never-LOD geometry: %d nodes, %d tris; hiding it: draws %d -> %d, prims %d -> %d"
				% [v[0], extra_nodes, extra_tris, shown[0], no_extras[0], shown[1], no_extras[1]])
		_set_cast_visible(npcs, false)
		for _i: int in 10:
			await get_tree().process_frame
		var hidden: Array = _info()
		_set_cast_visible(npcs, true)
		for _i: int in 10:
			await get_tree().process_frame
		print("[OFPERF] view=%s draws=%d (map %d, cast %d) prims=%d (cast %d) objects=%d (cast %d) tiers=%s anim_bands=%s"
				% [v[0], shown[0], hidden[0], shown[0] - hidden[0], shown[1], shown[1] - hidden[1], shown[2],
				shown[2] - hidden[2], tiers, bands])
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("user://of_perf_%s.png" % v[0]))
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
