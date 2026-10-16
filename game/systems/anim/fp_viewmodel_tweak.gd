## First-person viewmodel tunables for FpViewmodel (characters.md v1.3/v1.4, D-041/D-044). Owner: ENV A.
## Data: fp_viewmodel_tweak.tres. Presentation only: nothing here changes gameplay timing.
## `arms_scene`, `fps` and the part travels are ENV D's facts (char_arms_fp/SOURCE.txt); the clip event frames
## are parsed from SOURCE.txt at first use (`events_source`, cached statically), so a new ENV D clip set needs no
## edit here. `extra_events` are ENV A's own ◇ additions merged over them; the rest are ◇ presentation values.
class_name FpViewmodelTweak
extends Resource

const PATH: String = "res://systems/anim/fp_viewmodel_tweak.tres"

static var _cached: FpViewmodelTweak = null
## SOURCE.txt path -> parsed {clip: {event: frame}} (parsed once per path).
static var _parsed: Dictionary = {}
static var _gen: int = 0

@export_group("Arms rig (characters.md v1.3)")
## The `char_arms_fp` scene (root = camera origin, -Z forward). null = static viewmodel fallback.
@export var arms_scene: PackedScene = null
## Helper bones: the WeaponVisual hangs on `weapon_bone`; `magazine_bone` moves the weapon's Magwell.
@export var weapon_bone: StringName = &"weapon"
@export var magazine_bone: StringName = &"magazine"
## Clip frame rate of the event frames below.
@export var fps: float = 30.0
## The arms rig's SOURCE.txt (data reference; its `clip.<set>_<clip>: ... events=a@N,b@M` lines are parsed).
## Empty = "SOURCE.txt" next to `arms_scene`.
@export_file("*.txt") var events_source: String = ""
## Extra ◇ part events not in SOURCE.txt (pistol slide cycle inside fire), merged over the parsed ones:
## {"<set>_<clip>": {event: frame}}.
@export var extra_events: Dictionary = {}

## characters.md v1.8: heister -> sleeve variant scene (`char_arms_fp_<heister>`, mesh only: its `Arms` mesh and
## skin replace the rig's; no entry = the rig's own suit sleeves).
@export var sleeve_scenes: Dictionary[StringName, PackedScene] = {}

@export_group("Part travel (characters.md v1.4)")
## Pistol `Slide` travel along its local +Z when locked back / cycling (◇, not in the contract).
@export var slide_travel_m: float = 0.028
## Shotgun `Pump` travel along local +Z.
@export var pump_travel_m: float = 0.075
## Sniper `Bolt`: handle lift about its local Z (bore axis), then slide along local +Z.
@export var bolt_lift_deg: float = 62.0
@export var bolt_travel_m: float = 0.075
## LMG `FeedCover`: opens about its local X (rear hinge pivot).
@export var feed_cover_deg: float = 78.0
## Frames a part takes to reach the position its event names (the ramp ends on the event frame).
@export var part_ramp_frames: float = 3.0

@export_group("Left hand IK (D-069, characters.md v1.7)")
## The FP left hand IKs (TwoBoneIK3D upper_arm.L -> forearm.L -> hand.L) to the weapon model's `LeftHandIK`
## marker while the clip leaves the left hand on the gun (not during reload / swap, nor for these sets).
## D-116: pistol / revolver are one-handed in first person (one_handed_fp_sets), so they skip the IK again (PO6-11
## had put them on it with the clip's own wrist offset; their set_left_hand_grip_offset entries stay for the record).
## Akimbo sets: the WeaponVisual's offhand gun rides hand.L at akimbo_offhand_grip (hand.L bone space; ENV D's
## rig SOURCE.txt fp.offhand_grip: the X-mirror of the weapon bone's hand.R offset).
@export var akimbo_sets: Array[StringName] = [&"akimbo"]
@export var akimbo_offhand_grip: Transform3D = Transform3D(Basis(Vector3(-0.0, -0.0, -1.0), Vector3(0.9511, -0.309, 0.0),
	Vector3(-0.309, -0.9511, -0.0)), Vector3(0.012, 0.072, -0.03))
