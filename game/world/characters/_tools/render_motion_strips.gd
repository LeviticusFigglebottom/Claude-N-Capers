## PO "largely inorganic" follow-up: in-motion frame strips from a real loud heist (AnimDriver as the game drives it),
## for characters v1.25 (gait-locked crew holds) and v1.26 (police aim on the move, stagger). The whole crew is AI
## (heister bodies, as loud_anim_coverage); the alarm goes up and the tool watches every crew body and police unit
## until it sees each case, then follows that body for STRIP_N frames, STEP_S apart, from the side:
##   crew_sprint: a crew body on sprint / run with its hold_<kind>_<gait> layer
##   crew_strafe: a crew body on strafe_* / walk_* (8-way) with a hold_* or aim_* layer
##   cop_run_gun: a police unit on run* / walk* with an aim_<fam>_<gait> layer (aiming while moving)
##   cop_stagger: a small real explosion (Explosion.apply, 1 dmg) beside a police unit: stagger_<fam>
## Each tile's label is the base clip / the layer clip @ its time / the horizontal speed; the log has every frame.
## Writes <out>/<case>.png (strip, 2 rows) and <out>/motion_log.txt.
##   xvfb-run -a -s "-screen 0 960x540x24" /opt/godot/godot --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 960x540 --path game res://world/characters/_tools/render_motion_strips.tscn -- --out=/abs/dir \
##     [--heist=glasshouse] [--seed=7] [--difficulty=0] [--wait=300] [--cases=crew_strafe,cop_stagger,cop_look_1..4]
## Owner: ENV D.
extends Node3D

const CASES: Array[String] = ["crew_sprint", "crew_strafe", "cop_run_gun", "cop_stagger"]
const STRIP_N: int = 12
const STEP_S: float = 0.1
const TILE: Vector2i = Vector2i(320, 270)
const CAM_DIST: float = 3.6
const LEAD_M: float = 12.0

var _out: String = ""
var _heist: String = "glasshouse"
var _seed: int = 7
var _difficulty: int = Enums.Difficulty.ROUTINE
var _wait: float = 300.0
var _cam: Camera3D = null
var _label: Label = null
var _log: PackedStringArray = []
var _done: Dictionary = {}
var _rt: HeistRuntime = null
## the cases to shoot (--cases=crew_strafe,...; default all)
var _cases: Array[String] = CASES.duplicate()
var _home: Vector3 = Vector3.INF
## looks already stripped by a cop_look_<n> case
var _looks: Dictionary = {}
var _legs: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": _out = v
			"heist": _heist = v
			"seed": _seed = int(v)
			"difficulty": _difficulty = int(v)
			"wait": _wait = float(v)
			"cases":
				_cases.clear()
				for c: String in v.split(","):
					_cases.append(c)
	if _out == "":
		_out = OS.get_user_data_dir() + "/motion_strips"
	RenderingServer.render_loop_enabled = false  # frames only for the strips (llvmpipe)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var heisters: Array = Tweak.crew().body_scenes.keys()
	heisters.sort()
	var loadouts: Dictionary = {}
	for slot: int in 3:
		var l: Loadout = CrewWeapons.build_loadout(null).duplicate() as Loadout
		l.heister = StringName(heisters[slot % heisters.size()]) if not heisters.is_empty() else &""
		loadouts[slot] = l
	_rt = await HeistLauncher.launch(StringName(_heist), _seed, _difficulty, self,
		{"ai_teammates": 2, "crew_ai": true, "loadouts": loadouts})
	if _rt == null:
		push_error("[MOTION] launch failed")
		get_tree().quit(1)
		return
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = 50.0
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8, 6)
	_label.add_theme_font_size_override(&"font_size", 26)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 7)
	layer.add_child(_label)
	await _seconds(1.0)
	_rt.stealth.raise_alarm(&"d_motion_strips")
	var t: float = 0.0
	var stagger_tried: int = 0
	while t < _wait and _done.size() < _cases.size():
		await _seconds(STEP_S)
		t += STEP_S
		for cl: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if cl != layer:
				(cl as CanvasLayer).visible = false
		_cam.current = true
		for c: String in _cases:
			if _done.has(c) or c == "cop_stagger":
				continue
			var body: Node3D = _find(c)
			if body != null:
				_say("t=%.1f %s on %s" % [t, c, _who(body)])
				await _strip(c, body)
				_done[c] = true
				_looks[_look(body)] = true
				break
		if int(t * 10.0) % 100 == 0:
			_crew_diag(t)
		if int(t * 10.0) % 60 == 0 and (not _done.has("crew_sprint") or not _done.has("crew_strafe")):
			_lead_off(t)
		if _cases.has("cop_stagger") and not _done.has("cop_stagger") and t > 20.0 and stagger_tried < 5 and int(t * 10.0) % 50 == 0:
			stagger_tried += 1
			await _stagger()
	for c: String in _cases:
		if not _done.has(c):
			_say("MISSING %s: not seen in %.0f s" % [c, _wait])
	var f: FileAccess = FileAccess.open("%s/motion_log.txt" % _out, FileAccess.WRITE)
	f.store_string("\n".join(_log) + "\n")
	f.close()
	print("[MOTION] RESULT DONE %d/%d %s" % [_done.size(), _cases.size(), _out])
	get_tree().quit(0)


