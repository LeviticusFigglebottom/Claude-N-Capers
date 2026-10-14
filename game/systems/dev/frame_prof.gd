## Opt-in per-system frame cost accounting (lead: find the ND wave-2 stall; any system > 2 ms/frame). Owner: ENV A.
## Off by default: `begin()` / `end()` cost one static bool check. A harness (po5 driver, perf tests) sets
## `enabled`, then reads `top()` for the frame and calls `reset_frame()`; `totals` keeps the whole run.
##   var t: int = FrameProf.begin()
##   ... work ...
##   FrameProf.end(&"npc_motor", t)
class_name FrameProf
extends RefCounted

static var enabled: bool = false
## key -> usec spent this frame (cleared by reset_frame()).
static var frame: Dictionary = {}
## key -> usec spent since enabled.
static var totals: Dictionary = {}
## key -> calls this frame.
static var calls: Dictionary = {}


## Start time for end(); 0 when disabled.
static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0


static func end(key: StringName, t0: int) -> void:
	if not enabled or t0 == 0:
		return
	var us: int = Time.get_ticks_usec() - t0
	frame[key] = int(frame.get(key, 0)) + us
	totals[key] = int(totals.get(key, 0)) + us
	calls[key] = int(calls.get(key, 0)) + 1


## The `n` most expensive keys of this frame as "key=ms(calls)", most expensive first.
static func top(n: int = 8) -> String:
	var keys: Array = frame.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(frame[a]) > int(frame[b]))
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(mini(n, keys.size())):
		parts.append("%s=%.1fms(%d)" % [keys[i], int(frame[keys[i]]) / 1000.0, int(calls.get(keys[i], 0))])
	return " ".join(parts)


static func reset_frame() -> void:
	frame.clear()
	calls.clear()
