## RT-D2 windowed evidence: every Rolling Thunder cast member in place on C's map. Launches the heist, shoots each live
## NPC from in front of it (label: look, clip, spawn tags), then forces a clean convoy stop (signals rigged), shoots the
## seated escorts in their cars and the dismount (vehicle_exit_*) of one car, and composes a contact sheet. Logs every
## NPC with its look, clip, position and facing. PNGs, sheet and log go to --out.
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 60 \
##     --resolution 640x360 \
##     --path game res://world/characters/_tools/render_rt_cast_review.tscn \
##     -- --out=/abs/dir [--seed=1] [--difficulty=0] [--no-convoy] [--only=<spawn tag>] [--crash] [--skip-cast] [--cab]
## Owner: ENV D.
extends Node3D

const THUMB: Vector2i = Vector2i(320, 180)
const COLS: int = 6
const EYE_DIST: float = 2.6
const EYE_H: float = 1.45

var _out: String = ""
var _seed: int = 1
var _difficulty: int = Enums.Difficulty.ROUTINE
var _convoy: bool = true
## --only=<spawn tag>: shoot only the NPCs with that tag (e.g. driver_mixer), no convoy phase
var _only: StringName = &""
## --crash: the signals are not rigged, so the convoy runs into the crash stop (Reyes rams it); --skip-cast: convoy only
var _crash: bool = false
## --cab: a seated character (with --only) shot from fixed views through its vehicle's door window and windscreen
var _cab: bool = false
var _skip_cast: bool = false
var _cam: Camera3D = null
var _label: Label = null
var _log: PackedStringArray = []
var _shots: Array[String] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--seed="):
			_seed = int(a.trim_prefix("--seed="))
		elif a.begins_with("--difficulty="):
			_difficulty = int(a.trim_prefix("--difficulty="))
		elif a == "--no-convoy":
			_convoy = false
		elif a == "--cab":
			_cab = true
		elif a == "--crash":
			_crash = true
		elif a == "--skip-cast":
			_skip_cast = true
		elif a.begins_with("--only="):
			_only = StringName(a.trim_prefix("--only="))
	if _out == "":
		_out = OS.get_user_data_dir() + "/rt_cast"
	RenderingServer.render_loop_enabled = false  # frames only for the shots (llvmpipe draws this map slowly)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	# no probe prewarm: it waits on drawn frames, and with the render loop off the heist clock ran past the convoy's
	# ETA during launch (the crash ambush, then the heist failed before the first shot)
	var rt: HeistRuntime = await HeistLauncher.launch(&"rolling_thunder", _seed, _difficulty, self,
		{"crew_ai": false, "ai_teammates": 0, "probe_prewarm": false})
	if rt == null:
		push_error("[RTCAST] launch failed")
		get_tree().quit(1)
		return
	if not _convoy and rt.mission != null:
		rt.mission.cancel_timer(&"convoy")  # --no-convoy: the cast in the calm casing phase, no arrival mid-shoot
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = 55.0
	_cam.current = true
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8, 6)
	_label.add_theme_font_size_override(&"font_size", 22)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)
	await _ticks(60)
	_say("seed %d difficulty %d" % [_seed, _difficulty])
	var i: int = 0
	for n: Node in ([] as Array[Node]) if _skip_cast else rt.npcs():
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.visible:
			continue
		if _only != &"" and not (npc.spawn_info.get("tags", []) as Array).has(_only):
			continue
		i += 1
		if _cab:
			await _cab_shots("cab_%02d" % i, npc)
			continue
		await _npc_shot("cast_%02d" % i, npc)
	if _convoy and _only == &"" and rt.mission != null and &"signals_rigged" in rt.mission:
		await _convoy_phase(rt)
	_sheet()
	_finish()


