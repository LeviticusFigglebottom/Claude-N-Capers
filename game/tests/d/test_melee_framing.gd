## B's firing-range report (melee_blunt / melee_blade): in PD2 the melee weapon stays in view through the wind-up
## (raised at the right of the screen). In every frame of charge_start and charge, and of swing and charge_swing up
## to their hit@ (the follow-through may leave the bottom of the view, as in PD2), some point of the item (REACH along
## the weapon bone's +Y: butt to head) is inside the viewmodel frame (VM_FOV_DEG vertical, 16:9) by MARGIN_DEG, at
## least MIN_DEPTH in front of the eye.
## Owner: ENV D.
extends TestCase

const GLB: String = "res://assets/characters/char_arms_fp/char_arms_fp.glb"
const SOURCE: String = "res://assets/characters/char_arms_fp/SOURCE.txt"
const FPS: float = 30.0
const VM_FOV_DEG: float = 52.0
const ASPECT: float = 16.0 / 9.0
const MARGIN_DEG: float = 2.0
const MIN_DEPTH: float = 0.08
const CLIPS: Array[String] = ["swing", "charge_start", "charge", "charge_swing"]
## the item along the weapon bone +Y (m from the grip): butt, head
const REACH: Dictionary = {
	"melee_knife": Vector2(-0.03, 0.12), "melee_blunt": Vector2(-0.05, 0.35), "melee_blade": Vector2(-0.05, 0.35),
	"melee_heavy": Vector2(-0.33, 0.55),
}
## frames a clip may leave the view: melee_heavy's quick swing whips from over the shoulder into the strike in 2
## frames (67 ms; the LEAD-approved v1.38 framing)
const ALLOWED_OUT: Dictionary = {"melee_heavy_swing": 2}

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


func test_melee_item_stays_in_view() -> void:
	if _root == null or _skel == null or _player == null:
		fail("could not load %s (run godot --import first)" % GLB)
		return
	var weapon: int = _skel.find_bone("weapon")
	var tan_v: float = tan(deg_to_rad(VM_FOV_DEG / 2.0 - MARGIN_DEG))
	var tan_h: float = tan(atan(tan(deg_to_rad(VM_FOV_DEG / 2.0)) * ASPECT) - deg_to_rad(MARGIN_DEG))
	for set_name: String in REACH:
		var reach: Vector2 = REACH[set_name]
		for clip: String in CLIPS:
			var name: String = "%s_%s" % [set_name, clip]
			if not _player.has_animation(StringName(name)):
				fail("%s missing" % name)
				continue
			var a: Animation = _player.get_animation(StringName(name))
			var last: int = roundi(a.length * FPS)
			if clip.ends_with("swing"):
				last = _event(name, "hit")
				assert_true(last > 0, "%s has hit@" % name)
			var out: PackedStringArray = []
			_player.play(StringName(name))
			for f: int in range(last + 1):
				_player.seek(minf(f / FPS, a.length), true)
				var w: Transform3D = _skel.get_bone_global_pose(weapon)
				var seen: bool = false
				for k: int in 8:
					var p: Vector3 = w * Vector3(0.0, lerpf(reach.x, reach.y, k / 7.0), 0.0)
					var d: float = -p.z
					if d >= MIN_DEPTH and absf(p.x) <= d * tan_h and absf(p.y) <= d * tan_v:
						seen = true
						break
				if not seen:
					out.append("f%d" % f)
			_player.stop()
			assert_true(out.size() <= int(ALLOWED_OUT.get(name, 0)), "%s: the item is out of view in %d frame(s) %s" % [
				name, out.size(), " ".join(out)])


## The frame of `ev`@ in SOURCE's clip.<clip> row (-1 when absent).
func _event(clip: String, ev: String) -> int:
	var row: String = String(_source.get("clip.%s" % clip, ""))
	var at: int = row.find("%s@" % ev)
	if at < 0:
		return -1
	return row.substr(at + ev.length() + 1).split(",")[0].to_int()
