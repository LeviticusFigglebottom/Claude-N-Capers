## Third-person animation driver for NPCs and crew bodies (characters.md v1.3, D-041). Owner: ENV A.
## Child `AnimDriver` of an NpcBase or a CrewController. Finds the character visual's AnimationPlayer at the
## contract path (`Visual/<Root>/AnimationPlayer` with library "humanoid"); with no such player (capsule
## placeholder) it does nothing. **Presentation only**: it reads gameplay state and never writes it; no
## gameplay code may read animation state. Headless-safe.
## Each frame it picks one clip, by priority:
##   death_front/back (from the last hit direction vs facing) > crew state (downed, tased, kneel_cuffed) /
##   stun (tased) > pose hints (tied, cower, hands_up, surrender, lie_down, kneel_cuffed) > special actions
##   (kick_charge, shield_bang, heal_ally) > crew actions (mask_on, throw_grenade; CrewActionAnim) >
##   (crew) interact_* / pager_answer (D-115: an interaction beats every one-shot; a hit is an upper-body flinch) >
##   one-shots (turn, fire, reload, throw_bag, melee, kick_hit,
##   hit_head / hit_chest / hit_shoulder_* / hit_leg_* by zone, else hit_react*) >
##   locomotion by velocity (walk, run, sprint, crouch_walk, strafe,
##   walk_back, flee, carry_bag_walk, the unit's EnemyDef.params.anim_walk_clip = shield_walk / dozer_walk at
##   walking speed; speed_scale = v / clip speed) > aim_* >
##   the brain's `anim_hint` idles (phone_call, smoke, radio_call, investigate_look...) > idle / idle_alert /
##   crouch_idle. Clips crossfade (AnimTweak.blend_s).
## Pose variants (characters.md v1.18): hands_up / surrender / surrender_idle / kneel_cuffed play this body's
## variant (hash(net_id) % 3, every peer agrees); a surrender* one-shot holds its own surrender_idle* loop.
## Shield carry: while the NPC carries a raised BulwarkShield (guard up, not dropped), the clip picked
## below the poses / actions is remapped through AnimTweak.shield_clips (idle / aim / fire / turn ->
## shield_idle*, walk family -> shield_walk*), so the left hand stays on the grip and the shield Visual
## follows HandL/Socket. Guard down (stagger: hit_react), dropped, dead or a rig without the clip: the normal
## clips play.
## Turn in place (TurnInPlace): a standing body whose yaw moved more than AnimTweak.turn_threshold_deg (20) plays
## turn_l_45 / turn_r_45 (below 67.5 deg) or turn_l / turn_r at speed_scale 1 while the rig root yaws at the clip's
## own rate (the rig is counter-rotated; the body itself is untouched); the residual eases in over the blend-out;
## smaller changes snap over turn_snap_s.
## Third-person weapon: WeaponVisual (ENV B, by class name) of WeaponDef.model at `HandR/Socket` (crew: the
## equipped weapon, NPC: EnemyDef.weapon when it has a WeaponDef with a model; otherwise none).
## D-116 police combat (CombatClips): aim on the move, class / moving reloads, cover poses, stagger, DB-4 sit_chair_armed;
## each falls back to the older clip when the rig lacks it.
## Clients: velocity comes from position deltas and alert state / crew state are replicated; brain hints and
## interaction heights are host data (clients fall back to alert-state poses).
class_name AnimDriver
extends Node

const NODE_NAME: String = "AnimDriver"
const LIBRARY: String = "humanoid"
const WEAPON_NODE: String = "ThirdPersonWeapon"
## Brain anim_hint -> clip (characters.md names). Locomotion hints (walk/run/walk_back) are ignored:
## velocity decides. &"aim" resolves to aim_pistol / aim_rifle by weapon class.
const HINT_CLIPS: Dictionary = {
	&"idle": &"idle", &"idle_alert": &"idle_alert", &"investigate_look": &"investigate_look",
	&"radio_call": &"radio_call", &"pager_answer": &"pager_answer", &"phone_call": &"phone_call",
	&"smoke": &"smoke", &"cower": &"cower", &"hands_up": &"hands_up", &"tied": &"tied",
	&"kneel_cuffed": &"kneel_cuffed", &"lie_down": &"lie_down", &"surrender": &"surrender",
	&"browse": &"browse", &"desk_type": &"desk_type", &"sit_chair": &"sit_chair", &"lean_wall": &"lean_wall",
	&"sit_chair_armed": &"sit_chair_armed",
	&"melee": &"melee", &"flee": &"flee", &"aim_pistol": &"aim_pistol", &"aim_rifle": &"aim_rifle",
	&"tased": &"tased", &"downed": &"downed", &"hit_react": &"hit_react",
	# Specials (characters.md v1.4): Phantom windup / kick, Bulwark bang, Corpsman heal.
	&"kick_charge": &"kick_charge", &"kick_hit": &"kick_hit", &"shield_bang": &"shield_bang",
	&"heal_ally": &"heal_ally",
	# characters.md v1.7 NPC ambient clips (D-069, ENV D 4355913).
	&"desk_work": &"desk_work", &"phone_seated": &"phone_seated", &"sit_chair_watch": &"sit_chair_watch",
	&"mop": &"mop", &"sit_bed_read": &"sit_bed_read", &"sit_chair_read": &"sit_chair_read", &"mug": &"mug_idle", &"idle_thug": &"idle_thug",
	&"mug_walk": &"mug_idle",
	# characters.md v1.9 (D-103, Gallery Night): inspect a hung work, cower standing / seated, walk texting.
	&"curator_inspect": &"curator_inspect", &"inspect": &"curator_inspect", &"cower_stand": &"cower_stand",
	&"cower_seated": &"cower_seated", &"text": &"phone_call", &"walk_text": &"phone_call",
	# D-111 ambient activities: bar staff, club door, dancers (dance_a/b/c picked per NPC), bank tellers.
	&"bartender": &"bartender_wipe", &"bartender_wipe": &"bartender_wipe", &"bartender_pour": &"bartender_pour",
	&"bouncer": &"bouncer_idle", &"teller": &"teller_count", &"dance_a": &"dance_a", &"dance_b": &"dance_b",
	&"dance_c": &"dance_c", &"teller_count": &"teller_count",  # QC-67: OF spawns name the clip as the activity
	# AH (afterhours.md cast table): the bouncers' posts and the DJ's set name their clips (QC-74 dj_mix).
	&"bouncer_idle": &"bouncer_idle", &"dj_mix": &"dj_mix",
	# Brain / patrol-point aliases.
	&"phone": &"phone_call", &"call": &"phone_call", &"sit": &"sit_chair",
	&"queue": &"queue_idle", &"lean": &"lean_wall", &"check_door": &"investigate_look", &"down": &"lie_down",
	&"cuff": &"interact_low", &"look": &"investigate_look", &"desk": &"desk_work",
	# OF-D1 (SOURCE bank_animdriver): a customer at a queue / counter / check_desk mark; queue_idle is a variant group.
	&"queue_idle": &"queue_idle", &"counter": &"counter_customer", &"counter_customer": &"counter_customer",
	&"check_desk": &"check_desk_write", &"check_desk_write": &"check_desk_write",
	# OF-A6 (S3.1): a panicked civilian pressing an alarm_button (CivilianBrain CALLING at REASON_BUTTON).
	&"press_alarm": &"interact_mid",
	# RT-D1 (Rolling Thunder, clips announced by ENV D): seated in a car / cab, eating in a diner booth, the diner cook.
	&"sit_vehicle": &"sit_vehicle", &"vehicle": &"sit_vehicle", &"sit_eat": &"sit_eat", &"eat": &"sit_eat",
	&"sit_vehicle_drive": &"sit_vehicle_drive",  # D (r280): a driver, hands on the wheel at 10 and 2
	&"cook_stove": &"cook_stove", &"cook": &"cook_stove",
	&"counter_wipe": &"counter_wipe",  # the RT diner waitress at the counter (D)
}
## Clips that win over locomotion (the body holds a pose).
## One-shot poses that must stay held when they end (P coverage: a surrendered cop froze with a stopped player):
## clip -> its held loop (ENV D ask: `surrender_idle`, kneeling hands on head). Without the loop in the library the
## last frame of the one-shot is held with the player still playing (speed 0). characters.md v1.18: each surrender
## variant holds its own loop (every surrender* ends on surrender's last frame = every surrender_idle* frame 0).
const HOLD_END: Dictionary = {
	&"surrender": &"surrender_idle", &"surrender_b": &"surrender_idle_b", &"surrender_c": &"surrender_idle_c",
}
## characters.md v1.18 (SOURCE `variants.<group>`): pose clip -> its variants, in SOURCE order. One index per body,
## hash(net_id) % 3, used in every group (hands_up_b -> surrender_b -> surrender_idle_b -> kneel_cuffed_b); a
## variant the rig lacks plays the original.
const VARIANT_GROUPS: Dictionary = {
	&"hands_up": [&"hands_up", &"hands_up_b", &"hands_up_c"],
	&"surrender": [&"surrender", &"surrender_b", &"surrender_c"],
	&"surrender_idle": [&"surrender_idle", &"surrender_idle_b", &"surrender_idle_c"],
	&"kneel_cuffed": [&"kneel_cuffed", &"kneel_cuffed_b", &"kneel_cuffed_c"],
	# D-116 civ_panic_variants (same index: cower_b <-> flee_b <-> hands_up_b ...).
	&"cower": [&"cower", &"cower_b", &"cower_c"],
	&"flee": [&"flee", &"flee_b", &"flee_c"],
	# OF-D1 SOURCE queue_variants (same index: queue_idle_b <-> cower_b <-> hands_up_b ...).
	&"queue_idle": [&"queue_idle", &"queue_idle_b", &"queue_idle_c"],
	# D 7d86014f SOURCE idle_variants / idle_alert_variants: a calm post (idle) and the alert stand (idle_alert) per
	# body; frame 0 is the base's frame 0, so chains into / out of them are unchanged (no gear: civilians and
	# unmasked crew share idle). Not offset loops: entered from walk_stop / a one-shot on frame 0 like the base.
	&"idle": [&"idle", &"idle_b", &"idle_c"],
	&"idle_alert": [&"idle_alert", &"idle_alert_b", &"idle_alert_c"],
}
## Variant loops that start at a per-body random offset (SOURCE surrender_variants: the periods differ, so they never
## re-sync). surrender_idle* reached from its surrender* one-shot starts on frame 0 instead (the chain frame).
## D-116: cower too (flee keeps the gait phase). OF-D1: queue_idle (a queue never syncs).
const OFFSET_LOOP_GROUPS: Array[StringName] = [&"hands_up", &"kneel_cuffed", &"surrender_idle", &"cower", &"queue_idle"]
const POSE_CLIPS: Array[StringName] = [
	&"tied", &"kneel_cuffed", &"lie_down", &"cower", &"hands_up", &"surrender", &"downed", &"tased",
	&"cower_stand", &"cower_seated", &"surrender_idle", &"cower_b", &"cower_c", &"panic_start",
	&"hands_up_b", &"hands_up_c", &"surrender_b", &"surrender_c", &"surrender_idle_b", &"surrender_idle_c",
	&"kneel_cuffed_b", &"kneel_cuffed_c",
	# v1.21 crew states (the weapon follows weapon_shown(), not this list, for the downed set).
	&"crew_cuffed", &"crew_cuffed_enter", &"crew_cuffed_free", &"downed_arrested", &"downed_getup", &"downed_fire",
	&"downed_reload",
]
## Special actions held while the hint lasts: they win over one-shots, locomotion and aim (the brain
## stands the body still for them).
const ACTION_CLIPS: Array[StringName] = [&"kick_charge", &"shield_bang", &"heal_ally"]
## D-116: held brain hints the host replicates to clients (NetEntityCodec NPC state "ah", stored in META_NET_HINT):
## the police / guard cuff (interact_low). Every other hint stays host-only (clients use the alert-state fallbacks).
const NET_HINTS: Array[StringName] = [&"cuff"]
const META_NET_HINT: StringName = &"net_anim_hint"
## Hints played once when the hint changes to them.
const ONESHOT_HINTS: Array[StringName] = [&"melee", &"kick_hit", &"hit_react"]
## characters.md v1.11: clips that mean "seated at a desk / chair" for the seated deaths.
const SEATED_CLIPS: Array[StringName] = [&"desk_work", &"phone_seated", &"sit_chair_watch", &"cower_seated",
	&"sit_eat", &"sit_vehicle", &"sit_vehicle_drive"]
