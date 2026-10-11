## End-of-heist award definitions (data: res://content/data/ui/heist_awards.tres). Owner: ENV B.
## Schema and rules: content/docs/scoreboard.md. Each entry of `awards` (shown in this order):
##   {"id": "most_kills", "stat": "kills", "rule": "max" | "min" | "zero",
##    "threshold": number (optional; max: the winner needs >= it, min: <= it),
##    "min_shots": int (optional; rows with fewer shots are not candidates, for accuracy)}
## Strings: ui.awards.<id>.name and ui.awards.<id>.desc ({value}).
class_name HeistAwardTable
extends Resource

const DEFAULT_PATH: String = "res://content/data/ui/heist_awards.tres"
const RULE_MAX: StringName = &"max"
const RULE_MIN: StringName = &"min"
const RULE_ZERO: StringName = &"zero"
const RULES: Array[StringName] = [RULE_MAX, RULE_MIN, RULE_ZERO]

static var _cached: HeistAwardTable = null

@export var awards: Array[Dictionary] = []


static func load_default() -> HeistAwardTable:
	if _cached == null:
		if ResourceLoader.exists(DEFAULT_PATH):
			_cached = load(DEFAULT_PATH) as HeistAwardTable
		if _cached == null:
			Log.error(&"ui", "missing %s" % DEFAULT_PATH)
			_cached = HeistAwardTable.new()
	return _cached


## Award ids in table order.
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for a: Dictionary in awards:
		out.append(StringName(String(a.get("id", ""))))
	return out