@export var left_hand_ik_skip_sets: Array[StringName] = [&"bow", &"akimbo", &"pistol", &"revolver"]
## D-116 (PO, Fallout: New Vegas refs): first-person pistol / revolver are ONE-HANDED: the left arm drops out of view
## by one_handed_left_drop (camera space, m, applied to upper_arm.L) while the set plays, and eases back in for the
## reload clips (they use the left hand) at one_handed_drop_rate (1/s). Third person stays two-handed.
@export var one_handed_fp_sets: Array[StringName] = [&"pistol", &"revolver"]
@export var one_handed_left_drop: Vector3 = Vector3(-0.15, -0.7, 0.25)
@export var one_handed_drop_rate: float = 5.0
## D-116 (LEAD ADS note): per-set rotation (deg, x pitch up / y yaw / z roll) of the arms about the rear sight
## (AimPoint) at full ADS (x ads_weight), e.g. a small nose-down pitch puts the eye above and behind
## the firing hand, looking along the slide; the rear sight stays on the crosshair. Empty: tried -8 on the D-116
## v3 clips, it hardly changes the sleeve (the wrist sits right of the grip in the clip).
@export var set_ads_rot_deg: Dictionary[StringName, Vector3] = {}
## PO6-11: sets whose support hand keeps the orientation (relative to the gun) it had at hip / full ADS through the ADS
## transition, instead of the blended clip's (off by ~10 deg mid-blend). Needs the IK (HandRestore).
@export var left_hand_hold_rel_sets: Array[StringName] = [&"pistol", &"revolver"]
## Elbow pole in skeleton space, relative to upper_arm.L (outward / down) ◇.
@export var left_hand_pole_offset: Vector3 = Vector3(-0.35, -0.45, 0.15)
## hand.L origin (wrist) relative to the LeftHandIK marker (palm contact), in marker space: measured from
## ENV D's baked rifle clip on its four guns (x -0.033..-0.038 constant; y -0.03..+0.017, z = per-gun fore-end).
@export var left_hand_grip_offset: Vector3 = Vector3(-0.035, -0.02, 0.0)
## Per-set override of left_hand_grip_offset (ENV D 2026-10-14): the long-gun sets' PD2 support grip (palm up under
## B's centred under-fore-end markers, thumb along the left side) puts the wrist here; side-grip sets keep the global.
@export var set_left_hand_grip_offset: Dictionary[StringName, Vector3] = {}
## D-118 (ENV D, PD2 vertical grip): with a vertical-grip mod (its own LeftHandIK) the wrist sits here relative to the
## mod's marker (same convention as set_left_hand_grip_offset) and the left hand takes `<set>_vgrip_hand` frame 0.
## Sets not listed keep their normal grip with a vgrip mod.
@export var set_vgrip_grip_offset: Dictionary[StringName, Vector3] = {
	&"smg": Vector3(-0.018, 0.0, 0.047), &"rifle": Vector3(-0.018, 0.0, 0.047),
	&"launcher": Vector3(-0.018, 0.0, 0.047),
}
## IK influence blend rate (1/s) when the hand leaves / returns to the grip.
@export var left_hand_ik_rate: float = 8.0
## PO-13: keep the clip's left-hand orientation relative to the gun while the IK moves the wrist (else the hand
## inherits the IK'd forearm's rotation: fingers up off the handguard).
@export var left_hand_keep_orientation: bool = true

@export_group("Shared reload clips (D-063)")
## A set's single reload / reload_empty clip plays at clip time / the weapon's reload_time_s (reload_empty_time_s).
## Outside this range (before skill multipliers) the weapon needs its own clip: FpViewmodel logs an error.
@export var reload_scale_min: float = 0.75
@export var reload_scale_max: float = 1.35