## RT-D1 vehicle dismounts (~45 f one-shots with root motion, step events, ending on idle_alert f0): played only when
## the rig has them (play_vehicle_exit; no fallback clip). No caller yet: the convoy / police dismount is QC-83/86.
const VEHICLE_EXIT_L: StringName = &"vehicle_exit_l"
const VEHICLE_EXIT_R: StringName = &"vehicle_exit_r"
## characters v1.27 reversal states (_reversal_step).
const REV_NONE: int = 0
const REV_PENDING: int = 1
const REV_PLAYING: int = 2
const DEATH_SEATED_SLUMP: StringName = &"death_seated_slump"
const DEATH_SEATED_FALL: StringName = &"death_seated_fall"
## characters.md v1.10 8-way locomotion by 45 deg sector clockwise from forward (index 0 = forward).
const WALK_8: Array[StringName] = [
	&"walk", &"walk_fr", &"strafe_r", &"walk_br", &"walk_back", &"walk_bl", &"strafe_l", &"walk_fl"]
const RUN_8: Array[StringName] = [&"run", &"run_fr", &"run_r", &"run_br", &"run_b", &"run_bl", &"run_l", &"run_fl"]
## Hit reacts by where the bullet came from (characters.md v1.10), and the spacing between two of them.
const HIT_FRONT: StringName = &"hit_react"
const HIT_BACK: StringName = &"hit_react_back"
const HIT_LEFT: StringName = &"hit_react_left"
const HIT_RIGHT: StringName = &"hit_react_right"
## characters.md v1.18 hit-zone flinches (SOURCE `hit_zones:`); the directional hit_react* set is the fallback.
const HIT_HEAD: StringName = &"hit_head"
const HIT_CHEST: StringName = &"hit_chest"
const HIT_SHOULDER_L: StringName = &"hit_shoulder_l"
const HIT_SHOULDER_R: StringName = &"hit_shoulder_r"
const HIT_LEG_L: StringName = &"hit_leg_l"
const HIT_LEG_R: StringName = &"hit_leg_r"
const HIT_ZONE_CLIPS: Array[StringName] = [HIT_HEAD, HIT_CHEST, HIT_SHOULDER_L, HIT_SHOULDER_R, HIT_LEG_L, HIT_LEG_R]
## D-123: DamageInfo `limb` sub-zone (NpcLimbHitboxes.SUB_*, a limb box hit; zone BODY) -> its flinch.
const LIMB_CLIPS: Dictionary = {
	&"shoulder_l": HIT_SHOULDER_L, &"shoulder_r": HIT_SHOULDER_R, &"leg_l": HIT_LEG_L, &"leg_r": HIT_LEG_R,
}
## SOURCE hit_zones: a LIMB hit above the hips joint (root-space y, m at 1.78 m x motion_scale) is a shoulder hit.
const HIT_ZONE_HIPS_Y_M: float = 0.95
## Damage types whose `zone` / `position` name a point on the body (explosions, fire, gas... use the direction set).
const HIT_ZONE_TYPES: Array[int] = [Enums.DamageType.BULLET, Enums.DamageType.MELEE]
## characters.md v1.20 (SOURCE weapon_holds): weapon class -> hold kind (idle_alert_<kind> / hold_<kind>). PISTOL is
## `akimbo` for a pair (WeaponDef.akimbo). The aim / fire / reload clips stay two families: PISTOL_KINDS aim as
## pistols, every other kind as a rifle.
const KIND_BY_CLASS: Dictionary = {
	Enums.WeaponClass.ASSAULT_RIFLE: &"rifle", Enums.WeaponClass.SHOTGUN: &"rifle", Enums.WeaponClass.SMG: &"smg",
	Enums.WeaponClass.SPECIAL: &"smg", Enums.WeaponClass.SNIPER: &"sniper", Enums.WeaponClass.LMG: &"lmg",
	Enums.WeaponClass.PISTOL: &"pistol",
}
const PISTOL_KINDS: Array[StringName] = [&"pistol", &"akimbo"]
## v1.20 armed interactions (SOURCE armed_interactions): a crew body holding a weapon plays `<clip>_armed`.
const ARMED_SUFFIX: String = "_armed"
const ARMED_CLIPS: Array[StringName] = [&"interact_low", &"interact_mid", &"interact_high", &"throw_bag"]
## v1.20: the carried-bag visual (LootDef.bag_model) on Back/Socket while the crew body carries a bag.
const CARRIED_BAG_NODE: String = "CarriedBag"
## v1.20 akimbo: the pair's second gun (WeaponVisual.offhand) moves to HandL/Socket under this name.
const OFFHAND_NODE: String = "ThirdPersonOffhand"
## v1.21: one-shots that end exactly on crew_cuffed frame 0 (switch without a crossfade).
const CUFF_INTO: Array[StringName] = [&"downed_arrested", &"crew_cuffed_enter"]
## Lead ruling (b): the upper-body flinch layer's node name (after the weapon-hold layer).
const FLINCH_LAYER_NODE: String = "FlinchLayer"
## Starts / stops only for straight-ahead motion (|dir . forward| at least this).
const START_STOP_DOT: float = 0.7
## One-shot hints that are not held as an idle once played (the hint may linger in the brain).
## D-115: melee too (a lingering melee hint held the finished non-looping clip: the player stopped under the driver).
const ONCE_ONLY_HINTS: Array[StringName] = [&"kick_hit", &"hit_react", &"melee"]
## Clip -> substitute when the library lacks it (then idle).
const FALLBACK_CLIPS: Dictionary = {
	&"aim_pistol": &"idle_alert", &"aim_rifle": &"idle_alert", &"interact_low": &"interact_mid",
	&"interact_high": &"interact_mid", &"flee": &"run", &"carry_bag_walk": &"walk", &"crouch_walk": &"walk",
	&"crouch_idle": &"idle", &"strafe_l": &"walk", &"strafe_r": &"walk", &"walk_back": &"walk",
	&"run_l": &"run", &"run_r": &"run", &"run_b": &"run",
	&"sprint": &"run", &"pager_answer": &"phone_call", &"idle_alert": &"idle",
	&"shield_walk": &"walk", &"dozer_walk": &"walk", &"kick_charge": &"idle_alert", &"kick_hit": &"melee",
	&"shield_bang": &"idle_alert", &"heal_ally": &"interact_mid",
	&"desk_work": &"desk_type", &"phone_seated": &"phone_call", &"sit_chair_watch": &"sit_chair", &"mop": &"browse",
	&"sit_bed_read": &"sit_chair", &"sit_chair_read": &"sit_bed_read", &"mug_idle": &"idle", &"mug_carry_walk": &"walk", &"idle_thug": &"idle",
	&"cower_b": &"cower", &"cower_c": &"cower", &"panic_start": &"cower", &"flee_b": &"run", &"flee_c": &"run",
	&"rappel": &"climb_ladder", &"climb_ladder": &"idle", &"turn_l_45": &"turn_l", &"turn_r_45": &"turn_r",
	# D-111: drill / crawl / gala and club ambient clips (characters.md v1.9-v1.10).
	&"drill_place": &"interact_mid", &"downed_crawl": &"downed", &"bartender_wipe": &"browse",
	&"bartender_pour": &"browse", &"teller_count": &"desk_type", &"dance_a": &"idle",
	&"dance_b": &"idle", &"dance_c": &"idle",
	# v1.10: 8-way, hit reacts, death variety (each falls back to the v1.3 set).
	&"walk_fl": &"walk", &"walk_fr": &"walk", &"walk_bl": &"walk_back", &"walk_br": &"walk_back",
	&"run_fl": &"run", &"run_fr": &"run", &"run_bl": &"run_b", &"run_br": &"run_b",
	&"hit_react_back": &"hit_react", &"hit_react_left": &"hit_react", &"hit_react_right": &"hit_react",
	&"death_front_b": &"death_front", &"death_back_b": &"death_back", &"death_side": &"death_back",
	&"curator_inspect": &"browse", &"cower_stand": &"cower", &"cower_seated": &"cower", &"walk_text": &"walk",
	# PO6-17 assault events (ENV D clips; played through NpcBase meta META_ANIM_OVERRIDE).
	&"rappel_hang": &"climb_ladder", &"rappel_descend": &"climb_ladder", &"rappel_land": &"idle_alert",
	&"heli_door_idle": &"aim_rifle", &"heli_door_aim": &"aim_rifle", &"van_exit": &"walk",
	&"breach_place": &"interact_mid", &"breach_standback": &"crouch_idle",
	# OF-D1 bank customer clips: before them a queue stood in idle; the counter / check-desk loops stand at a ledge
	&"queue_idle": &"idle", &"queue_idle_b": &"queue_idle", &"queue_idle_c": &"queue_idle",
	# (not desk_type: it is a seated clip; not teller_count: it holds the cash stack)
	&"counter_customer": &"idle", &"check_desk_write": &"idle",
	# RT-D1: seated loops sit on the chair loop, the cook stands.
	&"sit_vehicle": &"sit_chair", &"sit_eat": &"sit_chair", &"cook_stove": &"idle", &"counter_wipe": &"idle",
	&"sit_vehicle_drive": &"sit_vehicle",  # a rig without the driver clip sits as a passenger
}
## PO6-17: an NPC meta (StringName clip) that wins over every NPC state / brain hint while set (host). The
## assault-event runner sets it for scripted moments: rope descent, landing, heli door, van exit, breach charge.
const META_ANIM_OVERRIDE: StringName = &"anim_override"
## EnemyDef.params key: the unit's own walk clip (Bulwark shield_walk, Wrecker dozer_walk), played instead
## of walk while moving at walking speed (above it: run / sprint).
const WALK_CLIP_PARAM: String = "anim_walk_clip"
const CREW_STATE_CLIPS: Dictionary = {
	Enums.CrewState.DOWNED: &"downed", Enums.CrewState.CLOAKER_DOWNED: &"downed",
	Enums.CrewState.TASED: &"tased", Enums.CrewState.CUFFED: &"kneel_cuffed",
}
const ALERT_STATES: Array[int] = [
	Enums.AlertState.CURIOUS, Enums.AlertState.INVESTIGATING, Enums.AlertState.ALARMED, Enums.AlertState.COMBAT,
]

