## D-113 (ENV C's gore VFX): FX-only blood facts, emitted by the server and replicated to every peer.
##   blood_hit(victim_net_id, point, direction, normal, strength, headshot, exit_point, victim_kind)
##     a bullet / melee flesh hit (crew: only when it reaches health, not armour); after damage_applied.
##   bleed_changed(body_net_id, bleeding, position, rate)
##     a corpse (NPC death) or a downed crew member starts bleeding; bagging, revive or custody stops it.
## The EventBus signals are a LEAD contract edit; until they exist these calls do nothing. Owner: ENV A.
class_name BloodFx
extends RefCounted

const KIND_NPC: StringName = &"npc"
const KIND_CREW: StringName = &"crew"
const SIG_HIT: StringName = &"blood_hit"
const SIG_BLEED: StringName = &"bleed_changed"
## Half the body's depth along the shot (m): where a penetrating or lethal round leaves the capsule.
const EXIT_DEPTH_M: float = 0.35
## Weapon classes whose rounds exit the body.
const EXIT_CLASSES: Array[StringName] = [&"sniper", &"lmg", &"shotgun"]
## Pool growth hints: a headshot / explosion death bleeds faster.
const RATE_DEATH: float = 0.6
const RATE_DEATH_HEAVY: float = 1.0
const RATE_DOWNED: float = 0.35


## Server: one blood_hit for damage `out` (a take_hit result) on `victim` (max health `max_health`).
static func hit(victim: Node3D, victim_net_id: int, out: Dictionary, max_health: float, kind: StringName) -> void:
	var t: int = int(out.get("type", Enums.DamageType.BULLET))
	if t != Enums.DamageType.BULLET and t != Enums.DamageType.MELEE:
		return
	var amount: float = float(out.get("health_damage", out.get("amount", 0.0))) if kind == KIND_CREW \
		else float(out.get("amount", 0.0))
	if amount <= 0.0 or victim == null or not victim.is_inside_tree():
		return
	var dir: Vector3 = out.get("direction", Vector3.ZERO)
	dir = dir.normalized() if dir.length() > 0.0001 else Vector3.ZERO
	var point: Vector3 = out.get("position", Vector3.ZERO)
	if point == Vector3.ZERO:
		point = victim.global_position + Vector3(0.0, 1.2, 0.0)
	var headshot: bool = int(out.get("zone", -1)) == Enums.HitZone.HEAD
	var exit_point: Vector3 = Vector3.ZERO
	var cls: StringName = ShotFx.npc_weapon_class(StringName(out.get("weapon_id", &"")))
	if t == Enums.DamageType.BULLET and dir != Vector3.ZERO \
			and (bool(out.get("killed", false)) or EXIT_CLASSES.has(cls) or bool(out.get("pierced_armor", false))):
		exit_point = point + dir * EXIT_DEPTH_M * 2.0
	var strength: float = clampf(amount / maxf(max_health, 1.0), 0.0, 1.0)
	_emit(SIG_HIT, [victim_net_id, point, dir, Vector3.ZERO, strength, headshot, exit_point, kind])


## Server: a body starts / stops bleeding at `position` (rate 0..1, pool growth hint).
static func bleed(body_net_id: int, bleeding: bool, position: Vector3, rate: float = RATE_DEATH) -> void:
	if body_net_id == 0:
		return
	_emit(SIG_BLEED, [body_net_id, bleeding, position, clampf(rate, 0.0, 1.0)])


## The death's pool rate from its damage (`info` of NpcBase.die).
static func death_rate(info: Dictionary) -> float:
	var heavy: bool = int(info.get("zone", -1)) == Enums.HitZone.HEAD \
		or int(info.get("type", -1)) == Enums.DamageType.EXPLOSION
	return RATE_DEATH_HEAVY if heavy else RATE_DEATH


static func _emit(sig: StringName, args: Array) -> void:
	if not Net.is_authority() or not EventBus.has_signal(sig):
		return
	EventBus.emit_signal.callv([sig] + args)
	Net.replicate_event(sig, args)
