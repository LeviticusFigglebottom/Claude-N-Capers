## D1-03 / D-034: first-person arms rig `rig_arms` + the viewmodel sets (char_arms_fp).
## Checks the rig (root at the camera origin, contract arm/finger bones, weapon/magazine helper
## bones and the weapon grip offset), the mesh budget, every `<set>_<clip>` animation (present,
## loop mode, length, identical track layout), the clip lengths against the weapon data, the
## events listed in SOURCE.txt and the moving parts (magazine, sniper bolt hand, shotgun loop).
## D-050 (B4-12): akimbo (offhand gun on hand.L at the mirrored grip), revolver (speedloader on the
## magazine bone), pistol fire_auto. Their lengths are checked against the weapon data once ENV B's
## files with those anim_sets exist.
## D-055 (B4-18): break_action, lever, bow, crossbow, launcher, flamethrower, saw, minigun (hold-to-fire
## loops fire_hold / cut_hold, bow draw_string / hold / release / nock, lever shell-by-shell); their
## lengths are checked against ENV B's batch-3 data once it exists (DATA_PENDING until then).
## D-058: shotgun_box (box / drum-fed shotguns: rifle hold, shotgun kick, rock-in mag swap, charging
## handle on reload_empty); the lever gate <-> fore-end hand moves turn the wrist <= LEVER_MAX_STEP_DEG / frame.
## D-063: a set's reload clips play at speed_scale = clip / reload_time_s for every weapon of the set, so one weapon
## must match exactly and every weapon must sit within RELOAD_RATIO_MIN..MAX of the clip.
## D2-04: a `bash` (quick melee with the gun out) in every gun set; the non-gun sets melee_knife / melee_blunt /
## melee_blade, throwable, deploy_bag / deploy_small / deploy_sentry (clips, loops, events, data lengths);
## with ENV B's real models: the support hand on LeftHandIK and, in ADS, the AimPoint on the camera axis with
## the stock below the eye where it crosses the near plane (never enclosing the camera).
## Vise two-half string (StringUpper / StringLower meeting at the string centre): fp.crossbow gives the latched
## (on the Magwell) and released centres, curve.crossbow_<clip> the latch fraction per frame, and the left hand
## pulls the centre from released to latched in the reload; ENV B's model rests released (cords meet there).
## Arm skin weights change smoothly along every edge of the sleeves / cuffs / wrists (ARM_WEIGHT_GRADIENT_MAX).
extends TestCase

const GLB: String = "res://assets/characters/char_arms_fp/char_arms_fp.glb"
const SOURCE: String = "res://assets/characters/char_arms_fp/SOURCE.txt"
## D2-03 follow-up: crew heisters with a first-person sleeve variant char_arms_fp_<heister>.
const HEISTERS: Array[String] = ["rook", "sable", "dutch", "wren", "marten", "jay"]
const WEAPONS_DIR: String = "res://content/data/weapons"
const FPS: float = 30.0
const FINGERS: Array[String] = ["thumb", "index", "middle", "ring", "pinky"]
const SETS: Array[String] = [
	"pistol", "smg", "rifle", "shotgun", "lmg", "sniper", "akimbo", "revolver",
	"break_action", "lever", "bow", "crossbow", "launcher", "flamethrower", "saw", "minigun", "shotgun_box",
]
## Sets whose weapon data may not exist yet (D-050, D-055): their length checks run once it does.
const DATA_PENDING: Array[String] = [
	"akimbo", "revolver", "break_action", "lever", "bow", "crossbow", "launcher", "flamethrower", "saw", "minigun",
	"shotgun_box",
]
## D2-04 non-gun sets and their clips (lengths from MeleeDef / DeployableDef when that data exists).
const ITEM_SETS: Array[String] = [
	"melee_knife", "melee_blunt", "melee_blade", "melee_heavy", "throwable", "deploy_bag", "deploy_small",
	"deploy_sentry",
]
const ITEM_CLIPS: Dictionary = {
	"melee": ["idle", "sprint", "draw", "holster", "swing", "charge_start", "charge", "charge_swing"],
	"throwable": ["idle", "sprint", "draw", "holster", "throw", "throw_low"],
	"deploy": ["idle", "draw", "holster", "place"],
}
const ITEM_EVENTS: Dictionary = {
	"swing": ["hit", "done"], "charge_swing": ["hit", "done"], "charge_start": ["charged"], "draw": ["ready"],
	"holster": ["gone"], "throw": ["release", "done"], "throw_low": ["release", "done"], "place": ["place", "done"],
}
## MeleeDef id fragments per melee set until MeleeDef.anim_set exists (as _arms_sets.MELEE_MATCH).
const MELEE_MATCH: Dictionary = {
	"melee_knife": ["knife", "dagger", "shank"],
	"melee_blunt": ["baton", "bat", "club", "hammer", "pipe", "crowbar", "wrench"],
	"melee_blade": ["machete", "sword", "katana", "axe", "cleaver"],
	"melee_heavy": ["sledge", "fire_axe"],
}
## characters v1.38: melee_heavy is two-handed; the left hand closes round the handle this far below the right hand's
## grip pivot (Godot item axes: the handle along +Y), in every frame of every clip.
const HEAVY_LEFT_Y: float = -0.28
## the left palm may sit this much further off its handle point than the right palm sits off the item origin
const HEAVY_LEFT_TOL: float = 0.02
const DEPLOY_KINDS: Dictionary = {
	"deploy_bag": ["ammo_bag", "doctor_bag", "body_bag_case", "armor_bag"],
	"deploy_small": ["ecm", "trip_mine", "fak"], "deploy_sentry": ["sentry"],
}
## D-063: every weapon of a set plays its reload at clip / reload_time_s within these bounds.
const RELOAD_RATIO_MIN: float = 0.75
const RELOAD_RATIO_MAX: float = 1.35
## Reference model per set for the marker fit checks (ENV B's glbs).
const REF_WEAPON: Dictionary = {
	"pistol": "kestrel_p9", "smg": "hornet_9", "rifle": "corsair_ar", "shotgun": "plowman_12", "lmg": "rampart_lmg",
	"sniper": "heron_308", "revolver": "marshal_357", "break_action": "reaper_db", "lever": "shrike_44",
	"crossbow": "vise_crossbow", "launcher": "thumper_40", "flamethrower": "furnace_ft", "saw": "rotor_saw",
	"minigun": "cyclone_rotary", "shotgun_box": "brute_12",
}
## D-118: the sets whose guns take a vertical foregrip mod: {set: grip mod id}. `<set>_vgrip_hand` is the hip hold with the
## left hand closed round that grip (ENV P blends the left-hand bones to it and IKs to the mod's LeftHandIK).
const VGRIP: Dictionary = {
	"smg": "mod_rail_vertical_grip", "rifle": "mod_corsair_vertical_grip", "launcher": "mod_thumper_vertical_grip",
}
## D-116: one-handed first-person sets (the left hand waits off-screen except while a reload uses it).
const ONE_HAND: Array[String] = ["pistol", "revolver"]
## The viewmodel camera's vertical FOV (FpViewmodel, 16:9) for the off-screen check.
const VM_FOV_DEG: float = 52.0
## Sets without sight alignment in ADS (a raised hold instead).
const NO_SIGHTS: Array[String] = ["saw", "minigun"]
## PO6-09: support finger / thumb skin may sit at most this deep inside the reference gun (ENV P's PFingerClip: 2 mm).
const SKIN_DEPTH_M: float = 0.001
## ADS stock check (D2-04): no weapon geometry may cross the camera's near plane inside the view, i.e. where a
## stock passes under the eye it is cut by the near plane below the view's bottom edge (half height =
## near x tan(37.5 deg) at the crew camera's 75 deg FOV; 16:9 half width). CAMERA_NEAR is the viewmodel near
## plane proposed to the lead (0.02 m; the Camera3D default 0.05 m cuts every shouldered stock, the accepted
## smg / rifle / shotgun ones too).
const CAMERA_NEAR: float = 0.02
const NEAR_HALF_H: float = 0.0153
const NEAR_HALF_W: float = 0.0272
## Largest single-frame rotation (deg) of any arm joint in the lever's gate <-> fore-end pieces (B4-18 polish).
const LEVER_MAX_STEP_DEG: float = 25.0
## One reload motion whatever the ammo state: reload_empty is the same clip (timed by reload_time_s).
const SAME_RELOAD: Array[String] = ["revolver", "break_action", "crossbow", "launcher", "bow", "saw"]
## Shell-by-shell sets: the composed reload / reload_empty are previews (D-053), the pieces follow the data.
const SHELL_SETS: Array[String] = ["shotgun", "lever"]
const COMMON: Array[String] = [
	"idle", "ads_idle", "draw", "holster", "fire", "fire_ads", "reload", "reload_empty", "sprint",
]
const LOOPED: Array[String] = ["idle", "ads_idle", "sprint"]
const EXTRA: Dictionary = {
	"pistol": ["fire_auto", "fire_auto_ads"],
	"akimbo": ["fire_l", "fire_ads_l"],
	"shotgun": ["reload_start", "reload_loop", "reload_end", "reload_end_empty"],
	"sniper": ["bolt", "bolt_ads"],
	"lever": ["reload_start", "reload_loop", "reload_end", "reload_end_empty"],
	"bow": ["draw_string", "hold", "release", "nock"],
	"flamethrower": ["fire_start", "fire_hold", "fire_end"],
	"saw": ["rev", "cut_hold", "cut_end"],
	"minigun": ["spin_up", "fire_hold", "spin_down"],
}
## Clips that must import looped (besides LOOPED; Godot also loops names ending in "_loop").
const EXTRA_LOOPS: Array[String] = ["hold", "fire_hold", "cut_hold", "reload_loop", "charge"]
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
	"akimbo_reload": ["mag_out_r", "mag_out_l", "mag_in_r", "mag_in_l", "done"],
	"akimbo_reload_empty": [
		"mag_out_r", "mag_out_l", "mag_in_r", "mag_in_l", "slide_release_r", "slide_release_l", "done",
	],
	"revolver_reload": ["crane_open", "eject", "loader_show", "speedloader_in", "loader_drop", "crane_close", "done"],
	"revolver_reload_empty": [
		"crane_open", "eject", "loader_show", "speedloader_in", "loader_drop", "crane_close", "done",
	],
	"break_action_reload": ["breech_open", "eject", "shell_in_1", "shell_in_2", "breech_close", "done"],
	"break_action_reload_empty": ["breech_open", "eject", "shell_in_1", "shell_in_2", "breech_close", "done"],
	"launcher_reload": ["breech_open", "eject", "round_in", "breech_close", "done"],
	"crossbow_fire": ["shot", "string_release"],
	"crossbow_reload": ["cock", "string_back", "bolt_show", "bolt_in", "done"],
	"lever_fire": ["shot", "lever_open", "lever_close", "done"],
	"lever_fire_ads": ["shot", "lever_open", "lever_close", "done"],
	"lever_reload_loop": ["round_in"],
	"lever_reload_end_empty": ["lever_open", "lever_close", "done"],
	"lever_reload": ["round_in_1", "done"],
	"lever_reload_empty": ["round_in_1", "lever_open", "lever_close", "done"],
	"bow_draw_string": ["drawn"],
	"bow_release": ["release"],
	"bow_fire": ["release"],
	"bow_nock": ["arrow_show", "nocked", "done"],
	"bow_reload": ["arrow_show", "nocked", "done"],
	"flamethrower_fire_start": ["ignite"],
	"flamethrower_fire_end": ["extinguish", "done"],
	"flamethrower_reload": ["mag_out", "mag_in", "done"],
	"saw_rev": ["rev"],
	"saw_reload": ["nut_off", "blade_out", "blade_in", "nut_on", "done"],
	"minigun_spin_up": ["spin", "spun"],
	"minigun_spin_down": ["stopped"],
	"minigun_reload": ["mag_out", "mag_in", "belt_seat", "done"],
	"minigun_reload_empty": ["mag_out", "mag_in", "belt_seat", "done"],
	"shotgun_box_fire": ["shot"],
	"shotgun_box_fire_ads": ["shot"],
	"shotgun_box_reload": ["mag_out", "mag_swap", "mag_in", "done"],
	"shotgun_box_reload_empty": ["mag_out", "mag_swap", "mag_in", "bolt_release", "done"],
}