## The AnimationPlayer driven (null = inactive, e.g. capsule placeholder).
var player: AnimationPlayer = null
## The character visual root (the AnimationPlayer's parent).
var rig: Node3D = null
## Clip currently requested (without the library prefix), &"" before the first frame.
var clip: StringName = &""
## D-115: hand props attached for the playing clip (HandProps, e.g. ["phone"] while phone_call plays).
var hand_props: PackedStringArray = PackedStringArray()
## D-115 (ENV D audit R1): the hard-hat hand lift of this rig (null when it wears no hard hat).
var hat_lift: HardHatHandLift = null
## characters.md v1.19: the upper-body layer over locomotion (crew hold_*; aim_* while aiming; D-116 aim_<fam>_<gait>
## and a moving reload, NPCs too).
var hold_layer: UpperBodyLayer = null
## D-116 police combat clip choices (CombatClips).
var combat: CombatClips = null
## The upper-body layers (weapon hold / aim gait / moving reload, hit-zone flinch) and the left-hand IK (AnimLayers).
var layers: AnimLayers = null
## Hit reacts, hit-zone flinches and death clips (HitClips).
var hits: HitClips = null
## The third-person weapon / akimbo offhand and carried-bag visuals (HeldVisuals).
var held_visuals: HeldVisuals = null
## D-132 animation LOD (AnimLod): which frames an NPC ticks / samples vs the local camera.
var lod: AnimLod = null
## D-115: a loop cut by a one-shot resumes its running phase (LoopResume).
var loop_resume: LoopResume = null
## D-116: turn in place (TurnInPlace).
var turn: TurnInPlace = null
## D-116: a civilian's panic_start before its first cower* (CivPanic).
var civ_panic: CivPanic = null
## D-116 npc_oneshot (NetOneshot): client, seconds left of a one-shot the host sent (no turn clip starts meanwhile);
## the last one sent (host) / applied (client) as [clip, start_s, speed] (tests).
var net_oneshot_left: float = 0.0
var last_net_oneshot: Array = []
## WeaponDef.weapon_class of the held weapon (-1 without a WeaponDef): the D-116 class reloads.
var weapon_class: int = -1
## Lead ruling (b): the upper-body hit-zone flinch layer (every animated body); see AnimLayers.play_flinch.
var flinch_layer: UpperBodyLayer = null
## Lead ruling (c): the third-person left hand on the weapon's LeftHandIK (rifle-family holds); null without a rig.
var left_hand_ik: ThirdPersonLeftHandIK = null
## characters.md v1.23: the crew actions (mask_on during the mask-up hold, throw_grenade; CrewActionAnim), crew only.
var crew_action: CrewActionAnim = null
## Crossfade (s) used for the last clip change (0 for the first clip).
var last_blend_s: float = -1.0
## Hold kind (v1.20 KIND_BY_CLASS): rifle / smg / sniper / lmg / pistol / akimbo; aim_family() gives the
## aim / fire / reload clip family.
var weapon_kind: StringName = &"pistol"
## Third-person WeaponVisual at HandR/Socket (null when there is no model).
var weapon_visual: Node3D = null
## v1.20 akimbo: the pair's second gun, moved to HandL/Socket (null otherwise).
var weapon_offhand: Node3D = null
## v1.20: the carried-bag visual at Back/Socket (null when not carrying).
var bag_visual: Node3D = null
## v1.21 crew-state one-shot (downed_fire / downed_reload / downed_getup / downed_arrested / crew_cuffed_enter /
## crew_cuffed_free): wins over the crew state's own clip while it lasts; `_state_oneshot_t` = seconds since it began.
## _locomotion_clip's current 8-way sector (-1 = none yet) and how long it has been held (s).
var _sector: int = -1
var _sector_age: float = 0.0
## characters v1.27 reversal (D's loco_reverse clips): REV_NONE, REV_PENDING (the source loop runs on to the brake foot's
## touch-down `_rev_u_in`), REV_PLAYING (`_rev_clip`, `_rev_left` s); then `_rev_target` is entered at `_rev_u_out`.
var _rev_state: int = REV_NONE
var _rev_clip: StringName = &""
var _rev_target: StringName = &""
var _rev_u_in: float = 0.0
var _rev_u_out: float = 0.0
var _rev_prev_u: float = 0.0
var _rev_left: float = 0.0
## Set when a reversal clip ends: _apply enters `_rev_target` at this normalised time without a crossfade.
var _rev_seek: float = -1.0
## The last 8-way gait loop left for a non-gait clip, its normalised time then, and the seconds since (the resume
## carry: a bot's stop-start reset the stride, D's motion strips).
var _left_gait: StringName = &""
var _left_gait_u: float = 0.0
var _left_gait_age: float = INF
var _state_oneshot: StringName = &""
var _state_oneshot_left: float = 0.0
var _state_oneshot_t: float = 0.0
var _state_oneshot_speed: float = 1.0
## Crew state seen last tick (-1 before the first), for the v1.21 transition clips.
var _last_crew_state: int = -1
## v1.21 akimbo: the next shot is the left gun's (fire_akimbo_l); the first shot is the right one.
var _akimbo_left_next: bool = false

var _body: Node3D = null
var _npc: NpcBase = null
var _crew: CrewController = null
var _rig_base_yaw: float = 0.0
var _visual_yaw: float = 0.0
var _prev_body_yaw: float = 0.0
var _last_pos: Vector3 = Vector3.INF
var _vel: Vector3 = Vector3.ZERO
var _oneshot: StringName = &""
var _oneshot_left: float = 0.0
var _oneshot_speed: float = 1.0
var _oneshot_dur: float = 0.0
var _oneshot_while_moving: bool = false
var _oneshot_start: float = 0.0
var _restart: bool = false
var _turning_left: float = 0.0
## A4-02: this tick's choose_clip(), shared by TurnInPlace and the tick (valid while _sel_rev is unchanged: a one-shot
## started in between, a turn or a door kick, invalidates it).
var _sel_clip: StringName = &""
var _sel_rev: int = 0
var _sel_cached_rev: int = -1
var _aim_hold_left: float = 0.0
var _hit_dir: Vector3 = Vector3.ZERO
var _death_clip: StringName = &""
## HOLD_END one-shots that reached their end this pose (cleared when the pose changes).
var _hold_done: Dictionary[StringName, bool] = {}
## True while a HOLD_END one-shot is frozen on its last frame (no loop clip in the library).
var _pose_frozen: bool = false
## PO6-18: the clip the body showed on its last living frame, and whether the death holds that pose frozen.
var _alive_clip: StringName = &""
var _death_hold: bool = false
var _last_hit_react_t: float = -100.0
## Moving (above move_threshold_mps) last tick, for the v1.10 starts / stops.
var _was_moving: bool = false
## The NPC's last clip while alive was a seated one (SEATED_CLIPS): it dies in the chair.
var _seated: bool = false
var _last_hint: StringName = &""
var _interact_kind: StringName = &""
var _interact_height: float = 1.0
## Shield clip family -> its variants in the library (Array[StringName], sorted); variant -> family. v1.18 pose
## variants (VARIANT_GROUPS) register here too (variant -> group).
var _family_variants: Dictionary = {}
var _variant_family: Dictionary = {}
## v1.18: per variant group, the loop start offset as a fraction of the clip (GameRng `anim_variants`, drawn once).
var _loop_offsets: Dictionary[StringName, float] = {}
## v1.19: the body holds a weapon with a WeaponDef (crew: the equipped one).
var _holds_weapon: bool = false


## The driver of `body` (null when it has none).
static func of(body: Node) -> AnimDriver:
	return body.get_node_or_null(NODE_NAME) as AnimDriver if body != null else null


## True when `body` has an active driver (an animated character visual): NpcBase skips the capsule tip-over.
static func drives(body: Node) -> bool:
	var d: AnimDriver = of(body)
	return d != null and d.player != null


## Contract AnimationPlayer of `body`'s visual: `Visual/<Root>/AnimationPlayer` with library "humanoid".
static func find_player(body: Node) -> AnimationPlayer:
	var visual: Node = body.get_node_or_null(^"Visual") if body != null else null
	if visual == null:
		return null
	for c: Node in visual.get_children():
		if c.is_queued_for_deletion():
			continue
		var ap: AnimationPlayer = c.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		if ap != null and ap.has_animation_library(LIBRARY):
			return ap
	return null


## `<Marker>/Socket` (characters.md v1.2: HandR, HandL, Head, Back, Hip) of `body`'s contract visual, or null
## (capsule placeholder / no skeleton).
static func socket_of(body: Node, marker: String) -> Node3D:
	var ap: AnimationPlayer = find_player(body)
	var root: Node = ap.get_parent() if ap != null else null
	return root.get_node_or_null(NodePath("Skeleton3D/%s/Socket" % marker)) as Node3D if root != null else null


