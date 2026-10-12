## The crew's pre-planning selection for one heist (B2-01, C3; contract docs/contracts/preplanning.md
## v1.0, D-038). Owner: ENV B. Pure logic: the single resolver from assets to a PreplanResult.
##
## A selection is {"asset": StringName, "point": StringName (&"" for crew assets), "buyer": int slot,
## or SPLIT for a voted plan}. Rules (PD2): favors are a TEAM budget per heist; each player pays for
## the assets they place from their own spending cash; at most one asset per point; an asset has a
## max count; one asset per exclusive group; vote groups (plans) hold one option, the PlanVote
## winner, whose cost is split equally among the human crew (AI never pays).
##
##   var plan := PreplanPlan.new(board, host_slot, human_slots)
##   plan.add(&"asset.ammo_bag_drop", &"pp_alley_dumpsters", 0, {0: profile.cash})  # -> &"" or a reason
##   plan.vote(0, &"asset.escape_position", &"pp_escape_side_street", {0: profile.cash})
##   var result: Dictionary = plan.apply()          # PreplanResult v1 -> options["preplan"]
##   PreplanPlan.resolve_ids(&"glasshouse", [&"asset.extra_cable_ties"])   # dev path, no UI
class_name PreplanPlan
extends RefCounted

## PreplanResult version (contract preplanning.md).
const HANDOFF_VERSION: int = 1
## Exactly the keys of a PreplanResult v1 (contract preplanning.md).
const RESULT_KEYS: Array[String] = [
	"version", "modifier_sources", "drops", "spawn_tag", "escape_tag", "force_variants", "reveals",
	"cash_spent", "plan",
]
## Buyer of a voted plan: the cost is split equally among the human crew (PlanVote.voters).
const SPLIT: int = -1

## Reasons returned by can_add/add/vote (&"" = allowed). UI text: ui.preplan.reason.<reason>.
const OK: StringName = &""
const R_UNKNOWN: StringName = &"unknown_asset"
const R_NEEDS_POINT: StringName = &"needs_point"
const R_NO_POINT: StringName = &"no_point_needed"
const R_WRONG_POINT: StringName = &"wrong_point"
const R_POINT_TAKEN: StringName = &"point_taken"
const R_MAX_COUNT: StringName = &"max_count"
const R_EXCLUSIVE: StringName = &"exclusive"
const R_FAVORS: StringName = &"favors"
const R_CASH: StringName = &"cash"
const R_NOT_VOTER: StringName = &"not_voter"

var board: PreplanBoard
var selections: Array[Dictionary] = []
var votes: PlanVote


func _init(p_board: PreplanBoard = null, host_slot: int = 0, voters: Array[int] = []) -> void:
	board = p_board
	votes = PlanVote.new(host_slot, voters)


func favors_used() -> int:
	var n: int = 0
	for s: Dictionary in selections:
		n += board.favors_of(StringName(s["asset"]))
	return n


func favors_left() -> int:
	return board.favors_budget - favors_used()


## Slots that share a voted plan's cost: the human crew (the voters), else the host alone.
func payers() -> Array[int]:
	if not votes.voters.is_empty():
		return votes.voters.duplicate()
	return [votes.host_slot] as Array[int]


## What `slot` pays for one selection. A SPLIT selection is divided equally among payers(); the
## remainder of the integer division goes to the host (or the first payer when the host is not one).
func share_of(sel: Dictionary, slot: int) -> int:
	var c: int = board.cost_of(StringName(sel["asset"]))
	var buyer: int = int(sel["buyer"])
	if buyer != SPLIT:
		return c if buyer == slot else 0
	var who: Array[int] = payers()
	if not who.has(slot):
		return 0
	var share: int = c / who.size()
	var rest_to: int = votes.host_slot if who.has(votes.host_slot) else who[0]
	return share + (c - share * who.size() if slot == rest_to else 0)


## Spending cash `slot` pays for the plan; `slot` = -1 for the whole crew.
func cash_cost(slot: int = -1) -> int:
	var n: int = 0
	for s: Dictionary in selections:
		n += board.cost_of(StringName(s["asset"])) if slot < 0 else share_of(s, slot)
	return n


## slot -> spending cash, for every slot that pays something.
func cash_by_payer() -> Dictionary:
	var slots: Array[int] = payers()
	for s: Dictionary in selections:
		var b: int = int(s["buyer"])
		if b != SPLIT and not slots.has(b):
			slots.append(b)
	slots.sort()
	var out: Dictionary = {}
	for slot: int in slots:
		var c: int = cash_cost(slot)
		if c > 0:
			out[slot] = c
	return out


func count_of(asset_id: StringName) -> int:
	var n: int = 0
	for s: Dictionary in selections:
		if StringName(s["asset"]) == asset_id:
			n += 1
	return n