@export_group("Special parts (B4-18, D-055)")
## WeaponPartsAnimator (◇ presentation): `Breech` opens about local X during a reload.
@export var breech_open_deg: float = 40.0
@export var breech_ramp_s: float = 0.15
## `Lever` throw about local X after each shot, over `lever_cycle_s`.
@export var lever_throw_deg: float = 55.0
@export var lever_cycle_s: float = 0.35
## Bow `StringUpper`/`StringLower` limb flex about local X at full draw; `String` travel along +Z at full draw.
@export var bow_limb_deg: float = 10.0
@export var string_draw_m: float = 0.12
## D-070 crossbow: latched string halves (visual_slots.md): Upper -deg / Lower +deg about local X, both
## stretched along local Y; ramp time of the latch during the reload.
@export var crossbow_latch_deg: float = 18.74
@export var crossbow_latch_stretch: float = 1.3049
@export var crossbow_latch_s: float = 0.4
## `Arrow` / bolt on the Magwell hidden this long after a shot (until the next one is nocked).
@export var arrow_hidden_s: float = 0.3
## `Blade` spin (rev/s) while firing / idle; `Rotor` spin at full minigun spin.
@export var blade_rps_firing: float = 14.0
@export var blade_rps_idle: float = 1.0
@export var rotor_rps_max: float = 9.0

@export_group("Timing")
## Crossfade between idle / ads_idle / sprint.
@export var blend_s: float = 0.15
## Crossfade into one-shots (fire, reload, draw, holster).
@export var oneshot_blend_s: float = 0.04
## Share of the gameplay equip time spent on the old weapon's holster (the rest is the draw).
@export var holster_share: float = 0.4
## D-102 lane (PD2 PlayerCarry:_enter -> _start_action_equip): picking up a bag re-plays the weapon's `draw` over
## its equip time (not on drop: PD2 exits the carry state with skip_equip).
@export var carry_reequip: bool = true
## PO pass (PD2 PlayerStandard:_start_action_interact -> _play_unequip_animation): a timed interaction (lockpick,
## bagging, drill placement...) holsters the weapon and holds it out of view; completing or cancelling it draws the
## weapon again. Lowered only once the interaction has run interact_lower_delay_s, so instant ones never holster.
@export var interact_lower: bool = true
@export var interact_lower_delay_s: float = 0.12
## ADS weight rate (1/s toward the target).
@export var ads_rate: float = 10.0

@export_group("Viewmodel camera (PP-P-11)")
## PD2-style fixed vertical FOV (deg) the first-person arms/weapon render with, independent of the world FOV
## setting and ADS zoom (no stretched guns at wide FOV). 0 = draw them with the world camera.
@export var viewmodel_fov_deg: float = 52.0
## PO-4 (PD2 readability): a key light that lights ONLY the viewmodel layer (light_cull_mask), riding the viewmodel
## camera, so the arms and gun stay readable when the world light is behind the player (night streets, backlit
## doorways). 0 energy = off. Direction: euler degrees in camera space (x pitch down, y yaw), light shines along -Z.
@export var viewmodel_key_light_energy: float = 0.7
@export var viewmodel_key_light_color: Color = Color(1.0, 0.96, 0.9)
@export var viewmodel_key_light_euler_deg: Vector3 = Vector3(-35.0, 25.0, 0.0)
## PO6-10 (LEAD ruling 2026-10-15): a fill light on the first-person GUN only (CrewView.VIEWMODEL_GUN_LAYER), riding
## the viewmodel camera: the coated finishes are dielectric now but their albedo stays near-black, so the gun reads
## as a silhouette next to the arms. Lifts it toward the arms' luminance without touching the arms. 0 energy = off.
## D-119 (PO): off by default (the PO wants the darker gun back); the PO6-10 tuning was 0.7 hip / 0.45 ADS.
## Direction: euler degrees in camera space (light shines along -Z).
@export var viewmodel_gun_fill_energy: float = 0.0
## Fill energy at full ADS (eased with CrewView.ads_blend): the sights sit ~10 cm from the eye and read near-white
## at the hip energy (LEAD round 213).
@export var viewmodel_gun_fill_ads_energy: float = 0.0
@export var viewmodel_gun_fill_color: Color = Color(1.0, 0.96, 0.9)
@export var viewmodel_gun_fill_specular: float = 0.6
@export var viewmodel_gun_fill_euler_deg: Vector3 = Vector3(-20.0, -15.0, 0.0)
## PO-4 (PD2): per-shot muzzle light at the weapon's Muzzle, on the world layer + CrewView.VIEWMODEL_LIT_LAYER, so
## it lights the arms, the gun and the surroundings. 0 energy = off. Suppressed guns use the multiplier.
@export var muzzle_light_energy: float = 1.25
@export var muzzle_light_range_m: float = 4.0
@export var muzzle_light_s: float = 0.034
@export var muzzle_light_color: Color = Color(1.0, 0.78, 0.45)
@export var muzzle_light_suppressed_mult: float = 0.15