## Add a driver to `body` when its visual has a contract AnimationPlayer (else none; returns the driver or null).
## Crew bodies (CrewView calls this for everyone but the local human) also get their D-118 CrewGadgetVisual,
## capsule placeholders included.
static func ensure(body: Node) -> AnimDriver:
	if body is CrewController:
		CrewGadgetVisual.ensure(body as CrewController)
	var d: AnimDriver = of(body)
	if d != null:
		d.bind()
		return d
	if find_player(body) == null:
		return null
	d = AnimDriver.new()
	d.name = NODE_NAME
	body.add_child(d)
	return d


func _init() -> void:
	layers = AnimLayers.new(self)
	hits = HitClips.new(self)
	held_visuals = HeldVisuals.new(self)
	lod = AnimLod.new(self)
	loop_resume = LoopResume.new(self)
	turn = TurnInPlace.new(self)
	civ_panic = CivPanic.new(self)


func _ready() -> void:
	bind()
	EventBus.damage_applied.connect(_on_damage_applied)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.audio_cue_requested.connect(_on_audio_cue)
	EventBus.loot_dropped.connect(_on_loot_dropped)
	EventBus.interaction_started.connect(_on_interaction_started)
	EventBus.interaction_cancelled.connect(_on_interaction_ended)
	EventBus.interaction_completed.connect(_on_interaction_completed)


func _exit_tree() -> void:
	for pair: Array in [
		[EventBus.damage_applied, _on_damage_applied], [EventBus.weapon_fired, _on_weapon_fired],
		[EventBus.audio_cue_requested, _on_audio_cue],
		[EventBus.loot_dropped, _on_loot_dropped], [EventBus.interaction_started, _on_interaction_started],
		[EventBus.interaction_cancelled, _on_interaction_ended],
		[EventBus.interaction_completed, _on_interaction_completed],
	]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	held_visuals.clear_bag()  # v1.20: the LootBag shows its own visual again


## (Re)find the visual's AnimationPlayer and the weapon; returns true when active.
func bind() -> bool:
	_body = get_parent() as Node3D
	combat = combat if combat != null else CombatClips.new(self)
	_npc = _body as NpcBase
	_crew = _body as CrewController
	lod.reset()  # D-132: the old player back to IDLE, nothing banked
	player = find_player(_body)
	rig = player.get_parent() as Node3D if player != null else null
	set_process(player != null)
	if player == null:
		return false
	_rig_base_yaw = rig.rotation.y if rig != null else 0.0
	_visual_yaw = _body.global_rotation.y if _body.is_inside_tree() else _body.rotation.y
	_prev_body_yaw = _visual_yaw
	_last_pos = Vector3.INF
	_family_variants.clear()
	_variant_family.clear()
	if _crew != null and _crew.weapons != null and not _crew.weapons.equipped_changed.is_connected(_on_equipped):
		_crew.weapons.equipped_changed.connect(_on_equipped)
		_crew.weapons.reload_started.connect(_on_reload_started)
	refresh_weapon()
	# v1.19 weapon holds (D-116: NPCs too); first among the modifiers (the hat lift fixes up after it)
	hold_layer = UpperBodyLayer.ensure(rig.get_node_or_null(^"Skeleton3D") as Skeleton3D)
	var skel: Skeleton3D = rig.get_node_or_null(^"Skeleton3D") as Skeleton3D
	flinch_layer = UpperBodyLayer.ensure(skel, FLINCH_LAYER_NODE, 1)
	if _crew != null:
		crew_action = crew_action if crew_action != null else CrewActionAnim.new(self, _crew)
		crew_action.bind_layer(skel)  # over the weapon holds, under the flinch
	left_hand_ik = ThirdPersonLeftHandIK.ensure(skel)
	if clip == &"":
		# P GH regression: never show the rig's bind pose before the first tick (a spawn / visual swap renders a
		# frame before _process runs): start on idle at once; the next tick blends to the real state.
		var first: String = _resolve(&"idle")
		if first != "" and not player.is_playing():
			player.play(first, 0.0)  # `clip` stays &"": the first tick's clip still starts without a fade
	hat_lift = null
	if HardHatHandLift.wears_hard_hat(rig):
		hat_lift = HardHatHandLift.ensure(rig.get_node_or_null(^"Skeleton3D") as Skeleton3D)
	return true


func _process(delta: float) -> void:
	var fp: int = FrameProf.begin()
	_process_step(delta)
	FrameProf.end(&"anim_driver", fp)


func _process_step(delta: float) -> void:
	step_lod(delta, Engine.get_process_frames())


## D-132: one process frame through AnimLod: on its due frames the driver ticks with the banked time and the player
## samples it (FULL band: every frame, as before). Tests drive it with simulated frame numbers.
func step_lod(delta: float, frame: int) -> void:
	var dt: float = lod.step(delta, frame)
	if dt < 0.0:
		return
	tick(dt)
	lod.after_tick()


## Advance one presentation frame (tests call it directly).
func tick(delta: float) -> void:
	if player == null or _body == null or not is_instance_valid(player):
		return
	if _npc != null and NpcRagdoll.owns_pose(_npc):
		return  # PO6-19: the ragdoll owns the pose (paused player, baked skeleton, rig yaw kept)
	delta = maxf(delta, 0.0001)
	_sel_cached_rev = -1  # a new tick: choose afresh
	loop_resume.step(delta)
	var tw: AnimTweak = AnimTweak.data()
	_update_velocity(delta, tw)
	_sector_age += delta
	if _rev_state == REV_PLAYING:
		_rev_left -= delta
	_left_gait_age += delta
	_oneshot_left = maxf(_oneshot_left - delta, 0.0)
	net_oneshot_left = maxf(net_oneshot_left - delta, 0.0)
	_update_start_stop(tw)
	_aim_hold_left = maxf(_aim_hold_left - delta, 0.0)
	_update_crew_state_clips(delta)
	if crew_action != null:
		crew_action.update(delta)
	var hint: StringName = _hint()
	if hint != _last_hint:
		_last_hint = hint
		var once: StringName = combat.hint_oneshot(hint)  # D-116: hit_react while staggered (L4.5) = stagger_<fam>
		if ONESHOT_HINTS.has(hint) and not (once != hint and _oneshot == once and _oneshot_left > 0.0):
			play_oneshot(once, -1.0, true)
	_update_turn(delta, tw)
	combat.update_door_kick(_npc)  # D-116: the loud breach of a locked door (door_kick_<fam>)
	var want: StringName = civ_panic.apply(_choose_clip_tick(), delta)
	if _npc != null and _npc.alive:
		_seated = SEATED_CLIPS.has(want)
		_alive_clip = want
	_apply(want, _speed_scale_for(want, tw), tw)
	_hold_pose_end()
	layers.update_hold(delta, tw)
	layers.update_flinch(delta, tw)
	layers.update_left_hand_ik(delta, tw)
	if weapon_visual != null and is_instance_valid(weapon_visual):
		weapon_visual.visible = weapon_shown(want)
		if weapon_offhand != null and is_instance_valid(weapon_offhand):
			weapon_offhand.visible = weapon_visual.visible
		held_visuals.show_silhouette(weapon_visual.visible)
	if crew_action != null:
		crew_action.update_visuals(delta, tw)
	held_visuals.update_bag(tw)
	if hat_lift != null and is_instance_valid(hat_lift):
		var lift_on: float = 1.0 if tw.hard_hat_lift_clips.has(clip) else 0.0
		hat_lift.influence = move_toward(hat_lift.influence, lift_on, delta * tw.hard_hat_lift_rate)
		hat_lift.active = hat_lift.influence > 0.0


## v1.21 crew-state transitions, from the replicated crew_state (so every peer plays them):
##   DOWNED / CLOAKER_DOWNED -> CUFFED: downed_arrested (L2.12 police arrest; the weapon goes at `disarm`), then
##     crew_cuffed. Any other -> CUFFED: crew_cuffed_enter (a guard cuffs a standing heister), then crew_cuffed.
##   CUFFED -> NORMAL (uncuffed / self-free): crew_cuffed_free (the weapon comes back at `free`).
##   DOWNED / CLOAKER_DOWNED / TASED... -> NORMAL from a downed state (revive): downed_getup, then the current
##     hold (crossfade AnimTweak.getup_blend_s). A missing clip skips its step.
func _update_crew_state_clips(delta: float) -> void:
	if _state_oneshot_left > 0.0:
		_state_oneshot_left = maxf(_state_oneshot_left - delta, 0.0)
		_state_oneshot_t += delta * _state_oneshot_speed
	if _crew == null:
		return
	var now: int = _crew.crew_state
	var was: int = _last_crew_state
	_last_crew_state = now
	if was == -1 or was == now:
		return
	var downed: Array[int] = [Enums.CrewState.DOWNED, Enums.CrewState.CLOAKER_DOWNED]
	_state_oneshot_left = 0.0
	if crew_action != null:
		crew_action.end()  # v1.23: downed / tased / cuffed cut the mask-up or the throw
	if now == Enums.CrewState.CUFFED:
		_play_state_oneshot(&"downed_arrested" if downed.has(was) else &"crew_cuffed_enter")
	elif was == Enums.CrewState.CUFFED and now == Enums.CrewState.NORMAL:
		_play_state_oneshot(&"crew_cuffed_free")
	elif downed.has(was) and now == Enums.CrewState.NORMAL:
		_play_state_oneshot(&"downed_getup")


## Start crew-state one-shot `c` (when the rig has it) for `duration` s (-1 = its length / speed).
func _play_state_oneshot(c: StringName, duration: float = -1.0, speed: float = 1.0) -> void:
	if not _has_clip(c):
		return
	_state_oneshot = c
	_sel_rev += 1
	_state_oneshot_speed = speed
	_state_oneshot_t = 0.0
	_oneshot_left = 0.0
	_state_oneshot_left = duration if duration >= 0.0 \
		else player.get_animation("%s/%s" % [LIBRARY, c]).length / maxf(speed, 0.01)
	_restart = true
	_oneshot = c  # _apply restarts it from frame 0 when it repeats (downed_fire per shot)


## v1.21: whether the third-person weapon shows with clip `c` playing. Hidden in poses, in death and while cuffed
## (crew_cuffed*, kneel_cuffed*); shown while downed (downed / downed_fire / downed_reload / downed_getup); in
## downed_arrested until its `disarm` event, in crew_cuffed_free from its `free` event (AnimTweak event times).
func weapon_shown(c: StringName) -> bool:
	if _death_clip != &"" or (crew_action != null and crew_action.holsters_weapon()):
		return false  # v1.23: none while casing (PD2), drawn when mask_on has finished
	var tw: AnimTweak = AnimTweak.data()
	match c:
		&"downed", &"downed_crawl", &"downed_fire", &"downed_reload", &"downed_getup":
			return true
		&"downed_arrested":
			return _state_oneshot_t < tw.disarm_s()
		&"crew_cuffed_free":
			return _state_oneshot_t >= tw.free_s()
	return not POSE_CLIPS.has(c)


