## D1-03 / D-034: first-person arms rig `rig_arms` + the viewmodel sets (char_arms_fp).
## Checks the rig (root at the camera origin, contract arm/finger bones, weapon/magazine helper
## bones and the weapon grip offset), the mesh budget, every `<set>_<clip>` animation (present,
## loop mode, length, identical track layout), the clip lengths against the weapon data, the
## events listed in SOURCE.txt and the moving parts (magazine, sniper bolt hand, shotgun loop).
extends TestCase

const GLB: String = "res://assets/characters/char_arms_fp/char_arms_fp.glb"
const SOURCE: String = "res://assets/characters/char_arms_fp/SOURCE.txt"
const WEAPONS_DIR: String = "res://content/data/weapons"
const FPS: float = 30.0
const FINGERS: Array[String] = ["thumb", "index", "middle", "ring", "pinky"]
const SETS: Array[String] = ["pistol", "smg", "rifle", "shotgun", "lmg", "sniper"]
const COMMON: Array[String] = [
	"idle", "ads_idle", "draw", "holster", "fire", "fire_ads", "reload", "reload_empty", "sprint",
]
const LOOPED: Array[String] = ["idle", "ads_idle", "sprint"]
const EXTRA: Dictionary = {
	"shotgun": ["reload_start", "reload_loop", "reload_end", "reload_end_empty"],
	"sniper": ["bolt", "bolt_ads"],
}
## Events every clip of that kind must list in SOURCE.txt (per set where it differs).
const EVENTS: Dictionary = {
	"pistol_reload": ["mag_out", "mag_in", "done"],
	"pistol_reload_empty": ["mag_out", "mag_in", "slide_release", "done"],
	"smg_reload": ["mag_out", "mag_in", "done"],
	"smg_reload_empty": ["mag_out", "mag_in", "bolt_release", "done"],
	"rifle_reload": ["mag_out", "mag_in", "done"],
	"rifle_reload_empty": ["mag_out", "mag_in", "bolt_release", "done"],
	"shotgun_fire": ["shot", "pump_back", "pump_forward"],
	"shotgun_fire_ads": ["shot", "pump_back", "pump_forward"],
	"shotgun_reload_loop": ["shell_in"],
	"shotgun_reload_end_empty": ["pump_back", "pump_forward", "done"],
	"shotgun_reload": ["shell_in_1", "shell_in_6", "done"],
	"shotgun_reload_empty": ["shell_in_1", "shell_in_6", "pump_back", "pump_forward", "done"],
	"lmg_reload": ["cover_open", "mag_out", "mag_in", "belt_seat", "cover_close", "done"],
	"lmg_reload_empty": ["cover_open", "mag_out", "mag_in", "belt_seat", "cover_close", "charge", "done"],
	"sniper_bolt": ["bolt_open", "bolt_back", "bolt_forward", "bolt_close", "done"],
	"sniper_bolt_ads": ["bolt_open", "bolt_back", "bolt_forward", "bolt_close", "done"],
	"sniper_reload": ["mag_out", "mag_in", "done"],
	"sniper_reload_empty": ["mag_out", "mag_in", "bolt_open", "bolt_close", "done"],
}

var _root: Node3D = null
var _skel: Skeleton3D = null
var _player: AnimationPlayer = null
var _source: Dictionary = {}


func before_all() -> void:
	var packed: PackedScene = load(GLB) as PackedScene
	if packed == null:
		return
	_root = packed.instantiate() as Node3D
	add_child(_root)
	_skel = _root.get_node_or_null("rig_arms/Skeleton3D") as Skeleton3D
	var found: Array[Node] = _root.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_player = found[0] as AnimationPlayer
	var f: FileAccess = FileAccess.open(SOURCE, FileAccess.READ)
	if f != null:
		for line: String in f.get_as_text().split("\n"):
			var i: int = line.find(": ")
			if i > 0:
				_source[line.substr(0, i)] = line.substr(i + 2)


func after_all() -> void:
	if _root != null:
		_root.queue_free()


func _ready_or_fail() -> bool:
	if _root == null or _skel == null or _player == null:
		fail("could not load %s with rig_arms/Skeleton3D + AnimationPlayer (run godot --import first)" % GLB)
		return false
	return true