## Vise string centre, Godot weapon-model space: latched on the Magwell, released 0.16 m forward (ENV B's model).
const CROSSBOW_LATCHED: Vector3 = Vector3(0.0, 0.066, -0.016)
const CROSSBOW_RELEASED: Vector3 = Vector3(0.0, 0.066, -0.176)
const CROSSBOW_LATCHED_TEXT: String = "(0.000, 0.066, -0.016)"
const CROSSBOW_RELEASED_TEXT: String = "(0.000, 0.066, -0.176)"
## The string halves' prod-tip anchors (StringUpper left, StringLower right), Godot weapon-model space.
const CROSSBOW_ANCHOR: Vector3 = Vector3(0.290, 0.066, -0.339)
const CROSSBOW_ANCHOR_TEXT: String = "(-0.290 / 0.290, 0.066, -0.339)"
## Arm skin weights (verts weighted to upper_arm / forearm / hand only: the sleeves, cuffs and the wrist): the
## largest weight change per metre along a mesh edge. The loft's elbow / wrist blends stay near 23 /m; a ring
## whose verts alternate between bones (a sawtooth under a forearm roll) would be hundreds.
const ARM_WEIGHT_GRADIENT_MAX: float = 35.0
## Palm centre (hand.L .. middle_01.L midpoint) to the hooked string centre (29 mm: the fingers curl over it;
## the string follows the hand's own ease, so the distance holds through the pull).
const CROSSBOW_HOOK_TOL: float = 0.04

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


static func item_kind(set_name: String) -> String:
	if set_name.begins_with("melee_"):
		return "melee"
	return "deploy" if set_name.begins_with("deploy_") else "throwable"


static func clips_of(set_name: String) -> Array[String]:
	var out: Array[String] = []
	if ITEM_SETS.has(set_name):
		for c: Variant in ITEM_CLIPS[item_kind(set_name)]:
			out.append(String(c))
		return out
	out.append("bash")
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


## fire_rate_rpm of the weapons using ``set_name`` that have ``mode`` in their fire_modes.
func _rpm_with_mode(set_name: String, mode: StringName) -> Array[float]:
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
		var modes: Variant = def.get("fire_modes")
		var stats: Resource = def.get("base") as Resource
		if stats != null and modes is Array and (modes as Array).has(mode):
			out.append(float(stats.get("fire_rate_rpm")))
	return out


static func _parse_vec(row: String, key: String) -> Vector3:
	var at: int = row.find(key + "=(")
	if at < 0:
		return Vector3(INF, INF, INF)
	var inner: String = row.substr(at + key.length() + 2).split(")")[0]
	var p: PackedStringArray = inner.split(",")
	return Vector3(p[0].to_float(), p[1].to_float(), p[2].to_float())


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
	if mesh_node.skin != null:
		var g: float = _arm_weight_gradient(mesh_node, _skel)
		assert_true(g < ARM_WEIGHT_GRADIENT_MAX, "char_arms_fp: arm weight gradient %.1f /m < %.0f" % [g, ARM_WEIGHT_GRADIENT_MAX])
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
	for set_name: String in SETS + ITEM_SETS:
		for clip: String in clips_of(set_name):
			var name: String = "%s_%s" % [set_name, clip]
			var a: Animation = _anim(name)
			assert_true(a != null, "clip %s" % name)
			if a == null:
				continue
			assert_true(a.length > 0.0, "%s length" % name)
			# Godot also loops names ending in "_loop": the seamless shell loop plays n x its length
			var looped: bool = LOOPED.has(clip) or EXTRA_LOOPS.has(clip)
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
		if SAME_RELOAD.has(set_name):  # one reload motion: reload_empty is the same clip
			pairs["reload_empty"] = "reload_time_s"
		if set_name == "bow":  # the bow's reload is the nock
			pairs["nock"] = "reload_time_s"
		if DATA_PENDING.has(set_name) and _weapon_times(set_name, "equip_time_s").is_empty():
			continue
		if SHELL_SETS.has(set_name):  # composed previews (D-053): the pieces follow the data
			pairs = {}
			_check_shell_pieces(set_name)
		for clip: String in pairs:
			_check_reload_ratio(set_name, clip, pairs[clip], 0.002)
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
	# machine pistols (pistol set, full-auto) restart pistol_fire_auto every shot
	var auto_rpm: Array[float] = _rpm_with_mode("pistol", &"auto")
	for clip: String in ["fire_auto", "fire_auto_ads"]:
		var pa: Animation = _anim("pistol_%s" % clip)
		assert_true(pa != null and pa.length <= 1.5 * 60.0 / 900.0 + 0.002, "pistol_%s supports 900 rpm" % clip)
		if pa != null and not auto_rpm.is_empty():
			assert_true(pa.length <= 1.5 * 60.0 / auto_rpm.max(), "pistol_%s vs %s rpm" % [clip, auto_rpm])
	# akimbo fire clips end within one shot interval (alternating fire_l never cuts a kick)
	var ak_rpm: Array[float] = _weapon_times("akimbo", "fire_rate_rpm")
	if ak_rpm.is_empty():
		ak_rpm = _weapon_times("pistol", "fire_rate_rpm")  # the Warden .45 until akimbo data exists
	for clip: String in ["fire", "fire_l", "fire_ads", "fire_ads_l"]:
		var af: Animation = _anim("akimbo_%s" % clip)
		if af != null and not ak_rpm.is_empty():
			assert_true(af.length <= 60.0 / ak_rpm.max() + 0.002, "akimbo_%s %.3f s vs %s rpm" % [clip, af.length, ak_rpm])
	# pump and bolt cycles fit the shot interval
	var sg: Animation = _anim("shotgun_fire")
	if sg != null:
		assert_true(sg.length <= 60.0 / _weapon_times("shotgun", "fire_rate_rpm").max(), "shotgun_fire fits the rpm")
	var sn_fire: Animation = _anim("sniper_fire")
	var sn_bolt: Animation = _anim("sniper_bolt")
	if sn_fire != null and sn_bolt != null:
		var interval: float = 60.0 / _weapon_times("sniper", "fire_rate_rpm").max()
		assert_true(sn_fire.length + sn_bolt.length <= interval + 0.002, "sniper fire + bolt fit the rpm")


