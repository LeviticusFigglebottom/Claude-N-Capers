## Base of one perk-deck signature mechanic (QB-62, P4). Owner: ENV A. One subclass per `perk.*` PARAMS
## key; CrewPerks (the per-crew dispatcher) creates the component while Modifiers.params(slot, KEY) is
## non-empty and routes the hooks below to it. Every number comes from `params` (the granted dict) via
## num()/param(), falling back to PerkTweak.defaults[KEY]. Server-authoritative: CrewPerks only routes
## gameplay events on the authority. Schemas: game/systems/modifiers_params.md.
class_name PerkComponent
extends RefCounted

## The `perk.*` key this component implements (set by CrewPerks).
var key: StringName = &""
var crew: CrewController = null
## The granted PARAMS dict.
var params: Dictionary = {}

var _immunity_cd: float = 0.0


func setup(p_crew: CrewController, p_key: StringName, p_params: Dictionary) -> void:
	crew = p_crew
	key = p_key
	params = p_params


## A field of the granted dict, else the PerkTweak default.
func param(field: String, fallback: Variant = null) -> Variant:
	return PerkTweak.value(params, key, field, fallback)


func num(field: String) -> float:
	return float(param(field, 0.0))


# --- Hooks (override as needed) -----------------------------------------------------------------

## Max health after this perk. `raw_armor` = the armor before any perk (ArmorDef x defense.armor_mult).
func adjust_max_health(value: float, _raw_armor: float) -> float:
	return value


## Max armor after this perk. `raw_health` = the health before any perk.
func adjust_max_armor(value: float, _raw_health: float) -> float:
	return value


## Fraction 0..1 of incoming damage removed (summed over perks, capped by PerkTweak).
func damage_reduction(_info: Dictionary) -> float:
	return 0.0


## Incoming damage after damage reduction, before armor; returns the part that applies now.
func incoming(_info: Dictionary, dmg: float) -> float:
	return dmg


## After a hit landed on the holder (out = final DamageInfo with armor_damage / health_damage).
func after_hit(_out: Dictionary) -> void:
	pass


## Authority tick while the holder is NORMAL (not downed / custody / tased).
func tick(_delta: float) -> void:
	pass


## True: this perk replaces CrewHealth's delayed full armor regen.
func handles_armor_regen() -> bool:
	return false


## The holder damaged an NPC (`victim`), `info` = its final DamageInfo.
func on_damage_dealt(_victim: Node, _info: Dictionary) -> void:
	pass


## The holder killed an NPC.
func on_kill(_victim: Node, _info: Dictionary) -> void:
	pass


## The holder picked up `amount` rounds from an ammo pickup.
func on_ammo_picked(_amount: int) -> void:
	pass


func dodge_add() -> float:
	return 0.0


## Enemy target-selection weight on the holder (> 1 = targeted more); `_from` = the choosing NPC.
func aggro_mult(_from: Node3D) -> float:
	return 1.0


func melee_damage_mult() -> float:
	return 1.0


## The deck throwable of `kind` (ThrowableDef.kind) was used; true when this perk consumed it.
## D-163: the holder dodged a hit (CrewHealth: dodge roll or smoke avoid).
func on_dodge() -> void:
	pass


## D-163 generic flat absorption this component gives crew member `target` (the holder or a teammate), as
## {pool: value}: per pool only the best value counts (PD2: Hysteria from several holders does not stack), pools add.
func absorb_for(_target: CrewController) -> Dictionary:
	return {}


func use_throwable(_kind: StringName) -> bool:
	return false


# --- Shared helpers -------------------------------------------------------------------------------

func _health() -> CrewHealth:
	return crew.health if crew != null else null


func _slot() -> int:
	return crew.slot if crew != null else -1


## Restore armor (capped at max armor).
func _add_armor(amount: float) -> void:
	var h: CrewHealth = _health()
	if h != null and amount > 0.0:
		h.armor = minf(h.armor + amount, h.max_armor)


func _health_frac() -> float:
	var h: CrewHealth = _health()
	return h.health / maxf(h.max_health, 0.001) if h != null else 1.0


## Armor just broke on this hit (`out` = final DamageInfo).
func _armor_broke(out: Dictionary) -> bool:
	var h: CrewHealth = _health()
	return h != null and h.max_armor > 0.0 and float(out.get("armor_damage", 0.0)) > 0.0 and h.armor <= 0.0


## Health immunity of `seconds` when armor broke on this hit, at most once per `cooldown` s.
func _try_break_immunity(out: Dictionary, seconds: float, cooldown: float) -> bool:
	if seconds <= 0.0 or _immunity_cd > 0.0 or not _armor_broke(out):
		return false
	var h: CrewHealth = _health()
	h.invuln_left = maxf(h.invuln_left, seconds)
	_immunity_cd = cooldown
	return true


func _tick_immunity(delta: float) -> void:
	_immunity_cd = maxf(_immunity_cd - delta, 0.0)