static func expected_bones() -> Array[String]:
	var out: Array[String] = ["root"]
	for s: String in ["L", "R"]:
		for b: String in ["clavicle", "upper_arm", "forearm", "hand"]:
			out.append("%s.%s" % [b, s])
		for f: String in FINGERS:
			for i: int in [1, 2, 3]:
				out.append("%s_0%d.%s" % [f, i, s])
	out.append("weapon")
	out.append("magazine")
	return out


static func clips_of(set_name: String) -> Array[String]:
	var out: Array[String] = []
	for c: String in COMMON:
		out.append(c)
	for c: Variant in EXTRA.get(set_name, []):
		out.append(String(c))
	return out


func _anim(name: String) -> Animation:
	if _player == null or not _player.has_animation(StringName(name)):
		return null
	return _player.get_animation(StringName(name))


func _parent(bone: String) -> String:
	var p: int = _skel.get_bone_parent(_skel.find_bone(bone))
	return _skel.get_bone_name(p) if p >= 0 else ""


func _track(a: Animation, bone: String, type: Animation.TrackType) -> int:
	for t: int in range(a.get_track_count()):
		if a.track_get_type(t) == type and String(a.track_get_path(t).get_concatenated_subnames()) == bone:
			return t
	return -1


func _track_layout(a: Animation) -> Array[String]:
	var out: Array[String] = []
	for t: int in range(a.get_track_count()):
		out.append("%s:%d" % [String(a.track_get_path(t).get_concatenated_subnames()), a.track_get_type(t)])
	out.sort()
	return out


## Largest distance a position track moves away from its first key.
func _pos_travel(a: Animation, bone: String) -> float:
	var t: int = _track(a, bone, Animation.TYPE_POSITION_3D)
	if t < 0:
		return 0.0
	var p0: Vector3 = a.track_get_key_value(t, 0)
	var best: float = 0.0
	for k: int in range(a.track_get_key_count(t)):
		best = maxf(best, (a.track_get_key_value(t, k) as Vector3).distance_to(p0))
	return best


func _weapon_times(set_name: String, field: String) -> Array[float]:
	var out: Array[float] = []
	var dir: DirAccess = DirAccess.open(WEAPONS_DIR)
	if dir == null:
		return out
	for fname: String in dir.get_files():
		if not fname.ends_with(".tres"):
			continue
		var def: Resource = load("%s/%s" % [WEAPONS_DIR, fname])
		if def == null or String(def.get("anim_set")) != set_name:
			continue
		var stats: Resource = def.get("base") as Resource
		if stats != null:
			out.append(float(stats.get(field)))
	return out


func test_bones_and_parents() -> void:
	if not _ready_or_fail():
		return
	var names: Array[String] = []
	for i: int in range(_skel.get_bone_count()):
		names.append(_skel.get_bone_name(i))
	assert_eq(names, expected_bones(), "rig_arms bone names and order")
	assert_eq(_parent("root"), "", "root has no parent")
	assert_eq(_parent("clavicle.L"), "root", "clavicle.L under root")
	assert_eq(_parent("clavicle.R"), "root", "clavicle.R under root")
	assert_eq(_parent("hand.R"), "forearm.R", "hand.R chain")
	assert_eq(_parent("index_01.L"), "hand.L", "fingers under the hand")
	assert_eq(_parent("weapon"), "hand.R", "weapon under hand.R")
	assert_eq(_parent("magazine"), "weapon", "magazine under weapon")


func test_root_is_the_camera_origin() -> void:
	if not _ready_or_fail():
		return
	var root_rest: Transform3D = _skel.get_bone_global_rest(_skel.find_bone("root"))
	assert_true(root_rest.origin.length() < 0.0001, "root bone at the origin")
	# shoulders are below and behind the eye; the right side is +X
	var sh_r: Vector3 = _skel.get_bone_global_rest(_skel.find_bone("upper_arm.R")).origin
	assert_true(sh_r.x > 0.1 and sh_r.y < -0.15 and sh_r.z > 0.03, "right shoulder at %s" % sh_r)