## Shell-by-shell pieces vs reload_start_s / reload_per_round_s / reload_end_s / reload_end_empty_s (when set).
func _check_shell_pieces(set_name: String) -> void:
	var pieces: Dictionary = {
		"reload_start": "reload_start_s", "reload_loop": "reload_per_round_s", "reload_end": "reload_end_s",
		"reload_end_empty": "reload_end_empty_s",
	}
	for clip: String in pieces:
		var a: Animation = _anim("%s_%s" % [set_name, clip])
		var times: Array[float] = _weapon_times(set_name, pieces[clip])
		if a == null or times.is_empty() or times.max() <= 0.0:
			continue
		_check_reload_ratio(set_name, clip, pieces[clip], 0.02)


func test_batch3_fire_rates_and_parts() -> void:
	if not _ready_or_fail():
		return
	# burst rifles restart rifle_fire every burst round (<= 1.5 shot intervals at the burst rpm)
	var fire: Animation = _anim("rifle_fire")
	for rpm: float in _rpm_with_mode("rifle", &"burst3"):
		assert_true(fire != null and fire.length <= 1.5 * 60.0 / rpm, "rifle_fire vs burst3 %s rpm" % rpm)
	# smg / lmg weapons of the new batch (<= 900 rpm) still restart the 3 f fire clip
	for set_name: String in ["smg", "lmg", "flamethrower", "saw", "minigun"]:
		var f: Animation = _anim("%s_fire" % set_name)
		assert_true(f != null and f.length <= 1.5 * 60.0 / 900.0 + 0.002, "%s_fire restartable" % set_name)
	# the lever cycle fits the shot interval
	var lv: Animation = _anim("lever_fire")
	for rpm: float in _weapon_times("lever", "fire_rate_rpm"):
		assert_true(lv != null and lv.length <= 60.0 / rpm + 0.002, "lever_fire %.3f s fits %s rpm" % [lv.length, rpm])
	# the bow draws in 0.6..0.8 s; the hold loop starts where the draw ends
	var ds: Animation = _anim("bow_draw_string")
	var hold: Animation = _anim("bow_hold")
	assert_true(ds != null and ds.length >= 0.6 and ds.length <= 0.8, "bow_draw_string 0.6..0.8 s")
	if ds != null and hold != null:
		for bone: String in ["hand.L", "hand.R", "forearm.R", "upper_arm.L"]:
			var t0: int = _track(ds, bone, Animation.TYPE_ROTATION_3D)
			var t1: int = _track(hold, bone, Animation.TYPE_ROTATION_3D)
			var q0: Quaternion = ds.rotation_track_interpolate(t0, ds.length)
			var q1: Quaternion = hold.rotation_track_interpolate(t1, 0.0)
			assert_true(q0.angle_to(q1) < deg_to_rad(1.0), "bow_draw_string ends on bow_hold frame 0 (%s)" % bone)
	# the bow is in the left hand: the weapon bone moves relative to hand.R; the lever cycle moves it too
	for name: String in ["bow_draw_string", "bow_nock", "bow_release"]:
		var a: Animation = _anim(name)
		assert_true(a != null and _pos_travel(a, "weapon") > 0.02, "%s moves the weapon bone" % name)
	var lf: Animation = _anim("lever_fire")
	assert_true(lf != null and _pos_travel(lf, "weapon") > 0.01, "lever_fire: the right hand turns with the lever")
	# carried parts ride the magazine bone: crossbow bolt, bow arrow, saw blade, canister, ammo box, round
	for name: String in ["crossbow_reload", "bow_nock", "bow_draw_string", "saw_reload", "flamethrower_reload",
			"minigun_reload", "minigun_reload_empty"]:
		var a: Animation = _anim(name)
		assert_true(a != null and _pos_travel(a, "magazine") > 0.03, "%s moves the magazine bone" % name)
	for name: String in ["crossbow_reload", "saw_reload", "bow_nock"]:
		var a: Animation = _anim(name)
		if a == null:
			continue
		var t: int = _track(a, "magazine", Animation.TYPE_POSITION_3D)
		var p0: Vector3 = a.position_track_interpolate(t, 0.0)
		var p1: Vector3 = a.position_track_interpolate(t, a.length)
		assert_true(p0.distance_to(p1) < 0.0005, "%s returns the magazine bone to rest" % name)
	# hold-to-fire loops are seamless
	for name: String in ["flamethrower_fire_hold", "saw_cut_hold", "minigun_fire_hold", "bow_hold", "lever_reload_loop"]:
		var a: Animation = _anim(name)
		if a == null:
			fail("missing %s" % name)
			continue
		for bone: String in ["hand.L", "forearm.L", "hand.R", "weapon"]:
			var t: int = _track(a, bone, Animation.TYPE_ROTATION_3D)
			var q0: Quaternion = a.rotation_track_interpolate(t, 0.0)
			var q1: Quaternion = a.rotation_track_interpolate(t, a.length)
			assert_true(q0.angle_to(q1) < deg_to_rad(0.5), "%s %s ends where it starts" % [name, bone])
	for set_name: String in ["break_action", "lever", "bow", "crossbow", "launcher", "flamethrower", "saw", "minigun"]:
		assert_true(String(_source.get("fp.%s" % set_name, "")).length() > 40, "SOURCE fp.%s documented" % set_name)
	assert_true(String(_source.get("curve.bow_draw_string", "")).begins_with("draw=0.000"), "bow draw curve listed")
	assert_true(String(_source.get("curve.bow_hold", "")).begins_with("draw=1.000"), "bow hold at full draw")
	_check_crossbow_string_halves()


## "string=1.000,0.500,..." -> [1.0, 0.5, ...]
func _curve(key: String) -> Array[float]:
	var out: Array[float] = []
	var row: String = String(_source.get(key, ""))
	if not row.begins_with("string="):
		return out
	for v: String in row.trim_prefix("string=").split(","):
		out.append(v.to_float())
	return out


func _check_crossbow_string_halves() -> void:
	var doc: String = String(_source.get("fp.crossbow", ""))
	assert_true(doc.contains("StringUpper") and doc.contains("StringLower"), "fp.crossbow: the two string halves")
	assert_true(doc.contains(CROSSBOW_LATCHED_TEXT), "fp.crossbow: latched centre on the Magwell %s" % CROSSBOW_LATCHED_TEXT)
	assert_true(doc.contains(CROSSBOW_RELEASED_TEXT), "fp.crossbow: released centre %s" % CROSSBOW_RELEASED_TEXT)
	assert_true(doc.contains(CROSSBOW_ANCHOR_TEXT), "fp.crossbow: the halves' anchors %s" % CROSSBOW_ANCHOR_TEXT)
	_check_vise_string_model()
	for clip: String in ["fire", "fire_ads"]:
		var c: Array[float] = _curve("curve.crossbow_%s" % clip)
		assert_true(c.size() >= 2 and is_equal_approx(c[0], 1.0) and is_equal_approx(c[c.size() - 1], 0.0),
			"crossbow_%s: latched -> released (%s)" % [clip, c])
	for clip: String in ["reload", "reload_empty"]:
		var c: Array[float] = _curve("curve.crossbow_%s" % clip)
		var a: Animation = _anim("crossbow_%s" % clip)
		if c.is_empty() or a == null:
			fail("curve.crossbow_%s / crossbow_%s missing" % [clip, clip])
			continue
		assert_eq(c.size(), int(round(a.length * 30.0)) + 1, "crossbow_%s: one string value per frame" % clip)
		var mono: bool = true
		for i: int in range(1, c.size()):
			mono = mono and c[i] >= c[i - 1] - 1e-6
		assert_true(mono and is_equal_approx(c[0], 0.0) and is_equal_approx(c[c.size() - 1], 1.0),
			"crossbow_%s: released -> latched, never back" % clip)
		# the left hand hooks the centre at cock and pulls it to the latch by string_back
		var cock: int = _event("crossbow_%s" % clip, "cock")
		var back: int = _event("crossbow_%s" % clip, "string_back")
		if cock < 0 or back < 0:
			fail("crossbow_%s: cock / string_back events" % clip)
			continue
		var worst: float = 0.0
		for f: int in range(cock, back + 1):
			_player.play(StringName("crossbow_%s" % clip))
			_player.seek(float(f) / 30.0, true)
			var wt: Transform3D = _skel.get_bone_global_pose(_skel.find_bone("weapon"))
			var centre: Vector3 = wt * CROSSBOW_RELEASED.lerp(CROSSBOW_LATCHED, c[f])
			var hand: Vector3 = _skel.get_bone_global_pose(_skel.find_bone("hand.L")).origin
			var mid: Vector3 = _skel.get_bone_global_pose(_skel.find_bone("middle_01.L")).origin
			worst = maxf(worst, ((hand + mid) * 0.5).distance_to(centre))
		_player.stop()
		assert_true(worst < CROSSBOW_HOOK_TOL, "crossbow_%s: the left palm stays %.3f m from the string centre while it pulls" % [
			clip, worst])


