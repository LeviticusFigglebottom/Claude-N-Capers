## D-164 perk.copycat (PD2 Copycat's fixed behaviours). Owner: ENV A. Schema: B's perk_decks.md (card choices and the
## mimicked card 9 are B's resolver: ordinary merged keys). Every behaviour is off while its number is 0:
##   Tactical reload: tactical_reload_kills kills with the equipped weapon (a counter per weapon slot) refill the
##     holstered weapon's magazine from its reserve; a swap to it within quick_swap_window_s is near-instant
##     (CrewWeapons.grant_quick_equip).
##   Headshot heal: a headshot hit heals headshot_heal (display health), at most once per headshot_heal_cooldown_s.
##   Ricochet: dodge_ricochet sends a dodged bullet back at the enemy that fired it (its damage ◇), at most once per
##     ricochet_cooldown_s (RICOCHET_COOLDOWN_TOP_S on the top two difficulties ◇).
##   Grace: a hit that takes health from >= grace_health_threshold x max to below it starts grace_immunity_s of
##     health immunity (armor still takes hits; that hit applies), at most once per grace_cooldown_s.
## Server only.
class_name PerkCopycat
extends PerkComponent

const KEY: StringName = &"perk.copycat"
const RICOCHET_COOLDOWN_TOP_S: float = 0.35
const RICOCHET_SOURCE: StringName = &"copycat_ricochet"
const SLOTS: Array[int] = [Enums.WeaponSlot.PRIMARY, Enums.WeaponSlot.SECONDARY]

## weapon slot -> kills toward the tactical reload.
var reload_kills: Dictionary[int, int] = {}
var heal_cd: float = 0.0
var ricochet_cd: float = 0.0
var grace_cd: float = 0.0
var grace_left: float = 0.0


func tick(delta: float) -> void:
	heal_cd = maxf(heal_cd - delta, 0.0)
	ricochet_cd = maxf(ricochet_cd - delta, 0.0)
	grace_cd = maxf(grace_cd - delta, 0.0)
	grace_left = maxf(grace_left - delta, 0.0)


func on_kill(_victim: Node, _info: Dictionary) -> void:
	var need: int = int(num("tactical_reload_kills"))
	var w: CrewWeapons = crew.weapons if crew != null else null
	if need <= 0 or w == null or not SLOTS.has(w.equipped_slot):
		return
	var ws: int = w.equipped_slot
	reload_kills[ws] = int(reload_kills.get(ws, 0)) + 1
	if reload_kills[ws] < need:
		return
	reload_kills[ws] = 0
	var other: int = SLOTS[1] if ws == SLOTS[0] else SLOTS[0]
	if w.has_weapon(other):
		w.refill_mag(other)
		if num("quick_swap_window_s") > 0.0:
			w.grant_quick_equip(other, num("quick_swap_window_s"))


func on_damage_dealt(_victim: Node, info: Dictionary) -> void:
	var h: CrewHealth = _health()
	if num("headshot_heal") <= 0.0 or heal_cd > 0.0 or h == null or not PerkHooks.is_headshot(info):
		return
	h.heal(num("headshot_heal"))
	heal_cd = num("headshot_heal_cooldown_s")


func on_dodge(info: Dictionary) -> void:
	if not bool(param("dodge_ricochet", false)) or ricochet_cd > 0.0:
		return
	if int(info.get("type", Enums.DamageType.BULLET)) != Enums.DamageType.BULLET:
		return
	var npc: NpcBase = Ids.lookup(int(info.get("attacker", 0))) as NpcBase
	var amount: float = float(info.get("amount", 0.0))
	if npc == null or not npc.alive or amount <= 0.0:
		return
	ricochet_cd = ricochet_cooldown()
	var dir: Vector3 = (npc.global_position - crew.global_position).normalized()
	npc.take_hit(Damage.info(amount, Enums.DamageType.BULLET, Enums.HitZone.BODY, RICOCHET_SOURCE, npc.global_position,
		dir), crew.net_id)


## ricochet_cooldown_s, or RICOCHET_COOLDOWN_TOP_S on the top two difficulties.
func ricochet_cooldown() -> float:
	var rt: HeistRuntime = HeistRuntime.of(crew)
	var top: bool = rt != null and rt.difficulty >= Enums.Difficulty.LETHAL
	return minf(num("ricochet_cooldown_s"), RICOCHET_COOLDOWN_TOP_S) if top else num("ricochet_cooldown_s")


func incoming(_info: Dictionary, dmg: float) -> float:
	var h: CrewHealth = _health()
	if grace_left <= 0.0 or h == null:
		return dmg
	return minf(dmg, h.armor)  # health immunity: only what the armor can take (no overflow into health)


func after_hit(out: Dictionary) -> void:
	var h: CrewHealth = _health()
	var thr: float = num("grace_health_threshold")
	if h == null or thr <= 0.0 or num("grace_immunity_s") <= 0.0 or grace_cd > 0.0:
		return
	var line: float = thr * h.max_health
	var before: float = h.health + float(out.get("health_damage", 0.0))
	if before >= line and h.health < line and h.health > 0.0:
		grace_left = num("grace_immunity_s")
		grace_cd = num("grace_cooldown_s")
