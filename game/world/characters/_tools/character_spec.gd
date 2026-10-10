## Shared constants for the assembled character scenes (docs/contracts/characters.md v1.1, D-029).
## Owner: ENV D. Used by assemble_characters.gd, render_lineup.gd and game/tests/d/test_scenes.gd.
## Load it with `preload("res://world/characters/_tools/character_spec.gd")`; there is no class_name,
## so headless `--script` runs work without the global class cache.
extends RefCounted

const ASSETS_DIR: String = "res://assets/characters/"
const OUT_DIR: String = "res://world/characters/"
const ANIM_ASSET: String = "char_anim_humanoid"
const ANIM_GLB: String = "res://assets/characters/char_anim_humanoid/char_anim_humanoid.glb"
const ANIM_SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
const ANIM_LIBRARY_PATH: String = "res://world/characters/anim_humanoid.res"
const ANIM_LIBRARY_NAME: StringName = &"humanoid"
const INDEX_PATH: String = "res://world/characters/characters.json"

## Asset folders `char_<x>` that are NOT characters: animation source, first-person arms, masks
## and the test bodies. Everything else under assets/characters/ named `char_<id>` whose
## `char_<id>.glb` contains a Skeleton3D is assembled into world/characters/<id>/<id>.tscn.
const EXCLUDE_PREFIXES: Array[String] = ["char_anim_", "char_arms_", "char_mask_", "char_body_base"]
## Test fixtures assembled anyway (asset id -> scene path), flagged `"test": true` in the index.
const TEST_SCENES: Dictionary = {
	"char_body_base": "res://world/characters/_test/body_base.tscn",
}

## Looped clips (the `*` names in characters.md). Fallback only: the tool prefers a `loops:` line in
## char_anim_humanoid/SOURCE.txt, then `LOOPS` in tools/blender/characters/anim_humanoid.py.
const DEFAULT_LOOPS: Array[String] = [
	"idle", "idle_alert", "walk", "run", "sprint", "crouch_idle", "crouch_walk", "strafe_l", "strafe_r",
	"walk_back", "aim_rifle", "aim_pistol", "kneel_cuffed", "hands_up", "cower", "lie_down", "tied",
	"flee", "phone_call", "pager_answer", "investigate_look", "smoke", "lean_wall", "sit_chair",
	"desk_type", "browse", "downed", "tased", "shield_walk", "dozer_walk", "climb_ladder",
	"carry_bag_walk", "interact_low", "interact_mid", "interact_high",
]

## Clips ENV A needs in P1 (checked by test_scenes.gd once the animation glb exists).
const P1_CLIPS: Array[String] = [
	"idle", "walk", "run", "crouch_idle", "crouch_walk", "aim_pistol", "aim_rifle", "fire_pistol",
	"fire_rifle", "reload_pistol", "reload_rifle", "death_front", "death_back", "hit_react", "cower",
	"hands_up", "lie_down", "tied", "flee", "phone_call", "radio_call", "pager_answer", "downed",
	"carry_bag_walk", "throw_bag", "interact_low", "interact_mid", "interact_high",
]

## Attachment markers: BoneAttachment3D name -> bone (children of Skeleton3D).
const MARKERS: Dictionary = {
	"HandR": "hand.R",
	"HandL": "hand.L",
	"Head": "head",
	"Back": "chest",
	"Hip": "hips",
}
## Each marker has one child Marker3D with this name at the attach point (a BoneAttachment3D's own
## transform is overwritten by the bone pose every frame, so the offset lives on the child).
const SOCKET_NAME: String = "Socket"

