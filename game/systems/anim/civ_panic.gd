## D-116 civ panic variants (ENV D SOURCE `civ_panic_variants`) for AnimDriver. Owner: ENV A. Presentation only.
## The cower / flee variants themselves are AnimDriver.VARIANT_GROUPS (one index per body, hash(net_id) % 3, as the
## surrender groups). This helper adds `panic_start` (24 f one-shot, in place, idle f0 -> cower f0): played once per
## civilian, before its first cower* (lead fix: CivilianBrain always flees or runs to call first, then cowers on
## arrival / a stalled flee / in place with no way out, so a first flee* no longer uses it up; a seated civilian's
## cower_seated and a cower point's cower_stand are not cower*, so they never play it). Crossfades: ~0.1 s in from
## the clip before (ambient or flee*), then cower with no crossfade (the exact chain), cower_b 0.2 s, cower_c 0.3 s,
## flee* 0.2 s (it set off running again). A rig without panic_start goes straight to cower* as before. The host
## picks it from the clip the driver chooses and sends it (NetOneshot, npc_oneshot); a client plays it only on that
## cue (start_net), never from its own alert-state cower guess.
class_name CivPanic
extends RefCounted

const PANIC_START: StringName = &"panic_start"
## Death by pose for panic_start: from this clip time on (s, ~f10 at 30 fps) the body is low enough for death_crouch.
const CROUCH_DEATH_FROM_S: float = 10.0 / 30.0
## Crossfades (s) out of panic_start by target clip (AnimDriver._apply), and into it.
const BLEND_IN_S: float = 0.1
const BLEND_OUT: Dictionary = {&"cower": 0.0, &"cower_b": 0.2, &"cower_c": 0.3}
const BLEND_TO_FLEE_S: float = 0.2

## True once this body has panicked (panic_start played or skipped); seconds of panic_start left.
var done: bool = false
var left: float = 0.0

var _d: AnimDriver = null


func _init(driver: AnimDriver) -> void:
	_d = driver


## The VARIANT_GROUPS family of `c`: &"cower" / &"flee", or &"".
static func family(c: StringName) -> StringName:
	var s: String = String(c)
	if s == "cower" or s == "cower_b" or s == "cower_c":
		return &"cower"
	if s == "flee" or s == "flee_b" or s == "flee_c":
		return &"flee"
	return &""


## Once per tick with the clip the driver chose: panic_start while it runs (or on the first cower*), else `want`.
func apply(want: StringName, delta: float) -> StringName:
	var npc: NpcBase = _d._npc
	if npc == null or npc.role != &"civilian" or not npc.alive:
		left = 0.0
		return want
	var fam: StringName = family(want)
	if left > 0.0:
		left = maxf(left - delta, 0.0)
		if left > 0.0 and fam != &"flee" and _d.horizontal_speed() <= AnimTweak.data().move_threshold_mps:
			return PANIC_START
		left = 0.0  # it ran out, or the civilian set off running: the chosen clip takes over
		return want
	if done or fam != &"cower":
		return want  # a flee* first does not use it up: the real brain always runs before it cowers
	done = true
	if not _d._has_clip(PANIC_START) or not Net.is_authority():
		return want  # a client plays panic_start only on the host's npc_oneshot (start_net)
	left = _length()
	NetOneshot.relay(_d, PANIC_START, 0.0, 1.0)
	return PANIC_START


## Client: the host's npc_oneshot panic_start (started `start_s` s into the clip on the host): play it now, once.
func start_net(start_s: float) -> void:
	var npc: NpcBase = _d._npc
	if npc == null or npc.role != &"civilian" or not npc.alive or not _d._has_clip(PANIC_START):
		return
	done = true
	left = maxf(_length() - maxf(start_s, 0.0), 0.0)


func _length() -> float:
	return _d.player.get_animation("%s/%s" % [AnimDriver.LIBRARY, PANIC_START]).length


## The crossfade (s) from clip `from` to `to` for the panic chain, or -1 (the driver's usual blend).
static func blend(from: StringName, to: StringName) -> float:
	if to == PANIC_START:
		return BLEND_IN_S
	if from != PANIC_START:
		return -1.0
	if BLEND_OUT.has(to):
		return float(BLEND_OUT[to])
	return BLEND_TO_FLEE_S if family(to) == &"flee" else -1.0


## Whether `to` starts on its frame 0 after `from` (panic_start -> cower: the exact chain, no loop offset).
static func chained(from: StringName, to: StringName) -> bool:
	return from == PANIC_START and to == &"cower"


## Death by pose for a body killed during panic_start: death_crouch from ~f10 (when the rig has it), else &"".
func death_clip() -> StringName:
	var player: AnimationPlayer = _d.player
	if player == null or String(player.current_animation) != "%s/%s" % [AnimDriver.LIBRARY, PANIC_START]:
		return &""
	if player.current_animation_position < CROUCH_DEATH_FROM_S or not _d._has_clip(&"death_crouch"):
		return &""
	return &"death_crouch"