func test_weapon_bone_matches_grip_offset() -> void:
	if not _ready_or_fail():
		return
	var hand: Transform3D = _skel.get_bone_global_rest(_skel.find_bone("hand.R"))
	var weapon: Transform3D = _skel.get_bone_global_rest(_skel.find_bone("weapon"))
	var rel: Transform3D = hand.affine_inverse() * weapon
	# _anim.grip_offset_godot(): 18 deg grip rake, origin 76 % along the hand
	var c: float = cos(deg_to_rad(18.0))
	var s: float = sin(deg_to_rad(18.0))
	assert_true(rel.basis.x.is_equal_approx(Vector3(0, 0, 1)), "weapon X = %s" % rel.basis.x)
	assert_true(rel.basis.y.distance_to(Vector3(-c, -s, 0)) < 0.001, "weapon Y = %s" % rel.basis.y)
	assert_true(rel.basis.z.distance_to(Vector3(s, -c, 0)) < 0.001, "weapon Z = %s" % rel.basis.z)
	assert_near(rel.origin.x, -0.012, 0.001, "grip offset x")
	assert_near(rel.origin.z, -0.030, 0.001, "grip offset z")


func test_mesh_and_budget() -> void:
	if not _ready_or_fail():
		return
	var mesh_node: MeshInstance3D = _skel.get_node_or_null("Arms") as MeshInstance3D
	assert_true(mesh_node != null, "Arms mesh under the skeleton")
	if mesh_node == null:
		return
	var tris: int = 0
	for si: int in range(mesh_node.mesh.get_surface_count()):
		var arrays: Array = mesh_node.mesh.surface_get_arrays(si)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		tris += idx.size() / 3
		assert_true(mesh_node.mesh.surface_get_material(si) != null, "surface %d has a material" % si)
	assert_true(tris <= 12000, "arms triangles %d <= 12000" % tris)
	assert_true(mesh_node.skin != null, "Arms is skinned")


func test_every_set_has_its_clips() -> void:
	if not _ready_or_fail():
		return
	var layout: Array[String] = _track_layout(_anim("pistol_idle"))
	assert_true(layout.size() > 0, "pistol_idle has tracks")
	for set_name: String in SETS:
		for clip: String in clips_of(set_name):
			var name: String = "%s_%s" % [set_name, clip]
			var a: Animation = _anim(name)
			assert_true(a != null, "clip %s" % name)
			if a == null:
				continue
			assert_true(a.length > 0.0, "%s length" % name)
			# Godot also loops names ending in "_loop": the seamless shell loop plays n x its length
			var looped: bool = LOOPED.has(clip) or clip == "reload_loop"
			var want: Animation.LoopMode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
			assert_eq(a.loop_mode, want, "%s loop mode" % name)
			# every clip keys the same transforms, so switching clips never leaves a stale track
			assert_eq(_track_layout(a), layout, "%s track layout" % name)
			for t: int in range(a.get_track_count()):
				var bone: String = String(a.track_get_path(t).get_concatenated_subnames())
				assert_true(_skel.find_bone(bone) >= 0, "%s: track bone %s" % [name, bone])
			# SOURCE.txt lists the clip with the same frame count
			var row: String = String(_source.get("clip.%s" % name, ""))
			assert_true(row.begins_with("%df " % roundi(a.length * FPS)), "SOURCE clip.%s = '%s'" % [name, row])


