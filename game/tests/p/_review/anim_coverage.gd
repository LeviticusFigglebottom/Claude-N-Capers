## D-111 animation coverage (PO: "almost zero animations play"): rides along a playthrough (put on the root by
## anim_coverage_boot.gd before A's PO-5 runner, or by nd_stealth_pass.gd) and records, per body class, every clip
## actually playing, plus:
## - STATIC: a body (NPC / crew) with no AnimDriver or no AnimationPlayer (placeholder / T-pose: never animates);
## - SLIDE: moving > 0.5 m/s for > 0.5 s while the clip is not a locomotion clip (idle / aim / none);
## - NO_CLIP: an interaction by a crew member whose body shows no interact / action clip within 0.6 s
##   (lockpick, bag, cuff, revive, drill place...);
## - FP: every first-person viewmodel clip (FpViewmodel.clip) of the local player.
## Writes <out>/anim_coverage.json every 10 s and at exit (counts in seconds of playtime per clip per class) and
## prints "[ANIM] ..." lines for STATIC / SLIDE / NO_CLIP. Never touches game state. Owner: ENV P.
extends Node

const LOCOMOTION_PREFIXES: PackedStringArray = ["walk", "run", "sprint", "crouch_walk", "strafe", "flee", "carry",
	"shield_walk", "dozer_walk", "jog"]
const SLIDE_MPS: float = 0.5
const SLIDE_S: float = 0.5

var _out: String = ""
## class -> clip -> seconds seen
var _seen: Dictionary = {}
## class -> number of distinct bodies
var _bodies: Dictionary = {}
var _static: Dictionary = {}
var _slides: Dictionary = {}
var _no_clip: Dictionary = {}
var _slide_t: Dictionary = {}
var _last_pos: Dictionary = {}
var _known: Dictionary = {}
var _pending_interact: Array[Dictionary] = []
var _flush_t: float = 0.0
var _rt: HeistRuntime = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--anim-out="):
			_out = a.substr(11)
	if _out == "":
		_out = OS.get_user_data_dir() + "/anim_coverage"
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.interaction_started.connect(_on_interaction_started)
	tree_exiting.connect(_flush)


func _class_of(body: Node) -> String:
	var npc: NpcBase = body as NpcBase
	if npc != null:
		var def_id: String = String(npc.enemy_def.id) if npc.enemy_def != null else ""
		return "npc:%s%s" % [npc.role, (":" + def_id) if def_id != "" else ""]
	var c: CrewController = body as CrewController
	if c != null:
		return "crew_ai" if c.is_ai else ("crew_local" if c.is_local() else "crew_remote")
	return "other"


func _process(delta: float) -> void:
	var rt: HeistRuntime = HeistRuntime.current()
	if rt != _rt:
		_rt = rt
		_last_pos.clear()
		_slide_t.clear()
	if _rt == null or not is_instance_valid(_rt):
		return
	for n: Node in _rt.npcs():
		_sample(n as Node3D, delta)
	for c: CrewController in _rt.crew_members():
		if not c.is_local():
			_sample(c, delta)
		else:
			_sample_fp(c, delta)
	_check_interactions(delta)
	_flush_t += delta
	if _flush_t >= 10.0:
		_flush_t = 0.0
		_flush()


func _sample(body: Node3D, delta: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var cls: String = _class_of(body)
	var id: int = body.get_instance_id()
	if not _known.has(id):
		_known[id] = true
		_bodies[cls] = int(_bodies.get(cls, 0)) + 1
	var drv: AnimDriver = body.get_node_or_null(AnimDriver.NODE_NAME) as AnimDriver
	var clip: StringName = &""
	if drv == null or drv.player == null:
		if not _static.has(id):
			_static[id] = cls
			print("[ANIM] STATIC %s %s: no %s" % [cls, body.name, "AnimDriver" if drv == null else "AnimationPlayer"])
		clip = &"<none>"
	else:
		clip = drv.clip if drv.clip != &"" else &"<none>"
	_add(cls, String(clip), delta)
	# slide check
	var p: Vector3 = body.global_position
	var lp: Vector3 = _last_pos.get(id, p)
	_last_pos[id] = p
	var speed: float = Vector2(p.x - lp.x, p.z - lp.z).length() / maxf(delta, 1e-4)
	var loco: bool = false
	for pre: String in LOCOMOTION_PREFIXES:
		if String(clip).begins_with(pre):
			loco = true
	if speed > SLIDE_MPS and not loco and speed < 15.0:  # teleports excluded
		_slide_t[id] = float(_slide_t.get(id, 0.0)) + delta
		if float(_slide_t[id]) > SLIDE_S:
			var key: String = "%s|%s" % [cls, clip]
			if not _slides.has(key):
				print("[ANIM] SLIDE %s %s moving %.1f m/s on clip '%s'" % [cls, body.name, speed, clip])
			_slides[key] = int(_slides.get(key, 0)) + 1
			_slide_t[id] = -5.0  # one count per ~5 s per body
	elif float(_slide_t.get(id, 0.0)) > 0.0:
		_slide_t[id] = 0.0  # back on a locomotion clip / stopped: restart the window (a negative cooldown stays)


func _sample_fp(c: CrewController, delta: float) -> void:
	var view: CrewView = CrewView.of(c)
	if view == null or view.camera() == null:
		return
	var vm: FpViewmodel = FpViewmodel.of(view.camera())
	if vm == null or not view.viewmodel_visible():
		_add("fp", "<hidden>", delta)
		return
	_add("fp:%s" % vm.anim_set, String(vm.clip) if vm.clip != &"" else "<none>", delta)


func _add(cls: String, clip: String, dt: float) -> void:
	var m: Dictionary = _seen.get(cls, {})
	m[clip] = float(m.get(clip, 0.0)) + dt
	_seen[cls] = m


func _on_interaction_started(_id: int, slot: int, kind: StringName) -> void:
	_pending_interact.append({"slot": slot, "kind": kind, "left": 0.6, "hit": false})


func _check_interactions(delta: float) -> void:
	if _pending_interact.is_empty():
		return
	for k: int in range(_pending_interact.size() - 1, -1, -1):
		var e: Dictionary = _pending_interact[k]
		var c: CrewController = _rt.crew_controller(int(e["slot"])) as CrewController
		var clip: String = ""
		if c != null:
			if c.is_local():
				clip = "fp-local"  # the local player's own body is hidden; FP side: weapon lowered
			else:
				var drv: AnimDriver = c.get_node_or_null(AnimDriver.NODE_NAME) as AnimDriver
				clip = String(drv.clip) if drv != null else ""
		if clip == "fp-local" or clip.begins_with("interact") or clip.begins_with("pager") or clip.begins_with("kneel") \
				or clip.begins_with("revive") or clip.begins_with("cuff") or clip.begins_with("throw"):
			_pending_interact.remove_at(k)
			continue
		e["left"] = float(e["left"]) - delta
		if float(e["left"]) <= 0.0:
			var key: String = "%s|%s" % [e["kind"], clip]
			if not _no_clip.has(key):
				print("[ANIM] NO_CLIP interaction %s by slot %d shows clip '%s'" % [e["kind"], e["slot"], clip])
			_no_clip[key] = int(_no_clip.get(key, 0)) + 1
			_pending_interact.remove_at(k)


func _flush() -> void:
	var f: FileAccess = FileAccess.open(_out + "/anim_coverage.json", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"seen": _seen, "bodies": _bodies, "static": _static.values(),
		"slides": _slides, "no_clip": _no_clip}, "  "))
	f.close()