@export_group("Sway / breathing (PO-13)")
## PO-13: the gun dips this far (m) mid-way through the ADS transition (sin(pi x ads_weight)): a small arc into and
## out of the sights instead of a straight slide. 0 at hip and at full ADS, so the sight alignment is untouched.
@export var ads_dip_m: float = 0.012
## PO6-11: per-set roll (deg, about the weapon's bore axis) through the ADS transition (sin(pi x ads_weight)): the
## sights swing up into the eye on a short arc instead of sliding straight. 0 at hip and at full ADS.
@export var set_ads_arc_roll_deg: Dictionary[StringName, float] = {}
## PO6-11: ADS settle. An underdamped spring (frequency Hz, damping ratio < 1) chases ads_weight; the viewmodel pitches
## by (spring - ads_weight) x ads_settle_pitch_deg about the firing hand, so the gun trails a little on the way into
## the sights, overshoots and settles. x the set's ads_settle_set_mult (sets not listed: 1). 0 = off.
@export var ads_settle_hz: float = 4.5
@export var ads_settle_damping: float = 0.45
@export var ads_settle_pitch_deg: float = 3.0
@export var ads_settle_set_mult: Dictionary[StringName, float] = {}
## PD2 vel_overshot (fpcameraplayerbase.lua _calculate_soft_velocity_overshot, playertweakdata stances.default):
## the weapon lags behind look motion. Target = sign x (|look speed| / sway_full_dps)^1.5 x max (deg); the target
## steps toward it at sway_target_rate_dps; the applied sway follows at lerp(3, 180, |diff| / 40) deg/s. Roll = -yaw.
## Hip (standard) max yaw 6 / pitch 10, ADS (steelsight) 4 / 2. 0 max = off.
@export var sway_yaw_max_deg: float = 6.0
@export var sway_pitch_max_deg: float = 10.0
@export var sway_ads_yaw_max_deg: float = 4.0
@export var sway_ads_pitch_max_deg: float = 2.0
## Look speed (deg/s) that reaches the full sway.
@export var sway_full_dps: float = 300.0
@export var sway_target_rate_dps: float = 120.0
## D-116 (PO "organic"): the applied sway follows its PD2 target on an underdamped spring (frequency Hz, damping
## ratio < 1: a slight overshoot as a turn stops, then it settles), instead of the PD2 rate chase. 0 Hz = PD2 chase.
@export var sway_spring_hz: float = 3.2
@export var sway_spring_damping: float = 0.55
## PD2 stances.default shakers.breathing amplitude: hip 0.3, crouched 0.25, ADS 0.025 (deg); slow idle sway.
@export var breathing_amp_deg: float = 0.3
@export var breathing_crouched_amp_deg: float = 0.25
@export var breathing_ads_amp_deg: float = 0.025
@export var breathing_hz: float = 0.22

