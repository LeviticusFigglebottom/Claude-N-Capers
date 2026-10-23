## D-161 stealth.pocket_ecm (Hacker deck). Owner: ENV A. The deck's throwable (perk.throwable item_id
## throwable.pocket_ecm, ThrowableDef kind KIND) uses a charge through EcmSystem.use_pocket (jam in stealth, feedback
## loud: see EcmSystem); this component carries the holder's own kill effects:
##   every kill: EcmSystem.pocket_kill (the recharging charge - kill_cooldown_reduction_s);
##   kill_heal (Bit Decay): a kill while the holder's feedback runs heals kill_heal (display health);
##   kill_dodge_add / kill_dodge_s (Kluge): a kill while the jam or the feedback runs grants +kill_dodge_add dodge
##   for kill_dodge_s.
## crew_kill_heal (Botnet) is EcmSystem's (a teammate's kill). Server only, like every perk event.
class_name PerkPocketEcm
extends PerkComponent

const KEY: StringName = &"stealth.pocket_ecm"
const KIND: StringName = &"pocket_ecm"

## Seconds of Kluge dodge left.
var kill_dodge_left: float = 0.0


func use_throwable(kind: StringName) -> bool:
	var ecm: EcmSystem = _ecm()
	return kind == KIND and ecm != null and ecm.use_pocket(_slot(), params)


func tick(delta: float) -> void:
	kill_dodge_left = maxf(kill_dodge_left - delta, 0.0)


func on_kill(_victim: Node, _info: Dictionary) -> void:
	var ecm: EcmSystem = _ecm()
	if ecm == null:
		return
	var mode: StringName = StringName(ecm.pocket_state(_slot()).get("mode", &""))
	ecm.pocket_kill(_slot())
	var h: CrewHealth = _health()
	if mode == EcmSystem.MODE_FEEDBACK and num("kill_heal") > 0.0 and h != null:
		h.heal(num("kill_heal"))
	if mode != &"" and num("kill_dodge_add") > 0.0:
		kill_dodge_left = num("kill_dodge_s")


func dodge_add() -> float:
	return num("kill_dodge_add") if kill_dodge_left > 0.0 else 0.0


func _ecm() -> EcmSystem:
	var rt: HeistRuntime = HeistRuntime.of(crew)
	return rt.service(EcmSystem.SERVICE) as EcmSystem if rt != null else null
