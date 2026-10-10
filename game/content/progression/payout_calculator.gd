## Heist payout and XP from a HeistResult (contracts/events.md). pd2_fidelity S10.4, S7.3, C6.
## Single place that applies difficulty, crew-alive, stealth and other multipliers (D-020):
## HeistResult.contract_pay and every HeistResult.loot[i].value are UNSCALED base values.
##
## compute(result, difficulty_def = null, tweak = null, is_pro = false, crew_slot = -1,
##         banked_stealth_mult = 1.0, xp_mult = 1.0) -> Dictionary
##   xp_mult             -> the player's progression.xp_mult; (xp_mult - 1) joins the additive XP line
##   difficulty_def null -> res://content/data/difficulty/<name>.tres from result.difficulty
##   tweak null          -> res://content/data/tweak/payout.tres
##   crew_slot           -> the player this payout is for (custody XP penalty, civilian penalty,
##                          crew-alive teammates). -1 = crew-wide view: civilian penalty sums every
##                          crew member's kills, no custody XP penalty, teammates = survivors - 1.
##   banked_stealth_mult -> PlayerProfile.banked_stealth_mult: the stealth bonus banked by the
##                          PREVIOUS successful stealth heist (D-022 QB-13, pd2_fidelity S11.1).
##                          Applied to this payday's XP on success only; a failure keeps the bank.
##
## Output (stable; consumed by the payday UI and SaveService.apply_heist_payout):
##   { "success": bool, "stealth": bool,
##     "contract": int,                           contract_pay x payout_mult (0 on failure)
##     "loot_lines": [{ "loot_id": StringName, "base": int, "value": int }],  value = base x payout_mult
##     "loot": int,                               sum of loot_lines.value (0 on failure)
##     "small_loot": int,                         x payout_mult if tweak.small_loot_scaled_by_difficulty
##     "civilian_penalty": int,                   kills x DifficultyDef.civilian_kill_penalty (>= 0)
##     "subtotal": int,                           contract + loot + small_loot
##     "crew_alive_mult": float,                  tweak.crew_alive_bonus_mult or 1.0
##     "gross": int,                              subtotal x crew_alive_mult
##     "total": int,                              gross - civilian_penalty (may be negative)
##     "stash": int,                              gross x stash_fraction
##     "spending": int,                           total - stash (the penalty comes out of spending)
##     "xp_lines": [{ "key": StringName, "amount": int }],  always 6 lines, C6 order (base, pro,
##                                                difficulty, custody, additive, stealth); 0 = n/a
##     "xp_total": int,                           sum of xp_lines (>= 0)
##     "stealth_bonus_consumed": bool,            success and banked_stealth_mult > 1 (bank spent)
##     "stealth_bonus_banked": float }            tweak.stealth_xp_bonus_mult on a successful stealth
##                                                heist (banked for the NEXT payday), else 1.0
##
## Rounding: every money/XP line is rounded on its own with roundi() (half away from zero), then
## lines are summed as integers. stash = roundi(gross x stash_fraction); spending absorbs the rest,
## so stash + spending == total always.
## Failed heist: no contract/loot/small-loot cash, crew-alive bonus off; civilian penalty per
## tweak.civilian_penalty_on_failure. XP base = base_xp_success x base_xp_failure_fraction (no loot
## XP); pro, difficulty and custody still apply; no crew-alive or stealth bonus, the bank is NOT
## consumed and nothing new is banked.
## Stealth bonus (S11.1, D-022 QB-13): the "stealth" XP line = running total x (banked_stealth_mult
## - 1), i.e. the bonus earned by the previous stealth heist. This heist's own stealth success only
## sets "stealth_bonus_banked"; SaveService.apply_heist_payout stores it in the profile.
## Crew-alive cash bonus: success and no crew member (human or AI) has in_custody == true.
class_name PayoutCalculator
extends RefCounted

const DEFAULT_TWEAK_PATH: String = "res://content/data/tweak/payout.tres"
const DIFFICULTY_PATH_FMT: String = "res://content/data/difficulty/%s.tres"

