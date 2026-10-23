## Rolling Thunder phase 2 capture (the LEAD's ask after the mixer map, r280): the clean-stop mixer move through the
## Tannery gate, from the live map in a HeistRuntime. Rigs the signals, brings the convoy in now, and from a high eye
## over Tannery west and the junction snapshots every `--step` s from the stop until the mixer has parked
## (ConvoyVehicle.is_stopped) plus one frame; logs the mixer's position, the gate's state and the layout per frame, and
## composes a contact sheet. PNGs, sheet and log to --out. Compatibility renderer, as the low-end players see it:
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --fixed-fps 60 --resolution 960x540 --path game res://world/tools/rt_mixer_capture.tscn -- --out=/abs/dir \
##     [--seed=1] [--step=1.0] [--crash] [--route=north|east]
## --crash leaves the signals unrigged (the crash stop); --route quits with code 3 when the seed rolls the other route
## (loop seeds in the shell). The log carries the mixer's pitch / roll / yaw (deg) per frame.
## Owner: ENV C.
extends Node3D

## Under the Skyway deck (its soffit is at 7.6 m), south of the junction, wide enough for the gate (x -33.5) and the
## east stop (x 12.5).
const EYE: Vector3 = Vector3(-16.0, 5.5, 16.0)
const AT: Vector3 = Vector3(-14.0, 0.0, -6.0)
const FOV: float = 90.0
const MAX_S: float = 40.0
const THUMB: Vector2i = Vector2i(320, 180)
const COLS: int = 4

var _out: String = ""
var _seed: int = 1
var _step: float = 1.0
var _crash: bool = false
var _want_route: String = ""
var _cam: Camera3D = null
var _log: PackedStringArray = []
var _shots: PackedStringArray = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--seed="):
			_seed = int(a.trim_prefix("--seed="))
		elif a.begins_with("--step="):
			_step = float(a.trim_prefix("--step="))
		elif a == "--crash":
			_crash = true
		elif a.begins_with("--route="):
			_want_route = a.trim_prefix("--route=")
	if _out == "":
		_out = OS.get_user_data_dir() + "/rt_mixer"
	RenderingServer.render_loop_enabled = false
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"rolling_thunder", _seed, Enums.Difficulty.ROUTINE, self,
		{"crew_ai": false, "ai_teammates": 0, "skip_casing": true})
	if rt == null or rt.mission == null:
		push_error("[RTMIXER] launch failed")
		get_tree().quit(1)
		return
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = FOV
	_cam.current = true
	_cam.look_at_from_position(EYE, AT)
	await _ticks(30)
	var m: Node = rt.mission
	var route: String = String(m.call(&"_route"))
	print("[RTMIXER] seed %d route %s %s" % [_seed, route, "crash" if _crash else "clean"])
	if _want_route != "" and not route.contains(_want_route):
		get_tree().quit(3)
		return
	m.set(&"signals_rigged", not _crash)
	await _snap("00_before", rt)
	m.call(&"_convoy_arrives")
	var mixer: ConvoyVehicle = m.call(&"_mixer") as ConvoyVehicle
	var t: float = 0.0
	var k: int = 1
	var parked_frames: int = 0
	while t < MAX_S:
		await _ticks(roundi(_step * Engine.physics_ticks_per_second))
		t += _step
		await _snap("%02d_t%04.1f" % [k, t], rt)
		k += 1
		if mixer != null and mixer.is_stopped() and mixer.global_position.distance_to(_stop(rt)) < 0.2:
			parked_frames += 1
			if parked_frames >= 2:
				break
	_sheet()
	var f: FileAccess = FileAccess.open("%s/rt_mixer_log.txt" % _out, FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	print("[RTMIXER] RESULT DONE %s (%d frames)" % [_out, _shots.size()])
	get_tree().quit(0)


func _stop(rt: HeistRuntime) -> Vector3:
	var layout: Node3D = ConvoyLayouts.find(rt.map, String(rt.mission.get(&"layout_id")))
	var s: Node3D = layout.get_node_or_null(^"MixerStop") as Node3D if layout != null else null
	return s.global_position if s != null else Vector3.INF


func _snap(nm: String, rt: HeistRuntime) -> void:
	var mixer: ConvoyVehicle = rt.mission.call(&"_mixer") as ConvoyVehicle
	var gate: Door = rt.map.find_child("SiteTanneryGate", true, false) as Door
	_cam.make_current()   # the crew's camera takes over once the heist goes loud
	_cam.look_at_from_position(EYE, AT)
	for n: Node in rt.find_children("*", "CanvasLayer", true, false):   # the crew's viewmodel / HUD overlays
		(n as CanvasLayer).visible = false
	var rot: Vector3 = Vector3.ZERO
	if mixer != null:   # Godot YXZ euler: x = pitch, y = yaw, z = roll
		rot = mixer.global_basis.orthonormalized().get_euler() * (180.0 / PI)
	var line: String = "%s layout %s mixer %s pitch %.2f roll %.2f yaw %.1f gate open %s" % [nm,
		rt.mission.get(&"layout_id"), mixer.global_position.snapped(Vector3.ONE * 0.01) if mixer != null else "-",
		rot.x, rot.z, rot.y, gate.is_open if gate != null else "-"]
	_log.append(line)
	print("[RTMIXER] " + line)
	RenderingServer.render_loop_enabled = true
	for _i: int in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%s.png" % [_out, nm])
	_shots.append(nm)


func _sheet() -> void:
	if _shots.is_empty():
		return
	var rows: int = ceili(float(_shots.size()) / COLS)
	var sheet: Image = Image.create(THUMB.x * COLS, THUMB.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i: int in _shots.size():
		var img: Image = Image.load_from_file("%s/%s.png" % [_out, _shots[i]])
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, THUMB), Vector2i((i % COLS) * THUMB.x, (i / COLS) * THUMB.y))
	sheet.save_png("%s/rt_mixer_sheet.png" % _out)


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame
