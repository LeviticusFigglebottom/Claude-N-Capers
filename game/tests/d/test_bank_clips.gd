## OF-D1: bank customer clips in the "humanoid" library (char_anim_humanoid, tools/blender/characters/_anim_bank.py):
## queue_idle / queue_idle_b / queue_idle_c (the variant group variants.queue_idle), counter_customer, check_desk_write.
## Companion of test_anims.gd (which counts these clips). Every clip is present, looped, within its frame budget with
## its events, the loops close, the root never moves, SOURCE.txt lists the group, the pick rule and the placement
## notes, the contact hands lie on the ledge / desk plane (HandL / HandR Socket heights at the documented contact
## frames, 1 cm), nothing goes through the counter or the desk, the queue variants have periods of their own and differ,
## and queue_idle_b holds the phone at the chest, screen to the face. Run after `godot --import`.
extends TestCase

const GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
## clip -> [frames, frame budget, events]
const CLIPS: Dictionary = {
	"queue_idle": [150, 150, {"watch": 100}],
	"queue_idle_b": [126, 150, {"look_up": 80}],
	"queue_idle_c": [138, 150, {"sigh": 34, "look_back": 84}],
	"counter_customer": [180, 180, {"slip_push": 48, "nod": 146}],
	"check_desk_write": [150, 150, {"look_up": 98}],
}
const GROUP: String = "queue_idle, queue_idle_b, queue_idle_c"
const QUEUE: Array[String] = ["queue_idle", "queue_idle_b", "queue_idle_c"]
## surface clips: the plane height (m) and the surface's near edge ahead of the root (m)
const SURFACES: Dictionary = {"counter_customer": [1.05, 0.30], "check_desk_write": [1.00, 0.25]}
const NOTES: Array[String] = ["queue_variants", "queue_spacing", "counter_customer_placement", "check_desk_placement",
	"bank_animdriver"]
## the socket must sit at its documented height above the plane within this (m)
const CONTACT_TOL: float = 0.01

var _root: Node3D = null
var _player: AnimationPlayer = null
var _skel: Skeleton3D = null


func before_all() -> void:
	var packed: PackedScene = load(GLB) as PackedScene
	if packed == null:
		return
	_root = packed.instantiate() as Node3D
	add_child(_root)
	_skel = _root.get_node_or_null("rig_humanoid/Skeleton3D") as Skeleton3D
	var found: Array[Node] = _root.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_player = found[0] as AnimationPlayer


func after_all() -> void:
	if _root != null:
		_root.queue_free()


func _ready_or_fail() -> bool:
	if _root == null or _player == null or _skel == null:
		fail("could not load %s with rig_humanoid/Skeleton3D and an AnimationPlayer (run godot --import first)" % GLB)
		return false
	return true


func _anim(clip: String) -> Animation:
	return _player.get_animation(StringName(clip)) if _player.has_animation(StringName(clip)) else null


func _source_lines() -> Dictionary:
	var lines: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(SOURCE).split("\n"):
		var i: int = line.find(":")
		if i > 0:
			lines[line.substr(0, i)] = line.substr(i + 1)
	return lines


func _check_rows() -> Dictionary:
	var out: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(SOURCE).split("\n"):
		var m: RegExMatch = RegEx.create_from_string("^check\\.\\d+: (\\w+): (.*)$").search(line)
		if m != null:
			out[m.get_string(1)] = m.get_string(2)
	return out


static func _num(row: String, key: String) -> float:
	var m: RegExMatch = RegEx.create_from_string(key + "=(-?[0-9.]+)").search(row)
	return m.get_string(1).to_float() if m != null else INF


## "basis x=(..) y=(..) z=(..) origin=(..)" (SOURCE.txt transform notation) -> Transform3D.
static func _parse_xform(text: String) -> Transform3D:
	var re: RegEx = RegEx.create_from_string("(x|y|z|origin)=\\(([^)]*)\\)")
	var v: Dictionary = {}
	for m: RegExMatch in re.search_all(text):
		var p: PackedStringArray = m.get_string(2).split(",")
		v[m.get_string(1)] = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if v.size() < 4:
		return Transform3D(Basis(), Vector3.INF)
	return Transform3D(Basis(v["x"], v["y"], v["z"]), v["origin"])


func _bone_xform(bone: String) -> Transform3D:
	return _skel.global_transform * _skel.get_bone_global_pose(_skel.find_bone(bone))


func _seek(clip: String, f: int) -> void:
	_player.play(StringName(clip))
	_player.seek(float(f) / 30.0, true)


## Every bone's position at frame `f` of `clip`.
func _snapshot(clip: String, f: int) -> Array[Vector3]:
	_seek(clip, f)
	var out: Array[Vector3] = []
	for b: int in range(_skel.get_bone_count()):
		out.append((_skel.global_transform * _skel.get_bone_global_pose(b)).origin)
	_player.stop()
	return out