@export_group("Weapon FX (D-105)")
## impact_fx.md §4 (ENV P): first-person muzzle burst, smoke, shells, tracer origin, per-shot viewmodel kick.
## ENV C's library scenes (game/world/vfx/) replace the built-in placeholders when set.
## ENV C's scenes (impact_fx.md §3; "" or a missing file = the built-in placeholder). The muzzle scene's root has
## `flash(size, suppressed)` / `tick(delta)` / `auto_tick`; the tracer scene's root has `spawn(from, to)`.
@export var vfx_muzzle_scene_path: String = G.VFX_DIR + "muzzle_flash.tscn"
@export var vfx_tracer_scene_path: String = G.VFX_DIR + "tracer.tscn"
## `size` passed to the library flash (its star / flame scale relative to the root's FP scale).
@export var vfx_muzzle_size: float = 3.0
## PO6-13 (D-113 / D-114 §8): ENV C's flash shape per anim set (MuzzleFlash.flash weapon_class: pistol, smg, rifle,
## lmg, shotgun, sniper; sets not listed = rifle). C's scene picks the brake side-port jets by class and is already
## toned down (its SIZE_K / FLASH_S), so vfx_muzzle_size stays the D-113 FP scale.
@export var flash_class_by_set: Dictionary[StringName, StringName] = {
	&"pistol": &"pistol", &"revolver": &"pistol", &"akimbo": &"pistol", &"smg": &"smg", &"rifle": &"rifle",
	&"lmg": &"lmg", &"minigun": &"lmg", &"sniper": &"sniper", &"lever": &"rifle", &"shotgun": &"shotgun",
	&"shotgun_box": &"shotgun", &"break_action": &"shotgun",
}
## The trailing smoke wisp (MuzzleFlash.burst_end) plays this long after the last shot of a burst (s).
@export var burst_end_after_s: float = 0.25
## Burst visible this long (one or two frames at 60 fps); 0 = no burst.
@export var muzzle_flash_s: float = 0.035
## The muzzle sits ~1 m out through the viewmodel camera, so the burst is sized for that depth.
@export var muzzle_flash_size_m: float = 0.3
## Burst size multiplier by anim set (long guns sit further out and behind the support hand).
@export var muzzle_flash_set_mult: Dictionary[StringName, float] = {
	&"rifle": 1.6, &"lmg": 1.8, &"sniper": 1.7, &"shotgun": 1.8, &"shotgun_box": 1.7, &"smg": 1.3, &"minigun": 1.6,
	&"lever": 1.5, &"break_action": 1.8,
}
@export var muzzle_flash_color: Color = Color(1.0, 0.62, 0.22, 0.95)
@export var muzzle_flash_core_color: Color = Color(1.0, 0.95, 0.8, 1.0)
## Anim sets that never flash (no propellant at the muzzle).
@export var no_flash_sets: Array[StringName] = [&"bow", &"crossbow", &"flamethrower", &"saw"]
## Smoke puff particles per shot (x suppressed mult when suppressed); 0 = none.
@export var muzzle_smoke_amount: int = 6
@export var muzzle_smoke_suppressed_mult: float = 0.5
@export var muzzle_smoke_life_s: float = 0.6
## Casing per anim set: pistol / rifle / shotgun look; sets not listed eject nothing (revolver, break action, bow...).
@export var shell_kind: Dictionary[StringName, StringName] = {
	&"pistol": &"pistol", &"akimbo": &"pistol", &"smg": &"pistol", &"rifle": &"rifle", &"lmg": &"rifle",
	&"sniper": &"rifle", &"minigun": &"rifle", &"lever": &"rifle", &"shotgun": &"shotgun", &"shotgun_box": &"shotgun",
}
## Sets that eject on the cycle, not the shot: set -> [clip (fire / bolt), event] (SOURCE.txt clip events).
@export var shell_eject_event: Dictionary[StringName, Array] = {
	&"shotgun": [&"fire", &"pump_back"], &"lever": [&"fire", &"lever_open"], &"sniper": [&"bolt", &"bolt_back"],
}
@export var shell_life_s: float = 0.7
@export var shell_gravity: float = 9.8
@export var shell_speed_mult: float = 1.0
@export var shell_color: Color = Color(0.78, 0.6, 0.25)
@export var shell_color_shotgun: Color = Color(0.62, 0.1, 0.08)
## Tracer cadence by Enums.WeaponClass key (impact_fx.md §3: AR/SMG/LMG 1 in 2, pistol/shotgun 1 in 3, sniper all).
@export var tracer_every: Dictionary[StringName, int] = {
	&"PISTOL": 3, &"SMG": 2, &"ASSAULT_RIFLE": 2, &"SHOTGUN": 3, &"LMG": 2, &"SNIPER": 1, &"SPECIAL": 2,
}
@export var tracer_when_suppressed: bool = false
@export var tracer_speed_mps: float = 400.0
@export var tracer_length_m: float = 3.0
@export var tracer_width_m: float = 0.02
## The head starts this far out on the first frame (a streak shows on the shot's frame, not one frame late).
@export var tracer_first_frame_m: float = 2.0
@export var tracer_color: Color = Color(1.0, 0.8, 0.45, 0.85)
## Per-shot viewmodel kick (the visual punch on top of the camera recoil): back (m) and pitch up (deg) by anim set,
## as a critically damped impulse peaking after 1 / (TAU * kick_hz) s; x kick_ads_mult when aimed.
@export var kick_back_m: Dictionary[StringName, float] = {
	&"pistol": 0.014, &"akimbo": 0.012, &"revolver": 0.022, &"smg": 0.010, &"rifle": 0.016, &"lmg": 0.014,
	&"sniper": 0.035, &"lever": 0.03, &"shotgun": 0.035, &"shotgun_box": 0.03, &"break_action": 0.04,
	&"launcher": 0.03, &"minigun": 0.006,
}
@export var kick_pitch_deg: Dictionary[StringName, float] = {
	&"pistol": 2.2, &"akimbo": 1.6, &"revolver": 3.5, &"smg": 1.0, &"rifle": 1.4, &"lmg": 1.0, &"sniper": 3.0,
	&"lever": 3.0, &"shotgun": 3.5, &"shotgun_box": 3.0, &"break_action": 4.0, &"launcher": 2.5, &"minigun": 0.4,
}
@export var kick_hz: float = 9.0
@export var kick_ads_mult: float = 0.45
## Multiplier on the world Environment's ambient energy for the viewmodel camera only.
@export var viewmodel_ambient_mult: float = 1.6

