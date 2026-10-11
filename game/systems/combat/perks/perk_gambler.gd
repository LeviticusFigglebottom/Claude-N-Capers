## perk.gambler (Long Odds, PD2 Gambler). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## An ammo pickup by the holder (PerkHooks.on_ammo_picked) heals randf_range(heal_min, heal_max) +
## heal_bonus on GameRng &"perks", x (1 + lowest_health_bonus_per_ally per teammate with more health,
## up to lowest_health_max_stacks); cooldown_s. Teammates heal team_heal_fraction of it. Each
## teammate also gets team_ammo_share x the picked rounds in the equipped weapon (own cooldown).
class_name PerkGambler
extends PerkComponent

const KEY: StringName = &"perk.gambler"
const RNG_STREAM: StringName = &"perks"

var _heal_cd: float = 0.0
var _share_cd: float = 0.0


func tick(delta: float) -> void:
	_heal_cd = maxf(_heal_cd - delta, 0.0)
	_share_cd = maxf(_share_cd - delta, 0.0)


## The heal of one pickup (rolls the RNG).
func roll_heal() -> float:
	var lo: float = num("heal_min")
	var hi: float = maxf(num("heal_max"), lo)
	var amount: float = GameRng.stream(RNG_STREAM).randf_range(lo, hi) + num("heal_bonus")
	var h: CrewHealth = _health()
	var better: int = 0
	for c: CrewController in PerkUtil.crew_of(crew, true):
		if c != crew and c.health != null and h != null and c.health.health > h.health:
			better += 1
	better = mini(better, int(param("lowest_health_max_stacks", 0)))
	return amount * (1.0 + num("lowest_health_bonus_per_ally") * float(better))


func on_ammo_picked(amount: int) -> void:
	if _heal_cd <= 0.0 and _health() != null:
		var heal: float = roll_heal()
		_health().heal(heal)
		var team_frac: float = num("team_heal_fraction")
		if team_frac > 0.0:
			for c: CrewController in PerkUtil.crew_of(crew, true):
				if c != crew and c.health != null:
					c.health.heal(heal * team_frac)
		_heal_cd = num("cooldown_s")
	_share_ammo(amount)


func _share_ammo(amount: int) -> void:
	var share: float = num("team_ammo_share")
	if share <= 0.0 or _share_cd > 0.0 or amount <= 0:
		return
	var rounds: int = int(round(float(amount) * share))
	if rounds <= 0:
		return
	for c: CrewController in PerkUtil.crew_of(crew, true):
		if c != crew and c.weapons != null:
			_give_rounds(c, rounds)
	_share_cd = num("team_ammo_share_cooldown_s")


## Add `rounds` to the equipped weapon's reserve, capped at its total ammo (x weapon.ammo_total_mult)
## minus the magazine.
static func _give_rounds(c: CrewController, rounds: int) -> void:
	var w: CrewWeapons = c.weapons
	var ws: int = w.equipped_slot
	var st: WeaponStats = w.stats(ws)
	if st == null:
		return
	var def: WeaponDef = ContentDB.weapon(w.weapon_id(ws))
	var q: StringName = Enums.weapon_class_qualifier(def.weapon_class) if def != null else &"pistol"
	var total: int = int(round(float(st.total_ammo) * Modifiers.mult(c.slot, &"weapon.ammo_total_mult", q)))
	var cap: int = maxi(total - w.mag_size(ws), 0)
	w.set_ammo(ws, w.mag(ws), maxi(mini(w.reserve(ws) + rounds, cap), w.reserve(ws)))