## Play `p_clip` once for `duration` seconds (-1 = the clip's length / speed). `while_moving` lets it
## override locomotion (throw_bag, melee); otherwise it shows only while standing (fire, reload, turn). `start`: the
## clip time it starts from (D-116 door_kick joining its breach late).
func play_oneshot(p_clip: StringName, duration: float = -1.0, while_moving: bool = false, speed: float = 1.0,
		start: float = 0.0) -> void:
	if player == null:
		return
	var full: String = _resolve(p_clip)
	if full == "":
		return
	if String(_oneshot).begins_with("stagger_") and _oneshot_left > 0.0 and not String(p_clip).begins_with("stagger_"):
		return  # D (motion strips): the stagger plays out; a shot / turn / flinch inside it would hand over to the cover loop
	if duration < 0.0:
		duration = player.get_animation(full).length / maxf(speed, 0.01)
	_oneshot = p_clip
	_sel_rev += 1
	_oneshot_left = duration
	_oneshot_dur = duration
	_oneshot_speed = speed
	_oneshot_while_moving = while_moving
	_oneshot_start = start
	_restart = true


## The clip this frame's state asks for (pure selection; see the class doc for the priorities).
func choose_clip() -> StringName:
	if _npc != null and not _npc.alive:
		if _death_clip == &"":
			_death_clip = hits.pick_death_clip(AnimTweak.data())
		return _death_clip
	var state_clip: StringName = _state_clip()
	if state_clip != &"":
		return _held_pose(pose_variant(state_clip))
	var hint_clip: StringName = HINT_CLIPS.get(_hint(), &"")
	if POSE_CLIPS.has(hint_clip) or ACTION_CLIPS.has(hint_clip):
		return _held_pose(pose_variant(hint_clip))
	if crew_action != null and crew_action.action != &"" and horizontal_speed() <= AnimTweak.data().move_threshold_mps:
		return crew_action.action  # v1.23 standing: full body (moving: CrewActionAnim's upper-body layer)
	return _idle_variant(_shield_clip(_active_clip(hint_clip)))


## The body's idle / idle_alert variant (VARIANT_GROUPS) for the plain stands only: after the shield remap (a raised
## shield keeps its shield idle), never the armed idle_alert_<kind> holds.
func _idle_variant(c: StringName) -> StringName:
	return pose_variant(c) if c == &"idle" or c == &"idle_alert" else c


## A4-02: choose_clip() at most once per tick unless a one-shot started since (TurnInPlace asks first; the tick reuses
## it). Outside tick() it is choose_clip().
func _choose_clip_tick() -> StringName:
	if _sel_cached_rev != _sel_rev:
		_sel_clip = choose_clip()
		_sel_cached_rev = _sel_rev
	return _sel_clip


## characters.md v1.18: this body's variant index, hash(net_id) % 3: the same on every peer (net ids replicate) and
## for the body's life, shared by every VARIANT_GROUPS group.
func variant_index() -> int:
	return absi(hash(_net_id())) % 3


## `p_clip`'s variant for this body (VARIANT_GROUPS), or `p_clip` (not a variant group, no rig, or the rig lacks
## the variant: the original plays).
func pose_variant(p_clip: StringName) -> StringName:
	if not VARIANT_GROUPS.has(p_clip) or player == null:
		return p_clip
	var group: Array = _variant_group(p_clip)
	var v: StringName = group[variant_index() % group.size()]
	return v if player.has_animation("%s/%s" % [LIBRARY, v]) else p_clip


## The VARIANT_GROUPS list of `group` (cached in _family_variants, members registered in _variant_family).
func _variant_group(group: StringName) -> Array:
	if not _family_variants.has(group):
		var out: Array[StringName] = []
		for v: Variant in VARIANT_GROUPS[group]:
			out.append(v as StringName)
			_variant_family[v] = group
		_family_variants[group] = out
	return _family_variants[group] as Array


## A HOLD_END one-shot that has finished plays its held loop when the library has it (else it stays, frozen).
func _held_pose(p_clip: StringName) -> StringName:
	if not HOLD_END.has(p_clip):
		if not _hold_done.is_empty() and not HOLD_END.values().has(p_clip):
			_hold_done.clear()
		return p_clip
	var idle: StringName = HOLD_END[p_clip]
	if _hold_done.get(p_clip, false) and player != null and player.has_animation("%s/%s" % [LIBRARY, idle]):
		return idle
	return p_clip


## Called after _apply: a HOLD_END one-shot at its end is marked done and, with no held loop, frozen on its last
## frame while the player keeps playing (driver and player agree).
func _hold_pose_end() -> void:
	_pose_frozen = false
	if not HOLD_END.has(clip) or player == null:
		return
	var full: String = "%s/%s" % [LIBRARY, clip]
	if not player.has_animation(full):
		return
	var length: float = player.get_animation(full).length
	var at_end: bool = not player.is_playing() or String(player.current_animation) != full \
		or player.current_animation_position >= length - 0.05
	if not at_end and not _hold_done.get(clip, false):
		return
	_hold_done[clip] = true
	if player.has_animation("%s/%s" % [LIBRARY, HOLD_END[clip]]):
		return  # choose_clip switches to the loop next frame
	if String(player.current_animation) != full or not player.is_playing():
		player.play(full, 0.0)
	player.seek(maxf(length - 0.001, 0.0), true)
	player.speed_scale = 0.0
	_pose_frozen = true


## The BulwarkShield this NPC carries (the brain's `shield`, else a `Shield` child), or null.
func carried_shield() -> BulwarkShield:
	if _npc == null:
		return null
	var b: Node = _body.get_node_or_null(^"Brain")
	var s: BulwarkShield = b.get(&"shield") as BulwarkShield if b != null else null
	if s == null:
		s = _body.get_node_or_null(^"Shield") as BulwarkShield
	return s if s != null and is_instance_valid(s) and s.carrier == _npc and s.get_parent() == _body else null


## True while the NPC holds its shield up (carried, guard up, not dropped): the shield clip set plays.
func shield_up() -> bool:
	var s: BulwarkShield = carried_shield()
	return s != null and not s.dropped and not s.guard_down


## `c` remapped to its shield clip (AnimTweak.shield_clips) while the shield is up and the rig has that
## family; otherwise `c`.
func _shield_clip(c: StringName) -> StringName:
	var key: StringName = &"idle_alert" if String(c).begins_with("idle_alert_") else c  # v1.21 armed NPC idles
	var fam: StringName = AnimTweak.data().shield_clips.get(key, &"")
	if fam == &"" or not shield_up():
		return c
	var vs: Array = _variants_of(fam)
	return c if vs.is_empty() else StringName(vs[absi(_net_id()) % vs.size()])


## Library clips of family `fam` (`fam`, `fam_*`, `fam<digit>*`), sorted; cached per bind.
func _variants_of(fam: StringName) -> Array:
	if _family_variants.has(fam):
		return _family_variants[fam] as Array
	var out: Array[StringName] = []
	var lib: AnimationLibrary = player.get_animation_library(LIBRARY) if player.has_animation_library(LIBRARY) \
		else null
	if lib != null:
		var f: String = String(fam)
		for n: StringName in lib.get_animation_list():
			var rest: String = String(n).substr(f.length()) if String(n).begins_with(f) else "-"
			if rest == "" or rest.begins_with("_") or (rest != "-" and rest[0].is_valid_int()):
				out.append(n)
				_variant_family[n] = fam
		out.sort()
	_family_variants[fam] = out
	return out


## Below the poses: interaction (crew) > one-shot > locomotion > aim > hint idle > idle.
func _active_clip(hint_clip: StringName) -> StringName:
	var tw: AnimTweak = AnimTweak.data()
	var speed: float = horizontal_speed()
	var moving: bool = speed > tw.move_threshold_mps
	var out: StringName = _idle_clip()
	var aiming: bool = _aiming()
	var cover: StringName = combat.cover_clip(_npc) if _npc != null and not moving and aiming else &""
	# D-116: on a cover post the cover loop plays on through the shots and turns (they would restart it).
	var cover_hold: bool = cover != &"" and (String(_oneshot).begins_with("fire_") or String(_oneshot).begins_with("turn_"))
	if _interact_kind != &"" and _crew != null:
		out = _interact_clip(tw)  # D-115: an interaction (revive, bag, drill...) beats a turn / hit / fire one-shot
	elif _oneshot_left > 0.0 and (not moving or _oneshot_while_moving) and not cover_hold:
		out = _oneshot
	elif moving:
		out = _reversal_step(_locomotion_clip(speed, tw))
	elif aiming:
		out = cover if cover != &"" else aim_clip()
	elif hint_clip != &"" and hint_clip != &"idle" and not ONCE_ONLY_HINTS.has(hint_clip):
		out = pose_variant(hint_clip)  # OF-D1: an ambient variant group (queue_idle*) plays this body's member
	return out


## Horizontal speed estimate (m/s) used for locomotion.
func horizontal_speed() -> float:
	return Vector2(_vel.x, _vel.z).length()


## Rebuild the third-person weapon at `HandR/Socket` (crew: equipped weapon; NPC: EnemyDef.weapon; HeldVisuals).
func refresh_weapon() -> void:
	held_visuals.refresh_weapon()


# --- Selection helpers ---------------------------------------------------------------------

func _crew_state_clip() -> StringName:
	if _state_oneshot_left > 0.0:
		return _state_oneshot
	var sc: StringName = CREW_STATE_CLIPS.get(_crew.crew_state, &"")
	if sc == &"kneel_cuffed" and _has_clip(&"crew_cuffed"):
		return &"crew_cuffed"  # v1.21: cuffed crew stand, wrists behind the back
	if sc == &"downed" and horizontal_speed() > AnimTweak.data().move_threshold_mps:
		return &"downed_crawl"  # v1.10: a downed body being moved (bleed-out drag)
	return sc


## PO6-17 META_ANIM_OVERRIDE, else the QC-41 rope descent (characters.md v1.8 `rappel` loop), else &"".
func _scripted_clip() -> StringName:
	var ov: Variant = _npc.get_meta(META_ANIM_OVERRIDE, &"")
	if ov is StringName and ov != &"" and _npc.alive:
		return ov
	var motor: NpcMotor = _body.get_node_or_null(^"Motor") as NpcMotor
	return &"rappel" if motor != null and motor.rappelling else &""