## A body showing case `c` right now, or null.
func _find(c: String) -> Node3D:
	var bodies: Array[Node3D] = []
	if c.begins_with("crew_"):
		for m: CrewController in _rt.crew_members():
			bodies.append(m)
	else:
		for n: Node in _rt.npcs():
			var npc: NpcBase = n as NpcBase
			if npc != null and npc.alive and npc.role != &"civilian" and npc.enemy_def != null:
				bodies.append(npc)
	for b: Node3D in bodies:
		var ad: AnimDriver = AnimDriver.of(b)
		if ad == null or ad.hold_layer == null or not ad.hold_layer.active:
			continue
		var base: String = String(ad.clip)
		var lay: String = String(ad.hold_layer.clip)
		var ok: bool = false
		match c:
			"crew_sprint":
				ok = (base == "sprint" or base == "run") and lay.begins_with("hold_") and (lay.ends_with("_sprint")
					or lay.ends_with("_run"))
			"crew_strafe":
				ok = (base.begins_with("strafe_") or base.begins_with("walk_")) and (lay.begins_with("hold_")
					or lay.begins_with("aim_"))
			"cop_run_gun":
				ok = (base.begins_with("run") or base.begins_with("walk")) and lay.begins_with("aim_") \
					and (lay.ends_with("_run") or lay.ends_with("_walk"))
			_:
				# cop_look_<n>: any police unit on a run clip (aiming or not), one strip per distinct look (v1.37 roster)
				ok = c.begins_with("cop_look_") and base.begins_with("run") and not _looks.has(_look(b))
		if ok and ad.horizontal_speed() > 0.5:
			return b
	return null


## A 1-damage explosion 1.2 m beside the nearest live police unit in the open; strips it when it staggers.
func _stagger() -> void:
	var crew: Array[CrewController] = _rt.crew_members()
	var attacker: int = crew[0].net_id if not crew.is_empty() else 0
	for n: Node in _rt.npcs():
		var npc: NpcBase = n as NpcBase
		if npc == null or not npc.alive or npc.role == &"civilian" or npc.enemy_def == null:
			continue
		var ad: AnimDriver = AnimDriver.of(npc)
		if ad == null or ad.combat == null or ad.combat.stagger_clip() == &"":
			continue
		var side: Vector3 = npc.global_basis.x.normalized()
		Explosion.apply(self, npc.global_position + side * 1.2 + Vector3.UP * 0.3, 2.0, 1.0, attacker)
		await get_tree().physics_frame
		await get_tree().process_frame
		if String(ad.clip).begins_with("stagger_") or String(ad._oneshot).begins_with("stagger_"):
			_say("cop_stagger on %s" % _who(npc))
			await _strip("cop_stagger", npc)
			_done["cop_stagger"] = true
		else:
			_say("explosion beside %s: clip %s, no stagger" % [_who(npc), ad.clip])
		return


