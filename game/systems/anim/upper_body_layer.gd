## characters.md v1.19 (D-116 weapon holds, SOURCE `weapon_holds:`): an upper-body layer over the AnimationPlayer's
## clip. After the player applies its clip (walk / run / strafe*), this modifier writes the rotations of a second clip
## (hold_rifle / hold_pistol, or aim_* while aiming) onto the filtered bones (spine, chest, neck, head, clavicles, arms,
## hands, fingers); `influence` is the layer weight (AnimDriver blends it over AnimTweak.hold_layer_blend_s). The
## legs and hips stay the locomotion clip's. Presentation only. Owner: ENV A.
class_name UpperBodyLayer
extends SkeletonModifier3D

const NODE_NAME: String = "UpperBodyLayer"
## SOURCE weapon_holds bone filter: bone names equal to or starting with these.
const BONE_PREFIXES: Array[String] = [
	"spine", "chest", "neck", "head", "clavicle.", "upper_arm.", "forearm.", "hand.", "thumb_", "index_", "middle_",
	"ring_", "pinky_",
]

## The layered clip's name (without the library), &"" when none.
var clip: StringName = &""
## Playback time in the layered clip (s), looped.
var time: float = 0.0

var _anim: Animation = null
## Pairs of (bone index, rotation track index) of the filtered bones.
var _pairs: PackedInt32Array = PackedInt32Array()


## The layer under `skeleton` (created when missing, first among the skeleton's modifiers so the hard-hat lift and
## other fix-ups run after it).
static func ensure(skeleton: Skeleton3D) -> UpperBodyLayer:
	if skeleton == null:
		return null
	var m: UpperBodyLayer = skeleton.get_node_or_null(NODE_NAME) as UpperBodyLayer
	if m == null:
		m = UpperBodyLayer.new()
		m.name = NODE_NAME
		m.influence = 0.0
		m.active = false
		skeleton.add_child(m)
		skeleton.move_child(m, 0)
	return m


## True when bone `bone_name` is in the upper-body filter.
static func filtered(bone_name: String) -> bool:
	for p: String in BONE_PREFIXES:
		if bone_name.begins_with(p):
			return true
	return false


## Layer `anim` (named `p_clip`) from `start_s`. Same clip: keeps its time.
func set_clip(p_clip: StringName, anim: Animation, start_s: float = 0.0) -> void:
	if p_clip == clip and anim == _anim:
		return
	clip = p_clip
	_anim = anim
	time = start_s
	_pairs = PackedInt32Array()
	var sk: Skeleton3D = get_skeleton()
	if anim == null or sk == null:
		return
	for t: int in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name: String = String(anim.track_get_path(t).get_concatenated_subnames())
		var b: int = sk.find_bone(bone_name)
		if b >= 0 and filtered(bone_name):
			_pairs.append(b)
			_pairs.append(t)


## Advance the layered clip by `delta` seconds (looped).
func advance(delta: float) -> void:
	if _anim != null and _anim.length > 0.0:
		time = fposmod(time + delta, _anim.length)


## Number of bones the layer drives (tests).
func bone_count() -> int:
	return _pairs.size() / 2


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or _anim == null:
		return
	for i: int in range(0, _pairs.size(), 2):
		sk.set_bone_pose_rotation(_pairs[i], _anim.rotation_track_interpolate(_pairs[i + 1], time))
