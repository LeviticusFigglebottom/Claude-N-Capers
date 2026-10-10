## Direct-launch command-line flags (D-024), parsed from OS.get_cmdline_user_args(). Owner: ENV B.
##   --heist=<id> [--seed=<int>] [--difficulty=<0..5>]
## Pure and static so it is unit-testable. Unknown flags (e.g. the test runner's --dir/--filter)
## are ignored. parse() returns:
##   { "direct": bool (--heist given with a value),
##     "heist_id": StringName (&"" when absent),
##     "has_seed": bool, "seed": int (0 when absent; the caller picks a time seed),
##     "difficulty": int (Enums.Difficulty, ROUTINE when absent),
##     "errors": Array[String] (non-empty = do not launch; fall back to the main menu) }
## Heist ids are checked against the catalog by validate_heist(), which needs no scene tree either.
class_name LaunchArgs
extends RefCounted


static func parse(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {
		"direct": false, "heist_id": &"", "has_seed": false, "seed": 0,
		"difficulty": Enums.Difficulty.ROUTINE, "errors": [] as Array[String],
	}
	var errors: Array[String] = out["errors"]
	var flags: Dictionary = {}
	for a: String in args:
		if not a.begins_with("--"):
			continue
		var kv: PackedStringArray = a.substr(2).split("=", true, 1)
		flags[kv[0]] = kv[1].strip_edges() if kv.size() > 1 else null
	if flags.has("heist"):
		var h: Variant = flags["heist"]
		if h == null or String(h) == "":
			errors.append("--heist needs a value: --heist=<id>")
		else:
			out["direct"] = true
			out["heist_id"] = StringName(String(h))
	if flags.has("seed"):
		var s: Variant = flags["seed"]
		if s == null or not String(s).is_valid_int():
			errors.append("--seed needs an integer: --seed=<n>")
		else:
			out["has_seed"] = true
			out["seed"] = String(s).to_int()
	if flags.has("difficulty"):
		var d: Variant = flags["difficulty"]
		var n: int = String(d).to_int() if d != null and String(d).is_valid_int() else -1
		if n < 0 or n >= Enums.Difficulty.size():
			errors.append("--difficulty needs 0..%d, got '%s'" % [Enums.Difficulty.size() - 1, d])
		else:
			out["difficulty"] = n
	return out


## Empty when `heist_id` is one of `known_ids`, else an error message.
static func validate_heist(heist_id: StringName, known_ids: Array[StringName]) -> String:
	if known_ids.has(heist_id):
		return ""
	var names: PackedStringArray = PackedStringArray()
	for i: StringName in known_ids:
		names.append(String(i))
	return "unknown heist '%s' (known: %s)" % [heist_id, ", ".join(names)]