func _state_clip() -> StringName:
	if _crew != null:
		return _crew_state_clip()
	if _npc == null:
		return &""
	if _npc.is_stunned():
		return &"tased"
	var scripted: StringName = _scripted_clip()
	if scripted != &"":
		return scripted
	if Net.is_authority() and _hint() != &"":
		return &""  # the host's brain hint is authoritative; the fallbacks below are for clients
	var out: StringName = &""
	match _npc.alert_state:
		Enums.AlertState.TIED:
			out = &"tied" if _npc.role == &"civilian" else &"kneel_cuffed"  # tied cops / guards kneel cuffed (as host)
		Enums.AlertState.SURRENDERED:
			out = &"surrender"
		Enums.AlertState.INTIMIDATED, Enums.AlertState.DOMINATED:
			out = &"lie_down" if _npc.role == &"civilian" else &"hands_up"
		Enums.AlertState.PANICKED:
			out = &"cower" if horizontal_speed() <= AnimTweak.data().move_threshold_mps else &""
			if out == &"cower" and CivilianBrain.SEATED_ACTIVITIES.has(StringName(_npc.spawn_info.get("idle_activity", ""))):
				out = &"cower_seated"  # client approximation: a seated civilian that has not run
	return out


func _locomotion_clip(speed: float, tw: AnimTweak) -> StringName:
	var special: StringName = _special_locomotion(speed, tw)
	if special != &"":
		return special
	var fwd: Vector3 = -_body.global_transform.basis.z
	var right: Vector3 = _body.global_transform.basis.x
	var dir: Vector3 = Vector3(_vel.x, 0.0, _vel.z) / maxf(speed, 0.0001)
	var out: StringName = &"sprint"
	var side: float = dir.dot(right)
	var slow: bool = speed <= tw.strafe_max_mps
	var running: bool = not slow and speed <= tw.run_sprint_split_mps
	if slow or running:
		# characters.md v1.10 8-way: 45 deg sectors clockwise from forward (diagonals fall back to the 4-way set).
		var a: float = rad_to_deg(atan2(side, dir.dot(fwd)))
		var i: int = posmod(roundi(a / 45.0), 8)
		# D (motion strips, PO "inorganic"): into a NEIGHBOURING sector, keep the current one until the angle is past
		# its centre by the hysteresis, and hold a new one at least the min hold (the 8-way clip changed nearly every
		# tick). A real turn (two sectors or more) switches at once.
		var neighbour: bool = _sector >= 0 and absi(posmod(i - _sector + 4, 8) - 4) == 1
		if neighbour and (_sector_age < tw.locomotion_sector_min_hold_s
				or absf(wrapf(a - float(_sector) * 45.0, -180.0, 180.0)) <= tw.locomotion_sector_hysteresis_deg):
			i = _sector
		if i != _sector:
			_sector = i
			_sector_age = 0.0
		var clips: Array[StringName] = WALK_8 if slow else RUN_8
		out = clips[i]
		if i == 0:  # straight ahead: walk / run by the usual split
			out = &"walk" if speed <= tw.walk_run_split_mps else &"run"
	return out


## Crouch / carry / sprint (crew), flee (panicked civilians) and the unit's own walk clip (EnemyDef
## params anim_walk_clip, only at walking speed); &"" = pick by speed and direction.
func _special_locomotion(speed: float, tw: AnimTweak) -> StringName:
	var out: StringName = &""
	if _crew != null:
		if _crew.crouched:
			out = &"crouch_walk"
		elif _crew.is_carrying_bag():
			out = &"carry_bag_walk"
		elif _crew.sprinting:
			out = &"sprint"
	elif _npc != null and _hint() == &"mug_walk":
		out = &"mug_carry_walk"  # D-069: walking with a mug, speed_scale = v / 1.3
	elif _npc != null and _hint() == &"walk_text":
		out = &"walk_text"  # D-103: walking while texting (characters.md v1.9, 1.2 m/s)
	elif _npc != null and _npc.role == &"civilian" and (
			_npc.alert_state == Enums.AlertState.PANICKED or _hint() == &"run" or _hint() == &"flee"):
		out = pose_variant(&"flee")  # D-116 flee_b / flee_c (the same gait)
	elif _npc != null:
		out = _unit_walk_clip(speed, tw)
	return out


## The NPC's own walk clip at `speed`, or &"" (no such clip, or faster than a walk: never above
## AnimTweak.speed_scale_max nor walk_run_split_mps; then run / sprint play).
func _unit_walk_clip(speed: float, tw: AnimTweak) -> StringName:
	if _npc.enemy_def == null or not _npc.enemy_def.params.has(WALK_CLIP_PARAM):
		return &""
	var c: StringName = StringName(str(_npc.enemy_def.params[WALK_CLIP_PARAM]))
	var clip_speed: float = float(tw.clip_speeds.get(c, tw.clip_speeds.get(&"walk", 1.6))) * _motion_scale()
	if c == &"" or speed > minf(tw.walk_run_split_mps, clip_speed * tw.speed_scale_max):
		return &""
	return c


func _interact_clip(tw: AnimTweak) -> StringName:
	if _interact_kind == &"answer_pager":
		return &"pager_answer"
	if _interact_kind == &"place_drill" or _interact_kind == &"fix_drill":
		return &"drill_place"  # D-111: setting / fixing a drill
	if _interact_height < tw.interact_low_max_m:
		return armed_clip(&"interact_low")
	return armed_clip(&"interact_high" if _interact_height > tw.interact_high_min_m else &"interact_mid")


## characters.md v1.20 (SOURCE armed_interactions): `c`'s `_armed` variant (the left hand works, the weapon stays
## low in the right) while the crew body holds a weapon and the rig has it; otherwise `c`.
func armed_clip(c: StringName) -> StringName:
	if _crew == null or not _holds_weapon or not ARMED_CLIPS.has(c) or player == null:
		return c
	var a: StringName = StringName(String(c) + ARMED_SUFFIX)
	return a if player.has_animation("%s/%s" % [LIBRARY, a]) else c


## v1.20 carried-bag visual at Back/Socket (HeldVisuals.update_bag).
func _update_bag_visual(tw: AnimTweak) -> void:
	held_visuals.update_bag(tw)


func _idle_clip() -> StringName:
	if _crew != null:
		if _crew.crouched:
			return &"crouch_idle"
		if not _crew.masked:
			return &"idle"
		var held: StringName = _held_weapon_clip(&"idle_alert_")
		return held if held != &"" else &"idle_alert"
	if _npc != null and ALERT_STATES.has(_npc.alert_state):
		var npc_held: StringName = StringName("idle_alert_" + String(weapon_kind))
		# v1.21 (SOURCE weapon_holds: armed NPCs too): an alerted NPC with a modelled weapon holds it at the low ready.
		return npc_held if weapon_visual != null and _has_clip(npc_held) else &"idle_alert"
	return &"idle"


## characters.md v1.19: a masked crew body (human teammate or bot) holding a weapon: `<prefix><kind>` (idle_alert_ /
## hold_ + rifle / pistol, AnimDriver.weapon_kind from _kind_for) when the rig has it, else &"".
func _held_weapon_clip(prefix: String) -> StringName:
	if _crew == null or not _crew.masked or not _holds_weapon or player == null:
		return &""
	var c: StringName = StringName(prefix + String(weapon_kind))
	return c if player.has_animation("%s/%s" % [LIBRARY, c]) else &""


## Locomotion clips the v1.19 weapon-hold layer goes over (SOURCE weapon_holds: walk / run / strafe*; v1.25 also
## sprint and crouch_walk).
static func _layered_locomotion(c: StringName) -> bool:
	var s: String = String(c)
	if s == "walk_text":
		return false
	return s == "walk" or s == "run" or s.begins_with("walk_") or s.begins_with("run_") or s.begins_with("strafe_") \
		or s == "sprint" or s == "crouch_walk"  # v1.25


func _aiming() -> bool:
	if _crew != null:
		return _aim_hold_left > 0.0 or (_crew.weapons != null and _crew.weapons.is_shooting())
	var h: StringName = _hint()
	if h == &"aim":
		return true
	var gunner: NpcGunner = _body.get_node_or_null(^"Gunner") as NpcGunner
	return gunner != null and gunner.engaging


## The brain's anim_hint (a non-empty `Surrender` component hint wins) on the host; on a client only the NET_HINTS
## the host replicates (NetEntityCodec NPC state "ah" -> META_NET_HINT).
func _hint() -> StringName:
	if _npc == null:
		return &""
	if not Net.is_authority():
		var nh: Variant = _npc.get_meta(META_NET_HINT, &"")
		return nh if nh is StringName else &""
	var s: Node = _body.get_node_or_null(^"Surrender")
	if s != null:
		var sh: Variant = s.get(&"anim_hint")
		if sh is StringName and sh != &"":
			return sh
	var b: Node = _body.get_node_or_null(^"Brain")
	if b == null:
		return &""
	var h: Variant = b.get(&"anim_hint")
	return AmbientHints.resolve(_npc, combat, h if h is StringName else &"")  # D-111 dance pick, D-069 substitutions


func _speed_scale_for(p_clip: StringName, tw: AnimTweak) -> float:
	if _death_hold and p_clip == _death_clip:
		return 0.0
	if _hold_done.get(p_clip, false) and HOLD_END.has(p_clip):
		return 0.0  # frozen on the last frame (_hold_pose_end)
	if p_clip == _state_oneshot and _state_oneshot_left > 0.0:
		return _state_oneshot_speed
	if p_clip == _oneshot and _oneshot_left > 0.0:
		return _oneshot_speed
	var key: StringName = p_clip
	if not tw.clip_speeds.has(key):
		key = StringName(_variant_family.get(p_clip, &""))
	if not tw.clip_speeds.has(key):  # v1.10 8-way: the diagonals run at their family's speed
		key = &"walk" if String(p_clip).begins_with("walk_") else (&"run" if String(p_clip).begins_with("run_") else key)
	if not tw.clip_speeds.has(key):
		return 1.0
	var s: float = horizontal_speed() / maxf(float(tw.clip_speeds[key]) * _motion_scale(), 0.01)
	return clampf(s, tw.speed_scale_min, tw.speed_scale_max)


## Skeleton3D.motion_scale of the rig (1 when unset): clip speeds scale with character height.
func _motion_scale() -> float:
	var skel: Skeleton3D = rig.get_node_or_null(^"Skeleton3D") as Skeleton3D if rig != null else null
	return skel.motion_scale if skel != null and skel.motion_scale > 0.0 else 1.0


# --- Frame update helpers ---------------------------------------------------------------------

