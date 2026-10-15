## PO6-19 (D-114 §7) ragdoll / body propulsion tunables for NpcRagdoll. Owner: ENV A.
## Data: ragdoll_tweak.tres. Impulses in N s on ENV D's ~80 kg physical-bones ragdoll
## (world/characters/_tools/RAGDOLL.md: 150 N s on the chest knocks a standing body flat ~1 m back).
## All values are ◇ presentation tuning (PD2 "shotgunning": point-blank shotguns and explosions throw bodies).
class_name RagdollTweak
extends Resource

const PATH: String = "res://systems/anim/ragdoll_tweak.tres"

static var _cached: RagdollTweak = null

@export_group("Death")
## Master switch: false = every death plays its animation only (no physics).
@export var enabled: bool = true
## A death whose hits of the killing physics frame (all pellets of a shotgun shot) sum to at least this
## impulse starts the ragdoll at once from the current pose; below it the death animation plays.
@export var min_impulse: float = 90.0
## An explosion kill always ragdolls (impulse from the blast centre).
@export var explosion_always: bool = true
## Per-hit bullet impulse by weapon class (ShotFx class ids). A shotgun value is per pellet.
@export var bullet_impulse_by_class: Dictionary = {
	&"pistol": 12.0, &"smg": 10.0, &"ar": 16.0, &"lmg": 18.0, &"sniper": 70.0, &"shotgun": 25.0,
}
@export var bullet_impulse_default: float = 14.0
## Shotgun pellets push fully only within this range (m) of the shooter ("shotgunning"); beyond it each pellet
## pushes `shotgun_far_mult` of its impulse.
@export var shotgun_range_m: float = 6.0
@export var shotgun_far_mult: float = 0.25
@export var melee_impulse: float = 25.0
## Max lever arm (m) of a hit impulse from its body's origin (a far claimed hit point would spin the body).
@export var max_offset_m: float = 0.3

@export_group("Explosion")
## Speed change (m/s) given to every body of a ragdoll at the blast centre (impulse = body mass x this x falloff):
## the whole body flies outward instead of one limb.
@export var explosion_speed_mps: float = 5.5
## Falloff (1 - d / r)^pow of the blast push (gentler than damage's PD2 ^0.1).
@export var explosion_falloff_pow: float = 0.6
## Floor of the falloff for a body inside the radius (a kill at the rim still tips over).
@export var explosion_min_falloff: float = 0.25
## Upward bias added to the outward blast direction before normalizing.
@export var explosion_up_bias: float = 0.6
## Push multiplier from the feet (leg_mult) to `explosion_tip_height_m` above them (head_mult): the upper body
## takes more, so the body tips over and flies instead of sliding away upright.
@export var explosion_leg_mult: float = 0.3
@export var explosion_head_mult: float = 1.4
@export var explosion_tip_height_m: float = 1.6
## Corpses already on the ground take this fraction of a blast's push.
@export var corpse_blast_mult: float = 0.5

@export_group("Death animation settle")
## After a death animation ends, run a short ragdoll so the body rests on the floor (then freeze).
@export var settle_after_anim: bool = true
@export var settle_after_anim_s: float = 1.0
## Wait for the death clip at most this long (s) before the settle.
@export var anim_wait_max_s: float = 3.0

@export_group("Settle / cap")
## Freeze (bake + stop) a ragdoll after this long (s), or earlier once every body is slower than settle_speed_mps.
@export var settle_s: float = 3.0
@export var settle_min_s: float = 0.6
@export var settle_speed_mps: float = 0.05
## Simulating ragdolls at once on a peer; starting one more freezes the oldest first.
@export var max_active: int = 8
## A frozen corpse that moved more than this (m) restarts its blood pool where it lies (D-113 bleed_changed).
@export var bleed_move_m: float = 0.5

@export_group("Corpse hits")
## A bullet on a corpse restarts the ragdoll from the baked pose with this impulse range (N s) and re-freezes it.
@export var nudge_min: float = 5.0
@export var nudge_max: float = 20.0
## Corpse hit impulse = the live hit impulse x this, clamped to nudge_min..nudge_max.
@export var nudge_mult: float = 0.5
@export var nudge_settle_s: float = 1.0
## Corpse hitbox (layer hitboxes, zone BODY) lying along the body: width x height (m); the length follows the
## body (head to shins + `corpse_box_pad_m`). Before the ragdoll places it, `corpse_box_default` lies along -Z.
@export var corpse_box_width: float = 0.55
@export var corpse_box_height: float = 0.35
@export var corpse_box_pad_m: float = 0.35
@export var corpse_box_default: Vector3 = Vector3(0.55, 0.35, 1.8)
@export var corpse_box_default_offset: Vector3 = Vector3(0.0, 0.2, -0.85)


static func data() -> RagdollTweak:
	if _cached == null:
		_cached = load(PATH) as RagdollTweak
		if _cached == null:
			_cached = RagdollTweak.new()
	return _cached
