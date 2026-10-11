## Contact radio line selection (B7-03; brief content/docs/radio.md). Owner: ENV B. Pure apart from the
## RandomNumberGenerator it is handed (ContactRadio passes GameRng.stream(&"radio")).
##
## For (event, speaker, heist, ctx) the candidates are, in VoiceLineTable order:
##   1. heist lines: `"heist" == heist`, plus `"objective" == ctx.objective` for radio.objective_* lines and
##      `"loot" == ctx.loot_id` when the line names a loot id;
##   2. generic lines: no "heist" and no "objective" (and no "loot").
## The heist set wins while any of its lines is off cooldown, else the generic set is used. Within the set,
## lines on their own `cooldown_s` are skipped and the last `no_repeat_depth` picks of the event are
## avoided (never all of them: with N available lines at most N - 1 are excluded).
class_name RadioLinePicker
extends RefCounted

var table: VoiceLineTable = null
var no_repeat_depth: int = 2
## line id -> time (s) it was last picked.
var _last_played: Dictionary = {}
## event -> Array of the most recent line ids picked for it (newest last).
var _recent: Dictionary = {}


func _init(p_table: VoiceLineTable = null, p_no_repeat_depth: int = 2) -> void:
	table = p_table
	no_repeat_depth = p_no_repeat_depth


## Heist lines for the fact (step 1 above), ignoring cooldowns.
func heist_lines(event: StringName, speaker: StringName, heist: StringName, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if table == null or heist == &"":
		return out
	for l: Dictionary in table.lines:
		if _base_match(l, event, speaker) and StringName(l.get("heist", &"")) == heist and _filters_match(l, ctx):
			out.append(l)
	return out


## Generic lines of `speaker` for `event` (step 2 above).
func generic_lines(event: StringName, speaker: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if table == null:
		return out
	for l: Dictionary in table.lines:
		if _base_match(l, event, speaker) and StringName(l.get("heist", &"")) == &"" \
				and not l.has("objective") and not l.has("loot"):
			out.append(l)
	return out


## The line to speak at `now_s`, or {} when every candidate is cooling down (or none exists).
## Records the pick (cooldown + no-repeat history).
func pick(event: StringName, speaker: StringName, heist: StringName, ctx: Dictionary, now_s: float,
		rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[Dictionary] = _available(heist_lines(event, speaker, heist, ctx), now_s)
	if pool.is_empty():
		pool = _available(generic_lines(event, speaker), now_s)
	if pool.is_empty():
		return {}
	pool = _fresh(pool, event)
	var line: Dictionary = pool[rng.randi_range(0, pool.size() - 1)] if pool.size() > 1 else pool[0]
	_record(line, event, now_s)
	return line


func reset() -> void:
	_last_played.clear()
	_recent.clear()


func _available(lines: Array[Dictionary], now_s: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l: Dictionary in lines:
		var id: StringName = StringName(l.get("id", &""))
		if _last_played.has(id) and now_s - float(_last_played[id]) < float(l.get("cooldown_s", 0.0)):
			continue
		out.append(l)
	return out


func _fresh(pool: Array[Dictionary], event: StringName) -> Array[Dictionary]:
	var recent: Array = _recent.get(event, []) as Array
	var depth: int = mini(no_repeat_depth, pool.size() - 1)
	if depth <= 0 or recent.is_empty():
		return pool
	var avoid: Array = recent.slice(maxi(recent.size() - depth, 0))
	var out: Array[Dictionary] = []
	for l: Dictionary in pool:
		if not avoid.has(StringName(l.get("id", &""))):
			out.append(l)
	return out if not out.is_empty() else pool


func _record(line: Dictionary, event: StringName, now_s: float) -> void:
	var id: StringName = StringName(line.get("id", &""))
	_last_played[id] = now_s
	var recent: Array = _recent.get(event, []) as Array
	recent.append(id)
	while recent.size() > maxi(no_repeat_depth, 1):
		recent.pop_front()
	_recent[event] = recent


static func _base_match(l: Dictionary, event: StringName, speaker: StringName) -> bool:
	return StringName(l.get("event", &"")) == event and StringName(l.get("speaker", &"")) == speaker


static func _filters_match(l: Dictionary, ctx: Dictionary) -> bool:
	if l.has("objective") and StringName(l["objective"]) != StringName(ctx.get("objective", &"")):
		return false
	if l.has("loot") and StringName(l["loot"]) != StringName(ctx.get("loot_id", &"")):
		return false
	return true