@export_group("Gadgets (D-118)")
## FpViewmodelGadgets defaults; the resolved WeaponDef/mod params (visual_slots.md v1.3) win when present.
## Marker used when the gun has no LaserOrigin / LightOrigin.
@export var gadget_fallback_marker: StringName = &"Muzzle"
@export var gadget_laser_color: Color = Color(1.0, 0.12, 0.08)
@export var gadget_laser_range_m: float = 50.0
## Beam ribbon width (m) and opacity (additive); the dot's size (m) at gadget_laser_dot_ref_m, growing with distance
## past it so it stays readable.
@export var gadget_laser_width_m: float = 0.009
@export var gadget_laser_beam_alpha: float = 0.7
@export var gadget_laser_dot_m: float = 0.035
@export var gadget_laser_dot_ref_m: float = 5.0
@export var gadget_light_range_m: float = 25.0
@export var gadget_light_angle_deg: float = 30.0
@export var gadget_light_energy: float = 2.0
@export var gadget_light_color: Color = Color(1.0, 0.97, 0.9)
@export var gadget_light_attenuation: float = 1.2

@export_group("Scoped ADS (LEAD 2026-10-16)")
## A sight with WeaponStats.magnification >= this (or ENV B's `is_scope`, when present) shows the FpScopeOverlay
## sight picture at full ADS instead of the 3D gun; lower-power optics (reflex, holo, 3x prism) stay 3D.
@export var scope_overlay_min_mag: float = 3.5
## ads_blend range over which the overlay fades in (and back out on release).
@export var scope_blend_in: Vector2 = Vector2(0.8, 0.97)
## Overlay amount past which the gun image (arms, gun, ocular lens) is hidden.
@export var scope_hide_gun_at: float = 0.6
## Ocular radius as a fraction of the shorter screen side; the soft dark edge just inside it (px).
@export var scope_radius_frac: float = 0.46
@export var scope_edge_px: float = 14.0
## Reticle line width (px); style and colour when the weapon's scope data names none.
@export var scope_line_px: float = 2.0
@export var scope_reticle_default: StringName = &"duplex"
@export var scope_reticle_color: Color = Color(0.02, 0.02, 0.02)
## Duplex posts: width as a multiple of scope_line_px (at least 3 % of the ocular radius), ending this fraction of the
## radius from the centre.
@export var scope_post_width_mult: float = 4.0
@export var scope_post_inner_frac: float = 0.25
## The sight picture follows the gun's look-lag sway + breathing (FpViewmodel.sight_sway_deg) projected at the
## zoomed world FOV: the look-lag sway times scope_sway_mult (the ADS sway is tuned tiny for iron sights; a scope
## magnifies it, PD2: a turn swings the sight picture and it settles when still) and the breathing times
## scope_breath_mult (a slow drift); 0 / 0 = a fixed sight picture.
@export var scope_sway_mult: float = 8.0
@export var scope_breath_mult: float = 3.0

