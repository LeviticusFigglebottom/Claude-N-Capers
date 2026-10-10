## The crew's pre-planning selection for one heist (B2-01, C3). Owner: ENV B. Pure logic.
##
## A selection is {"asset": StringName, "point": StringName (&"" for crew assets), "buyer": int slot}.
## Rules (PD2): favors are a TEAM budget per heist; cash is paid by the buyer from spending cash;
## at most one asset per point; an asset has a max count; one asset per exclusive group; vote groups
## (plans) hold one option, the PlanVote winner, paid by the host (◇ ours).
##
##   var plan := PreplanPlan.new(board)
##   plan.add(&"asset.ammo_bag_drop", &"pp_alley_dumpsters", 0, {0: profile.cash})  # -> &"" or a reason
##   plan.vote(0, &"asset.escape_position", &"pp_escape_pell", {0: profile.cash})
##   var handoff: Dictionary = plan.apply()   # pure data for the host (shape: content/docs/preplanning.md)
class_name PreplanPlan
extends RefCounted

const HANDOFF_VERSION: int = 1

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


## Spending cash of the plan; `buyer` = -1 for the whole crew.
func cash_cost(buyer: int = -1) -> int:
	var n: int = 0
	for s: Dictionary in selections:
		if buyer < 0 or int(s["buyer"]) == buyer:
			n += board.cost_of(StringName(s["asset"]))
	return n


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
	var payer: int = votes.host_slot
	var r: StringName = _check(asset_id, point_id, payer, cash_by_slot, gi)
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


## Hand-off for the heist start (pure data; ENV A / the host applies it). Shape:
## { "version": 1, "heist_id", "difficulty", "favors_budget", "favors_used",
##   "cash_spent": {slot: int},
##   "modifier_sources": {&"asset.<id>": {key: value}},  # Modifiers.set_source(Modifiers.TEAM, name, grants)
##   "spawns": [{"asset", "item": deployable id, "point": PREPLAN_POINT id}],
##   "reveal_variant_groups": [StringName],
##   "force_variants": [{"asset", "group", "slot"}],
##   "player_spawn_tag": StringName (&"" = default spawns),
##   "plan": to_dict() }
func apply() -> Dictionary:
	var mods: Dictionary = {}
	var spawns: Array[Dictionary] = []
	var reveals: Array[StringName] = []
	var forces: Array[Dictionary] = []
	var spawn_tag: StringName = &""
	var cash: Dictionary = {}
	for s: Dictionary in _sorted_selections():
		var id: StringName = StringName(s["asset"])
		var pid: StringName = StringName(s["point"])
		var a: PreplanAssetDef = board.asset(id)
		if a == null:
			continue
		var buyer: int = int(s["buyer"])
		cash[buyer] = int(cash.get(buyer, 0)) + board.cost_of(id)
		var params: Dictionary = board.blueprint.point(pid).get("params", {}) as Dictionary
		match a.effect:
			PreplanAssetDef.Effect.MODIFIERS:
				mods[id] = a.grants.duplicate(true)
			PreplanAssetDef.Effect.SPAWN:
				spawns.append({"asset": id, "item": a.spawn_item, "point": pid})
			PreplanAssetDef.Effect.REVEAL:
				if not reveals.has(a.reveal_variant_group):
					reveals.append(a.reveal_variant_group)
			PreplanAssetDef.Effect.FORCE_VARIANT:
				var g: StringName = a.force_variant_group
				var sl: StringName = a.force_variant_slot
				if sl == &"":
					g = StringName(params.get("variant_group", g))
					sl = StringName(params.get("variant_slot", &""))
				forces.append({"asset": id, "group": g, "slot": sl})
			PreplanAssetDef.Effect.PLAYER_SPAWN:
				spawn_tag = StringName(params.get("spawn_tag", &""))
	return {
		"version": HANDOFF_VERSION,
		"heist_id": board.heist_id,
		"difficulty": board.difficulty,
		"favors_budget": board.favors_budget,
		"favors_used": favors_used(),
		"cash_spent": cash,
		"modifier_sources": mods,
		"spawns": spawns,
		"reveal_variant_groups": reveals,
		"force_variants": forces,
		"player_spawn_tag": spawn_tag,
		"plan": to_dict(),
	}


## Deduct `slot`'s share from a profile's spending cash. Returns the amount charged (0 if it can't pay).
func charge_profile(profile: PlayerProfile, slot: int) -> int:
	var c: int = cash_cost(slot)
	if profile == null or c > profile.cash:
		return 0
	profile.cash -= c
	return c


## Network / save form (JSON-safe apart from StringNames).
func to_dict() -> Dictionary:
	var sel: Array = []
	for s: Dictionary in _sorted_selections():
		sel.append({"asset": s["asset"], "point": s["point"], "buyer": s["buyer"]})
	return {"heist_id": board.heist_id, "difficulty": board.difficulty, "selections": sel, "votes": votes.to_dict()}


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
	var cash: int = 0
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
		if int(s["buyer"]) == buyer:
			cash += board.cost_of(sid)
	return _check_limits(a, count, favors, cash, buyer, cash_by_slot)


func _check_point(a: PreplanAssetDef, point_id: StringName) -> StringName:
	if not a.is_located():
		return R_NO_POINT if point_id != &"" else OK
	if point_id == &"":
		return R_NEEDS_POINT
	if board.blueprint.point(point_id).is_empty() or not a.allows_point(point_id, board.blueprint.category_of(point_id)):
		return R_WRONG_POINT
	return OK


## `count` / `favors` / `cash`: copies of this asset, favors of the plan and the buyer's cash, without it.
func _check_limits(a: PreplanAssetDef, count: int, favors: int, cash: int, buyer: int, cash_by_slot: Dictionary) -> StringName:
	var r: StringName = OK
	if count > 0 and a.exclusive_group != &"":
		r = R_EXCLUSIVE
	elif count >= (1 if not a.is_located() else a.max_count):
		r = R_MAX_COUNT
	elif favors + a.favors > board.favors_budget:
		r = R_FAVORS
	elif cash_by_slot.has(buyer) and cash + board.tweak.scaled_cost(a.base_cost, board.difficulty) > int(cash_by_slot[buyer]):
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
	selections.append({"asset": o["asset"], "point": o["point"], "buyer": votes.host_slot})


func _sorted_selections() -> Array[Dictionary]:
	var out: Array[Dictionary] = selections.duplicate()
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var kx: String = "%s@%s" % [x["asset"], x["point"]]
		var ky: String = "%s@%s" % [y["asset"], y["point"]]
		return kx < ky)
	return out
