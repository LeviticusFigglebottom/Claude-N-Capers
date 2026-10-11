## PD2-style end-of-heist "best of" awards from per-crew stats (B6-02; content/docs/scoreboard.md). Owner: ENV B.
## Pure: compute(crew_rows, table) -> Array[Dictionary], one entry per award that has a winner, in table order:
##   {"id": StringName, "stat": StringName, "value": float (accuracy as a 0..100 percentage),
##    "slots": Array[int] (winners), "name_key": StringName, "desc_key": StringName}
## `crew_rows` are HeistResult.crew rows (or LocalHudModel.crew_stats rows); see CrewStats for the keys.
## Rules:
##   * Candidates are the rows that carry the award's stat (CrewStats.has_stat); no candidate = no award,
##     so an award over a counter ENV A does not send yet (shots / hits / headshots) is skipped.
##   * "max" / "min": the best value wins; `threshold` must be met (max: >=, min: <=) or there is no award.
##     TIE-BREAK (one winner): human players before Crew AI, then the lowest crew slot.
##   * "zero": shared; every candidate whose value is 0 wins (listed by slot); nobody at 0 = no award.
class_name HeistAwards
extends RefCounted


static func compute(crew_rows: Array, table: HeistAwardTable = null) -> Array[Dictionary]:
	var t: HeistAwardTable = table if table != null else HeistAwardTable.load_default()
	var out: Array[Dictionary] = []
	var rows: Array[Dictionary] = CrewStats.by_slot(crew_rows)
	for def: Dictionary in t.awards:
		var award: Dictionary = evaluate(def, rows)
		if not award.is_empty():
			out.append(award)
	return out


## One award definition over `rows` ({} = not awarded).
static func evaluate(def: Dictionary, rows: Array[Dictionary]) -> Dictionary:
	var stat: StringName = StringName(String(def.get("stat", "")))
	var rule: StringName = StringName(String(def.get("rule", "")))
	var candidates: Array[Dictionary] = _candidates(def, rows, stat)
	if candidates.is_empty() or not HeistAwardTable.RULES.has(rule):
		return {}
	var winners: Array[Dictionary] = []
	var best: float = 0.0
	if rule == HeistAwardTable.RULE_ZERO:
		for r: Dictionary in candidates:
			if is_zero_approx(CrewStats.value(r, stat)):
				winners.append(r)
	else:
		var want_max: bool = rule == HeistAwardTable.RULE_MAX
		best = CrewStats.value(candidates[0], stat)
		for r: Dictionary in candidates:
			var v: float = CrewStats.value(r, stat)
			best = maxf(best, v) if want_max else minf(best, v)
		if def.has("threshold") and not _meets(best, float(def["threshold"]), want_max):
			return {}
		for r: Dictionary in candidates:
			if is_equal_approx(CrewStats.value(r, stat), best):
				winners.append(r)
		winners.sort_custom(tie_break_less)
		winners = [winners[0]]
	if winners.is_empty():
		return {}
	var slots: Array[int] = []
	for w: Dictionary in winners:
		slots.append(CrewStats.slot_of(w))
	var id: String = String(def.get("id", ""))
	return {"id": StringName(id), "stat": stat, "value": best * 100.0 if stat == CrewStats.ACCURACY else best,
			"slots": slots, "name_key": StringName("ui.awards.%s.name" % id), "desc_key": StringName("ui.awards.%s.desc" % id)}


## Tie-break order: human players before Crew AI, then the lowest crew slot.
static func tie_break_less(a: Dictionary, b: Dictionary) -> bool:
	if CrewStats.is_ai(a) != CrewStats.is_ai(b):
		return not CrewStats.is_ai(a)
	return CrewStats.slot_of(a) < CrewStats.slot_of(b)


static func _candidates(def: Dictionary, rows: Array[Dictionary], stat: StringName) -> Array[Dictionary]:
	var min_shots: float = float(def.get("min_shots", 0))
	var out: Array[Dictionary] = []
	for r: Dictionary in rows:
		if not CrewStats.has_stat(r, stat):
			continue
		if min_shots > 0.0 and CrewStats.value(r, CrewStats.SHOTS) < min_shots:
			continue
		out.append(r)
	return out


static func _meets(best: float, threshold: float, want_max: bool) -> bool:
	return best >= threshold if want_max else best <= threshold
