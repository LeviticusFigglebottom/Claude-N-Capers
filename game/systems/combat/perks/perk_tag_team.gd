## D-163 perk.tag_team (Buddy System; PD2 Tag Team). Owner: ENV A. Schema: B's perk_decks.md. The deck throwable
## (perk.throwable item_id throwable.gas_dispenser, ThrowableDef kind KIND) tags the teammate on the holder's aim line
## within tag_range_m (TagPairs; a miss costs nothing) for duration_s; the item recharges cooldown_s from the tag.
## While paired, each kill by the holder or the tagged teammate (CrewKillFeed) heals the holder holder_kill_heal and the
## teammate tagged_kill_heal; a holder kill extends the pair kill_extend_s; card 5: each such kill adds kill_absorb
## absorption to the holder (pool POOL, max max_absorb), kept until the item is off cooldown; card 9: a tagged
## teammate's kill cuts the cooldown tagged_kill_cooldown_cut_s. Server only; the item state goes to PerkItems (HUD).
class_name PerkTagTeam
extends PerkComponent

const KEY: StringName = &"perk.tag_team"
const KIND: StringName = &"gas_dispenser"
const POOL: StringName = &"tag_team"

## The holder's Synergy absorption now.
var absorb: float = 0.0
var _feed: CrewKillFeed = null


func use_throwable(kind: StringName) -> bool:
	var tp: TagPairs = _pairs()
	return kind == KIND and tp != null \
		and tp.tag(crew, num("tag_range_m"), num("duration_s"), num("cooldown_s")) >= 0


func tick(_delta: float) -> void:
	var rt: HeistRuntime = HeistRuntime.of(crew)
	if _feed == null:
		_feed = CrewKillFeed.of(rt)
		if _feed != null:
			_feed.crew_kill.connect(_on_crew_kill)
	var tp: TagPairs = _pairs()
	if tp == null:
		return
	var cd: float = tp.cooldown_left(_slot())
	if cd <= 0.0:
		absorb = 0.0  # Synergy lasts until the item is off cooldown
	var items: PerkItems = PerkItems.of(rt)
	if items != null:
		var left: float = float((tp.pairs.get(_slot(), {}) as Dictionary).get("left", 0.0))
		items.publish(_slot(), key, PerkItems.entry(KIND, 0 if cd > 0.0 else 1, 1, cd, left, tp.tagged_of(_slot())))



func absorb_for(target: CrewController) -> Dictionary:
	return {POOL: absorb} if target == crew and absorb > 0.0 else {}


func _on_crew_kill(killer_slot: int, _victim: int, _info: Dictionary) -> void:
	var tp: TagPairs = _pairs()
	var tagged: int = tp.tagged_of(_slot()) if tp != null else -1
	if tagged < 0 or (killer_slot != _slot() and killer_slot != tagged):
		return
	var h: CrewHealth = _health()
	if h != null:
		h.heal(num("holder_kill_heal"))
	var rt: HeistRuntime = HeistRuntime.of(crew)
	var mate: CrewController = rt.crew_controller(tagged) as CrewController if rt != null else null
	if mate != null and mate.health != null:
		mate.health.heal(num("tagged_kill_heal"))
	if num("kill_absorb") > 0.0:
		absorb = minf(absorb + num("kill_absorb"), num("max_absorb"))
	if killer_slot == _slot():
		tp.extend(_slot(), num("kill_extend_s"))
	else:
		tp.cut_cooldown(_slot(), num("tagged_kill_cooldown_cut_s"))


func _pairs() -> TagPairs:
	return TagPairs.of(HeistRuntime.of(crew)) if crew != null else null
