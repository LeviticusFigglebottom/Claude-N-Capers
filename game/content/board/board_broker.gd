## The contract broker (pd2_fidelity C1; PD2: buy any contract with offshore money). Owner: ENV B.
## Pure and static: the price and the stash charge. The screen saves the profile and emits the
## contract. A bought contract is never a pro job (pro jobs only come from the Board's rotation).
##
## cost = BoardTweak.broker_cost_by_difficulty[difficulty]
##        + roundi(contract pay preview x BoardTweak.broker_cost_payout_fraction)
## Like PD2, the stash is spent when the contract is bought: backing out of the briefing afterwards
## does not refund it.
class_name BoardBroker
extends RefCounted

const OK: StringName = &""
const R_UNKNOWN_HEIST: StringName = &"unknown_heist"
const R_LOCKED: StringName = &"locked"
const R_STASH: StringName = &"stash"


## Stash cost of a contract for a heist with UNSCALED `base_payout` at `difficulty`.
static func cost(base_payout: int, difficulty: int, tweak: BoardTweak) -> int:
	var preview: int = HeistCatalog.contract_preview(base_payout, difficulty)
	return maxi(tweak.broker_base_cost(difficulty) + roundi(float(preview) * tweak.broker_cost_payout_fraction), 0)


## OK, or why `profile` cannot buy `heist_id` at `difficulty` (heist_pool = BoardContracts.pool()).
static func check(profile: PlayerProfile, heist_id: StringName, difficulty: int, heist_pool: Array[Dictionary],
		tweak: BoardTweak, build_unlocked: Callable = Callable()) -> StringName:
	var heist: Dictionary = find_heist(heist_pool, heist_id)
	if heist.is_empty():
		return R_UNKNOWN_HEIST
	var level: int = profile.level if profile != null else 0
	if not BoardContracts.allowed_difficulties(level, tweak, build_unlocked).has(difficulty):
		return R_LOCKED
	var stash: int = profile.stash if profile != null else 0
	if stash < cost(int(heist["base_payout"]), difficulty, tweak):
		return R_STASH
	return OK


## Charges the stash and returns OK, or returns the refusal reason and changes nothing.
static func buy(profile: PlayerProfile, heist_id: StringName, difficulty: int, heist_pool: Array[Dictionary],
		tweak: BoardTweak, build_unlocked: Callable = Callable()) -> StringName:
	if profile == null:
		return R_STASH
	var reason: StringName = check(profile, heist_id, difficulty, heist_pool, tweak, build_unlocked)
	if reason != OK:
		return reason
	profile.stash -= cost(int(find_heist(heist_pool, heist_id)["base_payout"]), difficulty, tweak)
	return OK


static func find_heist(heist_pool: Array[Dictionary], heist_id: StringName) -> Dictionary:
	for h: Dictionary in heist_pool:
		if StringName(h.get("id", &"")) == heist_id:
			return h
	return {}


## strings.csv key explaining a refusal (`ui.board.broker.reason.<reason>`).
static func reason_key(reason: StringName) -> StringName:
	return StringName("ui.board.broker.reason.%s" % reason)