## Clean stop: rig the signals, the convoy arrives now; wait for the movers to park, shoot the seated units, then the
## dismount of the first visible seated unit over its vehicle_exit clip.
func _convoy_phase(rt: HeistRuntime) -> void:
	var m: Node = rt.mission
	m.set(&"signals_rigged", not _crash)
	m.call(&"_convoy_arrives")
	var waited: int = 0
	while String(m.get(&"convoy_state")) == "stopped" and (m.get(&"_trucks") as Array).is_empty() and waited < 60 * 120:
		await _ticks(60)
		waited += 60
	await _ticks(60)
	_say("convoy layout %s after %.0f s, units %d" % [m.get(&"layout_id"), waited / 60.0, (m.get(&"_units") as Array).size()])
	await _mixer_shot(m)
	var seated: Array = (m.get(&"_seated") as Array).duplicate()
	var j: int = 0
	for u: Variant in m.get(&"_units") as Array:
		var npc: NpcBase = u as NpcBase
		if npc == null or not is_instance_valid(npc):
			continue
		j += 1
		if not npc.visible:
			_say("convoy %02d %s HIDDEN (cab) look %s tags %s at %s" % [j, npc.name, NpcVisuals.character_id(npc),
				npc.spawn_info.get("tags"), npc.global_position])
			continue
		await _npc_shot("convoy_%02d" % j, npc, 3.4)
	var first: NpcBase = null
	for u: Variant in seated:
		if u is NpcBase and is_instance_valid(u) and (u as NpcBase).visible:
			first = u
			break
	if first == null:
		_say("no visible seated unit: no dismount strip")
		return
	var veh: Node3D = Ids.lookup(int(first.get_meta(&"seated_in", 0))) as Node3D if first.has_meta(&"seated_in") else null
	var focus: Vector3 = first.global_position
	var side: Vector3 = veh.global_basis.x if veh != null else Vector3.RIGHT
	if veh != null and veh.to_local(focus).x < 0.0:
		side = -side
	var eye: Vector3 = focus + side * 4.0 + Vector3.UP * 1.5 - (veh.global_basis.z if veh != null else Vector3.ZERO) * 1.5
	m.call(&"_dismount_all")
	for k: int in 6:
		_label.text = "dismount t=%.1f s  %s  clip %s" % [k * 0.4, NpcVisuals.character_id(first), _clip(first)]
		await _shot("dismount_%d" % k, eye, first.global_position + Vector3.UP * 0.9)
		await _ticks(24)


## The Mixer (C's ram truck, Reyes at the wheel) where it stands after the stop: a three-quarter view of its cab side.
func _mixer_shot(m: Node) -> void:
	await _ticks(240)  # clean: the mixer moves at stop + 3 s; crash: it has already rammed
	var mixer: Node3D = m.call(&"_mixer") as Node3D if m.has_method(&"_mixer") else null
	if mixer == null:
		_say("no Mixer on this map")
		return
	var b: Basis = mixer.global_basis.orthonormalized()
	var at: Vector3 = mixer.global_position + b.z * 3.0 + Vector3.UP * 1.8
	var eye: Vector3 = at + (b.x * 6.0 + b.z * 4.0) + Vector3.UP * 0.6
	_label.text = "mixer (%s)  %s" % ["crash" if _crash else "clean", m.get(&"layout_id")]
	_say("mixer at (%.2f, %.2f, %.2f)" % [mixer.global_position.x, mixer.global_position.y, mixer.global_position.z])
	await _shot("mixer_%s" % ("crash" if _crash else "clean"), eye, at)