func _rot_snapshot(clip: String, f: int) -> Array[Quaternion]:
	_seek(clip, f)
	var out: Array[Quaternion] = []
	for b: int in range(_skel.get_bone_count()):
		out.append(_skel.get_bone_global_pose(b).basis.get_rotation_quaternion())
	_player.stop()
	return out


## "contact.<clip>: plane=1.050 HandL=-0.0010@0-180 HandR=+0.0005@0-90,135-180 (...)" -> {plane, sides {L: [dy, spans]}}
static func _parse_contact(text: String) -> Dictionary:
	var out: Dictionary = {"plane": _num(text, "plane"), "sides": {}}
	var re: RegEx = RegEx.create_from_string("Hand([LR])=([-+0-9.]+)@([0-9,\\-]+)")
	for m: RegExMatch in re.search_all(text):
		var spans: Array = []
		for s: String in m.get_string(3).split(","):
			var ab: PackedStringArray = s.split("-")
			spans.append([int(ab[0]), int(ab[1])])
		out["sides"][m.get_string(1)] = [m.get_string(2).to_float(), spans]
	return out


func test_clips_present_with_source_group_and_notes() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	assert_eq(String(lines.get("variants.queue_idle", "")).strip_edges(), GROUP, "SOURCE variants.queue_idle")
	var rule: String = String(lines.get("queue_variants", ""))
	assert_true(rule.contains("hash") and rule.contains("random offset"), "SOURCE queue_variants: the pick rule")
	for n: String in NOTES:
		assert_true(String(lines.get(n, "")).length() > 40, "SOURCE %s" % n)
	assert_true(String(lines.get("bank_animdriver", "")).contains("check_desk_write"), "SOURCE bank_animdriver: the mapping")
	var periods: Array[int] = []
	for clip: String in CLIPS:
		var spec: Array = CLIPS[clip]
		var a: Animation = _anim(clip)
		assert_true(a != null, "OF-D1 clip %s" % clip)
		if a == null:
			continue
		var n: int = int(spec[0])
		assert_true(n <= int(spec[1]), "%s: %d f within its %d f budget" % [clip, n, spec[1]])
		assert_near(a.length, float(n) / 30.0, 0.002, "%s length" % clip)
		assert_eq(a.loop_mode, Animation.LOOP_LINEAR, "%s loops" % clip)
		var row: String = String(lines.get("clip." + clip, ""))
		assert_true(row.begins_with(" %df loop=True speed_mps=0.0" % n), "SOURCE clip.%s: %s" % [clip, row])
		var ev: Dictionary = spec[2]
		for e: String in ev:
			assert_true(row.contains("%s@%d" % [e, int(ev[e])]), "%s: event %s@%d" % [clip, e, int(ev[e])])
		if QUEUE.has(clip):
			assert_true(row.contains("variant_of=queue_idle"), "SOURCE clip.%s: variant_of" % clip)
			assert_false(periods.has(n), "%s: a loop period of its own (%d f)" % [clip, n])
			periods.append(n)


func test_loops_close_and_root_fixed() -> void:
	if not _ready_or_fail():
		return
	var root_bone: int = _skel.find_bone("root")
	for clip: String in CLIPS:
		var a: Animation = _anim(clip)
		if a == null:
			continue
		var n: int = int(CLIPS[clip][0])
		var first: Array[Vector3] = _snapshot(clip, 0)
		var d: float = 0.0
		var last: Array[Vector3] = _snapshot(clip, n)
		for i: int in range(first.size()):
			d = maxf(d, first[i].distance_to(last[i]))
		assert_true(d < 0.002, "%s: the loop closes (%f m)" % [clip, d])
		for t: int in range(a.get_track_count()):
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D or a.track_get_key_count(t) < 2:
				continue
			var q0: Quaternion = a.track_get_key_value(t, 0)
			var q1: Quaternion = a.track_get_key_value(t, a.track_get_key_count(t) - 1)
			assert_true(absf(q0.dot(q1)) > 0.9999, "%s: %s first == last" % [clip, a.track_get_path(t)])
		var drift: float = 0.0
		var hips_off: float = 0.0
		var lowest: float = 1.0
		for f: int in range(0, n + 1, 6):
			var snap: Array[Vector3] = _snapshot(clip, f)
			if root_bone >= 0:
				drift = maxf(drift, snap[root_bone].distance_to(first[root_bone]))
			var hp: Vector3 = snap[_skel.find_bone("hips")]
			hips_off = maxf(hips_off, Vector2(hp.x, hp.z).length())
			for p: Vector3 in snap:
				lowest = minf(lowest, p.y)
		assert_true(drift < 0.001, "%s: the root never moves (%f m)" % [clip, drift])
		assert_true(hips_off < 0.12, "%s: in place, the hips over the root (%f m)" % [clip, hips_off])
		assert_true(lowest > -0.005, "%s: no joint below the floor (%f)" % [clip, lowest])