## ENV B's real Vise: the half nodes sit on the anchors and, at rest, their cords meet on the RELEASED centre
## (the model rests released; fp.crossbow's bend is relative to that pose).
func _check_vise_string_model() -> void:
	var w: Dictionary = _weapon_model(String(REF_WEAPON["crossbow"]))
	if w.is_empty():
		return
	var marks: Dictionary = w["marks"]
	var root: Node3D = w["root"]
	for half: String in ["StringUpper", "StringLower"]:
		var anchor: Vector3 = CROSSBOW_ANCHOR * Vector3(-1.0 if half == "StringUpper" else 1.0, 1.0, 1.0)
		if not marks.has(half) or not marks.has(half + "Cord"):
			fail("wpn_vise_crossbow: %s / %sCord" % [half, half])
			continue
		var o: Vector3 = (marks[half] as Transform3D).origin
		assert_true(o.distance_to(anchor) < 0.002, "vise %s origin %s on its anchor %s" % [half, o, anchor])
		var mi: MeshInstance3D = root.find_child(half + "Cord", true, false) as MeshInstance3D
		var far: Vector3 = o
		if mi != null and mi.mesh != null:
			var xf: Transform3D = marks[half + "Cord"]
			for p: Vector3 in mi.mesh.get_faces():
				var q: Vector3 = xf * p
				if q.distance_to(o) > far.distance_to(o):
					far = q
		assert_true(far.distance_to(CROSSBOW_RELEASED) < 0.004,
				"vise %sCord ends %.4f m from the released centre %s (rest = released)" % [
					half, far.distance_to(CROSSBOW_RELEASED), CROSSBOW_RELEASED])
	root.queue_free()


## Largest |weight change| / edge length over the edges of `arms` whose two verts are skinned to upper_arm /
## forearm / hand bones only (named binds of `skin`, else bones of `sk`).
static func _arm_weight_gradient(arms: MeshInstance3D, sk: Skeleton3D) -> float:
	var names: Array[String] = []
	for i: int in range(arms.skin.get_bind_count()):
		var n: String = String(arms.skin.get_bind_name(i))
		names.append(n if n != "" else sk.get_bone_name(arms.skin.get_bind_bone(i)))
	var worst: float = 0.0
	for si: int in range(arms.mesh.get_surface_count()):
		var arr: Array = arms.mesh.surface_get_arrays(si)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var k: int = bones.size() / maxi(1, pos.size())
		var vw: Array[Dictionary] = []
		for v: int in range(pos.size()):
			var d: Dictionary = {}
			var arm_only: bool = true
			for j: int in range(k):
				var x: float = wts[v * k + j]
				if x <= 0.0:
					continue
				var n: String = names[bones[v * k + j]]
				arm_only = arm_only and (n.begins_with("upper_arm") or n.begins_with("forearm") or n.begins_with("hand"))
				d[n] = float(d.get(n, 0.0)) + x
			vw.append(d if arm_only else {})
		for t: int in range(0, idx.size(), 3):
			for e: int in 3:
				var a: int = idx[t + e]
				var b: int = idx[t + (e + 1) % 3]
				if vw[a].is_empty() or vw[b].is_empty():
					continue
				var ln: float = pos[a].distance_to(pos[b])
				if ln < 1e-4:
					continue
				var jump: float = 0.0
				for n: String in vw[a]:
					jump = maxf(jump, absf(float(vw[a][n]) - float(vw[b].get(n, 0.0))))
				for n: String in vw[b]:
					jump = maxf(jump, absf(float(vw[b][n]) - float(vw[a].get(n, 0.0))))
				worst = maxf(worst, jump / ln)
	return worst


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
	for set_name: String in ["pistol", "smg", "rifle", "lmg", "sniper", "akimbo", "revolver", "shotgun_box"]:
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


func test_akimbo_offhand_grip_is_the_mirrored_weapon_offset() -> void:
	if not _ready_or_fail():
		return
	var row: String = String(_source.get("fp.offhand_grip", ""))
	assert_true(row.contains("hand.L"), "fp.offhand_grip documented ('%s')" % row)
	var basis := Basis(_parse_vec(row, "basis x"), _parse_vec(row, " y"), _parse_vec(row, " z"))
	var off := Transform3D(basis, _parse_vec(row, "origin"))
	var hand_l: Transform3D = _skel.get_bone_global_rest(_skel.find_bone("hand.L"))
	var weapon: Transform3D = _skel.get_bone_global_rest(_skel.find_bone("weapon"))
	var left: Transform3D = hand_l * off
	# the X-mirror of the right gun: same model (proper rotation), x -> -x
	var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	var want := Transform3D(m * weapon.basis * m, m * weapon.origin)
	assert_true(left.origin.distance_to(want.origin) < 0.001, "offhand origin %s vs %s" % [left.origin, want.origin])
	for i: int in range(3):
		assert_true(left.basis[i].distance_to(want.basis[i]) < 0.002, "offhand axis %d %s vs %s" % [i, left.basis[i], want.basis[i]])
	assert_near(off.basis.determinant(), 1.0, 0.001, "the left gun is not mirrored (proper rotation)")


func test_akimbo_and_revolver_parts() -> void:
	if not _ready_or_fail():
		return
	# the right gun never leaves hand.R in the akimbo / revolver sets
	for set_name: String in ["akimbo", "revolver"]:
		for clip: String in clips_of(set_name):
			var a: Animation = _anim("%s_%s" % [set_name, clip])
			if a != null:
				assert_true(_pos_travel(a, "weapon") < 0.002, "%s_%s keeps the weapon in hand.R" % [set_name, clip])
	# fire kicks the right gun (hand.R moves), fire_l the left one (hand.L moves, hand.R holds still)
	for pair: Array in [["akimbo_fire", "hand.R", "hand.L"], ["akimbo_fire_l", "hand.L", "hand.R"]]:
		var a: Animation = _anim(pair[0])
		if a == null:
			continue
		var moved: int = _track(a, "forearm.%s" % String(pair[1]).right(1), Animation.TYPE_ROTATION_3D)
		var still: int = _track(a, "forearm.%s" % String(pair[2]).right(1), Animation.TYPE_ROTATION_3D)
		# constant tracks import with a single key: sample frames 0 and 1 instead of reading keys
		var q0: Quaternion = a.rotation_track_interpolate(moved, 0.0)
		var q1: Quaternion = a.rotation_track_interpolate(moved, 1.0 / FPS)
		assert_true(q0.angle_to(q1) > deg_to_rad(1.0), "%s kicks %s" % [pair[0], pair[1]])
		var s0: Quaternion = a.rotation_track_interpolate(still, 0.0)
		var s1: Quaternion = a.rotation_track_interpolate(still, 1.0 / FPS)
		assert_true(s0.angle_to(s1) < deg_to_rad(0.3), "%s holds %s still" % [pair[0], pair[2]])
	# the speedloader (magazine bone) is back at identity when the reload starts and ends
	var rv: Animation = _anim("revolver_reload")
	if rv != null:
		var t: int = _track(rv, "magazine", Animation.TYPE_POSITION_3D)
		var p0: Vector3 = rv.position_track_interpolate(t, 0.0)
		var p1: Vector3 = rv.position_track_interpolate(t, rv.length)
		assert_true(p0.distance_to(p1) < 0.0005, "revolver_reload returns the speedloader bone to rest")
	var re: Animation = _anim("revolver_reload_empty")
	if rv != null and re != null:
		assert_near(re.length, rv.length, 0.001, "revolver reload_empty = reload")
	for key: String in ["fp.akimbo", "fp.revolver", "fp.pistol_auto"]:
		assert_true(String(_source.get(key, "")).length() > 20, "SOURCE %s documented" % key)


func test_shotgun_box_set() -> void:
	if not _ready_or_fail():
		return
	# a shotgun kick (9..12 f) that still restarts every shot: <= 1.5 shot intervals at the data's rpm
	for clip: String in ["fire", "fire_ads"]:
		var f: Animation = _anim("shotgun_box_%s" % clip)
		assert_true(f != null and f.length >= 9.0 / FPS - 0.002 and f.length <= 12.0 / FPS + 0.002,
				"shotgun_box_%s 9..12 f" % clip)
		for rpm: float in _weapon_times("shotgun_box", "fire_rate_rpm"):
			assert_true(f != null and f.length <= maxf(1.5 * 60.0 / rpm, 9.0 / FPS) + 0.002,
					"shotgun_box_%s %.3f s vs %s rpm" % [clip, f.length if f != null else 0.0, rpm])
	# heavier than the rifle: the right forearm turns further on the shot
	var sb: Animation = _anim("shotgun_box_fire")
	var rf: Animation = _anim("rifle_fire")
	if sb != null and rf != null:
		assert_true(_max_step(sb, "forearm.R") > _max_step(rf, "forearm.R"), "shotgun_box kicks harder than the rifle")
		assert_true(_pos_travel(sb, "weapon") < 0.002, "shotgun_box_fire keeps the weapon in hand.R")
	# the drum is back on its seat (bone identity) when the reloads end
	for clip: String in ["reload", "reload_empty"]:
		var a: Animation = _anim("shotgun_box_%s" % clip)
		if a == null:
			continue
		var t: int = _track(a, "magazine", Animation.TYPE_POSITION_3D)
		var p0: Vector3 = a.position_track_interpolate(t, 0.0)
		var p1: Vector3 = a.position_track_interpolate(t, a.length)
		assert_true(p0.distance_to(p1) < 0.0005, "shotgun_box_%s re-seats the magazine bone" % clip)
		assert_true(_pos_travel(a, "weapon") < 0.002, "shotgun_box_%s keeps the weapon in hand.R" % clip)
	assert_true(String(_source.get("fp.shotgun_box", "")).contains("rock"), "SOURCE fp.shotgun_box documented")


