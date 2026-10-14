## (e) co-op FP / third-person FX check (D-086 windowed, D-105): a real host window + a real client window
## (coop_fx_client.tscn, spawned here) over loopback on the dev_sandbox. Each crew turns to watch the other:
## the host fires three taps (host frames: its own first-person FX; client frames: the host's third-person FX),
## then the client fires three (the reverse). A PNG per shot_fx on each peer plus fx_sheet.png (row 1 host,
## row 2 client; own | remote). Prints "FXC ..." lines and a RESULT line with the per-peer shot_fx counts.
##   xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 640x360 --path game res://tests/p/_review/coop_fx_capture.tscn -- --out=/abs/dir
## Owner: ENV P.
extends Node

const PROBE: GDScript = preload("res://tests/a/coop_loopback_probe.gd")
const CLIENT_SCENE: String = "res://tests/p/_review/coop_fx_client.tscn"
const TAPS: int = 3

var _out: String = "user://coop_fx"
var _probe: Node = null
var _pid: int = -1
var _rt: HeistRuntime = null
var _reports: Dictionary = {}
var _n: Dictionary = {"own": 0, "remote": 0}
var _busy: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var port: int = _host()
	if port < 0:
		_finish("no port")
		return
	_probe = PROBE.new()
	_probe.name = PROBE.NODE_NAME
	get_tree().root.add_child(_probe)
	_probe.connect(&"reported", func(kind: String, data: Dictionary) -> void: _reports[kind] = data)
	_pid = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--resolution", "640x360",
		"--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--", "--port=%d" % port, "--out=%s" % _out,
		"--timeout=900"]))
	if not await _until(func() -> bool: return Net.human_slots().size() >= 2, 120.0):
		_finish("client never joined")
		return
	var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
	l.primary = &"weapon.corsair_ar"
	l.primary_mods = [] as Array[StringName]
	l.resolved_primary = LoadoutResolver.resolve_weapon(l.primary, l.primary_mods)
	var loadouts: Dictionary = {}
	var heisters: Array[StringName] = [&"rook", &"sable", &"dutch", &"wren"]
	for s: int in Net.human_slots():  # a real third-person body (D-073), not the capsule placeholder
		var ls: Loadout = l.duplicate() as Loadout
		ls.heister = heisters[s % heisters.size()]
		loadouts[s] = ls
	_rt = await HeistLauncher.launch(&"dev_sandbox", 8108, Enums.Difficulty.ROUTINE, get_tree().root,
		{"skip_casing": true, "crew_ai": false, "ai_teammates": 0, "loadouts": loadouts})
	if not await _until(func() -> bool: return bool((await _snapshot()).get("launch_client", false)), 300.0):
		_finish("client built no replica")
		return
	_rt.isolate_npc(null)
	var host: CrewController = _rt.crew_controller(0) as CrewController
	var guest: CrewController = null
	for c: CrewController in _rt.crew_members():
		if c != host and not c.is_ai:
			guest = c
	if guest == null:
		_finish("no remote crew on the host")
		return
	host.set_masked(true)
	guest.set_masked(true)
	await _seconds(1.0)
	# 7 m apart across the open yard (clear of the spawn line, where the AI crew stand): each sees the other whole.
	_rt.teleport_crew(guest.slot, Transform3D(Basis.IDENTITY, host.global_position + Vector3(0.0, 0.0, -7.0)))
	await _seconds(1.0)
	_face(host, guest, false, true)
	_face(guest, host, true, false)
	await _seconds(2.5)
	print("FXC host at %s, client at %s" % [host.global_position, guest.global_position])
	for c: CrewController in [host, guest]:
		var vis: Node = c.get_node_or_null(^"Visual")
		print("FXC host crew slot=%d heister=%s local=%s visual=%s" % [c.slot, c.heister, c.is_local(),
			vis.get_children().map(func(n: Node) -> String: return n.name) if vis != null else "none"])
	EventBus.shot_fx.connect(_on_shot_fx)
	print("FXC host at %s, client at %s" % [host.global_position, guest.global_position])
	# Phase 1: the host fires past the client while the client watches it; phase 2 the reverse.
	_face(host, guest, false, true)
	_face(guest, host, true, false)
	await _seconds(2.0)
	for _k: int in TAPS:
		_face(host, guest, false, true, true)
		await _ticks(3)
		_face(host, guest, false, true)
		await _seconds(0.6)
	await _seconds(2.0)
	_face(guest, host, true, true)
	_face(host, guest, false, false)
	await _seconds(2.0)
	for _k: int in TAPS:
		_face(guest, host, true, true, true)
		await _ticks(3)
		_face(guest, host, true, true)
		await _seconds(0.6)
	await _seconds(2.0)
	EventBus.shot_fx.disconnect(_on_shot_fx)
	_sheet()
	_finish("host own=%d remote=%d" % [_n["own"], _n["remote"]])


