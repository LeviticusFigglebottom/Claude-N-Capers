## D-165 windowed evidence: the Afterhours cast in place on C's map under the real ClubLights. Launches the heist,
## shoots two wide views in stealth (state &"club": the hall from the DJ booth, the foyer from the street door) and up to
## PER_TAG NPCs of every spawn tag from in front (label: look, clip, spawn tags), then raises the alarm (the mission puts
## ClubLights to &"house") and shoots the two wide views again before the crowd has moved. Composes a contact sheet and
## logs every NPC with its look, clip, spawn tags and position. PNGs, sheet and log go to --out.
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 60 \
##     --resolution 960x540 \
##     --path game res://world/characters/_tools/render_ah_cast_review.tscn -- --out=/abs/dir [--seed=1] [--difficulty=0]
## Owner: ENV D.
extends Node3D

const COLS: int = 4
const THUMB: Vector2i = Vector2i(480, 270)
const EYE_DIST: float = 2.6
const EYE_H: float = 1.45
## NPC close-ups per spawn tag (the pools deal different looks; two show the variety without shooting the whole crowd)
const PER_TAG: int = 2
## the booth view: this high above the DJ booth's origin, looking at the dancers' centroid
const BOOTH_EYE_H: float = 2.6

var _out: String = ""
var _seed: int = 1
var _difficulty: int = Enums.Difficulty.ROUTINE
var _cam: Camera3D = null
var _label: Label = null
var _log: PackedStringArray = []
var _shots: Array[String] = []
## the wide views' [eye, target] from the stealth phase, reused after the alarm (the crowd starts to move) so the two
## lighting states frame the same shot
var _views: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--seed="):
			_seed = int(a.trim_prefix("--seed="))
		elif a.begins_with("--difficulty="):
			_difficulty = int(a.trim_prefix("--difficulty="))
	if _out == "":
		_out = OS.get_user_data_dir() + "/ah_cast"
	RenderingServer.render_loop_enabled = false  # frames only for the shots (llvmpipe draws this map slowly)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var rt: HeistRuntime = await HeistLauncher.launch(&"afterhours", _seed, _difficulty, self,
		{"crew_ai": false, "ai_teammates": 0})
	if rt == null:
		push_error("[AHCAST] launch failed")
		get_tree().quit(1)
		return
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = 60.0
	_cam.current = true
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8, 6)
	_label.add_theme_font_size_override(&"font_size", 20)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)
	await _ticks(90)
	var map: Node = rt.get_parent() if rt.get_parent() != null else get_tree().root
	_say("seed %d difficulty %d lights %s" % [_seed, _difficulty, _lights_state()])
	var npcs: Array[NpcBase] = []
	for n: Node in rt.npcs():
		var npc: NpcBase = n as NpcBase
		if npc != null and npc.visible:
			npcs.append(npc)
			_log_npc(npc)
	await _wide_views(map, npcs, "stealth")
	var per_tag: Dictionary = {}
	var i: int = 0
	for npc: NpcBase in npcs:
		var tags: Array = npc.spawn_info.get("tags", [])
		var key: String = str(tags[0]) if not tags.is_empty() else String(npc.role)
		if int(per_tag.get(key, 0)) >= PER_TAG:
			continue
		per_tag[key] = int(per_tag.get(key, 0)) + 1
		i += 1
		await _npc_shot("cast_%02d_%s" % [i, key], npc)
	if rt.mission != null:
		rt.mission.raise_alarm(&"cast_review")
		await _ticks(20)
		_say("alarm raised, lights %s" % _lights_state())
		await _wide_views(map, npcs, "loud")
	_sheet()
	_finish()


## The hall from above the DJ booth (towards the dancers) and the foyer from the player's entry spot (towards the door
## team), each from the map's own markers.
func _wide_views(map: Node, npcs: Array[NpcBase], phase: String) -> void:
	if _views.is_empty():
		var booth: Node3D = map.find_child("DJBooth", true, false) as Node3D
		var dancers: Vector3 = _centroid(npcs, [&"civ_dancer"])
		if booth != null and dancers != Vector3.INF:
			_views["hall_from_booth"] = [booth.global_position + Vector3.UP * BOOTH_EYE_H, dancers + Vector3.UP]
		# the ground-floor door team only (the rope bouncer stands on the balcony, 4.2 m up)
		var foyer: Node3D = map.find_child("PlayerFoyer1", true, false) as Node3D
		var door: Vector3 = _centroid(npcs, [&"guard_door", &"civ_box_office"])
		if foyer != null and door != Vector3.INF:
			_views["foyer"] = [foyer.global_position + Vector3.UP * 1.65, door + Vector3.UP * 1.2]
	for view: String in _views:
		_label.text = "%s: %s" % [phase, view.replace("_", " ")]
		await _shot("%s_%s" % [phase, view], _views[view][0], _views[view][1])


func _centroid(npcs: Array[NpcBase], tags: Array[StringName]) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for npc: NpcBase in npcs:
		for t: Variant in npc.spawn_info.get("tags", []):
			if tags.has(StringName(t)):
				sum += npc.global_position
				n += 1
				break
	return sum / float(n) if n > 0 else Vector3.INF


func _lights_state() -> String:
	var cl: Node = get_tree().root.find_child("ClubLights", true, false)
	return str(cl.get("state")) if cl != null else "-"


func _log_npc(npc: NpcBase) -> void:
	var tags: Variant = npc.spawn_info.get("tags", [])
	_say("%s role %s tags %s activity %s look %s clip %s at (%.2f, %.2f, %.2f) facing %.0f" % [npc.name, npc.role, tags,
		npc.spawn_info.get("idle_activity", ""), NpcVisuals.character_id(npc), _clip(npc), npc.global_position.x,
		npc.global_position.y, npc.global_position.z, rad_to_deg(npc.global_rotation.y)])


func _npc_shot(name: String, npc: NpcBase, dist: float = EYE_DIST) -> void:
	var fwd: Vector3 = -npc.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var at: Vector3 = npc.global_position + Vector3.UP * 0.9
	# the front three-quarter first, then the other 7 directions: the one with the most clear room (a bar back or a
	# booth right behind the camera would cramp the frame)
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
	_label.text = "%s  %s\n%s  %s" % [name, NpcVisuals.character_id(npc), _clip(npc), str(npc.spawn_info.get("tags", []))]
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
	sheet.save_png("%s/ah_cast_sheet.png" % _out)
	_say("sheet ah_cast_sheet.png %d shots" % _shots.size())


func _finish() -> void:
	var f: FileAccess = FileAccess.open("%s/ah_cast_log.txt" % _out, FileAccess.WRITE)
	if f == null:
		push_error("[AHCAST] could not write the log (%s)" % error_string(FileAccess.get_open_error()))
	else:
		f.store_string("\n".join(_log) + "\n")
		f.close()
	print("[AHCAST] RESULT DONE %s" % _out)
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
	print("[AHCAST] " + s)