## Largest single-frame rotation (deg) of a bone's rotation track, sampled at 30 fps.
func _max_step(a: Animation, bone: String) -> float:
	var t: int = _track(a, bone, Animation.TYPE_ROTATION_3D)
	if t < 0:
		return 0.0
	var best: float = 0.0
	var n: int = roundi(a.length * FPS)
	var prev: Quaternion = a.rotation_track_interpolate(t, 0.0)
	for f: int in range(1, n + 1):
		var q: Quaternion = a.rotation_track_interpolate(t, f / FPS)
		best = maxf(best, rad_to_deg(prev.angle_to(q)))
		prev = q
	return best


func test_lever_hand_moves_are_smooth() -> void:
	if not _ready_or_fail():
		return
	for clip: String in ["reload_start", "reload_end", "reload_end_empty", "reload", "reload_empty"]:
		var a: Animation = _anim("lever_%s" % clip)
		if a == null:
			fail("missing lever_%s" % clip)
			continue
		for bone: String in ["clavicle.L", "upper_arm.L", "forearm.L", "hand.L"]:
			var step: float = _max_step(a, bone)
			assert_true(step <= LEVER_MAX_STEP_DEG, "lever_%s %s steps %.1f deg/frame (<= %.0f)" % [clip, bone, step, LEVER_MAX_STEP_DEG])


## {weapon id: base stats Resource} of the weapons using `set_name`.
func _weapons_of(set_name: String) -> Dictionary:
	var out: Dictionary = {}
	var dir: DirAccess = DirAccess.open(WEAPONS_DIR)
	if dir == null:
		return out
	for fname: String in dir.get_files():
		if not fname.ends_with(".tres"):
			continue
		var def: Resource = load("%s/%s" % [WEAPONS_DIR, fname])
		if def != null and String(def.get("anim_set")) == set_name and def.get("base") != null:
			out[fname.get_basename()] = def.get("base")
	return out


## D-063: `<set>_<clip>` matches `field` of one weapon (within `tol` s) and every weapon of the set plays it at
## clip / field within RELOAD_RATIO_MIN..MAX (a weapon outside needs its own set: named in the failure).
func _check_reload_ratio(set_name: String, clip: String, field: String, tol: float) -> void:
	var a: Animation = _anim("%s_%s" % [set_name, clip])
	var weapons: Dictionary = _weapons_of(set_name)
	if a == null or weapons.is_empty():
		return
	var exact: bool = false
	var times: Array[float] = []
	for id: Variant in weapons:
		var t: float = float((weapons[id] as Resource).get(field))
		if t <= 0.0:
			continue
		times.append(t)
		exact = exact or absf(a.length - t) < tol
		var ratio: float = a.length / t
		assert_true(ratio >= RELOAD_RATIO_MIN and ratio <= RELOAD_RATIO_MAX,
				"%s_%s (%.3f s) plays at %.2fx for %s (%s %.3f s): outside %.2f..%.2f" % [
					set_name, clip, a.length, ratio, id, field, t, RELOAD_RATIO_MIN, RELOAD_RATIO_MAX])
	if not times.is_empty():
		assert_true(exact, "%s_%s length %.3f matches %s of one weapon %s" % [set_name, clip, a.length, field, times])


## Frame of event `ev` of `<clip>` from SOURCE.txt (-1 when missing).
func _event(clip: String, ev: String) -> int:
	var row: String = String(_source.get("clip.%s" % clip, ""))
	var key: String = "%s@" % ev
	var at: int = row.find(key)
	if at < 0 or (at > 0 and not row[at - 1] in "=,"):
		return -1
	return row.substr(at + key.length()).split(",")[0].to_int()


func _same_rotation(a: Animation, ta: float, b: Animation, tb: float, bones: Array, tol_deg: float) -> bool:
	for bone: Variant in bones:
		var q0: Quaternion = a.rotation_track_interpolate(_track(a, String(bone), Animation.TYPE_ROTATION_3D), ta)
		var q1: Quaternion = b.rotation_track_interpolate(_track(b, String(bone), Animation.TYPE_ROTATION_3D), tb)
		if q0.angle_to(q1) > deg_to_rad(tol_deg):
			return false
	return true


func test_gun_bash() -> void:
	if not _ready_or_fail():
		return
	var bones: Array = ["clavicle.R", "upper_arm.R", "forearm.R", "hand.R", "upper_arm.L", "forearm.L", "hand.L"]
	for set_name: String in SETS:
		var name: String = "%s_bash" % set_name
		var a: Animation = _anim(name)
		var idle: Animation = _anim("%s_idle" % set_name)
		if a == null or idle == null:
			fail("missing %s" % name)
			continue
		var n: int = roundi(a.length * FPS)
		var hit: int = _event(name, "hit")
		assert_true(hit > 2 and hit < n - 3, "%s hit@%d inside the strike" % [name, hit])
		assert_eq(_event(name, "done"), n, "%s done@ = the last frame" % name)
		# starts and ends on idle frame 0, and actually moves at the hit
		assert_true(_same_rotation(a, 0.0, idle, 0.0, bones, 0.5), "%s starts on idle" % name)
		assert_true(_same_rotation(a, a.length, idle, 0.0, bones, 0.5), "%s ends on idle" % name)
		assert_false(_same_rotation(a, hit / FPS, idle, 0.0, ["forearm.R"], 3.0), "%s strikes" % name)
	assert_true(String(_source.get("fp.bash", "")).contains("hit@"), "SOURCE fp.bash documented")


## The first content/data/<kind> row (as a Resource) that `want` accepts, else null.
func _def(kind: String, want: Callable) -> Resource:
	var dir: DirAccess = DirAccess.open("res://content/data/%s" % kind)
	if dir == null:
		return null
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for fname: String in files:
		if fname.ends_with(".tres"):
			var r: Resource = load("res://content/data/%s/%s" % [kind, fname])
			if r != null and want.call(r):
				return r
	return null


func test_item_sets() -> void:
	if not _ready_or_fail():
		return
	for set_name: String in ITEM_SETS:
		for clip: String in clips_of(set_name):
			var name: String = "%s_%s" % [set_name, clip]
			var a: Animation = _anim(name)
			if a == null:
				continue  # reported by test_every_set_has_its_clips
			for ev: Variant in ITEM_EVENTS.get(clip, []):
				var f: int = _event(name, String(ev))
				assert_true(f >= 0 and f <= roundi(a.length * FPS), "%s lists %s@ inside the clip (%d)" % [name, ev, f])
	# melee: the charge loop is seamless, starts where charge_start ends; charge_swing starts there too;
	# swings end on idle; charge_start follows MeleeDef.charge_time_s when the data exists
	var arm: Array = ["clavicle.R", "upper_arm.R", "forearm.R", "hand.R", "hand.L"]
	for set_name: String in ["melee_knife", "melee_blunt", "melee_blade", "melee_heavy"]:
		var cs: Animation = _anim("%s_charge_start" % set_name)
		var ch: Animation = _anim("%s_charge" % set_name)
		var sw: Animation = _anim("%s_charge_swing" % set_name)
		var idle: Animation = _anim("%s_idle" % set_name)
		var tap: Animation = _anim("%s_swing" % set_name)
		if cs == null or ch == null or sw == null or idle == null or tap == null:
			continue
		assert_true(_same_rotation(cs, cs.length, ch, 0.0, arm, 1.0), "%s charge_start ends on charge" % set_name)
		assert_true(_same_rotation(ch, 0.0, ch, ch.length, arm, 0.5), "%s charge loops" % set_name)
		assert_true(_same_rotation(sw, 0.0, ch, 0.0, arm, 1.0), "%s charge_swing starts from the charge" % set_name)
		assert_true(_same_rotation(tap, tap.length, idle, 0.0, arm, 1.0), "%s swing ends on idle" % set_name)
		assert_true(_same_rotation(sw, sw.length, idle, 0.0, arm, 1.0), "%s charge_swing ends on idle" % set_name)
		var frags: Array = MELEE_MATCH[set_name]
		var def: Resource = _def("melee", func(r: Resource) -> bool:
			if "anim_set" in r:
				return String(r.get("anim_set")) == set_name
			for k: Variant in frags:
				if String(r.get("id")).contains(String(k)):
					return true
			return false)
		if def != null:
			assert_near(cs.length, float(def.get("charge_time_s")), 0.02, "%s_charge_start = charge_time_s" % set_name)
	# deployables: `place` lands on DeployableDef.deploy_time_s (the hold); the item is lowered out of view
	for set_name: String in ["deploy_bag", "deploy_small", "deploy_sentry"]:
		var kinds: Array = DEPLOY_KINDS[set_name]
		var def: Resource = _def("deployables", func(r: Resource) -> bool:
			if "anim_set" in r:
				return String(r.get("anim_set")) == set_name
			return kinds.has(String(r.get("kind"))))
		var place: int = _event("%s_place" % set_name, "place")
		if def != null:
			assert_eq(place, roundi(float(def.get("deploy_time_s")) * FPS), "%s place@ = deploy_time_s" % set_name)
	# the throw releases before the follow-through and frees the gun's draw afterwards
	for clip: String in ["throw", "throw_low"]:
		var rel: int = _event("throwable_%s" % clip, "release")
		var a: Animation = _anim("throwable_%s" % clip)
		assert_true(a != null and rel > 4 and rel < roundi(a.length * FPS) - 6, "throwable_%s release@%d" % [clip, rel])
	assert_true(_event("throwable_draw", "pin_pull") > 0, "throwable_draw pin_pull@")
	for key: String in ["fp.melee", "fp.throwable", "fp.deploy"]:
		assert_true(String(_source.get(key, "")).length() > 60, "SOURCE %s documented" % key)
	_check_heavy_two_hands()


