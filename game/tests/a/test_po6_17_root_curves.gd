## P GN-P1 foot slide on tac_heavy breach_standback: the guide moves the root along ENV D's published root-motion
## curve (AssaultEventRunner.curve_root, AssaultEventsTweak.*_curve), not at a constant speed, so a planted foot
## stays put (< 1 cm) through breach_standback and van_exit, also on a rotated NPC. The curves match SOURCE.txt.
extends TestCase

const SOURCE: String = "res://assets/characters/char_anim_humanoid/SOURCE.txt"
const PLANT_Y_M: float = 0.005
const SLIDE_MAX_M: float = 0.01
## breach_standback: D 5e5a2567 fixed the left-foot creep (4.0 cm along the step), so it now holds SLIDE_MAX_M like
## van_exit. The old constant-speed root slid ~30 cm.
const OLD_ROOT_SLIDE_MIN_M: float = 0.2

var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await wait_frames(2)


static func _source_curve(key: String) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for line: String in FileAccess.get_file_as_string(SOURCE).split("\n"):
		if line.begins_with(key + ":"):
			var m: RegExMatch = RegEx.create_from_string("root_m=([0-9.,]+)").search(line)
			for v: String in m.get_string(1).split(","):
				out.append(v.to_float())
	return out


func test_po6_17_curves_match_source() -> void:
	var tw: AssaultEventsTweak = AssaultEventsTweak.data()
	for pair: Array in [["curve.breach_standback", tw.breach_standback_curve], ["curve.van_exit", tw.van_exit_curve]]:
		var src: PackedFloat32Array = _source_curve(String(pair[0]))
		var mine: PackedFloat32Array = pair[1]
		assert_eq(mine.size(), src.size(), "%s frame count" % pair[0])
		for i: int in mini(mine.size(), src.size()):
			assert_near(mine[i], src[i], 0.0002, "%s f%d" % [pair[0], i])


## Max horizontal drift (m) of a planted foot (near the floor) through `clip`, root moved by `curve` along `dir_local`
## (the clip's root direction in the NPC's frame), the NPC yawed `yaw`. `linear` = the old constant-speed root.
func _slide(clip: String, curve: PackedFloat32Array, dir_local: Vector3, yaw: float, linear: bool) -> float:
	var c: Node3D = (load(NpcVisuals.scene_path("tac_heavy")) as PackedScene).instantiate() as Node3D
	add_child(c)
	_nodes.append(c)
	var ap: AnimationPlayer = c.get_node(^"AnimationPlayer") as AnimationPlayer
	var sk: Skeleton3D = c.get_node(^"Skeleton3D") as Skeleton3D
	var basis: Basis = Basis(Vector3.UP, yaw)
	var from: Vector3 = Vector3(2.0, 0.0, -1.0)
	var total: float = curve[curve.size() - 1]
	var to: Vector3 = from + basis * dir_local * total
	ap.play("%s/%s" % [AnimDriver.LIBRARY, clip])
	ap.pause()
	var n: int = curve.size()
	var track: Dictionary = {"foot.L": [], "foot.R": [], "toe.L": [], "toe.R": []}
	for f: int in n:
		var t: float = float(f) / 30.0
		ap.seek(t, true)
		var root: Vector3 = AssaultEventRunner.curve_root(from, to, curve, t, 30.0)
		if linear:
			root = from.lerp(to, float(f) / float(n - 1))
		c.global_transform = Transform3D(basis, root)
		sk.force_update_all_bone_transforms()
		for foot: String in track:
			(track[foot] as Array).append(c.global_transform * sk.get_bone_global_pose(sk.find_bone(foot)).origin)
	# A foot is planted on frames where it is within PLANT_Y_M of its lowest height in the clip; across each run of
	# planted frames it must not slide horizontally.
	var worst: float = 0.0
	for foot: String in track:
		var ps: Array = track[foot]
		var low: float = INF
		for p: Vector3 in ps:
			low = minf(low, p.y)
		var anchor: Variant = null
		for p: Vector3 in ps:
			if p.y - low > PLANT_Y_M:
				anchor = null
				continue
			if anchor == null:
				anchor = p
				continue
			var a: Vector3 = anchor
			worst = maxf(worst, Vector2(p.x - a.x, p.z - a.z).length())
	return worst


func test_po6_17_breach_standback_feet_planted_rotated() -> void:
	var tw: AssaultEventsTweak = AssaultEventsTweak.data()
	for yaw: float in [0.0, deg_to_rad(37.0), deg_to_rad(-120.0)]:
		var s: float = _slide("breach_standback", tw.breach_standback_curve, Vector3.LEFT, yaw, false)
		print("[root curve] breach_standback yaw %.0f: slide %.4f m" % [rad_to_deg(yaw), s])
		assert_true(s < SLIDE_MAX_M,
			"breach_standback yaw %.0f: planted foot slides %.4f m" % [rad_to_deg(yaw), s])
	var old: float = _slide("breach_standback", tw.breach_standback_curve, Vector3.LEFT, deg_to_rad(37.0), true)
	print("[root curve] breach_standback constant-speed root (old): slide %.4f m" % old)
	assert_true(old > OLD_ROOT_SLIDE_MIN_M, "the old constant-speed root slid far more (%.3f m)" % old)
	var flipped: float = _slide("breach_standback", tw.breach_standback_curve, Vector3.RIGHT, 0.0, false)
	assert_true(flipped > 0.5, "the step is along local -X (left): +X slides %.3f m" % flipped)


func test_po6_17_van_exit_feet_planted_rotated() -> void:
	var tw: AssaultEventsTweak = AssaultEventsTweak.data()
	for yaw: float in [0.0, deg_to_rad(110.0)]:
		var s: float = _slide("van_exit", tw.van_exit_curve, Vector3.FORWARD, yaw, false)
		print("[root curve] van_exit yaw %.0f: slide %.4f m" % [rad_to_deg(yaw), s])
		assert_true(s < SLIDE_MAX_M, "van_exit yaw %.0f: planted foot slides %.4f m" % [rad_to_deg(yaw), s])