func test_clip_lengths_follow_the_weapon_data() -> void:
	if not _ready_or_fail():
		return
	for set_name: String in SETS:
		var pairs: Dictionary = {"reload": "reload_time_s", "reload_empty": "reload_empty_time_s"}
		# LEAD (D-045): shotgun reload timing formula is being aligned (ENV B data + reload_end_empty_s);
		# re-enable once trunk's Plowman data follows the D-045 formula.
		if set_name == "shotgun":
			pairs = {}
		for clip: String in pairs:
			var times: Array[float] = _weapon_times(set_name, pairs[clip])
			assert_true(not times.is_empty(), "a weapon uses anim_set %s" % set_name)
			var a: Animation = _anim("%s_%s" % [set_name, clip])
			if a == null or times.is_empty():
				continue
			var hit: bool = false
			for t: float in times:
				hit = hit or absf(a.length - t) < 0.002
			assert_true(hit, "%s_%s length %.3f matches %s %s" % [set_name, clip, a.length, pairs[clip], times])
		var draw: Animation = _anim("%s_draw" % set_name)
		var equip: Array[float] = _weapon_times(set_name, "equip_time_s")
		if draw != null and not equip.is_empty():
			var ok: bool = false
			for t: float in equip:
				ok = ok or absf(draw.length - ceilf(t * FPS - 0.001) / FPS) < 0.002
			assert_true(ok, "%s_draw %.3f s ~ equip_time_s %s" % [set_name, draw.length, equip])
	# full-auto fire clips can be restarted every shot (<= 1.5 shot intervals)
	for set_name: String in ["smg", "rifle", "lmg"]:
		var rpm: Array[float] = _weapon_times(set_name, "fire_rate_rpm")
		var fire: Animation = _anim("%s_fire" % set_name)
		if fire != null and not rpm.is_empty():
			assert_true(fire.length <= 1.5 * 60.0 / rpm.max(), "%s_fire %.3f s vs %s rpm" % [set_name, fire.length, rpm])
	# pump and bolt cycles fit the shot interval
	var sg: Animation = _anim("shotgun_fire")
	if sg != null:
		assert_true(sg.length <= 60.0 / _weapon_times("shotgun", "fire_rate_rpm").max(), "shotgun_fire fits the rpm")
	var sn_fire: Animation = _anim("sniper_fire")
	var sn_bolt: Animation = _anim("sniper_bolt")
	if sn_fire != null and sn_bolt != null:
		var interval: float = 60.0 / _weapon_times("sniper", "fire_rate_rpm").max()
		assert_true(sn_fire.length + sn_bolt.length <= interval + 0.002, "sniper fire + bolt fit the rpm")


func test_events_are_listed() -> void:
	if not _ready_or_fail():
		return
	for name: String in EVENTS:
		var row: String = String(_source.get("clip.%s" % name, ""))
		var a: Animation = _anim(name)
		for ev: Variant in EVENTS[name]:
			var key: String = "%s@" % String(ev)
			var at: int = row.find(key)
			assert_true(at >= 0 and (at == 0 or row[at - 1] in "=,"), "%s lists event %s ('%s')" % [name, ev, row])
			if at >= 0 and a != null:
				var frame: int = row.substr(at + key.length()).split(",")[0].to_int()
				assert_true(frame >= 0 and frame <= roundi(a.length * FPS), "%s %s@%d inside the clip" % [name, ev, frame])
	assert_true(String(_source.get("fp.shotgun", "")).contains("pump folded into fire"), "pump decision documented")
	assert_true(String(_source.get("fp.sniper", "")).contains("bolt"), "bolt decision documented")


func test_magazine_moves_in_reloads() -> void:
	if not _ready_or_fail():
		return
	for set_name: String in ["pistol", "smg", "rifle", "lmg", "sniper"]:
		for clip: String in ["reload", "reload_empty"]:
			var a: Animation = _anim("%s_%s" % [set_name, clip])
			if a == null:
				continue
			assert_true(_pos_travel(a, "magazine") > 0.03, "%s_%s moves the magazine" % [set_name, clip])
	var idle: Animation = _anim("rifle_idle")
	if idle != null:
		assert_true(_pos_travel(idle, "magazine") < 0.02, "the magazine stays seated in idle")


func test_shotgun_loop_is_seamless_and_bolt_frees_the_gun() -> void:
	if not _ready_or_fail():
		return
	var loop: Animation = _anim("shotgun_reload_loop")
	if loop != null:
		for bone: String in ["hand.L", "forearm.L", "upper_arm.L", "hand.R"]:
			var t: int = _track(loop, bone, Animation.TYPE_ROTATION_3D)
			if t < 0:
				continue
			var q0: Quaternion = loop.track_get_key_value(t, 0)
			var q1: Quaternion = loop.track_get_key_value(t, loop.track_get_key_count(t) - 1)
			assert_true(q0.angle_to(q1) < deg_to_rad(0.5), "reload_loop %s ends where it starts" % bone)
	# the right hand leaves the grip during the bolt: the weapon bone moves relative to hand.R
	var bolt: Animation = _anim("sniper_bolt")
	if bolt != null:
		assert_true(_pos_travel(bolt, "weapon") > 0.05, "sniper_bolt animates the weapon bone")
	var fire: Animation = _anim("rifle_fire")
	if fire != null:
		assert_true(_pos_travel(fire, "weapon") < 0.002, "the weapon stays in the right hand when firing")