## Pose the arms at `<clip>` frame 0 and return {"weapon": Transform3D, "palm_l", "palm_r": Vector3} in skeleton
## (camera) space; the palm = the middle of hand.<s> and middle_01.<s>.
func _pose_at(clip: String) -> Dictionary:
	_player.play(StringName(clip))
	_player.seek(0.0, true)
	_player.stop()
	var out: Dictionary = {}
	out["weapon"] = _skel.get_bone_global_pose(_skel.find_bone("weapon"))
	for s: String in ["L", "R"]:
		var a: Vector3 = _skel.get_bone_global_pose(_skel.find_bone("hand.%s" % s)).origin
		var b: Vector3 = _skel.get_bone_global_pose(_skel.find_bone("middle_01.%s" % s)).origin
		out["palm_%s" % s.to_lower()] = (a + b) * 0.5
	return out


## Instantiated weapon scene + {marker name: Transform3D relative to its root}.
func _weapon_model(id: String) -> Dictionary:
	var path: String = "res://assets/weapons/wpn_%s/wpn_%s.glb" % [id, id]
	if not ResourceLoader.exists(path):
		return {}
	var root: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	add_child(root)
	var marks: Dictionary = {}
	for n: Node in root.find_children("*", "Node3D", true, false):
		marks[String(n.name)] = root.global_transform.affine_inverse() * (n as Node3D).global_transform
	return {"root": root, "marks": marks}


## Highest point (camera y) of the weapon geometry cut by the plane z = -depth within |x| < half_w.
func _cut_top(root: Node3D, weapon: Transform3D, depth: float, half_w: float) -> float:
	var top: float = -INF
	var inv: Transform3D = root.global_transform.affine_inverse()
	for mi_node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = weapon * inv * mi.global_transform
		var faces: PackedVector3Array = mi.mesh.get_faces()
		for i: int in range(0, faces.size(), 3):
			var p: Array[Vector3] = [xf * faces[i], xf * faces[i + 1], xf * faces[i + 2]]
			for e: int in 3:
				var a: Vector3 = p[e]
				var b: Vector3 = p[(e + 1) % 3]
				var da: float = a.z + depth
				var db: float = b.z + depth
				if (da < 0.0) == (db < 0.0):
					continue
				var c: Vector3 = a.lerp(b, da / (da - db))
				if absf(c.x) < half_w:
					top = maxf(top, c.y)
	return top


func test_hands_and_sights_on_the_real_models() -> void:
	if not _ready_or_fail():
		return
	for set_name: String in REF_WEAPON:
		var w: Dictionary = _weapon_model(String(REF_WEAPON[set_name]))
		if w.is_empty():
			continue
		var marks: Dictionary = w["marks"]
		var root: Node3D = w["root"]
		# the support hand's palm on LeftHandIK (hip and ADS)
		# saw: a top handle; smg (PO6-09): the cup grip sits on the short fore-end's lower-left corner, ahead of the
		# magazine (skin contact is checked by _check_support_skin_clear and ENV P's PFingerClip)
		var tol: float = 0.04 if set_name in ["saw", "smg"] else 0.03
		for clip: String in ["idle", "ads_idle"]:
			var pose: Dictionary = _pose_at("%s_%s" % [set_name, clip])
			if ONE_HAND.has(set_name):
				assert_true(_off_screen(pose["palm_l"] as Vector3), "%s_%s: one-handed, the left hand off-screen (%s)" % [
						set_name, clip, pose["palm_l"]])
			elif marks.has("LeftHandIK") and set_name != "bow":
				var lhik: Vector3 = (pose["weapon"] as Transform3D) * (marks["LeftHandIK"] as Transform3D).origin
				var d: float = (pose["palm_l"] as Vector3).distance_to(lhik)
				assert_true(d < tol, "%s_%s: left palm %.3f m from %s LeftHandIK" % [set_name, clip, d, REF_WEAPON[set_name]])
		# ADS: the AimPoint on the camera axis, in front of the eye; the stock below the eye at the near plane
		if marks.has("AimPoint") and not NO_SIGHTS.has(set_name):
			var pose: Dictionary = _pose_at("%s_ads_idle" % set_name)
			var wt: Transform3D = pose["weapon"]
			var aim: Vector3 = wt * (marks["AimPoint"] as Transform3D).origin
			assert_true(Vector2(aim.x, aim.y).length() < 0.003 and -aim.z > 0.08 and -aim.z < 0.6,
					"%s ADS: AimPoint %s on the camera axis" % [set_name, aim])
			var top: float = _cut_top(root, wt, CAMERA_NEAR, NEAR_HALF_W)
			assert_true(top <= -NEAR_HALF_H,
					"%s ADS: the weapon crosses the near plane %.3f m below the eye (<= -%.4f: never cut in view)" % [
						set_name, top, NEAR_HALF_H])
		root.queue_free()
	_player.stop()
	_check_long_gun_support_grip()
	_check_support_skin_clear()
	_check_vgrip_hands()


## D-118: `<set>_vgrip_hand` exists and its left palm sits on the foregrip mod's LeftHandIK (mounted at Underbarrel).
func _check_vgrip_hands() -> void:
	for set_name: String in VGRIP:
		var clip: String = "%s_vgrip_hand" % set_name
		assert_true(_anim(clip) != null, "%s exists" % clip)
		if _anim(clip) == null:
			continue
		var w: Dictionary = _weapon_model(String(REF_WEAPON[set_name]))
		var mod_id: String = String(VGRIP[set_name])
		var mod_path: String = "res://assets/weapons/%s/%s.glb" % [mod_id, mod_id]
		if w.is_empty() or not ResourceLoader.exists(mod_path):
			if not w.is_empty():
				(w["root"] as Node3D).queue_free()
			continue
		var marks: Dictionary = w["marks"]
		(w["root"] as Node3D).queue_free()
		var mod: Node3D = (load(mod_path) as PackedScene).instantiate() as Node3D
		# the mod's LeftHandIK is ENV B's D-118 addition: checked once their mods carry it
		var lhik: Node3D = mod.find_child("LeftHandIK", true, false) as Node3D
		assert_true(marks.has("Underbarrel"), "%s: %s has an Underbarrel mount" % [set_name, REF_WEAPON[set_name]])
		if lhik != null and marks.has("Underbarrel"):
			var target: Transform3D = (marks["Underbarrel"] as Transform3D) * lhik.transform
			var pose: Dictionary = _pose_at(clip)
			var d: float = (pose["palm_l"] as Vector3).distance_to((pose["weapon"] as Transform3D) * target.origin)
			assert_true(d < 0.03, "%s: left palm %.3f m from the foregrip's LeftHandIK" % [clip, d])
		mod.free()
	_player.stop()


