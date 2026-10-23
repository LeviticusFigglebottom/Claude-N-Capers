## D-162 perk.maniac (Frenzy; PD2 Maniac). Owner: ENV A. Schema: B's perk_decks.md. Damage the holder deals becomes
## Hysteria stacks (x conversion, at most gain_cap per gain_window_s, up to max_stacks); every decay_interval_s the stacks
## lose decay_fraction of themselves + decay_flat. Every stacks_per_absorb stacks give 1 flat damage absorption (display
## units) off each hit taken: the holder x self_absorb_mult (Insanity); with `team` (Outburst) every teammate gets the
## best sharing holder's absorb (they do not stack): the generic PerkComponent.absorb_for, pool POOL. Stacks replicate per holder (META on
## the CrewController, HeistNetSync SVC_MANIAC) for the HUD.
class_name PerkManiac
extends PerkComponent

const KEY: StringName = &"perk.maniac"
const META: StringName = &"maniac_stacks"
## Absorb pool: several Hysteria holders never stack (the best one counts).
const POOL: StringName = &"hysteria"

var stacks: float = 0.0
var _gained: float = 0.0
var _gain_left: float = 0.0
var _decay_left: float = 0.0


func on_damage_dealt(_victim: Node, info: Dictionary) -> void:
	var gain: float = float(info.get("amount", 0.0)) * num("conversion")
	gain = minf(gain, maxf(num("gain_cap") - _gained, 0.0))
	if gain <= 0.0:
		return
	if _gain_left <= 0.0:
		_gain_left = num("gain_window_s")
	_gained += gain
	stacks = minf(stacks + gain, num("max_stacks"))
	crew.set_meta(META, stacks)


func tick(delta: float) -> void:
	if _gain_left > 0.0:
		_gain_left -= delta
		if _gain_left <= 0.0:
			_gained = 0.0
	if stacks <= 0.0:
		_decay_left = num("decay_interval_s")
		return
	_decay_left -= delta
	if _decay_left <= 0.0:
		_decay_left = num("decay_interval_s")
		stacks = maxf(stacks - stacks * num("decay_fraction") - num("decay_flat"), 0.0)
		crew.set_meta(META, stacks)


## Flat absorb these stacks give (no self mult).
func base_absorb() -> float:
	var per: float = num("stacks_per_absorb")
	return floorf(stacks / per) if per > 0.0 else 0.0


## D-163 generic absorb: the holder's own stacks x self_absorb_mult, a teammate the base absorb with `team`.
func absorb_for(target: CrewController) -> Dictionary:
	if target == crew:
		return {POOL: base_absorb() * num("self_absorb_mult")}
	if bool(param("team", false)):
		return {POOL: base_absorb()}
	return {}


## Hysteria stacks of `c` on any peer (the replicated META).
static func stacks_of(c: Node) -> float:
	return float(c.get_meta(META, 0.0)) if c != null else 0.0
