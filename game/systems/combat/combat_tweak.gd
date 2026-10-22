## Combat tunables (A1-08): player weapons, hit-claim validation, NPC gunfire, revive extras.
## Owner: ENV A. Data: combat_tweak.tres. Survival numbers (health, armor, bleedout, downs, revive
## time) live in CrewTweak (crew_tweak.tres); weapon stats come from ENV B's resolved WeaponStats.
## Fidelity rows: L2.2, L2.5, L2.7, L3.2, L3.7, L3.8, S1.1, S4.3. ◇ = design value, tune in playtest.
class_name CombatTweak
extends Resource

const PATH: String = "res://systems/combat/combat_tweak.tres"

static var _cached: CombatTweak = null

@export_group("Default loadout (D-025 QA-2)")
## Used when a crew member has no Loadout (no `options.loadouts`). Resolved by LoadoutResolver.
@export var default_primary: StringName = &""
@export var default_primary_mods: Array[StringName] = []
@export var default_secondary: StringName = &"weapon.kestrel_p9"
@export var default_secondary_mods: Array[StringName] = [&"mod.p9_suppressor"]
@export var default_armor: StringName = &"armor.tailored_suit"
## LEAD ruling 2026-10-20 (D-145.4, B's bot-gear probe): an AI teammate whose loadout has no primary (the default
## loadout, or a bot slot with nothing equipped) carries this starter rifle, unmodded; the pistol stays its secondary.
@export var bot_default_primary: StringName = &"weapon.corsair_ar"

@export_group("Hitscan")
@export var hitscan_max_range_m: float = 200.0
## world_static(1) + world_dynamic(2) + hitboxes(5).
@export_flags_3d_physics var hitscan_mask: int = (1 << 0) | (1 << 1) | (1 << 4)
## Rays that must be clear between shooter and hit point (server LOS check, NPC LOS).
@export_flags_3d_physics var los_mask: int = (1 << 0) | (1 << 1)
## Spread multipliers on the WeaponStats cone, PD2 (D-097): standing 1.0, moving 1.0, crouching 0.4 (crouched
## wins over moving, as PD2's crouching row). WeaponDef spread values are PD2's own.
@export var spread_mult_still: float = 1.0
@export var spread_mult_moving: float = 1.0
@export var spread_mult_crouched: float = 0.4
## D-131 (◇): aiming down sights scales WeaponStats.spread_deg_ads by this at runtime (ENV B's data unchanged), so an
## ADS pistol / revolver hits a torso at 10 m essentially always (test_l3_ads_pistol_accuracy, >= 98 / 100).
@export var ads_spread_mult: float = 0.7
## PO-8 (impact_fx.md, presentation only): an NPC miss lands this far (m) to the side of its aim point, and
## a replayed crew shot's (client-supplied) spread is clamped to this cone half-angle (deg).
@export var fx_npc_miss_offset_min_m: float = 0.6
@export var fx_npc_miss_offset_max_m: float = 1.6
@export var fx_max_replay_spread_deg: float = 45.0
## Horizontal speed (m/s) above which the shooter counts as moving.
@export var moving_speed_threshold: float = 0.5

@export_group("Hit claims (architecture.md §3)")
## A claim is accepted when the time since the last accepted shot >= interval x this.
@export var claim_rof_tolerance: float = 0.75
## Max distance between the claimed ray origin and the server's view of the shooter's eye.
@export var claim_origin_tolerance_m: float = 2.0
## Max distance between the claimed hit point and the target's centre.
@export var claim_target_tolerance_m: float = 1.6
## L3.3: max distance from a claimed HEAD hit point to the NPC head point (head sphere 0.14 m + lag) ◇.
@export var claim_head_tolerance_m: float = 0.45
## Max mismatch between the claimed and recomputed distance.
@export var claim_distance_tolerance_m: float = 1.0

@export_group("Downed / revive (L2.5, L2.7)")
## A downed crew member counts as "shooting" for this long after a shot (police hold fire otherwise).
@export var downed_shooting_grace_s: float = 2.0
## Armor fraction restored on revive (◇).
@export var revive_armor_frac: float = 1.0

@export_group("NPC gunfire")
## Seconds between NPC shots unless EnemyDef.params.fire_interval_s is set (◇).
@export var npc_fire_interval_s: float = 0.8
## D-111 (PD2 enemies reload): rounds per magazine and the reload time (s) when the EnemyDef has no
## params.mag_size / params.reload_s ◇. Specials reload only when their EnemyDef sets mag_size.
@export var npc_mag_size: int = 30
@export var npc_reload_s: float = 2.2
## D-113: a crew round of at least this damage (per pellet, PD2 units) flags its flesh hits FLAG_STRONG ◇.
@export var fx_strong_damage: float = 50.0
## Delay before the first shot after acquiring a target (EnemyDef.params.aim_delay_s overrides, ◇).
@export var npc_aim_delay_s: float = 0.6
@export var npc_max_range_m: float = 60.0
## S2.7: NPC loud targeting range at DR 3 / DR 75 (lerped on the target's detection risk).
@export var ai_target_range_min_m: float = 80.0
@export var ai_target_range_max_m: float = 180.0
## Point on the crew member NPCs aim at (height above the feet).
@export var npc_aim_height_m: float = 1.2
## Hit chance by distance (x = metres, y = chance 0..1), linear between points (◇ curve).
@export var npc_hit_chance_curve: PackedVector2Array = PackedVector2Array([
	Vector2(0.0, 0.9), Vector2(5.0, 0.8), Vector2(15.0, 0.6), Vector2(30.0, 0.35), Vector2(60.0, 0.1),
])
## Hit-chance multiplier by Enums.Difficulty (◇). PO-17 (D-145 §2): the curve is PD2's good/expert presets' shape
## (Very Hard / Overkill); PD2 Normal and Hard use the weaker "normal" preset, so Routine x0.65 and Tense x0.8
## (were 1.0 / 1.0); Hazardous+ unchanged.
@export var npc_hit_chance_mult: PackedFloat32Array = PackedFloat32Array([0.65, 0.8, 1.05, 1.1, 1.15, 1.2])
## Damage per shot when an NPC has no EnemyDef damage table.
@export var npc_fallback_damage: float = 10.0


@export_group("Melee (L3.9, D-069)")
## A melee press released before this is a quick swing; held longer it charges (MeleeDef.charge_time_s).
@export var melee_tap_s: float = 0.2
## Swing length / hit moment when the MeleeDef leaves swing_time_s / hit_delay_s at 0 (◇ PD2 knife shape).
@export var melee_swing_s: float = 0.6
@export var melee_hit_delay_s: float = 0.25
## Hit volume: cone (full angle) out to MeleeDef.range_m from the eye.
@export var melee_cone_deg: float = 50.0
## A knockdown (MeleeDef.knockdown chance x weapon.melee_knockdown_mult) stuns the NPC this long ◇.
@export var melee_knockdown_s: float = 1.2
## B2 defense.armor_broken_stagger: a hit while the holder's armor is broken stuns a non-special enemy this long ◇.
@export var armor_broken_stagger_s: float = 0.5
## B4b weapon.stagger_chance_add (Knockdown): a hit that rolls the skill's stagger stuns a non-special enemy this long ◇.
@export var skill_stagger_s: float = 0.5
## Gun bash (no melee item equipped): PD2 weapon butt ◇.
@export var bash_damage: float = 30.0
@export var bash_range_m: float = 1.5
@export var bash_knockdown: float = 0.5
@export var bash_swing_s: float = 0.55
@export var bash_hit_delay_s: float = 0.2

@export_group("NPC melee (A3-13)")
## PD2 point-blank shove / strike by non-special enemies (police, guards, cartel) on a crew member within reach.
@export var npc_melee_range_m: float = 1.6
## Windup (the `melee` clip) before the strike lands; a crew member countering in it (defense.melee_counter
## while charging / swinging a melee) knocks the NPC down instead ◇.
@export var npc_melee_windup_s: float = 0.4
@export var npc_melee_cooldown_s: float = 3.0
## Strike damage by Enums.Difficulty (ROUTINE..CATACLYSM) ◇; DamageType.MELEE (defense.melee_damage_taken_mult).
@export var npc_melee_damage: Array[float] = [8.0, 12.0, 16.0, 24.0, 32.0, 40.0]
## Shove: horizontal speed given to the struck crew member (m/s) ◇; the strike also cancels a reload.
@export var npc_melee_knockback_mps: float = 4.0
## Counterstrike: the countered NPC is stunned this long ◇.
@export var npc_melee_counter_stun_s: float = 2.0

@export_group("Throwables (A3-12)")
## Throw press -> release (the FP `throwable` throw clip's release@ is re-timed onto it) ◇.
@export var throw_windup_s: float = 0.4
## Recovery after the release before the next throw / shot ◇.
@export var throw_recover_s: float = 0.4
## Launch speed along the aim, lofted up by throw_loft_deg ◇.
@export var throw_speed_mps: float = 16.0
@export var throw_loft_deg: float = 8.0
## Bounce: velocity kept on a world contact (frag / concussion roll on) ◇.
@export var throw_bounce_keep: float = 0.35
## A thrown item that has not gone off by now is removed.
@export var throw_lifetime_s: float = 12.0
## Concussion: NPCs in the radius with LOS are stunned this long (stun-immune enemies ignore it) ◇.
@export var concussion_stun_s: float = 4.0
## Incendiary: the fire pool burns this long; NPCs in it are set burning (BurnStatus) ◇.
@export var incendiary_pool_s: float = 10.0
@export var incendiary_burn_dps: float = 40.0
@export var incendiary_burn_s: float = 3.0
@export var incendiary_panic_chance: float = 0.6
@export var incendiary_panic_s: float = 1.5
## Explosion (frag / concussion) noise radius for the stealth system ◇.
@export var throwable_noise_radius_m: float = 60.0

@export_group("Piercing (A3-06, L3.4)")
## Physics layer 9 `bullet_penetrable` (thin walls): stops bullets unless the weapon has wall_pierce.
@export_flags_3d_physics var penetrable_mask: int = 1 << 8
## Damage factor of a round that went through a thin wall (◇).
@export var wall_pierce_damage_mult: float = 0.5
## Thin walls one round may pass (◇).
@export var wall_pierce_max: int = 1
## Damage factor of a shield-piercing round passing a Bulwark shield (L3.4/L4.5: x0.25).
@export var shield_pierce_damage_mult: float = 0.25
## Fire (DamageType.FIRE) passes shields at this factor (L3.4 "fire ignores shields").
@export var shield_fire_damage_mult: float = 1.0
## How far behind a shield a piercing round keeps travelling.
@export var shield_pierce_reach_m: float = 60.0

@export_group("Suppression (A3-06, L3.5)")
## Threat per unit of WeaponStats.suppression on a damaging hit / a near miss (◇: AR 12 -> 0.48 / 0.24).
@export var threat_per_suppression_hit: float = 0.04
@export var threat_per_suppression_near_miss: float = 0.02
## A ray passing within this distance of an NPC's centre line is a near miss.
@export var near_miss_radius_m: float = 1.0
## Threat lost per second (◇).
@export var threat_decay_per_s: float = 0.2
@export var threat_hunch: float = 1.0
@export var threat_dive: float = 2.0
## Hunched: x shot delay, x aim time, x hit chance (PD2 +50% / +50% / -50%).
@export var hunch_shot_delay_mult: float = 1.5
@export var hunch_aim_delay_mult: float = 1.5
@export var hunch_hit_chance_mult: float = 0.5
## Dive for cover: seconds the dive lasts, COVER search radius, sidestep distance without cover (◇).
@export var dive_s: float = 1.5
@export var dive_cover_search_m: float = 6.0
@export var dive_sidestep_m: float = 3.0
@export var dive_speed_mult: float = 1.3
## After a dive: threat gains x resist_mult for resist_s seconds (PD2: 50% for 30 s).
@export var suppression_resist_mult: float = 0.5
@export var suppression_resist_s: float = 30.0
## Units on this difficulty or higher are immune ("top factions", ◇ CATACLYSM = Enums.Difficulty 5).
@export var suppression_immune_min_difficulty: int = 5

@export_group("Explosives (A3-06, L3.6)")
## damage x (1 - d/r)^explosion_falloff_pow (PD2 0.1).
@export var explosion_falloff_pow: float = 0.1
## What can be hit: players(3) + npcs(4) + hitboxes(5) + world_dynamic(2, cameras/glass/prefabs).
@export_flags_3d_physics var explosion_target_mask: int = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
## LOS from the blast centre (world_static + world_dynamic; Bulwark shields are ignored: PD2
## explosions go around shields).
@export_flags_3d_physics var explosion_los_mask: int = (1 << 0) | (1 << 1)

@export_group("Shotgun ammo (D-118)")
## Fallback per-type params (ShotgunAmmo) when the resolved WeaponDef.params (ENV B's AMMO mod) leave a key out.
## Keys are the `ammo_type` names; B's params always win, then the clamps below apply ◇.
@export var shotgun_ammo_defaults: Dictionary = {
	"slug": {"pellets": 1, "armor_pierce": 1.0, "shield_pierce": true, "penetration": true},
	"he": {"pellets_mult": 0.5, "explosion_radius_m": 1.0, "explosion_damage_mult": 1.0, "penetration": false},
	"flechette": {"pellets_mult": 1.4, "dot_dps": 8.0, "dot_s": 3.0},
	"dragons_breath": {"ignite": true, "dot_dps": 20.0, "dot_s": 3.0, "panic_civilians": true, "range_mult": 1.0},
}
@export var shotgun_ammo_max_pellets: int = 32
@export var shotgun_ammo_max_explosion_radius_m: float = 5.0
@export var shotgun_ammo_max_explosion_damage_mult: float = 10.0
@export var shotgun_ammo_max_dot_dps: float = 500.0
@export var shotgun_ammo_max_dot_s: float = 20.0
@export var shotgun_ammo_range_mult_min: float = 0.1
@export var shotgun_ammo_range_mult_max: float = 4.0
@export var shotgun_ammo_max_pickup_mult: float = 4.0
## Dragon's breath: civilians within this range (x range_mult) and cone (full angle) of the shot panic ◇.
@export var shotgun_panic_range_m: float = 12.0
@export var shotgun_panic_cone_deg: float = 40.0

@export_group("Hit grace (D-145, PD2 _chk_dmg_too_soon)")
## After a crew member takes (or dodges) a bullet hit, further hits of equal or lower damage do nothing for this
## long (s), by difficulty Routine..Cataclysm (PD2 player 0.45 s on every hit; PD2 caps intake from a crowd this
## way). 0 = off (D-145: Routine/Tense only for now; the LEAD decides Hazardous+).
@export var hit_grace_s_by_difficulty: PackedFloat32Array = PackedFloat32Array([0.45, 0.45, 0.0, 0.0, 0.0, 0.0])
## The same for AI bots (PD2 team AI 0.35 s).
@export var bot_hit_grace_s_by_difficulty: PackedFloat32Array = PackedFloat32Array([0.35, 0.35, 0.0, 0.0, 0.0, 0.0])

@export_group("Limb hitboxes (D-123)")
## Capsule radius of the upper-arm / thigh hitboxes on a rigged NPC (a little over ENV D's ragdoll capsules,
## 0.051 / 0.077 m, for clothing) ◇. Length = the bone's rest length to its child joint (fallback below).
@export var limb_upper_arm_radius_m: float = 0.065
@export var limb_thigh_radius_m: float = 0.09
@export var limb_upper_arm_length_m: float = 0.30
@export var limb_thigh_length_m: float = 0.43
## A shot that lands on the BODY hull is followed this far along its line, through the hull, to find the limb box
## it passes inside (the hull still decides the hit and its damage; the probe only names the flinch sub-zone).
@export var limb_probe_depth_m: float = 0.7

static func data() -> CombatTweak:
	if _cached == null:
		_cached = load(PATH) as CombatTweak
		if _cached == null:
			_cached = CombatTweak.new()
	return _cached


## Linear interpolation of the NPC hit-chance curve at `distance`.
func npc_hit_chance(distance: float, difficulty: int) -> float:
	var c: PackedVector2Array = npc_hit_chance_curve
	var chance: float = 0.0
	if c.is_empty():
		chance = 0.5
	elif distance <= c[0].x:
		chance = c[0].y
	elif distance >= c[c.size() - 1].x:
		chance = c[c.size() - 1].y
	else:
		for i: int in range(1, c.size()):
			if distance <= c[i].x:
				var t: float = (distance - c[i - 1].x) / maxf(c[i].x - c[i - 1].x, 0.0001)
				chance = lerpf(c[i - 1].y, c[i].y, t)
				break
	if npc_hit_chance_mult.size() > 0:
		chance *= npc_hit_chance_mult[clampi(difficulty, 0, npc_hit_chance_mult.size() - 1)]
	return clampf(chance, 0.0, 1.0)
