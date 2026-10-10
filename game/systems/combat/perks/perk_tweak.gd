## Perk-deck mechanic tunables (QB-62, P4). Owner: ENV A. Data: perk_tweak.tres.
## The deck numbers come from the `perk.*` PARAMS dicts that ENV B grants (perk_decks.md is the schema;
## game/systems/modifiers_params.md documents how ENV A reads them). `defaults` holds the value used
## when a field is MISSING from a granted dict: the card-1 value, or a neutral value (0 / 1.0 / off)
## for fields that a later card switches on, so a card-1 holder never gets a card-7 feature.
## The other exports are engine-side numbers the PARAMS schema does not carry. ◇ = design value.
class_name PerkTweak
extends Resource

const PATH: String = "res://systems/combat/perks/perk_tweak.tres"

static var _cached: PerkTweak = null

## perk key -> field -> default value.
@export var defaults: Dictionary[StringName, Dictionary] = {}

@export_group("Engine-side")
## ◇ Seconds an enemy "panics" (NpcBase.stun) from perk.muscle / perk.sociopath panic.
@export var panic_stun_s: float = 2.0
## ◇ Horizontal speed (m/s) under which a crew member counts as standing still (perk.burglar).
@export var still_speed_threshold: float = 0.3
## Cap of the summed damage reduction from all perks (PD2 caps DR well below 100%).
@export var max_damage_reduction: float = 0.9
## ◇ Target-selection weight of a perk.kingpin holder while the injector is active (draws_aggro).
@export var kingpin_aggro_mult: float = 2.0
## ◇ Radius (m) of "nearby enemies" for perk.kingpin draws_aggro.
@export var kingpin_aggro_radius_m: float = 18.0
## perk.anarchist [armor per tick, tick interval s] for an armor id missing from tick_by_armor.
@export var anarchist_fallback_tick: Vector2 = Vector2(1.0, 2.0)
## perk.ex_president bank cap for an armor id missing from max_store_by_armor.
@export var ex_president_fallback_store: float = 24.0
## Armor tier order (0 = suit .. 6 = heaviest) for perk.ex_president kill_regen_speedup (1 - tier/6).
@export var armor_tiers: Array[StringName] = []


static func data() -> PerkTweak:
	if _cached == null:
		_cached = load(PATH) as PerkTweak
		if _cached == null:
			_cached = PerkTweak.new()
	return _cached


## `params[field]`, else the tweak default for `key`, else `fallback`.
static func value(params: Dictionary, key: StringName, field: String, fallback: Variant = null) -> Variant:
	if params.has(field):
		return params[field]
	var d: Dictionary = data().defaults.get(key, {})
	return d.get(field, fallback)


## Armor tier 0..6 of `armor_id` (0 when unknown).
static func armor_tier(armor_id: StringName) -> int:
	return maxi(data().armor_tiers.find(armor_id), 0)