## v1.10 starts / stops: setting off straight ahead from a standstill plays walk_start / run_start, stopping out
## of a straight walk / run plays walk_stop / run_stop (one-shots; never over another one-shot, a pose or a death).
func _update_start_stop(tw: AnimTweak) -> void:
	var speed: float = horizontal_speed()
	var moving: bool = speed > tw.move_threshold_mps
	var was: bool = _was_moving
	_was_moving = moving
	if moving == was or _oneshot_left > 0.0 or (_npc != null and not _npc.alive):
		return
	if POSE_CLIPS.has(clip) or (_crew != null and _crew.crouched):
		return
	if moving:
		var fwd: Vector3 = -_body.global_transform.basis.z
		var dir: Vector3 = Vector3(_vel.x, 0.0, _vel.z).normalized()
		if dir.dot(fwd) >= START_STOP_DOT and (String(clip).begins_with("idle") or clip == &""):
			_play_if_present(&"walk_start" if speed <= tw.walk_run_split_mps else &"run_start", true)
	elif clip == &"walk" or clip == &"run":
		_play_if_present(&"walk_stop" if clip == &"walk" else &"run_stop", false)


## RT-D1: the vehicle dismount one-shot out of the `left` / right door; false (nothing plays) when the rig lacks it.
func play_vehicle_exit(left: bool) -> bool:
	var c: StringName = VEHICLE_EXIT_L if left else VEHICLE_EXIT_R
	if player == null or not player.has_animation("%s/%s" % [LIBRARY, c]):
		return false
	play_oneshot(c, -1.0, true)
	return true


## Seconds of vehicle_exit_l / _r on this rig, 0 when it has none (the mission slides the root out over it).
func vehicle_exit_length(left: bool) -> float:
	var key: String = "%s/%s" % [LIBRARY, VEHICLE_EXIT_L if left else VEHICLE_EXIT_R]
	if player == null or not player.has_animation(key):
		return 0.0
	return player.get_animation(key).length


## A one-shot only when the library has exactly that clip (the fallback chain would play idle / walk instead).
func _play_if_present(p_clip: StringName, while_moving: bool) -> void:
	if player != null and player.has_animation("%s/%s" % [LIBRARY, p_clip]):
		play_oneshot(p_clip, -1.0, while_moving)

func _update_velocity(delta: float, tw: AnimTweak) -> void:
	var pos: Vector3 = _body.global_position if _body.is_inside_tree() else _body.position
	var cb: CharacterBody3D = _body as CharacterBody3D
	var remote_crew: bool = _crew != null and not _crew.is_ai and _crew.peer_id != 0 \
		and _crew.peer_id != Net.local_peer_id()
	if cb != null and Net.is_authority() and not remote_crew:
		_vel = cb.velocity
	elif _last_pos != Vector3.INF:
		var raw: Vector3 = (pos - _last_pos) / delta
		if raw.length() <= tw.teleport_speed_mps:
			_vel = _vel.lerp(raw, clampf(tw.velocity_smoothing * delta, 0.0, 1.0))
	_last_pos = pos
	if _npc != null and not _npc.alive:
		_vel = Vector3.ZERO


## Turn in place (TurnInPlace: turn_*_45 / turn_l / turn_r at speed 1, the rig yaw at the clip's own rate).
func _update_turn(delta: float, tw: AnimTweak) -> void:
	turn.update(delta, tw)


func _apply(want: StringName, speed: float, tw: AnimTweak) -> void:
	var full: String = _resolve(want)
	if full == "":
		return
	var restart: bool = _restart and want == _oneshot
	if want != clip or restart:
		var blend: float = tw.blend_s
		if clip == &"":
			blend = 0.0  # first clip: no fade in from the bind pose (spawn A-pose flash)
		elif want == _death_clip:
			blend = tw.death_blend_s
		elif HOLD_END.get(clip, &"") == want or (want == &"crew_cuffed" and CUFF_INTO.has(clip)):
			blend = 0.0  # surrender* -> surrender_idle* (v1.18); downed_arrested / crew_cuffed_enter -> crew_cuffed (v1.21)
		elif clip == &"downed_getup":
			blend = tw.getup_blend_s  # v1.21: from hold_pistol f0 into the current weapon's hold
		elif CivPanic.blend(clip, want) >= 0.0:
			blend = CivPanic.blend(clip, want)  # D-116 panic_start in 0.1 s; out: cower 0, cower_b / _c, flee*
		elif want == _oneshot:
			blend = tw.hit_zone_blend_in_s if HIT_ZONE_CLIPS.has(want) else tw.oneshot_blend_s
		elif HIT_ZONE_CLIPS.has(clip):
			blend = tw.hit_zone_blend_out_s
		elif String(want).contains("_reverse_") or (want == _rev_target and _rev_seek >= 0.0):
			blend = 0.0  # v1.27: frame 0 IS the source loop at u_in; the last frame IS the target loop at u_out
		elif _reversal(clip, want):
			blend = tw.locomotion_reversal_blend_s  # D: opposite strides averaged fold the legs into a squat (fallback)
		var chained: bool = HOLD_END.get(clip, &"") == want or CivPanic.chained(clip, want)
		loop_resume.leaving(clip, want)
		var carry: float = _gait_phase(clip, want)
		player.play(full, blend)
		last_blend_s = blend
		if restart:
			player.seek(_oneshot_start, true)
		elif want == _rev_target and _rev_seek >= 0.0:
			player.seek(_rev_seek * player.get_animation(full).length, true)
			_rev_seek = -1.0
			_rev_target = &""
		elif carry >= 0.0:  # D: same gait family, shared foot contacts: the new direction keeps the stride's phase
			player.seek(carry * player.get_animation(full).length, true)
		elif not chained and not loop_resume.resume(want, full):  # D-115: a loop cut by a one-shot resumes its phase
			_seek_loop_offset(want, full)
		clip = want
		_restart = false
		hand_props = HandProps.sync(rig, StringName(full.get_slice("/", 1)))  # D-115 (characters.md v1.16)
		HeldVisuals.update_slung(rig, StringName(full.get_slice("/", 1)))  # v1.27: no slung gun through the chair
	if crew_action != null and want == crew_action.action:
		player.seek(crew_action.time, true)  # v1.23: the action's time and rate are CrewActionAnim's (the hold drives it)
		speed = crew_action.speed
	player.speed_scale = speed


## D (motion strips): the normalised time of `from` to carry into `to` (shifted by the back group's phase offset
## between a forward and a backward clip) when both are loops of one 8-way gait family
## (walk / walk_* / walk_back at 30 f, run / run_* at 21 f; strafe_l / _r (18 f), the starts / stops and walk_text
## stay out), else -1.
func _gait_phase(from: StringName, to: StringName) -> float:
	var fam: String = _gait_family(from)
	if fam == "" and _gait_family(to) != "" and _gait_family(to) == _gait_family(_left_gait) \
			and _left_gait_age <= AnimTweak.data().locomotion_resume_window_s and player != null:
		# back into the family within the resume window (a short stop / idle frame): the old stride, run on
		var la: Animation = player.get_animation("%s/%s" % [LIBRARY, _left_gait]) \
			if player.has_animation("%s/%s" % [LIBRARY, _left_gait]) else null
		var lu: float = _left_gait_u + (_left_gait_age / la.length if la != null and la.length > 0.0 else 0.0)
		var sh: float = (1.0 if _gait_back(to) else 0.0) - (1.0 if _gait_back(_left_gait) else 0.0)
		return fposmod(lu + sh * AnimTweak.data().locomotion_back_phase_offset, 1.0)
	if fam == "" or player == null or not player.is_playing():
		return -1.0
	var a: Animation = player.get_animation(player.current_animation)
	if a == null or a.length <= 0.0:
		return -1.0
	var u: float = player.current_animation_position / a.length
	if _gait_family(to) == "":  # leaving the family: remember the stride for a quick resume
		_left_gait = from
		_left_gait_u = u
		_left_gait_age = 0.0
		return -1.0
	if fam != _gait_family(to):
		return -1.0
	# D (test_loco_phase): the backward clips' feet run back_phase_offset of a cycle after the forward ones.
	var shift: float = (1.0 if _gait_back(to) else 0.0) - (1.0 if _gait_back(from) else 0.0)
	return fposmod(u + shift * AnimTweak.data().locomotion_back_phase_offset, 1.0)


## characters v1.27: `want` after the reversal gate. A >= 135 deg run <-> run_b / walk <-> walk_back switch with D's
## clips holds the source loop until the next brake-foot touch-down (u_in, the nearer of the two), then plays the
## reversal clip (no crossfade), then the target loop from u_out (no crossfade). Root travel stays the motor's (the body is
## server-moved by its velocity; the clip's curve is not applied to the body). Any other switch passes through.
func _reversal_step(want: StringName) -> StringName:
	if _rev_state == REV_PLAYING:
		if _rev_left > 0.0:
			return _rev_clip
		_rev_state = REV_NONE
		_rev_seek = _rev_u_out
		return _rev_target
	if _rev_state == REV_PENDING:
		return _reversal_pending(want)
	var u: float = _clip_u()
	var options: Array = AnimTweak.reversals().get(StringName("%s>%s" % [clip, want]), []) if u >= 0.0 else []
	var best: Dictionary = {}
	for o: Dictionary in options:
		if _has_clip(o["clip"]) and (best.is_empty()
				or fposmod(float(o["u_in"]) - u, 1.0) < fposmod(float(best["u_in"]) - u, 1.0)):
			best = o
	if best.is_empty():
		return want
	_rev_state = REV_PENDING
	_rev_clip = best["clip"]
	_rev_target = want
	_rev_u_in = best["u_in"]
	_rev_u_out = best["u_out"]
	_rev_prev_u = u
	return clip


## REV_PENDING: the source loop until it crosses u_in, then the reversal clip; a new turn cancels it.
func _reversal_pending(want: StringName) -> StringName:
	var u: float = _clip_u()
	if want != _rev_target or u < 0.0:
		_rev_state = REV_NONE  # turned again (or the source is gone): plain switch
		return want
	var crossed: bool = (_rev_prev_u <= _rev_u_in and u >= _rev_u_in) if u >= _rev_prev_u \
		else (_rev_prev_u <= _rev_u_in or u >= _rev_u_in)  # wrapped past 1
	_rev_prev_u = u
	if not crossed:
		return clip
	_rev_state = REV_PLAYING
	_rev_left = player.get_animation("%s/%s" % [LIBRARY, _rev_clip]).length
	return _rev_clip