## PO feedback (long-gun hold): on every set whose LeftHandIK sits centred under the fore-end (B e18011f4) the support
## hand cups it PD2-style in hip and ADS: the palm faces the gun's up axis (within 30 deg) and no finger joint is inside
## the gun's cross-section at that point (the AABB of the model's vertices within 15 mm along the barrel, inset 2 mm).
func _check_long_gun_support_grip() -> void:
	for set_name: String in REF_WEAPON:
		var w: Dictionary = _weapon_model(String(REF_WEAPON[set_name]))
		if w.is_empty():
			continue
		var marks: Dictionary = w["marks"]
		var root: Node3D = w["root"]
		if not marks.has("LeftHandIK") or absf((marks["LeftHandIK"] as Transform3D).origin.x) > 0.005:
			root.queue_free()
			continue
		var verts: PackedVector3Array = _model_verts(root)
		for clip: String in ["idle", "ads_idle"]:
			_player.play(StringName("%s_%s" % [set_name, clip]))
			_player.seek(0.0, true)
			_player.stop()
			var wt: Transform3D = _skel.get_bone_global_pose(_skel.find_bone("weapon"))
			var hand: Vector3 = _bone_pos("hand.L")
			var along: Vector3 = _bone_pos("middle_01.L") - hand
			var across: Vector3 = _bone_pos("index_01.L") - _bone_pos("pinky_01.L")
			var palm: Vector3 = along.cross(across).normalized()
			var up: Vector3 = (wt.basis * Vector3.UP).normalized()
			var ang: float = rad_to_deg(palm.angle_to(up))
			assert_true(ang <= 30.0, "%s_%s: support palm %.0f deg from the gun's up axis (<= 30)" % [set_name, clip, ang])
			var inv: Transform3D = wt.affine_inverse()
			for f: String in ["thumb", "index", "middle", "ring", "pinky"]:
				for j: int in [1, 2, 3]:
					var bone: String = "%s_0%d.L" % [f, j]
					if _skel.find_bone(bone) < 0:
						continue
					var q: Vector3 = inv * _bone_pos(bone)
					assert_false(_inside_section(verts, q), "%s_%s: %s inside %s" % [set_name, clip, bone, REF_WEAPON[set_name]])
		root.queue_free()
	_player.stop()


## PO review (lead 2026-10-14): finger / thumb SKIN, not only joints, must stay out of the gun. Every Arms vertex whose
## main bind is a left finger or thumb bone, CPU-skinned at idle 0, idle middle, ads_idle 0 and fire 2, must lie outside
## the convex hull of the reference gun's cross-section (sliced from its triangles every 4 mm along the barrel round
## LeftHandIK), 2 mm tolerance. Walking is `idle` under a whole-viewmodel bob (fp_viewmodel.gd), so idle covers it.
## PO6-09: a hull hit is only a candidate: the hull fills a section's hollows (an LMG shroud's underside, a stock's
## barrel channel), so it must also be inside the gun's real triangles (ray parity, 2 of 3 axes) and deeper than
## SKIN_DEPTH_M (ENV P's PFingerClip limit is 2 mm).
func _check_support_skin_clear() -> void:
	var arms_mi: MeshInstance3D = _skel.get_node_or_null("Arms") as MeshInstance3D
	if arms_mi == null or arms_mi.skin == null:
		return
	var verts: Array[Vector3] = []
	var bones: Array[PackedInt32Array] = []
	var weights: Array[PackedFloat32Array] = []
	var skin: Skin = arms_mi.skin
	var finger_binds: Dictionary = {}
	for i: int in skin.get_bind_count():
		var bname: String = String(skin.get_bind_name(i))
		if bname.ends_with(".L") and (bname.begins_with("thumb_") or bname.begins_with("index_") or bname.begins_with("middle_")
				or bname.begins_with("ring_") or bname.begins_with("pinky_")):
			finger_binds[i] = true
	for si: int in arms_mi.mesh.get_surface_count():
		var arr: Array = arms_mi.mesh.surface_get_arrays(si)
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bb: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ww: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var n: int = bb.size() / vv.size()
		for vi: int in vv.size():
			var best: int = 0
			for k: int in n:
				if ww[vi * n + k] > ww[vi * n + best]:
					best = k
			if finger_binds.has(bb[vi * n + best]) and ww[vi * n + best] > 0.5:
				verts.append(vv[vi])
				bones.append(bb.slice(vi * n, vi * n + n))
				weights.append(ww.slice(vi * n, vi * n + n))
	assert_true(verts.size() > 100, "support skin: %d finger / thumb vertices found" % verts.size())
	for set_name: String in REF_WEAPON:
		var w: Dictionary = _weapon_model(String(REF_WEAPON[set_name]))
		if w.is_empty():
			continue
		var marks: Dictionary = w["marks"]
		var root: Node3D = w["root"]
		if not marks.has("LeftHandIK") or absf((marks["LeftHandIK"] as Transform3D).origin.x) > 0.005:
			root.queue_free()
			continue
		var mz: float = (marks["LeftHandIK"] as Transform3D).origin.z
		var sections: Dictionary = _sections(root, mz)
		var near_tris: PackedVector3Array = _near_tris(_model_verts(root), mz)
		for pose: Array in [["idle", 0.0], ["idle", 0.5], ["ads_idle", 0.0], ["fire", 2.0 / FPS]]:
			var clip: String = "%s_%s" % [set_name, pose[0]]
			_player.play(StringName(clip))
			var t: float = float(pose[1])
			if t == 0.5:
				t = _player.current_animation_length * 0.5
			_player.seek(t, true)
			_player.stop()
			var inv: Transform3D = _skel.get_bone_global_pose(_skel.find_bone("weapon")).affine_inverse()
			var bind_xf: Array[Transform3D] = []
			for i: int in skin.get_bind_count():
				var bi: int = _skel.find_bone(String(skin.get_bind_name(i)))
				bind_xf.append(_skel.get_bone_global_pose(bi) * skin.get_bind_pose(i) if bi >= 0 else Transform3D.IDENTITY)
			var inside: int = 0
			for vi: int in verts.size():
				var p: Vector3 = Vector3.ZERO
				for k: int in bones[vi].size():
					var wk: float = weights[vi][k]
					if wk > 0.0:
						p += (bind_xf[bones[vi][k]] * verts[vi]) * wk
				var q: Vector3 = inv * p
				var key: int = roundi((q.z - mz) / 0.004)
				if not sections.has(key):
					continue
				if _inside_hull(sections[key], Vector2(q.x, q.y), 0.002) and _inside_solid(near_tris, q, SKIN_DEPTH_M):
					inside += 1
			assert_eq(inside, 0, "%s: %d finger / thumb skin vertices inside %s" % [clip, inside, REF_WEAPON[set_name]])
		root.queue_free()
	_player.stop()


## Cross-section convex hulls (x, y in weapon space) of the gun every 4 mm along the barrel within 8 cm of z = `mz`, from
## its triangle edges cut by each plane; only parts within 6 cm of the centre line (the fore-end, not a sling or bipod).
func _sections(root: Node3D, mz: float) -> Dictionary:
	var out: Dictionary = {}
	var tris: PackedVector3Array = _model_verts(root)
	for key: int in range(-20, 21):
		var z: float = mz + key * 0.004
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(0, tris.size(), 3):
			for e: int in 3:
				var a: Vector3 = tris[i + e]
				var b: Vector3 = tris[i + (e + 1) % 3]
				if (a.z - z) * (b.z - z) > 0.0 or a.z == b.z:
					continue
				var c: Vector3 = a.lerp(b, (z - a.z) / (b.z - a.z))
				if absf(c.x) < 0.06 and absf(c.y - 0.05) < 0.12:
					pts.append(Vector2(c.x, c.y))
		if pts.size() >= 3:
			out[key] = Geometry2D.convex_hull(pts)
	return out


## The triangles of `tris` (weapon space, 3 verts each) within 12 cm of LeftHandIK along the barrel.
func _near_tris(tris: PackedVector3Array, mz: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for i: int in range(0, tris.size(), 3):
		var lo: float = minf(tris[i].z, minf(tris[i + 1].z, tris[i + 2].z))
		var hi: float = maxf(tris[i].z, maxf(tris[i + 1].z, tris[i + 2].z))
		if hi > mz - 0.12 and lo < mz + 0.12:
			out.append_array([tris[i], tris[i + 1], tris[i + 2]])
	return out


## True when `q` is inside the closed triangle soup `tris` (odd ray crossings along at least 2 of the 3 axes) and more
## than `depth` from its nearest triangle.
func _inside_solid(tris: PackedVector3Array, q: Vector3, depth: float) -> bool:
	var votes: int = 0
	for d: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		var hits: int = 0
		for i: int in range(0, tris.size(), 3):
			if Geometry3D.ray_intersects_triangle(q, d, tris[i], tris[i + 1], tris[i + 2]) != null:
				hits += 1
		votes += hits % 2
	if votes < 2:
		return false
	for i: int in range(0, tris.size(), 3):
		if _tri_dist(q, tris[i], tris[i + 1], tris[i + 2]) <= depth:
			return false
	return true


## Distance from `p` to triangle a b c.
func _tri_dist(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() > 1e-18:
		var nn: Vector3 = n.normalized()
		var proj: Vector3 = p - nn * nn.dot(p - a)
		if (b - a).cross(proj - a).dot(n) >= 0.0 and (c - b).cross(proj - b).dot(n) >= 0.0 \
				and (a - c).cross(proj - c).dot(n) >= 0.0:
			return absf(nn.dot(p - a))
	return minf(Geometry3D.get_closest_point_to_segment(p, a, b).distance_to(p),
		minf(Geometry3D.get_closest_point_to_segment(p, b, c).distance_to(p),
			Geometry3D.get_closest_point_to_segment(p, c, a).distance_to(p)))


## True when the skeleton-space (camera) point `p` is outside the viewmodel camera's view (behind it or past an edge).
func _off_screen(p: Vector3) -> bool:
	var fwd: float = -p.z
	var th: float = tan(deg_to_rad(VM_FOV_DEG * 0.5))
	return fwd < 0.02 or absf(p.y) > fwd * th or absf(p.x) > fwd * th * 16.0 / 9.0


## True when `p` lies inside the closed convex polygon `hull` by more than `tol`.
func _inside_hull(hull: PackedVector2Array, p: Vector2, tol: float) -> bool:
	if not Geometry2D.is_point_in_polygon(p, hull):
		return false
	for i: int in hull.size() - 1:
		if Geometry2D.get_closest_point_to_segment(p, hull[i], hull[i + 1]).distance_to(p) <= tol:
			return false
	return true


func _bone_pos(bone: String) -> Vector3:
	return _skel.get_bone_global_pose(_skel.find_bone(bone)).origin


## Every vertex of the weapon model in its root (weapon) space.
func _model_verts(root: Node3D) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var inv: Transform3D = root.global_transform.affine_inverse()
	for mi_node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mi_node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = inv * mi.global_transform
		for v: Vector3 in mi.mesh.get_faces():
			out.append(xf * v)
	return out


## True when `q` (weapon space) is inside the AABB of the vertices within 15 mm of it along the barrel, inset 2 mm.
func _inside_section(verts: PackedVector3Array, q: Vector3) -> bool:
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for v: Vector3 in verts:
		if absf(v.z - q.z) < 0.015:
			lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
			hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.y))
	return lo.x < INF and q.x > lo.x + 0.002 and q.x < hi.x - 0.002 and q.y > lo.y + 0.002 and q.y < hi.y - 0.002