## Index of the selection on `point_id` (crew assets: of `asset_id` with no point), or -1.
func index_at(point_id: StringName, asset_id: StringName = &"") -> int:
	for i: int in range(selections.size()):
		var s: Dictionary = selections[i]
		if point_id != &"" and StringName(s["point"]) == point_id:
			return i
		if point_id == &"" and StringName(s["point"]) == &"" and StringName(s["asset"]) == asset_id:
			return i
	return -1


func has(asset_id: StringName, point_id: StringName = &"") -> bool:
	var i: int = index_at(point_id, asset_id)
	return i >= 0 and StringName(selections[i]["asset"]) == asset_id


## Why `asset_id` cannot be added at `point_id` for `buyer` (OK = it can). `cash_by_slot` maps
## slot -> spending cash available; a slot not in it is not cash-checked (remote peers check their own).
func can_add(asset_id: StringName, point_id: StringName, buyer: int, cash_by_slot: Dictionary = {}) -> StringName:
	return _check(asset_id, point_id, buyer, cash_by_slot, -1)


func add(asset_id: StringName, point_id: StringName, buyer: int, cash_by_slot: Dictionary = {}) -> StringName:
	var a: PreplanAssetDef = board.asset(asset_id)
	if a != null and a.vote_group != &"":
		return vote(buyer, asset_id, point_id, cash_by_slot)
	var r: StringName = can_add(asset_id, point_id, buyer, cash_by_slot)
	if r == OK:
		selections.append({"asset": asset_id, "point": point_id, "buyer": buyer})
	return r


## Remove the selection of `asset_id` at `point_id`. A vote-group option retracts `slot`'s vote.
func remove(asset_id: StringName, point_id: StringName = &"", slot: int = -1) -> bool:
	var a: PreplanAssetDef = board.asset(asset_id)
	if a != null and a.vote_group != &"":
		votes.retract(slot if slot >= 0 else votes.host_slot, a.vote_group)
		_resolve_vote(a.vote_group)
		return true
	var i: int = index_at(point_id, asset_id)
	if i < 0 or StringName(selections[i]["asset"]) != asset_id:
		return false
	selections.remove_at(i)
	return true


## Cast `slot`'s vote for a plan option; the plan then holds the group's winner.
func vote(slot: int, asset_id: StringName, point_id: StringName, cash_by_slot: Dictionary = {}) -> StringName:
	var a: PreplanAssetDef = board.asset(asset_id)
	if a == null:
		return R_UNKNOWN
	var gi: int = _group_index(a.vote_group)
	var r: StringName = _check(asset_id, point_id, SPLIT, cash_by_slot, gi)
	if r != OK:
		return r
	if not votes.cast(slot, a.vote_group, PlanVote.option_key(asset_id, point_id)):
		return R_NOT_VOTER
	_resolve_vote(a.vote_group)
	return OK