## Default socket points in Godot character space (metres, rest A-pose, 1.78 m body), scaled by
## head height. Measured from tools/blender/characters/_rig.py joints() and _body.py:
## * Head: face centre = midway between the eye centres (eye.L/R) at cornea depth (eye centre
##   -0.0645 m + EYE_RADIUS 0.0122 m), the mask pivot of tools/blender/masks/_mask_base.py.
## * Back: behind the chest on the spine line, ~17 mm off the bare back surface (bag pivot).
## * Hip: right side of the belt (pager/radio).
## Outfit SOURCE.txt may override any of them with `attach_<head|hand_r|hand_l|back|hip>: [x, y, z]`
## in the same space at the asset's own height (not rescaled).
const SOCKET_POINTS: Dictionary = {
	"Head": Vector3(0.0, 1.666, -0.0767),
	"Back": Vector3(0.0, 1.30, 0.12),
	"Hip": Vector3(0.17, 1.00, 0.0),
}
## Hand sockets in hand-bone-local space (1.78 m; origin scaled by height): the weapon origin and
## axes (X right, Y up, -Z muzzle) the animation solver puts in the fist, i.e.
## `_anim.grip_offset_godot()` in tools/blender/characters (18-degree grip rake). The assembly
## re-reads them from python when it can; these are the values at the time of writing.
const HAND_SOCKETS: Dictionary = {
	"HandR": Transform3D(Basis(Vector3(0.0, 0.0, 1.0), Vector3(-0.9510565, -0.3090170, 0.0),
		Vector3(0.3090170, -0.9510565, 0.0)), Vector3(-0.012, 0.0587512, -0.03)),
	"HandL": Transform3D(Basis(Vector3(0.0, 0.0, -1.0), Vector3(0.9510565, -0.3090170, 0.0),
		Vector3(-0.3090170, -0.9510565, 0.0)), Vector3(0.012, 0.0587512, -0.03)),
}
const SOURCE_KEYS: Dictionary = {
	"HandR": "attach_hand_r",
	"HandL": "attach_hand_l",
	"Head": "attach_head",
	"Back": "attach_back",
	"Hip": "attach_hip",
}
## Head bone height at the 1.78 m default; the socket points are scaled by head_y / this.
const DEFAULT_HEAD_Y: float = 1.585
## The animation generator, relative to the repository root (outside res://).
const ANIM_PY: String = "tools/blender/characters/anim_humanoid.py"


## The 52 contract bones in generator order (parents first).
static func contract_bones() -> Array[String]:
	var fingers: Array[String] = ["thumb", "index", "middle", "ring", "pinky"]
	var out: Array[String] = ["root", "hips", "spine", "chest", "neck", "head"]
	for s: String in ["L", "R"]:
		for b: String in ["clavicle", "upper_arm", "forearm", "hand"]:
			out.append("%s.%s" % [b, s])
		for f: String in fingers:
			for i: int in [1, 2, 3]:
				out.append("%s_0%d.%s" % [f, i, s])
	for s: String in ["L", "R"]:
		for b: String in ["thigh", "shin", "foot", "toe"]:
			out.append("%s.%s" % [b, s])
	return out


## Socket basis in the bone's local space for the non-hand sockets: character space at rest
## (+Y up, -Z forward).
static func socket_basis(bone_global_rest: Basis) -> Basis:
	return bone_global_rest.inverse()


## Hand sockets (see HAND_SOCKETS) from `_anim.grip_offset_godot()` via python3, else the constants.
## Returns [Dictionary marker -> Transform3D, source description].
static func hand_sockets() -> Array:
	var repo: String = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	if FileAccess.file_exists(repo.path_join("tools/blender/characters/_anim.py")):
		var code: String = "import sys, json; sys.path[:0] = [sys.argv[1] + '/tools/blender', " + \
			"sys.argv[1] + '/tools/blender/characters']; import _anim as A; sk = A.Skeleton.humanoid(); " + \
			"print(json.dumps({s: A.grip_offset_godot(sk, s) for s in 'RL'}))"
		var lines: Array = []
		if OS.execute("python3", ["-c", code, repo], lines, false) == 0 and not lines.is_empty():
			var data: Variant = JSON.parse_string(String(lines[0]).strip_edges())
			var out: Dictionary = {}
			if data is Dictionary:
				for sfx: String in ["R", "L"]:
					var t: Transform3D = _xform_from_json((data as Dictionary).get(sfx))
					if t != Transform3D():
						out["Hand" + sfx] = t
			if out.size() == 2:
				return [out, "tools/blender/characters/_anim.py grip_offset_godot (python)"]
	return [HAND_SOCKETS.duplicate(), "CharacterSpec.HAND_SOCKETS"]


## [[x, y, z], origin] as written by grip_offset_godot -> Transform3D (zero Transform3D on error).
static func _xform_from_json(v: Variant) -> Transform3D:
	if not v is Array or (v as Array).size() != 2:
		return Transform3D()
	var cols: Variant = v[0]
	var o: Variant = v[1]
	if not cols is Array or (cols as Array).size() != 3 or not o is Array or (o as Array).size() != 3:
		return Transform3D()
	var vs: Array[Vector3] = []
	for c: Variant in cols:
		if not c is Array or (c as Array).size() != 3:
			return Transform3D()
		vs.append(Vector3(float(c[0]), float(c[1]), float(c[2])))
	return Transform3D(Basis(vs[0], vs[1], vs[2]), Vector3(float(o[0]), float(o[1]), float(o[2])))


