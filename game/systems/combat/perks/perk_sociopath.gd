## perk.sociopath (Clean Sweep, PD2 Sociopath + Hitman). Owner: ENV A. Schema: perk_decks.md /
## modifiers_params.md.
## - A kill restores kill_armor (kill_armor_cooldown_s); a kill within close_range_m also restores
##   close_kill_armor (own cooldown) and may spread panic (close_kill_panic_chance, panic_radius_m,
##   close_kill_panic_cooldown_s); a MELEE kill heals melee_kill_health_fraction x max health.
## - close_range_dr while an enemy is within close_range_m.
## - forced_regen_after_break_s (> 0): armor starts regenerating that long after breaking, whatever
##   the regen delay or the damage taken meanwhile.
class_name PerkSociopath
extends PerkComponent

const KEY: StringName = &"perk.sociopath"
const RNG_STREAM: StringName = &"perks"

## Seconds until the forced regen starts (0 = not forcing).
var forced_left: float = 0.0

var _kill_cd: float = 0.0
var _close_cd: float = 0.0
var _melee_cd: float = 0.0
var _panic_cd: float = 0.0


func damage_reduction(_info: Dictionary) -> float:
	var dr: float = num("close_range_dr")
	if dr <= 0.0 or PerkUtil.enemies_near_crew(crew, num("close_range_m")).is_empty():
		return 0.0
	return dr


func on_kill(victim: Node, info: Dictionary) -> void:
	if _kill_cd <= 0.0 and num("kill_armor") > 0.0:
		_add_armor(num("kill_armor"))
		_kill_cd = num("kill_armor_cooldown_s")
	var v3: Node3D = victim as Node3D
	var close: bool = v3 != null and v3.global_position.distance_to(crew.global_position) <= num("close_range_m")
	if close and _close_cd <= 0.0 and num("close_kill_armor") > 0.0:
		_add_armor(num("close_kill_armor"))
		_close_cd = num("kill_armor_cooldown_s")
	var melee: bool = int(info.get("type", Enums.DamageType.BULLET)) == Enums.DamageType.MELEE
	if melee and _melee_cd <= 0.0 and num("melee_kill_health_fraction") > 0.0 and _health() != null:
		_health().heal(_health().max_health * num("melee_kill_health_fraction"))
		_melee_cd = num("melee_kill_cooldown_s")
	var chance: float = num("close_kill_panic_chance")
	if close and chance > 0.0 and _panic_cd <= 0.0 and GameRng.stream(RNG_STREAM).randf() < chance:
		CrewPerks.panic(crew, v3.global_position, num("panic_radius_m"))
		_panic_cd = num("close_kill_panic_cooldown_s")


func after_hit(out: Dictionary) -> void:
	var s: float = num("forced_regen_after_break_s")
	var h: CrewHealth = _health()
	if s <= 0.0 or h == null:
		return
	if forced_left <= 0.0 and _armor_broke(out):
		forced_left = s
	if forced_left > 0.0:
		h.regen_delay_left = minf(h.regen_delay_left, forced_left)


func tick(delta: float) -> void:
	forced_left = maxf(forced_left - delta, 0.0)
	_kill_cd = maxf(_kill_cd - delta, 0.0)
	_close_cd = maxf(_close_cd - delta, 0.0)
	_melee_cd = maxf(_melee_cd - delta, 0.0)
	_panic_cd = maxf(_panic_cd - delta, 0.0)