@export_group("Motion")
## Horizontal speed (m/s) above which walk bob / sprint play.
@export var move_threshold_mps: float = 0.3
## Walk bob amplitude (m) at `bob_ref_speed_mps`, x = side, y = vertical; frequency of one step pair.
@export var bob_amplitude: Vector2 = Vector2(0.008, 0.006)
@export var bob_frequency_hz: float = 1.0
@export var bob_ref_speed_mps: float = 3.5
## D-116: the bob rides the camera's footstep phase (CrewController.bob_phase: one cycle = two steps) and weight, as a
## figure-8 (x = sin, y = sin 2x) with roll / pitch, x bob_sprint_mult while sprinting (bigger running). false = the
## old free-running bob_frequency_hz clock.
@export var bob_follow_steps: bool = true
@export var bob_sprint_mult: float = 1.6
@export var bob_roll_deg: float = 0.8
@export var bob_pitch_deg: float = 0.5
## D-116: landing dip of the arms on top of the camera's (CrewController.land_dip x this) and a pitch per m of dip
## (deg/m; the gun noses down as it lands).
@export var land_vm_mult: float = 0.6
@export var land_vm_pitch_deg_per_m: float = 60.0
## Bob multiplier while fully aimed down sights.
@export var ads_bob_mult: float = 0.2
## Bob amplitude response rate (1/s) when starting / stopping.
@export var bob_rate: float = 8.0
## PI-21: share of the camera's step smoothing offset (CrewController.step_offset) the arms add on top, so they
## trail the camera on stairs and curbs instead of riding it rigidly. 0 = off; ADS scales it by `ads_bob_mult`.
@export var step_lag_mult: float = 0.6
## PO-4: camera-space offset (m) of the whole viewmodel per anim_set at hip fire (x right, y up, -z forward). The
## authored rig puts the rifle's stock behind the lens (receiver fills the corner); PD2 shows the gun low-right with
## the receiver in view. Sets not listed: no offset.
@export var set_hip_offset: Dictionary[StringName, Vector3] = {}
## PO6-11: per-set hip pose rotation (deg: x pitch up, y yaw left, z roll left) about the firing hand (the weapon bone),
## blended out toward full ADS: the natural hip cant / angle the authored clip lacks. Sets not listed: none.
@export var set_hip_rot_deg: Dictionary[StringName, Vector3] = {}
## PO-4: extra forward offset (m, negative = away from the eye) per anim_set when fully aimed (eye relief), on top
## of the AimPoint alignment. Sets not listed: 0.
@export var set_ads_offset_z: Dictionary[StringName, float] = {}
## PO-4: how fast (m/s) the framing offset moves when the playing set changes (gun <-> melee item, swaps).
@export var set_offset_rate: float = 1.5
## While aimed, shift the arms so the weapon's `AimPoint` sits on the camera axis.
@export var ads_align_aim_point: bool = true
## Viewmodel meshes cast no world shadows.
@export var cast_shadows: bool = false

var _merged: Dictionary = {}
var _merged_path: String = ""
var _merged_extra: int = 0
var _merged_gen: int = -1


