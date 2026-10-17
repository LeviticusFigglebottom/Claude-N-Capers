## Civilian panic review (D-116, LEAD 2026-10-17): a heist launched as the game does (HeistLauncher, lit), the camera
## framed on the largest cluster of civilians, the alarm raised, and frames shot at --times seconds after it. Shows
## how a crowd scatters: panic_start / cower* / flee* per body (ENV A's AnimDriver variant groups). Writes
## <out>/scatter_<t>.png and <out>/scatter_sheet.png (one row).
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 960x540 --path game res://world/characters/_tools/render_crowd_scatter.tscn -- --out=/abs/dir \
##     [--heist=gallery_night] [--seed=1002] [--difficulty=5] [--times=0,0.3,0.6,1,1.6]
## Owner: ENV D.
extends Node

var _out: String = "user://crowd_scatter"
var _heist: String = "gallery_night"
var _seed: int = 1002
var _times: PackedFloat64Array = [0.0, 0.3, 0.6, 1.0, 1.6]
## Cataclysm: D-130's largest crowd
var _difficulty: int = Enums.Difficulty.CATACLYSM


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"heist": _heist = v
			"seed": _seed = int(v)
			"difficulty": _difficulty = int(v)
			"times":
				_times = []
				for t: String in v.split(","):
					_times.append(float(t))
	DirAccess.make_dir_recursive_absolute(_out)
	RenderingServer.render_loop_enabled = false
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	var rt: HeistRuntime = await HeistLauncher.launch(StringName(_heist), _seed, _difficulty, self,
			{"ai_teammates": 0, "crew_ai": false, "loadouts": {0: l}})
	for _i: int in 240:   # civilians settle into their ambient spots
		await get_tree().physics_frame
	(rt.crew_controller(0) as Node3D).visible = false
	var civs: Array[Node3D] = []
	for n: Node in rt.npcs(&"civilian"):
		civs.append(n as Node3D)
	# the densest cluster: the civilian with the most others within 6 m, and its neighbours' centroid
	var best: Vector3 = Vector3.ZERO
	var best_n: int = -1
	for c: Node3D in civs:
		var sum: Vector3 = Vector3.ZERO
		var n: int = 0
		for o: Node3D in civs:
			if c.global_position.distance_to(o.global_position) < 6.0:
				sum += o.global_position
				n += 1
		if n > best_n:
			best_n = n
			best = sum / float(maxi(n, 1))
	print("[SCATTER] %d civilians, cluster of %d at %s" % [civs.size(), best_n, best])
	var cam: Camera3D = Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.global_position = _clear_spot(best)
	cam.look_at(best + Vector3.UP * 0.9)
	cam.current = true
	rt.stealth.raise_alarm(&"d_crowd_scatter")
	var t0: int = Time.get_ticks_msec()
	var shots: Array[Image] = []
	var tick: int = 0
	for t: float in _times:
		while float(tick) / Engine.physics_ticks_per_second < t:
			await get_tree().physics_frame
			tick += 1
		var img: Image = await _shot()
		img.save_png("%s/scatter_%04.1f.png" % [_out, t])
		shots.append(img)
	var w: int = shots[0].get_width() / 2
	var h: int = shots[0].get_height() / 2
	var sheet: Image = Image.create(w * shots.size(), h, false, shots[0].get_format())
	for i: int in shots.size():
		var s: Image = shots[i].duplicate() as Image
		s.resize(w, h)
		sheet.blit_rect(s, Rect2i(0, 0, w, h), Vector2i(w * i, 0))
	sheet.save_png("%s/scatter_sheet.png" % _out)
	print("[SCATTER] RESULT DONE %s (%.0f s wall)" % [_out, (Time.get_ticks_msec() - t0) / 1000.0])
	RenderingServer.render_loop_enabled = true
	rt.teardown()
	get_tree().quit(0)


## A camera spot 7 m out and 3.5 m up with a clear line to the cluster (the first of 8 directions; walls block rays).
func _clear_spot(target: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var aim: Vector3 = target + Vector3.UP * 1.0
	for dist: float in [7.0, 5.0, 3.5]:
		for i: int in 8:
			var a: float = TAU * float(i) / 8.0 + PI * 0.25
			var p: Vector3 = target + Vector3(cos(a) * dist, 3.5, sin(a) * dist)
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p, aim)
			q.collide_with_areas = false
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty() or (hit["position"] as Vector3).distance_to(aim) < 1.5:
				print("[SCATTER] camera %s (dir %d, %.1f m)" % [p, i, dist])
				return p
	return target + Vector3(3.0, 3.0, 3.0)


func _shot() -> Image:
	RenderingServer.render_loop_enabled = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	return img