## Turn `c` toward `target` (`away`: 60 degrees past it, so its shots fly by the watcher's side, not into it).
func _face(c: CrewController, target: CrewController, remote: bool, away: bool, fire: bool = false) -> void:
	var d: Vector3 = target.global_position - c.global_position
	var i: CrewIntent = CrewIntent.new()
	i.look_yaw = atan2(-d.x, -d.z) + (deg_to_rad(60.0) if away else 0.0)
	i.look_pitch = deg_to_rad(-6.0)
	i.fire = fire
	i.weapon_slot = Enums.WeaponSlot.PRIMARY
	if remote:
		_probe.call(&"command", "intent", {"intent": i.to_dict()})
	else:
		_rt.set_bot_intent(c.slot, i)


func _on_shot_fx(_origin: Vector3, _end: Vector3, _normal: Vector3, _surface: StringName, _weapon_class: StringName,
		shooter: int, flags: int) -> void:
	var kind: String = "own" if flags & FpViewmodelFx.FLAG_FIRST_PERSON != 0 else "remote"
	print("FXC host shot_fx shooter=%d flags=%d %s" % [shooter, flags, kind])
	if not _busy:
		_grab(kind)


func _grab(kind: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	_n[kind] = int(_n[kind]) + 1
	get_viewport().get_texture().get_image().save_png("%s/host_%s_%02d.png" % [_out, kind, int(_n[kind])])
	await RenderingServer.frame_post_draw  # the next frame too: a third-person flash may spawn a frame late
	get_viewport().get_texture().get_image().save_png("%s/host_%s_%02d_next.png" % [_out, kind, int(_n[kind])])
	_busy = false


## Row 1 host, row 2 client; columns own 1..3 | remote 1..3 (missing frames stay black).
func _sheet() -> void:
	await _seconds(1.0)
	var w: int = 320
	var h: int = 180
	var sheet: Image = Image.create(w * TAPS * 2, h * 2, false, Image.FORMAT_RGBA8)
	for r: int in 2:
		var who: String = ["host", "client"][r]
		for k: int in TAPS * 2:
			var path: String = "%s/%s_%s_%02d.png" % [_out, who, "own" if k < TAPS else "remote", k % TAPS + 1]
			var img: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
			if img == null:
				continue
			img.convert(Image.FORMAT_RGBA8)
			img.resize(w, h, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(k * w, r * h))
	sheet.save_png("%s/fx_sheet.png" % _out)


func _finish(msg: String) -> void:
	print("FXC RESULT %s" % msg)
	if _probe != null:
		_probe.call(&"command", "quit", {})
	await _seconds(1.0)
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	get_tree().quit(0)


func _host() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec()
	for _i: int in 12:
		var port: int = rng.randi_range(49152, 65000)
		if Net.host(port, "Host") == OK:
			return port
	return -1


func _snapshot() -> Dictionary:
	_reports.erase("snapshot")
	_probe.call(&"command", "snapshot", {})
	await _until(func() -> bool: return _reports.has("snapshot"), 10.0)
	return _reports.get("snapshot", {})


func _until(cond: Callable, timeout_s: float) -> bool:
	var t_end: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < t_end:
		if await cond.call():
			return true
		await _seconds(0.25)
	return false


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ticks(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame
