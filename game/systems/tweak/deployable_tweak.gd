## Deployables + ECM tunables (A2-03, A2-06). Owner: ENV A. Data: deployable_tweak.tres.
## Rows: L2.11 (doctor bag / FAK / ammo bag), S6.2 (body bag case), S8.4-S8.6 (ECM), S5.6.
## Rows marked ◇ in pd2_fidelity.md are design choices. DeployableDef (ENV B data) wins over the
## `fallback_defs` below; those only cover ids ENV B has not shipped yet (ECM, first aid kit).
class_name DeployableTweak
extends Resource

const PATH: String = "res://systems/tweak/deployable_tweak.tres"

static var _cached: DeployableTweak = null

@export_group("Fallback defs")
## id -> {kind, count, uses, deploy_time_s, params}: used when ContentDB.deployable(id) is null.
@export var fallback_defs: Dictionary = {
	&"deployable.ecm": {"kind": &"ecm", "count": 1, "uses": 1, "deploy_time_s": 2.0, "params": {"duration": 20.0}},
	# D-157 crew sentry (PD2: 2 per player ◇) until B ships content/data/deployables/sentry.tres; params: SentryGun.DEFAULTS.
	&"deployable.sentry": {"kind": &"sentry", "count": 2, "uses": 1, "deploy_time_s": 2.0, "params": {}},
	&"deployable.fak": {"kind": &"fak", "count": 4, "uses": 1, "deploy_time_s": 1.0, "params": {"heal": 150.0}},
	&"deployable.first_aid_kit": {"kind": &"fak", "count": 4, "uses": 1, "deploy_time_s": 1.0, "params": {"heal": 150.0}},
	&"deployable.doctor_bag": {"kind": &"doctor_bag", "count": 1, "uses": 2, "deploy_time_s": 2.0,
		"params": {"heal_frac": 1.0, "resets_downs": true}},
	&"deployable.ammo_bag": {"kind": &"ammo_bag", "count": 1, "uses": 4, "deploy_time_s": 2.0,
		"params": {"refill_frac_per_use": 1.0}},
	&"deployable.body_bag_case": {"kind": &"body_bag_case", "count": 1, "uses": 3, "deploy_time_s": 2.0,
		"params": {"bags": 3}},
	&"deployable.armor_bag": {"kind": &"armor_bag", "count": 1, "uses": 1, "deploy_time_s": 2.0, "params": {}},
	# S9.5: 3 base (deploy.extra.trip_mine adds); spent as shaped charges with interaction.shaped_charge.
	&"deployable.trip_mine": {"kind": &"trip_mine", "count": 3, "uses": 1, "deploy_time_s": 1.0, "params": {}},
}
## Deploy hold time when a def has none (s).
@export var default_deploy_time_s: float = 2.0

@export_group("Trip mine (S9.5)")
## ◇ arming delay after placement, proximity trigger radius, blast radius (x deploy.trip_mine_radius_mult),
## blast damage (L3.6 falloff) and explosion noise radius.
@export var trip_mine_arm_s: float = 1.0
@export var trip_mine_trigger_m: float = 1.5
@export var trip_mine_radius_m: float = 3.0
@export var trip_mine_damage: float = 600.0
@export var trip_mine_noise_radius_m: float = 45.0
@export_group("Placement")
## The deployable lands this far in front of the crew member's feet (m), on the floor below.
@export var place_forward_m: float = 0.8
## Floor probe: from this height above the feet down this far (m).
@export var place_probe_up_m: float = 1.0
@export var place_probe_down_m: float = 2.5
## S8.5: an ECM deployed while aiming at a keycard reader within this distance of the eye (m) and
## this half-angle (deg) attaches to it (needs stealth.ecm_opens_doors).
@export var ecm_reader_reach_m: float = 2.0
@export var ecm_reader_cone_deg: float = 35.0

@export_group("Use (◇ hold times, s)")
## kind -> hold time to use a placed deployable.
@export var use_time_s: Dictionary = {
	&"doctor_bag": 2.0, &"fak": 0.0, &"ammo_bag": 1.0, &"body_bag_case": 1.0, &"ecm": 0.5, &"armor_bag": 2.0,
}
## QB-58 armor bag (Walk-in Closet, deploy.armor_bag): the crew member starts in this armor and the
## bag holds the loadout's armor until they use it.
@export var armor_bag_start_armor: StringName = &"armor.tailored_suit"
## FAK heal (PD2 display units) when the def has no params.heal.
@export var fak_heal: float = 150.0

@export_group("ECM (S8.4-S8.6)")
## S8.4 jam duration (s) when the def has no params.duration; × stealth.ecm_duration_mult.
@export var ecm_jam_s: float = 20.0
## S8.4 the ECM flashes for the last seconds of its jam.
@export var ecm_flash_last_s: float = 8.0
## S8.5 placed on a keycard reader: doors open after this (s); the ECM is consumed.
@export var ecm_door_open_s: float = 4.0
## S8.5 ATM (no prefab yet): opens after this (s).
@export var ecm_atm_open_s: float = 8.0
## S8.6 feedback radius (m) ◇ and stun (s) ◇ (× stealth.ecm_feedback_duration_mult).
@export var ecm_feedback_radius_m: float = 15.0
@export var ecm_feedback_stun_s: float = 6.0
## S8.6 recharge (s) before a retrigger (stealth.ecm_feedback_retrigger).
@export var ecm_feedback_recharge_s: float = 240.0
## S8.6 Cloakers (Phantom) are immune: EnemyDef ids, or EnemyDef.params.ecm_feedback_immune.
@export var ecm_feedback_immune_ids: Array[StringName] = [&"enemy.phantom"]


static func data() -> DeployableTweak:
	if _cached == null:
		_cached = load(PATH) as DeployableTweak
		if _cached == null:
			_cached = DeployableTweak.new()
	return _cached