## The contact hands lie on the ledge / desk plane: HandL / HandR Socket (the hand bone * the SOURCE socket offset) at its
## documented height above the plane within 1 cm over the documented contact frames; a flat palm's socket is on the plane
## itself; the source skin measures agree (hand_gap) and nothing goes through the surface.
func test_hands_on_the_surfaces() -> void:
	if not _ready_or_fail():
		return
	var lines: Dictionary = _source_lines()
	var checks: Dictionary = _check_rows()
	var sockets: Dictionary = {"L": _parse_xform(String(lines.get("handl_shield_offset_godot", ""))),
		"R": _parse_xform(String(lines.get("handr_weapon_offset_godot", "")))}
	for clip: String in SURFACES:
		if _anim(clip) == null:
			continue
		var plane: float = float(SURFACES[clip][0])
		var c: Dictionary = _parse_contact(String(lines.get("contact." + clip, "")))
		assert_near(float(c["plane"]), plane, 0.0005, "SOURCE contact.%s: plane" % clip)
		assert_eq((c["sides"] as Dictionary).size(), 2, "SOURCE contact.%s: both hands" % clip)
		assert_true(absf(float(c["sides"].get("L", [1.0])[0])) <= CONTACT_TOL, "%s: the flat left palm's socket on the plane" % clip)
		var row: String = String(checks.get(clip, ""))
		assert_true(absf(_num(row, "hand_gap")) <= 10.0, "%s: the palm skin on the plane in the source (%s)" % [clip, row])
		assert_true(_num(row, "through") <= 3.0, "%s: nothing through the surface (%s)" % [clip, row])
		assert_true(_num(row, "forearm_gap") >= -3.0, "%s: the forearms on, not in, the surface (%s)" % [clip, row])
		for sfx: String in c["sides"]:
			var dy: float = float(c["sides"][sfx][0])
			var worst: float = 0.0
			var samples: int = 0
			for span: Array in c["sides"][sfx][1]:
				for f: int in range(int(span[0]), int(span[1]) + 1, 6):
					_seek(clip, f)
					var y: float = (_bone_xform("hand." + sfx) * sockets[sfx]).origin.y
					worst = maxf(worst, absf(y - plane - dy))
					samples += 1
			_player.stop()
			assert_true(samples >= 10, "%s Hand%s: contact frames sampled (%d)" % [clip, sfx, samples])
			assert_true(worst <= CONTACT_TOL, "%s Hand%s/Socket at %+.3f m above the plane (worst off %f m)" % [clip, sfx, dy, worst])
	var counter: String = String(checks.get("counter_customer", ""))
	assert_true(_num(counter, "front") < float(SURFACES["counter_customer"][1]),
		"counter_customer: the body below the ledge stays behind the counter face (%s)" % counter)
	# check_desk_write: the writing hand keeps its socket a few cm up (on its little-finger edge), not in the desk
	var w: Dictionary = _parse_contact(String(lines.get("contact.check_desk_write", "")))
	assert_true(absf(float(w["sides"].get("R", [1.0])[0])) < 0.06, "check_desk_write: the writing hand at the desk")


## queue_idle_b: the phone (phone_grip at HandR/Socket) at the chest, in front, the screen toward the face.
func test_queue_phone_in_hand() -> void:
	if not _ready_or_fail() or _anim("queue_idle_b") == null:
		return
	var lines: Dictionary = _source_lines()
	var socket: Transform3D = _parse_xform(String(lines.get("handr_weapon_offset_godot", "")))
	var grip: Transform3D = _parse_xform(String(lines.get("phone_grip", "")))
	assert_true(grip.origin.is_finite(), "SOURCE phone_grip")
	var look_up: int = int(CLIPS["queue_idle_b"][2]["look_up"])
	_player.play(&"queue_idle_b")
	for f: int in range(0, 127, 6):
		_player.seek(float(f) / 30.0, true)
		var ph: Transform3D = _bone_xform("hand.R") * socket * grip
		var head: Vector3 = _bone_xform("head").origin
		assert_true(ph.origin.y > 0.95 and ph.origin.y < 1.35 and ph.origin.z < -0.12,
			"queue_idle_b f%d: the phone in front of the chest (%s)" % [f, ph.origin])
		if absi(f - look_up) > 24:
			assert_true(ph.basis.z.normalized().dot((head - ph.origin).normalized()) > 0.7, "queue_idle_b f%d: screen to the face" % f)
	_player.stop()


func test_queue_variants_differ() -> void:
	if not _ready_or_fail():
		return
	for i: int in range(QUEUE.size()):
		for j: int in range(i + 1, QUEUE.size()):
			if _anim(QUEUE[i]) == null or _anim(QUEUE[j]) == null:
				continue
			var diff: float = 0.0
			for f: int in [10, 40, 70, 100]:
				var a: Array[Quaternion] = _rot_snapshot(QUEUE[i], f)
				var b: Array[Quaternion] = _rot_snapshot(QUEUE[j], f)
				for k: int in range(a.size()):
					diff = maxf(diff, rad_to_deg(2.0 * acos(minf(1.0, absf(a[k].dot(b[k]))))))
			assert_true(diff > 20.0, "%s and %s differ visibly (max bone %f deg)" % [QUEUE[i], QUEUE[j], diff])