const XP_BASE: StringName = &"ui.results.xp.base"
const XP_PRO: StringName = &"ui.results.xp.pro"
const XP_DIFFICULTY: StringName = &"ui.results.xp.difficulty"
const XP_CUSTODY: StringName = &"ui.results.xp.custody"
const XP_ADDITIVE: StringName = &"ui.results.xp.additive"
const XP_STEALTH: StringName = &"ui.results.xp.stealth"
## C6 order. The payday UI lists xp_lines in exactly this order.
const XP_ORDER: Array[StringName] = [XP_BASE, XP_PRO, XP_DIFFICULTY, XP_CUSTODY, XP_ADDITIVE, XP_STEALTH]


static func compute(result: Dictionary, difficulty_def: DifficultyDef = null, tweak: PayoutTweak = null,
		is_pro: bool = false, crew_slot: int = -1, banked_stealth_mult: float = 1.0,
		xp_mult: float = 1.0) -> Dictionary:
	var diff: DifficultyDef = difficulty_def if difficulty_def != null else _load_difficulty(int(result.get("difficulty", 0)))
	var tw: PayoutTweak = tweak if tweak != null else _load_tweak()
	var success: bool = bool(result.get("success", false))
	var stealth: bool = bool(result.get("stealth", false))
	var crew: Array = result.get("crew", []) as Array
	var out: Dictionary = {"success": success, "stealth": stealth}
	_compute_cash(out, result, diff, tw, success, crew, crew_slot)
	_compute_xp(out, result, diff, tw, success, is_pro, crew, crew_slot, banked_stealth_mult, xp_mult)
	out["stealth_bonus_banked"] = tw.stealth_xp_bonus_mult if success and stealth else 1.0
	return out


static func _compute_cash(out: Dictionary, result: Dictionary, diff: DifficultyDef, tw: PayoutTweak,
		success: bool, crew: Array, crew_slot: int) -> void:
	var mult: float = diff.payout_mult
	var contract: int = 0
	var loot_total: int = 0
	var small: int = 0
	var loot_lines: Array[Dictionary] = []
	if success:
		contract = roundi(float(result.get("contract_pay", 0)) * mult)
		for entry: Dictionary in result.get("loot", []) as Array:
			var base: int = int(entry.get("value", 0))
			var value: int = roundi(float(base) * mult)
			loot_lines.append({"loot_id": StringName(entry.get("loot_id", &"")), "base": base, "value": value})
			loot_total += value
		small = int(result.get("small_loot", 0))
		if tw.small_loot_scaled_by_difficulty:
			small = roundi(float(small) * mult)
	var kills: int = 0
	if success or tw.civilian_penalty_on_failure:
		for member: Dictionary in crew:
			if crew_slot < 0 or int(member.get("slot", -1)) == crew_slot:
				kills += int(member.get("civilians_killed", 0))
	var penalty: int = maxi(kills * diff.civilian_kill_penalty, 0)
	var subtotal: int = contract + loot_total + small
	var crew_mult: float = tw.crew_alive_bonus_mult if success and not _anyone_in_custody(crew) else 1.0
	var gross: int = roundi(float(subtotal) * crew_mult)
	var total: int = gross - penalty
	var stash: int = roundi(float(gross) * tw.stash_fraction)
	out["contract"] = contract
	out["loot_lines"] = loot_lines
	out["loot"] = loot_total
	out["small_loot"] = small
	out["civilian_penalty"] = penalty
	out["subtotal"] = subtotal
	out["crew_alive_mult"] = crew_mult
	out["gross"] = gross
	out["total"] = total
	out["stash"] = stash
	out["spending"] = total - stash