## The current base loop's normalised time, -1 when nothing plays.
func _clip_u() -> float:
	if player == null or not player.is_playing():
		return -1.0
	var a: Animation = player.get_animation(player.current_animation)
	return fposmod(player.current_animation_position / a.length, 1.0) if a != null and a.length > 0.0 else -1.0


## D (motion strips): two 8-way locomotion clips 135 deg or more apart (run <-> run_b, run_bl <-> run_r ...).
static func _reversal(from: StringName, to: StringName) -> bool:
	var a: int = _sector_of(from)
	var b: int = _sector_of(to)
	return a >= 0 and b >= 0 and absi(posmod(a - b + 4, 8) - 4) >= 3


static func _sector_of(c: StringName) -> int:
	var i: int = WALK_8.find(c)
	return i if i >= 0 else RUN_8.find(c)


static func _gait_back(c: StringName) -> bool:
	return c in [&"walk_back", &"walk_bl", &"walk_br", &"run_b", &"run_bl", &"run_br"]


static func _gait_family(c: StringName) -> String:
	if not (WALK_8.has(c) or RUN_8.has(c)) or String(c).begins_with("strafe_"):
		return ""
	return "walk" if WALK_8.has(c) else "run"


## v1.18: a variant-group loop (OFFSET_LOOP_GROUPS) starts at this body's random offset so a room of surrendered
## NPCs never breathes in sync. The offset comes from GameRng `anim_variants`; it is presentation only (no gameplay
## reads animation state) and each peer draws it in its own bind order, so peers may show different loop phases.
## The pose itself (the variant) is hash(net_id), identical on every peer.
## v1.19: the weapon-hold loops (idle_alert_<kind>, the hold_<kind> layer) start the same way (group &"weapon_hold").
func _seek_loop_offset(want: StringName, full: String) -> void:
	var group: StringName = StringName(_variant_family.get(want, &""))
	if group == &"" and String(want).begins_with("idle_alert_"):
		group = &"weapon_hold"
	if group == &"" or not (OFFSET_LOOP_GROUPS.has(group) or group == &"weapon_hold") \
			or full.get_slice("/", 1) != String(want):
		return
	var a: Animation = player.get_animation(full)
	if a == null or a.loop_mode == Animation.LOOP_NONE or a.length <= 0.0:
		return
	player.seek(_loop_offset(group) * a.length, true)


## This body's loop start fraction for `group` in [0, 1), drawn once from GameRng `anim_variants`.
func _loop_offset(group: StringName) -> float:
	if not _loop_offsets.has(group):
		_loop_offsets[group] = GameRng.stream(&"anim_variants").randf()
	return _loop_offsets[group]


## "humanoid/<clip>", else the fallback chain (FALLBACK_CLIPS, then idle); "" when nothing exists.
func _resolve(p_clip: StringName) -> String:
	var c: StringName = p_clip
	for _i: int in 4:
		var full: String = "%s/%s" % [LIBRARY, c]
		if player.has_animation(full):
			return full
		c = FALLBACK_CLIPS.get(c, &"idle")
	return ""


## The aim / fire / reload clip family of weapon_kind: &"pistol" (pistol, akimbo) or &"rifle" (every other kind).
func aim_family() -> StringName:
	return &"pistol" if PISTOL_KINDS.has(weapon_kind) else &"rifle"


## Hold kind (characters.md v1.20) of `def` (HeldVisuals.kind_for).
func _kind_for(def: WeaponDef) -> StringName:
	return held_visuals.kind_for(def)


func _net_id() -> int:
	if _npc != null:
		return _npc.net_id
	return _crew.net_id if _crew != null else 0


# --- Events ---------------------------------------------------------------------------------

func _on_damage_applied(victim_net_id: int, _attacker: int, info: Dictionary) -> void:
	if victim_net_id == 0 or victim_net_id != _net_id():
		return
	_hit_dir = info.get("direction", Vector3.ZERO)
	if player == null or bool(info.get("killed", false)) or float(info.get("amount", 0.0)) <= 0.0:
		return
	if _npc != null and not _npc.alive:
		return
	if _crew != null and _crew.crew_state != Enums.CrewState.NORMAL:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_hit_react_t < AnimTweak.data().hit_react_min_gap_s:
		return
	_last_hit_react_t = now
	# D-116: an explosion staggers a non-shield NPC in place (stagger_<fam>), else the flinches
	var stagger: StringName = combat.stagger_clip() if combat.explosion_staggers(_npc, info) else &""
	var zone_clip: StringName = hit_zone_clip(info) if stagger == &"" else &""
	if _crew != null and _interact_kind != &"":
		# D-115: interacting, the body keeps its interact clip (upper-body flinch only, when the rig has it)
		layers.play_flinch(zone_clip if zone_clip != &"" else hit_react_clip(_hit_dir))
	elif zone_clip == &"" or horizontal_speed() <= AnimTweak.data().move_threshold_mps \
			or not layers.play_flinch(zone_clip):  # lead ruling (b): moving, the legs keep their locomotion
		play_oneshot(stagger if stagger != &"" else (zone_clip if zone_clip != &"" else hit_react_clip(_hit_dir)), -1.0, true)


## characters.md v1.18 / D-123: the hit-zone flinch for damage `info`, &"" for the directional set (HitClips.zone_clip).
func hit_zone_clip(info: Dictionary) -> StringName:
	return hits.zone_clip(info)


## v1.10: the directional hit react for a bullet travelling along `dir` (HitClips.react_clip).
func hit_react_clip(dir: Vector3) -> StringName:
	return hits.react_clip(dir)


func _on_weapon_fired(shooter_net_id: int, _weapon_id: StringName, _suppressed: bool, _pos: Vector3) -> void:
	if player == null or shooter_net_id == 0 or shooter_net_id != _net_id():
		return
	_aim_hold_left = AnimTweak.data().aim_hold_s
	if _crew != null and _crew.crew_state == Enums.CrewState.DOWNED:
		_play_state_oneshot(&"downed_fire")  # v1.21: shooting from the floor
		return
	play_oneshot(fire_clip())


## The aim clip for weapon_kind: aim_akimbo (v1.21, when the rig has it), else aim_rifle / aim_pistol by family.
func aim_clip() -> StringName:
	if weapon_kind == &"akimbo" and _has_clip(&"aim_akimbo"):
		return &"aim_akimbo"
	return &"aim_rifle" if aim_family() == &"rifle" else &"aim_pistol"


## The fire one-shot for the next shot: v1.21 akimbo alternates fire_akimbo (right) / fire_akimbo_l, right first;
## otherwise fire_rifle / fire_pistol by family.
func fire_clip() -> StringName:
	if weapon_kind == &"akimbo" and _has_clip(&"fire_akimbo") and _has_clip(&"fire_akimbo_l"):
		var c: StringName = &"fire_akimbo_l" if _akimbo_left_next else &"fire_akimbo"
		_akimbo_left_next = not _akimbo_left_next
		return c
	return &"fire_rifle" if aim_family() == &"rifle" else &"fire_pistol"


func _has_clip(c: StringName) -> bool:
	return player != null and player.has_animation("%s/%s" % [LIBRARY, c])


## A3-13: an NPC melee windup (`cue.npc_melee_swing` [R], source = this NPC) plays `melee` on every peer, so
## a client sees the windup in time to counter (defense.melee_counter).
func _on_audio_cue(cue_id: StringName, _pos: Vector3, source_net_id: int) -> void:
	if player == null or source_net_id == 0 or source_net_id != _net_id():
		return
	if cue_id == NpcGunner.CUE_MELEE_SWING:
		play_oneshot(&"melee", CombatTweak.data().npc_melee_windup_s + 0.3)
	elif _npc != null and (cue_id == NpcGunner.CUE_RELOAD_RIFLE or cue_id == NpcGunner.CUE_RELOAD_PISTOL):
		# D-111: an NPC reload (the crew's own come from CrewWeapons.reload_started)
		var g: NpcGunner = _npc.get_node_or_null(^"Gunner") as NpcGunner
		var dur: float = g.reload_time() if g != null else CombatTweak.data().npc_reload_s
		var clip_id: StringName = combat.reload_clip(&"reload_pistol" if cue_id == NpcGunner.CUE_RELOAD_PISTOL \
			else &"reload_rifle")  # D-116: the class reloads
		var done_s: float = AnimTweak.data().reload_done(StringName(String(clip_id).trim_prefix("reload_")))
		play_oneshot(clip_id, dur, false, done_s / maxf(dur, 0.05))
	elif crew_action != null and cue_id == CrewThrowables.CUE_PIN:
		crew_action.play_throw()  # v1.23 throw_grenade


func _on_reload_started(_ws: int, duration: float) -> void:
	if player == null:
		return
	var tw: AnimTweak = AnimTweak.data()
	var c: StringName = combat.reload_clip(&"reload_rifle" if aim_family() == &"rifle" else &"reload_pistol")  # D-116
	var key: StringName = StringName(String(c).trim_prefix("reload_"))
	if _crew != null and _crew.crew_state == Enums.CrewState.DOWNED and _has_clip(&"downed_reload"):
		c = &"downed_reload"  # v1.21
		key = c
	elif weapon_kind == &"akimbo" and _has_clip(&"reload_akimbo"):
		c = &"reload_akimbo"
		key = &"akimbo"
	var done_s: float = tw.reload_done(key, aim_family())
	var speed: float = done_s / maxf(duration, 0.05)  # the `done` event frame lands on reload completion
	if c == &"downed_reload":
		_play_state_oneshot(c, duration, speed)
		return
	play_oneshot(c, duration, false, speed)


func _on_equipped(_ws: int) -> void:
	refresh_weapon()


func _on_loot_dropped(_bag: int, crew_slot: int, thrown: bool) -> void:
	if thrown and _crew != null and crew_slot == _crew.slot:
		play_oneshot(armed_clip(&"throw_bag"), -1.0, true)


func _on_interaction_started(interactable_net_id: int, crew_slot: int, kind: StringName) -> void:
	if _crew == null or crew_slot != _crew.slot:
		return
	_interact_kind = kind if kind != &"" else &"use"
	_interact_height = 1.0
	var target: Node3D = Ids.lookup(interactable_net_id) as Node3D
	if target != null and target.is_inside_tree() and _body.is_inside_tree():
		_interact_height = target.global_position.y - _body.global_position.y


func _on_interaction_ended(_interactable_net_id: int, crew_slot: int) -> void:
	if _crew != null and crew_slot == _crew.slot:
		_interact_kind = &""


func _on_interaction_completed(interactable_net_id: int, crew_slot: int, _kind: StringName) -> void:
	_on_interaction_ended(interactable_net_id, crew_slot)
