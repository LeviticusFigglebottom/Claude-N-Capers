## DB-4 review (v1.24 sit_chair_armed): Dockside Burn launched as the game does (HeistLauncher, lit), the cartel
## gunmen on `sit` posts (cartel_platform: M2 BreakChairS, PF ForemanChair) shown seated, front 3/4 and side, with
## the clip ENV A's AnimDriver plays printed. Writes <out>/db4_<npc>_{front,side}.png.
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 960x540 --path game res://world/characters/_tools/render_db4_sit_review.tscn -- --out=/abs/dir \
##     [--seed=N] [--settle=s]
## Owner: ENV D.
extends Node

var _out: String = "user://db4_sit_review"
var _seed: int = 1002
## s of game time before the shots (the gunmen reach their seats)
var _settle: float = 8.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"seed": _seed = int(v)
			"settle": _settle = float(v)
	DirAccess.make_dir_recursive_absolute(_out)
	RenderingServer.render_loop_enabled = false
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	var rt: HeistRuntime = await HeistLauncher.launch(&"dockside_burn", _seed, Enums.Difficulty.CATACLYSM, self,
			{"ai_teammates": 0, "crew_ai": false, "loadouts": {0: l}})
	for _i: int in int(_settle * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
	var crew: Node3D = rt.crew_controller(0) as Node3D
	crew.visible = false
	var seated: Array[NpcBase] = []
	for n: Node in rt.npcs():
		var npc: NpcBase = n as NpcBase
		if String(npc.spawn_info.get("idle_activity", "")) == "sit":
			seated.append(npc)
	print("[DB4] seed %d: %d npc(s) on sit posts" % [_seed, seated.size()])
	var cam: Camera3D = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.current = true
	for npc: NpcBase in seated:
		var ap: AnimationPlayer = AnimDriver.find_player(npc)
		print("[DB4] %s role=%s tags=%s clip=%s pos=%s" % [npc.name, npc.role, npc.spawn_info.get("tags", []),
			ap.current_animation if ap != null else "-", npc.global_position])
		var o: Vector3 = npc.global_position
		var fwd: Vector3 = -npc.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var side: Vector3 = fwd.cross(Vector3.UP).normalized()
		for view: Array in [["front", fwd * 1.9 + side * 0.9], ["side", side * 2.0 + fwd * 0.3]]:
			cam.global_position = o + view[1] + Vector3.UP * 1.25
			cam.look_at(o + Vector3.UP * 0.7)
			var img: Image = await _shot()
			img.save_png("%s/db4_%s_%s.png" % [_out, npc.name, view[0]])
	RenderingServer.render_loop_enabled = true
	rt.teardown()
	print("[DB4] RESULT DONE %s" % _out)
	get_tree().quit(0)


func _shot() -> Image:
	RenderingServer.render_loop_enabled = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	return img