## Every rule re-checked (the host validates a plan it receives). Empty = valid.
func validate(cash_by_slot: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var probe: PreplanPlan = PreplanPlan.new(board, votes.host_slot, votes.voters)
	for s: Dictionary in selections:
		var r: StringName = probe._check(StringName(s["asset"]), StringName(s["point"]), int(s["buyer"]), cash_by_slot, -1)
		if r != OK:
			out.append("%s@%s: %s" % [s["asset"], s["point"], r])
		probe.selections.append(s)
	return out


## The PreplanResult (contract preplanning.md, version 1) for options["preplan"]. ENV A applies it
## and never re-resolves the catalog:
## { "version": 1,
##   "modifier_sources": {asset_id: {key: value}},   # Modifiers.set_source(TEAM, asset_id, ...)
##   "drops": [{"asset", "kind": StringName, "point": point id, "params": {}}],
##   "spawn_tag": StringName,                        # &"" = default spawns
##   "escape_tag": StringName,                       # &"" = mission default
##   "force_variants": {group: [slot ids]},
##   "reveals": [group],
##   "cash_spent": {crew_slot: int},                 # already charged by ENV B (charge_profile)
##   "plan": to_dict() }                             # selections, votes, heist, difficulty, favors
func apply() -> Dictionary:
	var mods: Dictionary = {}
	var drops: Array[Dictionary] = []
	var reveals: Array[StringName] = []
	var forces: Dictionary = {}
	var spawn_tag: StringName = &""
	var escape_tag: StringName = &""
	for s: Dictionary in _sorted_selections():
		var id: StringName = StringName(s["asset"])
		var pid: StringName = StringName(s["point"])
		var a: PreplanAssetDef = board.asset(id)
		if a == null:
			continue
		var params: Dictionary = board.blueprint.point(pid).get("params", {}) as Dictionary if pid != &"" else {}
		if not a.grants.is_empty():
			mods[id] = a.grants.duplicate(true)
		if a.drop != &"":
			drops.append({"asset": id, "kind": a.drop, "point": pid, "params": a.drop_params.duplicate(true)})
		for g: StringName in a.reveals:
			if not reveals.has(g):
				reveals.append(g)
		var fv: Dictionary = a.force_variants
		if fv.is_empty() and params.has("variant_group") and params.has("variant_slot"):
			fv = {StringName(String(params["variant_group"])): [StringName(String(params["variant_slot"]))]}
		for g: Variant in fv:
			var key: StringName = StringName(String(g))
			var slots: Array = forces.get(key, []) as Array
			for sl: Variant in fv[g] as Array:
				if not slots.has(StringName(String(sl))):
					slots.append(StringName(String(sl)))
			forces[key] = slots
		var st: StringName = a.spawn_tag if a.spawn_tag != &"" else StringName(String(params.get("spawn_tag", "")))
		if st != &"":
			spawn_tag = st
		var et: StringName = a.escape_tag if a.escape_tag != &"" else StringName(String(params.get("escape_tag", "")))
		if et != &"":
			escape_tag = et
	var typed_forces: Dictionary = {}
	for g: Variant in forces:
		var slots_typed: Array[StringName] = []
		slots_typed.assign(forces[g] as Array)
		typed_forces[g] = slots_typed
	return {
		"version": HANDOFF_VERSION,
		"modifier_sources": mods,
		"drops": drops,
		"spawn_tag": spawn_tag,
		"escape_tag": escape_tag,
		"force_variants": typed_forces,
		"reveals": reveals,
		"cash_spent": cash_by_payer(),
		"plan": to_dict(),
	}


## Dev path (ENV A's `options["preplanning"]`, contract preplanning.md): a PreplanResult from asset
## ids without UI, through the same rules. An id may name its point as "asset.<id>@<point id>";
## otherwise a located asset takes the first free allowed point in blueprint order. Slot 0 buys
## everything and votes alone; nothing is charged (cash_spent is empty). Rejected ids are logged.
## When no id is accepted (none given, all unknown or refused) the result is {} = no plan, so ENV A's
## preplan stays inactive (test_c3_unknown_dev_id_ignored). Only (heist_id, ids) are required.
static func resolve_ids(heist_id: StringName, ids: Array, difficulty: int = Enums.Difficulty.ROUTINE,
		def: HeistDef = null) -> Dictionary:
	var b: PreplanBoard = PreplanBoard.build(heist_id, difficulty, def)
	var p: PreplanPlan = PreplanPlan.new(b, 0, [0] as Array[int])
	for raw: Variant in ids:
		var o: Dictionary = PlanVote.parse_option(StringName(String(raw)))
		var id: StringName = StringName(o["asset"])
		var pid: StringName = StringName(o["point"])
		var a: PreplanAssetDef = b.asset(id)
		if a != null and a.is_located() and pid == &"":
			pid = p.first_free_point(id)
		var r: StringName = p.add(id, pid, 0)
		if r != OK:
			Log.warn(&"preplan", "resolve_ids(%s): %s@%s rejected (%s)" % [heist_id, id, pid, r])
	if p.selections.is_empty():
		return {}
	var res: Dictionary = p.apply()
	res["cash_spent"] = {}
	return res


## First point (blueprint order) where `asset_id` may be added for slot 0 now, or &"".
func first_free_point(asset_id: StringName) -> StringName:
	for pid: StringName in board.blueprint.point_ids():
		var a: PreplanAssetDef = board.asset(asset_id)
		if a != null and a.vote_group != &"":
			if _check(asset_id, pid, SPLIT, {}, _group_index(a.vote_group)) == OK:
				return pid
		elif can_add(asset_id, pid, 0) == OK:
			return pid
	return &""


## Deduct `slot`'s share (own assets + its part of voted plans) from a profile's spending cash.
## Returns the amount charged (0 if it can't pay).
func charge_profile(profile: PlayerProfile, slot: int) -> int:
	var c: int = cash_cost(slot)
	if profile == null or c > profile.cash:
		return 0
	profile.cash -= c
	Career.add_spent(profile, c)
	return c


## Apply a plan-vote lobby message (Net.lobby_message, PlanVote.MSG_*) from crew `slot`. Not
## cash-checked (a peer only knows its own cash; the host re-validates on confirm). Returns the
## PreplanPlan reason (OK = applied).
func receive_vote(slot: int, kind: StringName, data: Dictionary) -> StringName:
	match kind:
		PlanVote.MSG_CAST:
			var o: Dictionary = PlanVote.parse_option(StringName(String(data.get("option", ""))))
			return vote(slot, StringName(o["asset"]), StringName(o["point"]))
		PlanVote.MSG_RETRACT:
			var g: StringName = StringName(String(data.get("group", "")))
			if not votes.voters.is_empty() and not votes.voters.has(slot):
				return R_NOT_VOTER
			votes.retract(slot, g)
			_resolve_vote(g)
			return OK
	return R_UNKNOWN


## Network / save form (JSON-safe apart from StringNames).
func to_dict() -> Dictionary:
	var sel: Array = []
	for s: Dictionary in _sorted_selections():
		sel.append({"asset": s["asset"], "point": s["point"], "buyer": s["buyer"]})
	return {
		"heist_id": board.heist_id, "difficulty": board.difficulty, "favors_budget": board.favors_budget,
		"favors_used": favors_used(), "selections": sel, "votes": votes.to_dict(),
	}


static func from_dict(p_board: PreplanBoard, d: Dictionary) -> PreplanPlan:
	var v: PlanVote = PlanVote.from_dict(d.get("votes", {}) as Dictionary)
	var p: PreplanPlan = PreplanPlan.new(p_board, v.host_slot, v.voters)
	p.votes = v
	for s: Variant in d.get("selections", []) as Array:
		var sd: Dictionary = s as Dictionary
		p.selections.append({
			"asset": StringName(String(sd.get("asset", ""))),
			"point": StringName(String(sd.get("point", ""))),
			"buyer": int(sd.get("buyer", 0)),
		})
	return p


func _check(asset_id: StringName, point_id: StringName, buyer: int, cash_by_slot: Dictionary, ignore: int) -> StringName:
	var a: PreplanAssetDef = board.asset(asset_id)
	if a == null:
		return R_UNKNOWN
	var r: StringName = _check_point(a, point_id)
	if r != OK:
		return r
	var count: int = 0
	var favors: int = 0
	var spent: Dictionary = {}
	for i: int in range(selections.size()):
		if i == ignore:
			continue
		var s: Dictionary = selections[i]
		var sid: StringName = StringName(s["asset"])
		var other: PreplanAssetDef = board.asset(sid)
		if point_id != &"" and StringName(s["point"]) == point_id:
			return R_POINT_TAKEN
		if sid == asset_id:
			count += 1
		elif other != null and _shares_group(a, other):
			return R_EXCLUSIVE
		favors += board.favors_of(sid)
		for slot: Variant in cash_by_slot:
			spent[slot] = int(spent.get(slot, 0)) + share_of(s, int(slot))
	var cash_ok: bool = true
	var candidate: Dictionary = {"asset": asset_id, "point": point_id, "buyer": buyer}
	for slot: Variant in cash_by_slot:
		if int(spent.get(slot, 0)) + share_of(candidate, int(slot)) > int(cash_by_slot[slot]):
			cash_ok = false
	return _check_limits(a, count, favors, cash_ok)


func _check_point(a: PreplanAssetDef, point_id: StringName) -> StringName:
	if not a.is_located():
		return R_NO_POINT if point_id != &"" else OK
	if point_id == &"":
		return R_NEEDS_POINT
	if board.blueprint.point(point_id).is_empty() or not a.allows_point(point_id, board.blueprint.category_of(point_id)):
		return R_WRONG_POINT
	return OK


## `count` / `favors`: copies of this asset and favors of the plan, without it; `cash_ok`: every
## cash-checked slot can pay its share with it.
func _check_limits(a: PreplanAssetDef, count: int, favors: int, cash_ok: bool) -> StringName:
	var r: StringName = OK
	if count > 0 and a.exclusive_group != &"":
		r = R_EXCLUSIVE
	elif count >= (1 if not a.is_located() else a.max_count):
		r = R_MAX_COUNT
	elif favors + a.favors > board.favors_budget:
		r = R_FAVORS
	elif not cash_ok:
		r = R_CASH
	return r


static func _shares_group(a: PreplanAssetDef, b: PreplanAssetDef) -> bool:
	if a.exclusive_group != &"" and a.exclusive_group == b.exclusive_group:
		return true
	return a.vote_group != &"" and a.vote_group == b.vote_group


func _group_index(group: StringName) -> int:
	for i: int in range(selections.size()):
		var a: PreplanAssetDef = board.asset(StringName(selections[i]["asset"]))
		if a != null and a.vote_group == group:
			return i
	return -1


func _resolve_vote(group: StringName) -> void:
	var gi: int = _group_index(group)
	if gi >= 0:
		selections.remove_at(gi)
	var w: StringName = votes.winner(group)
	if w == &"":
		return
	var o: Dictionary = PlanVote.parse_option(w)
	selections.append({"asset": o["asset"], "point": o["point"], "buyer": SPLIT})


func _sorted_selections() -> Array[Dictionary]:
	var out: Array[Dictionary] = selections.duplicate()
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var kx: String = "%s@%s" % [x["asset"], x["point"]]
		var ky: String = "%s@%s" % [y["asset"], y["point"]]
		return kx < ky)
	return out