static func _compute_xp(out: Dictionary, result: Dictionary, diff: DifficultyDef, tw: PayoutTweak,
		success: bool, is_pro: bool, crew: Array, crew_slot: int, banked_stealth_mult: float,
		xp_mult: float) -> void:
	var base: int = 0
	if success:
		var bags: int = 0
		for entry: Dictionary in result.get("loot", []) as Array:
			if not tw.xp_loot_excluded_ids.has(StringName(entry.get("loot_id", &""))):
				bags += 1
		base = tw.base_xp_success + bags * tw.xp_per_loot_bag
	else:
		base = roundi(float(tw.base_xp_success) * tw.base_xp_failure_fraction)
	var running: int = base
	var pro: int = roundi(float(running) * (tw.pro_job_xp_mult - 1.0)) if is_pro else 0
	running += pro
	var difficulty: int = roundi(float(running) * (diff.xp_mult - 1.0))
	running += difficulty
	var custody: int = 0
	if crew_slot >= 0 and _slot_in_custody(crew, crew_slot):
		custody = -roundi(float(running) * tw.custody_xp_penalty_frac)
	running += custody
	var additive: int = 0
	if success:
		var frac: float = minf(float(_surviving_teammates(crew, crew_slot, tw)) * tw.crew_alive_xp_bonus_per_teammate,
				tw.crew_alive_xp_bonus_cap)
		# progression.xp_mult (Low Profile card, +45%): PD2 adds XP percentages, so the
		# player's xp_mult - 1 joins the additive line (D-031; MULT stays a multiplier elsewhere).
		frac += maxf(xp_mult - 1.0, 0.0)
		additive = roundi(float(running) * frac)
	running += additive
	var stealth_bonus: int = 0
	var consumed: bool = success and banked_stealth_mult > 1.0
	if consumed:
		stealth_bonus = roundi(float(running) * (banked_stealth_mult - 1.0))
	running += stealth_bonus
	var amounts: Array[int] = [base, pro, difficulty, custody, additive, stealth_bonus]
	var lines: Array[Dictionary] = []
	for i: int in range(XP_ORDER.size()):
		lines.append({"key": XP_ORDER[i], "amount": amounts[i]})
	out["xp_lines"] = lines
	out["xp_total"] = maxi(running, 0)
	out["stealth_bonus_consumed"] = consumed


static func _anyone_in_custody(crew: Array) -> bool:
	for member: Dictionary in crew:
		if bool(member.get("in_custody", false)):
			return true
	return false


static func _slot_in_custody(crew: Array, crew_slot: int) -> bool:
	for member: Dictionary in crew:
		if int(member.get("slot", -1)) == crew_slot:
			return bool(member.get("in_custody", false))
	return false


static func _surviving_teammates(crew: Array, crew_slot: int, tw: PayoutTweak) -> int:
	var n: int = 0
	var self_counted: bool = false
	for member: Dictionary in crew:
		if bool(member.get("in_custody", false)):
			continue
		if bool(member.get("is_ai", false)) and not tw.crew_alive_xp_counts_ai:
			continue
		if crew_slot >= 0 and int(member.get("slot", -1)) == crew_slot:
			self_counted = true
			continue
		n += 1
	if crew_slot < 0 and n > 0 and not self_counted:
		n -= 1  # crew-wide view: survivors minus "me"
	return n


static func _load_difficulty(d: int) -> DifficultyDef:
	var keys: Array = Enums.Difficulty.keys()
	var diff_name: String = String(keys[clampi(d, 0, keys.size() - 1)]).to_lower()
	var path: String = DIFFICULTY_PATH_FMT % diff_name
	var def: DifficultyDef = null
	if ResourceLoader.exists(path):
		def = load(path) as DifficultyDef
	if def == null:
		Log.warn(&"content", "PayoutCalculator: %s missing, using x1 multipliers" % path)
		def = DifficultyDef.new()
	return def


static func _load_tweak() -> PayoutTweak:
	var tw: PayoutTweak = null
	if ResourceLoader.exists(DEFAULT_TWEAK_PATH):
		tw = load(DEFAULT_TWEAK_PATH) as PayoutTweak
	if tw == null:
		Log.warn(&"content", "PayoutCalculator: %s missing, using script defaults" % DEFAULT_TWEAK_PATH)
		tw = PayoutTweak.new()
	return tw