## Views of a seated character from outside its cab, no collision check (the cab glass is in the way by design): through
## the door window on its own side, through the windscreen, and a close-up of the hands at the wheel.
func _cab_shots(name: String, npc: NpcBase) -> void:
	var b: Basis = npc.global_basis.orthonormalized()
	var fwd: Vector3 = -b.z
	var left: Vector3 = -b.x
	var chest: Vector3 = npc.global_position + Vector3.UP * 0.85
	_label.text = "%s  %s\n%s" % [name, NpcVisuals.character_id(npc), _clip(npc)]
	_say("%s %s look %s clip %s at (%.2f, %.2f, %.2f)" % [name, npc.name, NpcVisuals.character_id(npc), _clip(npc),
		npc.global_position.x, npc.global_position.y, npc.global_position.z])
	await _shot(name + "_door", chest + left * 1.9 + fwd * 0.6 + Vector3.UP * 0.25, chest)
	await _shot(name + "_windscreen", chest + fwd * 2.6 + Vector3.UP * 0.35, chest)
	# from the passenger seat, inside the cab: the hands on the wheel
	await _shot(name + "_hands", chest - left * 1.0 + fwd * 0.25 + Vector3.UP * 0.35, chest + fwd * 0.35 + Vector3.UP * 0.05)


func _npc_shot(name: String, npc: NpcBase, dist: float = EYE_DIST) -> void:
	var fwd: Vector3 = -npc.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var at: Vector3 = npc.global_position + Vector3.UP * 0.9
	# the front three-quarter first, then the other 7 directions: the one with the most clear room (a wall or a parked
	# truck right behind the camera would cramp the frame)
	var base: Vector3 = fwd * dist + Vector3(fwd.z, 0.0, -fwd.x) * 0.8 + Vector3.UP * (EYE_H - 0.9)
	var eye: Vector3 = at + base
	var best: float = -1.0
	for k: int in 8:
		var cand: Vector3 = at + base.rotated(Vector3.UP, k * PI / 4.0)
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at, cand)
		q.exclude = [npc.get_rid()] if npc is CollisionObject3D else []
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		var d: float = at.distance_to(cand) if hit.is_empty() else maxf(at.distance_to(hit["position"]) - 0.15, 0.9)
		if d > best + 0.3:
			best = d
			eye = at + (cand - at).normalized() * d
	var tags: Variant = npc.spawn_info.get("tags", [])
	_label.text = "%s  %s\n%s  %s" % [name, NpcVisuals.character_id(npc), _clip(npc), str(tags)]
	_say("%s %s role %s tags %s activity %s look %s clip %s at (%.2f, %.2f, %.2f) facing %.0f" % [name, npc.name,
		npc.role, tags, npc.spawn_info.get("idle_activity", ""), NpcVisuals.character_id(npc), _clip(npc),
		npc.global_position.x, npc.global_position.y, npc.global_position.z, rad_to_deg(npc.global_rotation.y)])
	await _shot(name, eye, at)


func _sheet() -> void:
	if _shots.is_empty():
		return
	var rows: int = ceili(float(_shots.size()) / COLS)
	var sheet: Image = Image.create(THUMB.x * COLS, THUMB.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for k: int in _shots.size():
		var img: Image = Image.load_from_file("%s/%s.png" % [_out, _shots[k]])
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, THUMB), Vector2i((k % COLS) * THUMB.x, (k / COLS) * THUMB.y))
	sheet.save_png("%s/rt_cast_sheet.png" % _out)
	_say("sheet rt_cast_sheet.png %d shots" % _shots.size())


func _finish() -> void:
	var f: FileAccess = FileAccess.open("%s/rt_cast_log.txt" % _out, FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	print("[RTCAST] RESULT DONE %s" % _out)
	get_tree().quit(0)


func _clip(npc: NpcBase) -> String:
	var ad: AnimDriver = AnimDriver.of(npc)
	return String(ad.choose_clip()) if ad != null else "-"


func _shot(name: String, eye: Vector3, at: Vector3) -> void:
	if eye.distance_to(at) < 0.05:
		eye += Vector3(0.0, 0.5, 1.0)
	_cam.look_at_from_position(eye, at)
	for n: Node in get_tree().root.find_children("*", "", true, false):
		if n is FpViewmodel:
			(n as Node3D).visible = false  # the player's first-person gun would draw over the review camera
	RenderingServer.render_loop_enabled = true
	for _i: int in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [_out, name])
	_shots.append(name)


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func _say(s: String) -> void:
	_log.append(s)
	print("[RTCAST] " + s)
