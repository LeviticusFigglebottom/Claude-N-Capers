## perk.muscle (Bulk, PD2 Muscle). Owner: ENV A. Schema: perk_decks.md / modifiers_params.md.
## - Heals regen_fraction x max health every regen_interval_s.
## - Enemy target-selection weight x aggro_near_crew_mult while a teammate is within near_crew_m.
## - Each firearm (BULLET) hit on an enemy panics enemies within panic_radius_m of it with panic_chance
##   (GameRng &"perks"; panic = NpcBase.stun for PerkTweak.panic_stun_s).
## The +100% health is the generic defense.health_mult.
class_name PerkMuscle
extends PerkComponent

const KEY: StringName = &"perk.muscle"
const RNG_STREAM: StringName = &"perks"

var _regen_acc: float = 0.0


func tick(delta: float) -> void:
	var frac: float = num("regen_fraction")
	var interval: float = num("regen_interval_s")
	var h: CrewHealth = _health()
	if frac <= 0.0 or interval <= 0.0 or h == null:
		return
	_regen_acc += delta
	while _regen_acc >= interval:
		_regen_acc -= interval
		h.heal(h.max_health * frac)


func aggro_mult(_from: Node3D) -> float:
	if PerkUtil.near_teammate(crew, num("near_crew_m")):
		return float(param("aggro_near_crew_mult", 1.0))
	return 1.0


func on_damage_dealt(victim: Node, info: Dictionary) -> void:
	var chance: float = num("panic_chance")
	var v3: Node3D = victim as Node3D
	if chance <= 0.0 or v3 == null or int(info.get("type", Enums.DamageType.BULLET)) != Enums.DamageType.BULLET:
		return
	if GameRng.stream(RNG_STREAM).randf() < chance:
		CrewPerks.panic(crew, v3.global_position, num("panic_radius_m"))