## D2-03 follow-up: the per-heister sleeve variants `char_arms_fp_<heister>` (mesh only, the clips stay in
## char_arms_fp): the same rig_arms bones / order / rests, one skinned `Arms` whose binds resolve to the same
## bones with the same bind poses as char_arms_fp's (so ENV A can put its mesh + skin on char_arms_fp's Arms),
## library materials incl. the heister's `fp_sleeve` ids (char_crew_<heister>/SOURCE.txt), <= 12k triangles.
func test_heister_sleeve_variants() -> void:
	if not _ready_or_fail():
		return
	var base_arms: MeshInstance3D = _skel.get_node_or_null("Arms") as MeshInstance3D
	assert_true(base_arms != null and base_arms.skin != null, "char_arms_fp Arms is skinned")
	if base_arms == null or base_arms.skin == null:
		return
	var base_binds: Dictionary = _binds(base_arms.skin, _skel)
	for h: String in HEISTERS:
		var id: String = "char_arms_fp_%s" % h
		var packed: PackedScene = load("res://assets/characters/%s/%s.glb" % [id, id]) as PackedScene
		assert_true(packed != null, "%s imported" % id)
		if packed == null:
			continue
		var root: Node3D = packed.instantiate() as Node3D
		var sk: Skeleton3D = root.get_node_or_null("rig_arms/Skeleton3D") as Skeleton3D
		var arms: MeshInstance3D = sk.get_node_or_null("Arms") as MeshInstance3D if sk != null else null
		assert_true(arms != null and arms.skin != null, "%s: rig_arms/Skeleton3D/Arms, skinned" % id)
		if arms == null or arms.skin == null:
			root.free()
			continue
		var players: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
		assert_true(players.is_empty() or (players[0] as AnimationPlayer).get_animation_list().is_empty(),
				"%s: mesh only, no clips" % id)
		assert_eq(sk.get_bone_count(), _skel.get_bone_count(), "%s: bone count" % id)
		for b: int in range(mini(sk.get_bone_count(), _skel.get_bone_count())):
			assert_eq(sk.get_bone_name(b), _skel.get_bone_name(b), "%s: bone %d" % [id, b])
			assert_eq(sk.get_bone_parent(b), _skel.get_bone_parent(b), "%s: parent of %s" % [id, sk.get_bone_name(b)])
			assert_true(sk.get_bone_rest(b).is_equal_approx(_skel.get_bone_rest(b)),
					"%s: rest of %s" % [id, sk.get_bone_name(b)])
		var binds: Dictionary = _binds(arms.skin, sk)
		for bone: String in binds:
			assert_true(base_binds.has(bone), "%s: bind %s exists in char_arms_fp" % [id, bone])
			if base_binds.has(bone):
				var d: Transform3D = binds[bone]
				assert_true(d.is_equal_approx(base_binds[bone]), "%s: bind pose of %s" % [id, bone])
		for b: String in ["forearm.L", "forearm.R", "hand.L", "hand.R", "index_01.R", "thumb_03.L"]:
			assert_true(binds.has(b), "%s: skinned to %s" % [id, b])
		var tris: int = 0
		var mats: Array[String] = []
		for si: int in range(arms.mesh.get_surface_count()):
			var idx: PackedInt32Array = arms.mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3
			var m: Material = arms.mesh.surface_get_material(si)
			assert_true(m != null and m.resource_path.begins_with("res://world/materials/"),
					"%s: surface %d has a library material (%s)" % [id, si, m.resource_path if m != null else "none"])
			if m != null:
				mats.append(m.resource_name.trim_prefix("M_"))
		assert_true(tris <= 12000, "%s: triangles %d <= 12000" % [id, tris])
		var g: float = _arm_weight_gradient(arms, sk)
		assert_true(g < ARM_WEIGHT_GRADIENT_MAX, "%s: arm weight gradient %.1f /m < %.0f" % [id, g, ARM_WEIGHT_GRADIENT_MAX])
		for want: String in _fp_sleeve_ids(h):
			assert_has(mats, want, "%s: fp_sleeve material %s" % [id, want])
		if h == "wren":
			assert_has(mats, "char_skin_2", "wren: bare forearm skin")
		else:
			assert_false(mats.any(func(s: String) -> bool: return s.begins_with("char_skin_")),
					"%s: gloved hands, no skin surface" % id)
		root.free()



## {bone name: bind pose} of `skin` (named binds, else bind bone indices of `sk`).
static func _binds(skin: Skin, sk: Skeleton3D) -> Dictionary:
	var out: Dictionary = {}
	for i: int in range(skin.get_bind_count()):
		var n: String = String(skin.get_bind_name(i))
		if n == "":
			n = sk.get_bone_name(skin.get_bind_bone(i))
		out[n] = skin.get_bind_pose(i)
	return out


## The library ids of `fp_sleeve` in char_crew_<h>/SOURCE.txt (descriptions such as Wren's bare cuff skipped).
static func _fp_sleeve_ids(h: String) -> Array[String]:
	var out: Array[String] = []
	var f: FileAccess = FileAccess.open("res://assets/characters/char_crew_%s/SOURCE.txt" % h, FileAccess.READ)
	if f == null:
		return out
	for line: String in f.get_as_text().split("\n"):
		if line.begins_with("fp_sleeve: "):
			var d: Variant = JSON.parse_string(line.trim_prefix("fp_sleeve: "))
			if d is Dictionary:
				for k: String in ["sleeve", "cuff", "glove"]:
					var v: String = String((d as Dictionary).get(k, ""))
					if v.begins_with("char_") and not v.contains(" "):
						out.append(v)
	return out


## characters v1.38: in every frame of every melee_heavy clip both hands hold the handle: the right palm at the item
## origin (as the one-handed sets), the left palm at item (0, HEAVY_LEFT_Y, 0) no further off it than the right.
func _check_heavy_two_hands() -> void:
	var weapon: int = _skel.find_bone("weapon")
	var worst: float = 0.0
	var where: String = ""
	var n: int = 0
	for clip: Variant in ITEM_CLIPS["melee"]:
		var name: String = "melee_heavy_%s" % clip
		var a: Animation = _anim(name)
		assert_true(a != null, "%s exists" % name)
		if a == null:
			continue
		_player.play(StringName(name))
		for f: int in range(roundi(a.length * FPS) + 1):
			_player.seek(minf(f / FPS, a.length), true)
			var w: Transform3D = _skel.get_bone_global_pose(weapon)
			var palm: Dictionary = {}
			for s: String in ["L", "R"]:
				var h: Vector3 = _skel.get_bone_global_pose(_skel.find_bone("hand.%s" % s)).origin
				var m: Vector3 = _skel.get_bone_global_pose(_skel.find_bone("middle_01.%s" % s)).origin
				palm[s] = (h + m) * 0.5
			var dl: float = (palm["L"] as Vector3).distance_to(w * Vector3(0.0, HEAVY_LEFT_Y, 0.0))
			var dr: float = (palm["R"] as Vector3).distance_to(w.origin)
			if dl - dr > worst:
				worst = dl - dr
				where = "%s f%d (left %.3f m, right %.3f m)" % [name, f, dl, dr]
			n += 1
		_player.stop()
	assert_true(n > 0, "melee_heavy frames sampled")
	assert_true(worst <= HEAVY_LEFT_TOL, "melee_heavy: the left hand stays on the handle (worst %s)" % where)