static func data() -> FpViewmodelTweak:
	if _cached == null:
		_cached = load(PATH) as FpViewmodelTweak
		if _cached == null:
			_cached = FpViewmodelTweak.new()
	return _cached


## The LeftHandGrip offset (wrist from the LeftHandIK marker, marker space) for FP set `set_id`.
func grip_offset(set_id: StringName) -> Vector3:
	return set_left_hand_grip_offset.get(set_id, left_hand_grip_offset)


## Path of the SOURCE.txt the clip events come from ("" when none is known).
func events_path() -> String:
	if events_source != "":
		return events_source
	if arms_scene != null and arms_scene.resource_path != "":
		return arms_scene.resource_path.get_base_dir().path_join("SOURCE.txt")
	return ""


## Event frames per glb clip "<set>_<clip>": SOURCE.txt (parsed once, cached) with `extra_events` merged over
## it, {clip: {event: frame}}. Every `clip.*` line yields an entry (empty when it has no events).
func clip_events() -> Dictionary:
	var path: String = events_path()
	if _merged_gen == _gen and _merged_path == path and _merged_extra == extra_events.hash():
		return _merged
	var out: Dictionary = {}
	var src: Dictionary = source_events(path)
	for c: Variant in src:
		out[c] = (src[c] as Dictionary).duplicate()
	for c: Variant in extra_events:
		var ev: Dictionary = out.get(StringName(c), {})
		ev.merge(extra_events[c] as Dictionary, true)
		out[StringName(c)] = ev
	_merged = out
	_merged_path = path
	_merged_extra = extra_events.hash()
	_merged_gen = _gen
	return out


## Seconds from the clip start to `event` of glb clip `full_name` ("<set>_<clip>"); -1 when unknown.
func event_s(full_name: StringName, event: StringName) -> float:
	var ev: Dictionary = clip_events().get(full_name, {})
	return float(ev[event]) / maxf(fps, 1.0) if ev.has(event) else -1.0


## Every event of a clip (SOURCE.txt + extras) as {event: seconds}.
func events_s(full_name: StringName) -> Dictionary:
	var out: Dictionary = {}
	var ev: Dictionary = clip_events().get(full_name, {})
	for k: Variant in ev:
		out[k] = float(ev[k]) / maxf(fps, 1.0)
	return out


## Parsed SOURCE.txt at `path` (cached per path; {} when the file is missing).
static func source_events(path: String) -> Dictionary:
	if path == "":
		return {}
	if not _parsed.has(path):
		_parsed[path] = parse_events(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	return _parsed[path]


## Parse SOURCE.txt text: each `clip.<name>: <N>f loop=<bool> [events=a@F,b@G]` line gives
## {&"<name>": {&"a": F, ...}} (frames as int, float when fractional). Unknown lines, unknown fields and
## malformed event tokens are ignored, so new sets and new SOURCE.txt keys need no parser change.
static func parse_events(text: String) -> Dictionary:
	var out: Dictionary = {}
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if not line.begins_with("clip."):
			continue
		var colon: int = line.find(":")
		if colon <= 5:
			continue
		var clip_name: String = line.substr(5, colon - 5).strip_edges()
		if clip_name == "" or clip_name.contains(" "):
			continue
		var ev: Dictionary = {}
		for field: String in line.substr(colon + 1).split(" ", false):
			if not field.begins_with("events="):
				continue
			for tok: String in field.substr(7).split(",", false):
				var at: int = tok.rfind("@")
				if at <= 0:
					continue
				var frame: String = tok.substr(at + 1)
				if frame.is_valid_int():
					ev[StringName(tok.substr(0, at))] = frame.to_int()
				elif frame.is_valid_float():
					ev[StringName(tok.substr(0, at))] = frame.to_float()
		out[StringName(clip_name)] = ev
	return out


## Drop the parsed SOURCE.txt cache (tests; a rebuilt rig in the editor).
static func clear_event_cache() -> void:
	_parsed.clear()
	_gen += 1