func _strip(c: String, body: Node3D) -> void:
	var tiles: Array[Image] = []
	for k: int in STRIP_N:
		if not is_instance_valid(body):
			break
		var ad: AnimDriver = AnimDriver.of(body)
		var fwd: Vector3 = -body.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		var at: Vector3 = body.global_position + Vector3.UP * 1.0
		var eye: Vector3 = _eye(body, at, fwd)
		var info: String = "%s | %s @%.2f | %.1f m/s" % [ad.clip, ad.hold_layer.clip if ad.hold_layer != null else &"-",
			ad.hold_layer.time if ad.hold_layer != null else 0.0, ad.horizontal_speed()]
		_label.text = "%s %d  %s\n%s" % [c, k, _look(body), info]
		_say("%s f%d %s" % [c, k, info])
		_cam.look_at_from_position(eye, at)
		RenderingServer.render_loop_enabled = true
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		RenderingServer.render_loop_enabled = false
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var w: int = img.get_height() * TILE.x / TILE.y
		tiles.append(img.get_region(Rect2i((img.get_width() - w) / 2, 0, w, img.get_height())))
		await _seconds(STEP_S)
	var cols: int = STRIP_N / 2
	var sheet: Image = Image.create(TILE.x * cols, TILE.y * 2, false, Image.FORMAT_RGB8)
	for k: int in tiles.size():
		tiles[k].resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(tiles[k], Rect2i(Vector2i.ZERO, TILE), Vector2i((k % cols) * TILE.x, (k / cols) * TILE.y))
	sheet.save_png("%s/%s.png" % [_out, c])


## The camera spot for `body`: the side three-quarter view first, then 7 more directions round it; the one with the
## most clear room (rays from the chest and the head), so a wall or counter is never between the camera and the body.
func _eye(body: Node3D, at: Vector3, fwd: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var base: Vector3 = (Vector3(-fwd.z, 0.0, fwd.x) * 0.85 + fwd * 0.5).normalized()
	var best: float = -1.0
	var eye: Vector3 = at + base * CAM_DIST + Vector3.UP * 0.35
	for k: int in 8:
		var dir: Vector3 = base.rotated(Vector3.UP, k * PI / 4.0)
		var room: float = CAM_DIST
		for from: Vector3 in [at, at + Vector3.UP * 0.6]:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from,
				from + dir * CAM_DIST + Vector3.UP * 0.35)
			if body is CollisionObject3D:
				q.exclude = [(body as CollisionObject3D).get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				room = minf(room, from.distance_to(hit["position"]) - 0.2)
		if room > best + 0.25:
			best = room
			eye = at + dir * maxf(room, 1.2) + Vector3.UP * 0.35
	return eye


## The bots follow the player body: move it (slot 0, first person, no third-person driver) to a nav point
## LEAD_M away, alternating directions, so they run / sprint after it with their weapons out.
func _lead_off(t: float) -> void:
	var crew: Array[CrewController] = _rt.crew_members()
	if crew.is_empty():
		return
	var lead: CrewController = crew[0]
	if _home == Vector3.INF:
		_home = lead.global_position
	var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, _legs * 2.4)
	_legs += 1
	var want: Vector3 = _home + dir * LEAD_M if _legs % 2 == 1 else _home
	var p: Vector3 = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, want)
	lead.global_position = p + Vector3.UP * 0.05
	_say("t=%.0f lead to %s" % [t, p])


## Every crew body's clip / layer / speed (why a crew case is not seen).
func _crew_diag(t: float) -> void:
	for m: CrewController in _rt.crew_members():
		var ad: AnimDriver = AnimDriver.of(m)
		if ad == null:
			_say("diag t=%.0f %s no AnimDriver" % [t, m.name])
			continue
		_say("diag t=%.0f %s ai %s clip %s layer %s active %s speed %.1f state %s" % [t, m.name, m.is_ai, ad.clip,
			ad.hold_layer.clip if ad.hold_layer != null else &"-", ad.hold_layer.active if ad.hold_layer != null else false,
			ad.horizontal_speed(), m.crew_state])


func _look(b: Node3D) -> String:
	return NpcVisuals.character_id(b as NpcBase) if b is NpcBase else String(b.name)


func _who(b: Node3D) -> String:
	var ad: AnimDriver = AnimDriver.of(b)
	return "%s (%s) clip %s layer %s at %s" % [b.name, _look(b), ad.clip, ad.hold_layer.clip, b.global_position]


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, true, true).timeout


func _say(s: String) -> void:
	_log.append(s)
	print("[MOTION] " + s)