## `char_security_officer` -> `security_officer`.
static func character_id(asset_id: String) -> String:
	return asset_id.trim_prefix("char_")


## `security_officer` -> `SecurityOfficer`.
static func root_name(char_id: String) -> String:
	return char_id.to_pascal_case()


static func scene_path(asset_id: String) -> String:
	if TEST_SCENES.has(asset_id):
		return TEST_SCENES[asset_id]
	var cid: String = character_id(asset_id)
	return "%s%s/%s.tscn" % [OUT_DIR, cid, cid]


static func is_excluded(asset_id: String) -> bool:
	if not asset_id.begins_with("char_"):
		return true
	for p: String in EXCLUDE_PREFIXES:
		if asset_id.begins_with(p):
			return true
	return false


## The index written by assemble_characters.gd: Array of {id, asset, scene, test}.
static func read_index() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(INDEX_PATH):
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not data is Dictionary:
		return out
	var chars: Variant = (data as Dictionary).get("characters", [])
	if chars is Array:
		for e: Variant in chars:
			if e is Dictionary:
				out.append(e as Dictionary)
	return out


## `key: value` lines of a SOURCE.txt (first ': ' splits). Missing file -> empty.
static func read_source(path: String) -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		return out
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var i: int = line.find(": ")
		if i <= 0:
			continue
		out[line.substr(0, i).strip_edges()] = line.substr(i + 2).strip_edges()
	return out


## Looped clip names: a `loops:` line in char_anim_humanoid/SOURCE.txt (JSON array or comma/space
## separated) wins, then `LOOPS` of tools/blender/characters/anim_humanoid.py (imported with
## python3, or its quoted names read from the source if python fails), then DEFAULT_LOOPS (the `*`
## names of characters.md).
static func loop_names() -> Array[String]:
	return _loops()[0]


## Where loop_names() got its list from (for logs).
static func loop_names_source() -> String:
	return _loops()[1]


static func _loops() -> Array:
	var src: Dictionary = read_source(ANIM_SOURCE)
	if src.has("loops"):
		var out: Array[String] = parse_names(String(src["loops"]))
		if not out.is_empty():
			return [out, ANIM_SOURCE]
	var repo: String = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var py: String = repo.path_join(ANIM_PY)
	if FileAccess.file_exists(py):
		var code: String = "import sys; sys.path[:0] = [sys.argv[1] + '/tools/blender', " + \
			"sys.argv[1] + '/tools/blender/characters']; import anim_humanoid as a; print(' '.join(sorted(a.LOOPS)))"
		var lines: Array = []
		if OS.execute("python3", ["-c", code, repo], lines, false) == 0 and not lines.is_empty():
			var out2: Array[String] = parse_names(String(lines[0]))
			if not out2.is_empty():
				return [out2, ANIM_PY + " (python)"]
		var re: RegEx = RegEx.create_from_string("(?ms)^LOOPS\\b[^=\\n]*=(.*?)^\\S")
		var m: RegExMatch = re.search(FileAccess.get_file_as_string(py) + "\nEND")
		if m != null:
			var out3: Array[String] = []
			var q: RegEx = RegEx.create_from_string("[\"']([A-Za-z0-9_]+)[\"']")
			for qm: RegExMatch in q.search_all(m.get_string(1)):
				if not out3.has(qm.get_string(1)):
					out3.append(qm.get_string(1))
			if not out3.is_empty():
				out3.sort()
				return [out3, ANIM_PY + " (source)"]
	return [DEFAULT_LOOPS.duplicate(), "CharacterSpec.DEFAULT_LOOPS"]


## Identifier-like words of `text` in order, without duplicates (`"a", "b"` / `a, b` / `["a"]`).
static func parse_names(text: String) -> Array[String]:
	var out: Array[String] = []
	var re: RegEx = RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*")
	for m: RegExMatch in re.search_all(text):
		var s: String = m.get_string()
		if not out.has(s):
			out.append(s)
	return out
