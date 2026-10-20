## D-145.3 windowed proof: the same Glasshouse loud wave on Routine and on Hazardous. Each run raises the alarm and
## waits for the AssaultDirector's own units (no hand-picked spawns), then logs every unit's EnemyDef and the look it
## resolved (NpcVisuals.character_id: `<id>_duty` = no body armour) and frames the group plus up to 4 units close up,
## HUD hidden. Writes <out>/d145_wave_<difficulty>_{group,unit<n>}.png, <out>/d145_wave_sheet.png (row per
## difficulty) and <out>/d145_wave_log.txt.
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 960x540 --path game res://world/characters/_tools/render_d145_wave_review.tscn -- --out=/abs/dir
## (no --fixed-fps: game time keeps pace with the wall clock, so the wave arrives in minutes on llvmpipe)
## Owner: ENV D.
extends Node3D

const DIFFICULTIES: Array[int] = [Enums.Difficulty.ROUTINE, Enums.Difficulty.HAZARDOUS]
const NAMES: Dictionary = {Enums.Difficulty.ROUTINE: "routine", Enums.Difficulty.HAZARDOUS: "hazardous"}
const SEED: int = 7
## wait for this many live director units, at most WAIT_S of game time
const WANT_UNITS: int = 6
const WAIT_S: float = 240.0
const CLOSEUPS: int = 4

var _out: String = ""
var _cam: Camera3D = null
var _log: PackedStringArray = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	if _out == "":
		_out = OS.get_user_data_dir() + "/d145_wave"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rows: Array[Array] = []
	for diff: int in DIFFICULTIES:
		rows.append(await _wave(diff))
	_sheet(rows)
	var f: FileAccess = FileAccess.open("%s/d145_wave_log.txt" % _out, FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	print("[D145W] RESULT DONE %s" % _out)
	get_tree().quit(0)


func _wave(diff: int) -> Array:
	var name: String = NAMES[diff]
	var rt: HeistRuntime = await HeistLauncher.launch(&"glasshouse", SEED, diff, self,
		{"crew_ai": false, "ai_teammates": 0})
	if rt == null:
		_say("%s: launch failed" % name)
		return []
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = 55.0
	await _seconds(2.0)
	rt.stealth.raise_alarm(&"d145_wave_review")
	var dir: AssaultDirector = rt.service(G.SVC_DIRECTOR) as AssaultDirector
	var t0: float = Time.get_ticks_msec() / 1000.0
	var waited: float = 0.0
	while waited < WAIT_S and (dir == null or dir.alive_count() < WANT_UNITS):
		await _seconds(2.0)
		waited += 2.0
	var units: Array[NpcBase] = dir.alive_units() if dir != null else ([] as Array[NpcBase])
	_say("%s: %d director units after %.0f s game (%.0f s wall)" % [name, units.size(), waited,
		Time.get_ticks_msec() / 1000.0 - t0])
	var duty: int = 0
	for u: NpcBase in units:
		var look: String = NpcVisuals.character_id(u)
		duty += 1 if look.ends_with("_duty") else 0
		_say("%s: %s look %s at %s" % [name, u.enemy_def.id if u.enemy_def != null else &"-", look, u.global_position])
	_say("%s: %d of %d units wear a _duty look" % [name, duty, units.size()])
	for cl: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	_cam.current = true
	var imgs: Array[Image] = []
	if not units.is_empty():
		var c: Vector3 = Vector3.ZERO
		for u: NpcBase in units:
			c += u.global_position
		c /= units.size()
		var first: NpcBase = units[0]
		var away: Vector3 = (first.global_position - c)
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3(0, 0, 1)
		imgs.append(await _shot("%s_group" % name, c + away * 7.0 + Vector3(0, 2.2, 0), c + Vector3(0, 1.0, 0)))
		for i: int in mini(CLOSEUPS, units.size()):
			var u: NpcBase = units[i]
			var fwd: Vector3 = -u.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3(0, 0, 1)
			var at: Vector3 = u.global_position + Vector3(0, 1.25, 0)
			imgs.append(await _shot("%s_unit%d" % [name, i], at + fwd * 2.4 + Vector3(0, 0.25, 0), at))
	rt.teardown()
	_cam.queue_free()
	for _i: int in 5:
		await get_tree().process_frame
	return imgs


func _shot(name: String, eye: Vector3, at: Vector3) -> Image:
	_cam.look_at_from_position(eye, at)
	for _i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/d145_wave_%s.png" % [_out, name])
	return img


func _sheet(rows: Array[Array]) -> void:
	var cols: int = 0
	for r: Array in rows:
		cols = maxi(cols, r.size())
	if cols == 0:
		return
	var w: int = 480
	var h: int = 270
	var sheet: Image = Image.create(w * cols, h * rows.size(), false, Image.FORMAT_RGB8)
	for y: int in rows.size():
		for x: int in (rows[y] as Array).size():
			var img: Image = ((rows[y] as Array)[x] as Image).duplicate() as Image
			img.resize(w, h, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(x * w, y * h))
	sheet.save_png("%s/d145_wave_sheet.png" % _out)


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, true, true).timeout


func _say(s: String) -> void:
	_log.append(s)
	print("[D145W] " + s)
