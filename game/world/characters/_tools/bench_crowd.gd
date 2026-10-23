## D-130 character performance audit: per-character static cost, and a bench of N animating characters. Owner: ENV D.
##   stats:  /opt/godot/godot --headless --path game res://world/characters/_tools/bench_crowd.tscn -- --stats \
##             --ids=a,b,c
##   bench:  [xvfb-run -a -s "-screen 0 1280x720x24"] /opt/godot/godot [--headless] [--rendering-driver opengl3]
##             --audio-driver Dummy --path game res://world/characters/_tools/bench_crowd.tscn -- --ids=a,b,c --n=30
##             [--near=4] [--far=45] [--lod=off] [--frames=300] [--seed=1] [--layer]
##   presets (D-132, the real-GPU check; README_bench.md): `-- --preset=both` runs gn34 then loud50 (each with --layer)
##             and prints one "[BENCH] preset=..." line per case; `--preset=gn34` / `--preset=loud50` run one;
##             `--preset=ah50` is the Afterhours dance floor (D-165: 50 club looks on dance_a/b/c, 5-18 m, no layer).
## Stats prints one "[CHAR]" line per id: mesh surfaces (= draw calls at LOD0/LOD1, shadow casters double that), distinct
## materials, vertices and triangles at LOD0, the first automatic LOD (LOD1, Godot picks it by screen size) and LOD2
## (Skeleton3D/CrowdLod, one surface), the LOD2 switch distance, bones and ragdoll bodies.
## Bench places --n characters (ids cycled) at seeded spots between --near and --far metres in front of a camera
## (eye 1.65 m, FOV 75), each looping `walk` from a seeded offset in place (--clip=dance: dance_a/b/c instead; --layer:
## plus hold_rifle_walk on a second AnimationPlayer, as AnimDriver's upper-body layer), and prints "[BENCH]" with the
## mean / p95 frame time (wall),
## Performance process time, draw calls, primitives, visible objects and the texture / video memory in use
## (MB, end of run). --lod=off forces LOD0 (no CrowdLod).
extends Node

const CrowdLod: GDScript = preload("res://world/characters/_tools/crowd_lod.gd")
## D-130 audit cases (d130_perf_audit.md §1): Gallery Night stealth at Cataclysm (30 NPCs + 4 crew), and a loud
## Cataclysm fight (police / specials, a few civilians, crew).
const PRESETS: Dictionary = {
	"gn34": {"n": 34, "ids": ["gallery_guard", "gallery_patron", "gallery_guard_b", "gallery_patron_b", "gallery_guard_c",
		"gallery_patron_c", "gallery_waiter", "gallery_patron_d", "gallery_guard_d", "gallery_patron_e", "gallery_attendant",
		"gallery_patron_f", "gallery_guard_e", "gallery_patron_g", "gallery_conservator", "gallery_patron_h", "gallery_guard_f",
		"gallery_patron_i", "gallery_curator", "gallery_patron_j", "gallery_guard_g", "npc_penthouse_guest_a", "gallery_guard_h",
		"npc_penthouse_guest_b", "gallery_guard_i", "gallery_admin", "armored_car_crew", "gallery_attendant_b",
		"armored_car_crew_b", "npc_penthouse_staff", "crew_rook", "crew_sable", "crew_rook", "crew_sable"]},
	"loud50": {"n": 50, "ids": ["tac_light", "tac_heavy", "patrol_officer", "frd_agent", "tac_light_frd", "tac_heavy_frd",
		"bulwark", "wrecker", "corpsman", "phantom", "stinger", "longshot", "gallery_patron", "gallery_patron_b", "crew_rook",
		"crew_sable"]},
	# D-165 Afterhours dance floor: 30 dancers + 14 patrons + 6 staff, 5-18 m, every one on a dance loop
	"ah50": {"n": 50, "near": 5.0, "far": 18.0, "clip": "dance", "layer": false, "ids": ["club_dancer", "club_patron",
		"club_dancer_b", "club_dancer_c", "club_patron_b", "club_dancer_d", "club_bouncer", "club_dancer_e", "club_patron_c",
		"club_dancer_f", "club_dancer_g", "club_patron_d", "club_dancer_h", "club_bartender", "club_dancer_i", "club_patron_e",
		"club_dancer_j", "club_dancer_k", "club_patron_f", "club_dancer_l", "club_bouncer_b", "club_dancer", "club_patron_g",
		"club_dancer_b", "club_dancer_c", "club_patron_h", "club_dancer_d", "club_dj", "club_dancer_e", "club_patron_i",
		"club_dancer_f", "club_dancer_g", "club_patron_j", "club_dancer_h", "club_bartender_b", "club_dancer_i", "club_patron_k",
		"club_dancer_j", "club_dancer_k", "club_patron_l", "club_dancer_l", "club_bouncer_c", "club_dancer", "club_patron",
		"club_dancer_b", "club_bouncer_d", "club_dancer_c", "club_patron_b", "club_dancer_d", "club_dancer_e"]},
}

var _ids: PackedStringArray = []
var _n: int = 30
var _near: float = 4.0
var _far: float = 45.0
var _lod: bool = true
var _frames: int = 300
var _seed: int = 1
var _layer: bool = false
var _stats: bool = false
## --preset=gn34|loud50|both: the audit cases, one [BENCH] line each ("" = the plain arguments)
var _preset: String = ""
var _label: String = ""
## --switch=m: every CrowdLod switch moved to m (the retune under test; 0 = as assembled)
var _switch: float = 0.0
## --small_shadows=off: surfaces under CrowdLod.MIN_SURFACE_TRIS cast no shadow (eyes, lashes, badges)
var _small_shadows: bool = true
## --clip=walk|dance: the loop every character plays (dance = dance_a/b/c by index, as AmbientHints spreads them)
var _clip: String = "walk"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"ids": _ids = v.split(",")
			"n": _n = int(v)
			"near": _near = float(v)
			"far": _far = float(v)
			"lod": _lod = v != "off"
			"frames": _frames = int(v)
			"seed": _seed = int(v)
			"layer": _layer = true
			"stats": _stats = true
			"preset": _preset = v
			"switch": _switch = float(v)
			"small_shadows": _small_shadows = v != "off"
			"clip": _clip = v
	if _stats:
		for id: String in _ids:
			_print_stats(id)
		get_tree().quit(0)
		return
	Engine.max_fps = 0   # measure the cost, not the cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if _preset.is_empty():
		await _bench()
	else:
		for name: String in (["gn34", "loud50"] if _preset == "both" else [_preset]):
			var p: Dictionary = PRESETS[name]
			_ids = PackedStringArray(p["ids"])
			_n = int(p["n"])
			_layer = bool(p.get("layer", true))
			_near = float(p.get("near", _near))
			_far = float(p.get("far", _far))
			_clip = String(p.get("clip", "walk"))
			_label = "preset=%s " % name
			await _bench()
			for c: Node in get_children():
				c.free()
	get_tree().quit(0)


func _scene(id: String) -> PackedScene:
	return load("res://world/characters/%s/%s.tscn" % [id, id]) as PackedScene


func _print_stats(id: String) -> void:
	var ch: Node3D = _scene(id).instantiate() as Node3D
	var skel: Skeleton3D = ch.get_node_or_null(^"Skeleton3D") as Skeleton3D
	var surfaces: int = 0
	var verts: int = 0
	var tris0: int = 0
	var tris1: int = 0
	var mats: Dictionary = {}
	for mi: MeshInstance3D in CrowdLod.source_meshes(skel):
		var mesh: ArrayMesh = mi.mesh as ArrayMesh
		var surfs: Array = mesh.get("_surfaces")
		for si: int in mesh.get_surface_count():
			surfaces += 1
			var m: Material = mesh.surface_get_material(si)
			mats[m.resource_path if m != null else "-"] = true
			verts += mesh.surface_get_array_len(si)
			var s: Dictionary = surfs[si]
			var t0: int = int(s.get("index_count", 0)) / 3
			tris0 += t0
			var lods: Array = s.get("lods", [])
			var raw: PackedByteArray = s.get("index_data", PackedByteArray())
			var width: int = raw.size() / maxi(int(s.get("index_count", 1)), 1)
			# the first automatic LOD (Godot's LOD1); a surface without one stays at full detail
			tris1 += (lods[1] as PackedByteArray).size() / width / 3 if lods.size() >= 2 and width > 0 else t0
	var lod2: MeshInstance3D = skel.get_node_or_null(NodePath(CrowdLod.NODE_NAME)) as MeshInstance3D
	var tris2: int = 0
	var verts2: int = 0
	if lod2 != null and lod2.mesh != null:
		tris2 = lod2.mesh.surface_get_array_index_len(0) / 3
		verts2 = lod2.mesh.surface_get_array_len(0)
	var rag: Node = skel.get_node_or_null(^"Ragdoll")
	print("[CHAR] %s surfaces=%d materials=%d verts=%d tris0=%d tris1=%d lod2_verts=%d tris2=%d switch_m=%.0f bones=%d ragdoll=%d"
		% [id, surfaces, mats.size(), verts, tris0, tris1, verts2, tris2,
		lod2.visibility_range_begin if lod2 != null else 0.0, skel.get_bone_count(),
		rag.get_child_count() if rag != null else 0])
	ch.free()


## Bench only: surfaces under MIN_SURFACE_TRIS moved to a shadow-less copy of their mesh instance.
func _split_small_shadows(ch: Node3D) -> void:
	var skel: Node = ch.get_node_or_null(^"Skeleton3D")
	for mi: MeshInstance3D in CrowdLod.source_meshes(skel):
		var mesh: ArrayMesh = mi.mesh as ArrayMesh
		var surfs: Array = mesh.get("_surfaces")
		var big: ArrayMesh = ArrayMesh.new()
		var small: ArrayMesh = ArrayMesh.new()
		for si: int in mesh.get_surface_count():
			var dst: ArrayMesh = small if int((surfs[si] as Dictionary).get("index_count", 0)) / 3 < CrowdLod.MIN_SURFACE_TRIS else big
			dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(si))
			dst.surface_set_material(dst.get_surface_count() - 1, mesh.surface_get_material(si))
		if small.get_surface_count() == 0:
			continue
		mi.mesh = big
		var copy: MeshInstance3D = mi.duplicate() as MeshInstance3D
		copy.mesh = small
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skel.add_child(copy)


func _bench() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()   # bench placement only, not gameplay
	rng.seed = _seed
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.52, 0.55)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	floor_mi.mesh = plane
	add_child(floor_mi)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.position = Vector3(0.0, 1.65, 0.0)
	cam.current = true
	for i: int in _n:
		var ch: Node3D = _scene(_ids[i % _ids.size()]).instantiate() as Node3D
		add_child(ch)
		var d: float = lerpf(_near, _far, rng.randf())
		var a: float = deg_to_rad(rng.randf_range(-30.0, 30.0))
		ch.position = Vector3(sin(a) * d, 0.0, -cos(a) * d)
		ch.rotation.y = rng.randf_range(0.0, TAU)
		if not _lod:
			CrowdLod.force_level(ch, false)
		elif _switch > 0.0:
			var proxy: MeshInstance3D = ch.get_node_or_null(NodePath("Skeleton3D/" + CrowdLod.NODE_NAME)) as MeshInstance3D
			if proxy != null:
				proxy.visibility_range_begin = _switch
				for mi: MeshInstance3D in CrowdLod.source_meshes(proxy.get_parent()):
					mi.visibility_range_end = _switch
		if not _small_shadows:
			_split_small_shadows(ch)
		var ap: AnimationPlayer = ch.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		if ap != null:
			var clip: String = "walk" if _clip != "dance" else ["dance_a", "dance_b", "dance_c"][i % 3]
			ap.play(StringName("humanoid/" + clip))
			ap.seek(rng.randf_range(0.0, ap.current_animation_length), true)
			if _layer:
				var lay: AnimationPlayer = AnimationPlayer.new()
				lay.root_node = ap.root_node
				ch.add_child(lay)
				lay.add_animation_library(&"humanoid", ap.get_animation_library(&"humanoid"))
				lay.play(&"humanoid/hold_rifle_walk")
	for _i: int in 60:
		await get_tree().process_frame
	var times: Array[float] = []
	var proc: float = 0.0
	var draws: int = 0
	var prims: int = 0
	var objs: int = 0
	var t_prev: int = Time.get_ticks_usec()
	for _i: int in _frames:
		await get_tree().process_frame
		var t: int = Time.get_ticks_usec()
		times.append(float(t - t_prev) / 1000.0)
		t_prev = t
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		objs += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var sorted: Array[float] = times.duplicate()
	sorted.sort()
	var mean: float = 0.0
	for t: float in times:
		mean += t
	mean /= float(times.size())
	var f: float = float(_frames)
	var mb: float = 1024.0 * 1024.0
	print(("[BENCH] " + _label + "n=%d clip=%s lod=%s layer=%s near=%.0f far=%.0f frame_ms mean=%.2f p95=%.2f process_ms=%.2f"
		+ " draws=%.0f prims=%.0f objects=%.0f tex_mem_mb=%.1f video_mem_mb=%.1f")
		% [_n, _clip, "on" if _lod else "off", _layer, _near, _far, mean, sorted[int(0.95 * (sorted.size() - 1))], proc / f,
		draws / f, prims / f, objs / f, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / mb,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / mb])
