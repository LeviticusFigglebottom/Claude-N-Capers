## characters.md v1.25 (D's fix for the PO's "inorganic" crew movement): the weapon-hold upper-body layer follows the
## gait. Over a locomotion clip it plays hold_<kind>_<gait> (walk / run / sprint / crouch, or the four start / stop
## names), frame-locked to the base clip; hold_<kind> stays the fallback when a gait clip is missing. Owner: ENV A.
class_name HoldGait
extends RefCounted

const START_STOP: Array[StringName] = [&"walk_start", &"walk_stop", &"run_start", &"run_stop"]
## The 30 f walk cycle (strafe_l / strafe_r at 18 f keep the plain hold_<kind>).
const WALK_FRAMES: int = 30
const FPS: float = 30.0


## Gait suffix for base locomotion clip `c` (&"" = the plain hold_<kind>). `frames` = the base clip's length in frames
## (strafes only gait-lock on the 30 f cycle).
static func gait_of(c: StringName, frames: int) -> StringName:
	var s: String = String(c)
	if START_STOP.has(c):
		return c
	if s == "sprint":
		return &"sprint"
	if s == "crouch_walk":
		return &"crouch"
	if s == "run" or s.begins_with("run_"):
		return &"run"
	if s.begins_with("strafe_"):
		return &"walk" if frames == WALK_FRAMES else &""
	if s == "walk" or s.begins_with("walk_"):
		return &"walk"
	return &""


## The gait-locked hold clip for `hold` (hold_<kind>) over base clip `c`, if `player` has it; else `hold`.
static func clip_for(hold: StringName, c: StringName, player: AnimationPlayer, library: String) -> StringName:
	if hold == &"" or player == null:
		return hold
	var base: Animation = player.get_animation("%s/%s" % [library, c]) if player.has_animation("%s/%s" % [library, c]) \
		else null
	var frames: int = roundi(base.length * FPS) if base != null else 0
	var g: StringName = gait_of(c, frames)
	if g == &"":
		return hold
	var want: StringName = StringName("%s_%s" % [hold, g])
	return want if player.has_animation("%s/%s" % [library, want]) else hold
