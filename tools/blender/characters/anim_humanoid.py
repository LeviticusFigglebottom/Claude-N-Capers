"""``char_anim_humanoid``: the shared ``humanoid`` animation library on ``rig_humanoid`` (D1-03).

One glb with the armature ``rig_humanoid`` (1.78 m, ``_rig.build_rig``), a tiny skinned proxy mesh
(``AnimProxy``, 1 triangle, material ``char_skin_1``: it only satisfies the exporter/validator and can
be ignored or deleted) and one glTF animation per clip, all procedural (``_anim_humanoid``), in place,
30 fps. ENV D's assembly tool turns the imported animations into the AnimationLibrary "humanoid".

Clip names in the glb: the contract name, plus the suffix ``-loop`` for looping clips. Godot's scene
importer strips ``-loop`` and sets ``Animation.loop_mode = LOOP_LINEAR`` (verified with Godot 4.7.2),
so the imported names are exactly the contract names. ``CLIPS``/``LOOPS`` below are plain data
(readable with ``lib.meta.read_constants`` without Blender) for tools that want the table: frames,
loop flag, intended locomotion speed and event frames.

Loops: the last frame equals the first (keys at 0..frames inclusive, length = frames / 30 s).
Locomotion clips plant the stance foot exactly: at ``speed`` m/s (for 1.78 m; multiply by
``Skeleton3D.motion_scale``) the feet do not slide. Play them at ``speed_scale = v / speed``.
"""

import _anim as anim
import _anim_ah as ah
import _anim_assault as assault
import _anim_bank as bank
import _anim_civ_panic as civ
import _anim_crew3p as crew3p
import _anim_d304 as d304
import _anim_hitzones as hitzones
import _anim_holds as holds
import _anim_humanoid as lib
import _anim_idle_var as idlev
import _anim_loco_holds as loco
import _anim_police as police
import _anim_reverse as rev
import _anim_rt as rt
import _anim_p5 as p5
import _anim_surrender as surr
import _rig as rig

TRI_BUDGET = 35000
EXPORT = {"embed": False, "animations": True, "skins": True, "morph": False}
ASSET_ID = "char_anim_humanoid"
PARAMS = {"height": 1.78}

# name: frames (at 30 fps), loop, speed (m/s along the travel direction, 0 = stationary), events
# (name -> frame), priority (1 = P1 subset of roadmap C1-05, 2 = the rest delivered by D1-03, 3 = the special
# enemies, P3). Specials, timed from ENV A's data: kick_charge = SpecialTweak.phantom_windup_s (0.5 s, standing,
# then `sprint` plays during the charge); kick_hit lands its kick at `impact`; shield_bang =
# HeavySpecialTweak.bulwark_bang_hold_s (0.8 s), one event per bang; heal_ally = corpsman_heal_lock_s (1.0 s),
# `heal` at the injector jab; dozer_walk cadence = wrecker_step_interval_s (0.55 s per step, step_l/step_r =
# heel strikes). shield_idle = the Bulwark's braced stand (shield_walk's upper body, to blend with it).
# shield_walk / dozer_walk are walks (1.6 m/s native): EnemyDef.move_speed (Bulwark 3.2, Wrecker
# 3.5 m/s) is a run speed, i.e. speed_scale 2.0 / 2.2.
CLIPS = {
    "idle": {"frames": 120, "loop": True, "speed": 0.0, "priority": 1},
    "idle_alert": {"frames": 90, "loop": True, "speed": 0.0, "priority": 2},
    "walk": {"frames": 30, "loop": True, "speed": 1.6, "priority": 1},
    "run": {"frames": 21, "loop": True, "speed": 3.5, "priority": 1},
    "sprint": {"frames": 18, "loop": True, "speed": 5.75, "priority": 2},
    "crouch_idle": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "crouch_walk": {"frames": 27, "loop": True, "speed": 1.5, "priority": 1},
    "strafe_l": {"frames": 18, "loop": True, "speed": 1.2, "priority": 2},
    "strafe_r": {"frames": 18, "loop": True, "speed": 1.2, "priority": 2},
    "walk_back": {"frames": 30, "loop": True, "speed": 1.3, "priority": 2},
    "turn_l": {"frames": 24, "loop": False, "speed": 0.0, "priority": 2, "turn_deg": 90.0},
    "turn_r": {"frames": 24, "loop": False, "speed": 0.0, "priority": 2, "turn_deg": -90.0},
    # small turns (the 3P turn-in-place foot-slide fix): the same footwork over 45 deg at the 90 clips' rate
    "turn_l_45": {"frames": 12, "loop": False, "speed": 0.0, "priority": 2, "turn_deg": 45.0},
    "turn_r_45": {"frames": 12, "loop": False, "speed": 0.0, "priority": 2, "turn_deg": -45.0},
    "aim_rifle": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "aim_pistol": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "fire_rifle": {"frames": 6, "loop": False, "speed": 0.0, "priority": 1, "events": {"shot": 0}},
    "fire_pistol": {"frames": 9, "loop": False, "speed": 0.0, "priority": 1, "events": {"shot": 0}},
    "reload_rifle": {"frames": 72, "loop": False, "speed": 0.0, "priority": 1,
                     "events": {"mag_out": 14, "mag_in": 50, "done": 58}},
    "reload_pistol": {"frames": 45, "loop": False, "speed": 0.0, "priority": 1,
                      "events": {"mag_out": 6, "mag_in": 30, "done": 34}},
    "melee": {"frames": 21, "loop": False, "speed": 0.0, "priority": 2, "events": {"hit": 10}},
    "death_front": {"frames": 54, "loop": False, "speed": 0.0, "priority": 1, "events": {"impact": 35}},
    "death_back": {"frames": 54, "loop": False, "speed": 0.0, "priority": 1, "events": {"impact": 35}},
    "hit_react": {"frames": 15, "loop": False, "speed": 0.0, "priority": 1},
    "surrender": {"frames": 48, "loop": False, "speed": 0.0, "priority": 2},
    "kneel_cuffed": {"frames": 90, "loop": True, "speed": 0.0, "priority": 2},
    "hands_up": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    # D-116 surrender variety (priority 8, _anim_surrender): per-NPC variants of hands_up / surrender / kneel_cuffed and
    # the held surrender (surrender_idle*, NEW: frame 0 = surrender's last frame); groups and how to pick in SOURCE
    # `variants.<group>` / `surrender_variants`. surrender_b/_c start on idle 0 and end exactly on surrender's last frame;
    # kneel_cuffed_b/_c frame 0 = kneel_cuffed frame 0. Unrelated loop periods so a group never re-syncs.
    "hands_up_b": {"frames": 82, "loop": True, "speed": 0.0, "priority": 8},
    "hands_up_c": {"frames": 98, "loop": True, "speed": 0.0, "priority": 8},
    "surrender_b": {"frames": 54, "loop": False, "speed": 0.0, "priority": 8},
    "surrender_c": {"frames": 42, "loop": False, "speed": 0.0, "priority": 8},
    "kneel_cuffed_b": {"frames": 104, "loop": True, "speed": 0.0, "priority": 8},
    "kneel_cuffed_c": {"frames": 118, "loop": True, "speed": 0.0, "priority": 8},
    "surrender_idle": {"frames": 96, "loop": True, "speed": 0.0, "priority": 8},
    "surrender_idle_b": {"frames": 110, "loop": True, "speed": 0.0, "priority": 8},
    "surrender_idle_c": {"frames": 84, "loop": True, "speed": 0.0, "priority": 8},
    "cower": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "lie_down": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "tied": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "flee": {"frames": 20, "loop": True, "speed": 4.0, "priority": 1},
    # D-116 civilian panic variety (priority 8, _anim_civ_panic): per-NPC variants of cower / flee and the startle;
    # groups and how to pick in SOURCE `variants.<group>` / `civ_panic_variants`. flee_b/_c = the flee gait (same
    # frames, speed, foot plants) with another upper body; cower_b/_c own periods; panic_start ends exactly on cower 0.
    "cower_b": {"frames": 52, "loop": True, "speed": 0.0, "priority": 8},
    "cower_c": {"frames": 46, "loop": True, "speed": 0.0, "priority": 8},
    "flee_b": {"frames": 20, "loop": True, "speed": 4.0, "priority": 8},
    "flee_c": {"frames": 20, "loop": True, "speed": 4.0, "priority": 8},
    "panic_start": {"frames": 24, "loop": False, "speed": 0.0, "priority": 8, "events": {"flinch": 2}},
    "phone_call": {"frames": 120, "loop": True, "speed": 0.0, "priority": 1},
    "radio_call": {"frames": 60, "loop": False, "speed": 0.0, "priority": 1, "events": {"key_on": 11, "key_off": 44}},
    "pager_answer": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "investigate_look": {"frames": 120, "loop": True, "speed": 0.0, "priority": 2},
    "smoke": {"frames": 120, "loop": True, "speed": 0.0, "priority": 2},
    "lean_wall": {"frames": 120, "loop": True, "speed": 0.0, "priority": 2},
    "sit_chair": {"frames": 120, "loop": True, "speed": 0.0, "priority": 2},
    "desk_type": {"frames": 60, "loop": True, "speed": 0.0, "priority": 2},
    "browse": {"frames": 120, "loop": True, "speed": 0.0, "priority": 2},
    "downed": {"frames": 90, "loop": True, "speed": 0.0, "priority": 1},
    "tased": {"frames": 30, "loop": True, "speed": 0.0, "priority": 2},
    "climb_ladder": {"frames": 36, "loop": True, "speed": 0.5, "priority": 2, "axis": "up"},
    "carry_bag_walk": {"frames": 22, "loop": True, "speed": 2.4, "priority": 1},
    "throw_bag": {"frames": 30, "loop": False, "speed": 0.0, "priority": 1, "events": {"release": 15}},
    "interact_low": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "interact_mid": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "interact_high": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "drill_place": {"frames": 45, "loop": False, "speed": 0.0, "priority": 2, "events": {"attach": 27}},
    "kick_charge": {"frames": 15, "loop": False, "speed": 0.0, "priority": 3},
    "kick_hit": {"frames": 21, "loop": False, "speed": 0.0, "priority": 3, "events": {"impact": 6}},
    "shield_walk": {"frames": 28, "loop": True, "speed": 1.6, "priority": 3},
    "shield_idle": {"frames": 108, "loop": True, "speed": 0.0, "priority": 3},
    "shield_bang": {"frames": 24, "loop": False, "speed": 0.0, "priority": 3,
                    "events": {"bang_1": 6, "bang_2": 12, "bang_3": 18}},
    "heal_ally": {"frames": 30, "loop": False, "speed": 0.0, "priority": 3, "events": {"heal": 12}},
    "dozer_walk": {"frames": 33, "loop": True, "speed": 1.6, "priority": 3, "events": {"step_r": 0, "step_l": 16}},
    # NPC ambient set (priority 4, heist casting: night_deposit / shadow_ledger civilians and staff). Props ride
    # HandR/Socket (SOURCE.txt `<prop>_grip`); seated clips share sit_chair's seat (0.47 m) and desk (0.74 m).
    "desk_work": {"frames": 360, "loop": True, "speed": 0.0, "priority": 4},
    "phone_seated": {"frames": 240, "loop": True, "speed": 0.0, "priority": 4},
    "sit_chair_watch": {"frames": 300, "loop": True, "speed": 0.0, "priority": 4},
    "mug_idle": {"frames": 240, "loop": True, "speed": 0.0, "priority": 4, "events": {"sip": 105}},
    "mug_carry_walk": {"frames": 34, "loop": True, "speed": 1.3, "priority": 4},
    "mop": {"frames": 120, "loop": True, "speed": 0.0, "priority": 4},
    "sit_bed_read": {"frames": 300, "loop": True, "speed": 0.0, "priority": 4, "events": {"page_turn": 221}},
    # D-116: Kessler in the bedside armchair (shadow_ledger.md), the sit_bed_read book and page turn seated like sit_chair
    "sit_chair_read": {"frames": 300, "loop": True, "speed": 0.0, "priority": 2, "events": {"page_turn": 221}},
    # cartel gunmen: hunched idle with a long gun held low across the body (weapon at HandR/Socket)
    "idle_thug": {"frames": 105, "loop": True, "speed": 0.0, "priority": 4},
    # police rappel (QC-41, NpcMotor one-way rappel links): one hop per loop down a vertical rope, facing the wall,
    # in place; ENV A moves the root straight down at `speed` (2.5 m/s native: an 8 m skylight drop in ~3 hops).
    # `land` = the feet hit the wall (thud). Rope / hand / wall placement: SOURCE.txt `rappel_rope`.
    "rappel": {"frames": 30, "loop": True, "speed": 2.5, "priority": 3, "axis": "down", "events": {"land": 0}},
    # P5 NPC ambient set (priority 5, D3-02: Afterhours, Gallery Night, Meridian Federal, Rolling Thunder casting), all
    # loops. Dances: 8 beats at 120 BPM (beat every 15 f from frame 0; speed_scale = track_bpm / 120). Bar, counter,
    # painting, seat and wall placement and the new prop grips: SOURCE.txt (`p5_placement`, `<prop>_grip`).
    "dance_a": {"frames": 120, "loop": True, "speed": 0.0, "priority": 5, "bpm": 120, "beats": 8},
    "dance_b": {"frames": 120, "loop": True, "speed": 0.0, "priority": 5, "bpm": 120, "beats": 8},
    "dance_c": {"frames": 120, "loop": True, "speed": 0.0, "priority": 5, "bpm": 120, "beats": 8},
    "bartender_wipe": {"frames": 180, "loop": True, "speed": 0.0, "priority": 5},
    "bartender_pour": {"frames": 150, "loop": True, "speed": 0.0, "priority": 5,
                       "events": {"lift": 2, "pour_start": 39, "pour_end": 77, "set_down": 110}},
    "bouncer_idle": {"frames": 300, "loop": True, "speed": 0.0, "priority": 5, "events": {"watch": 222}},
    "teller_count": {"frames": 240, "loop": True, "speed": 0.0, "priority": 5,
                     "events": {"count_start": 6, "count_end": 120, "stack_down": 144, "tap_1": 177, "tap_2": 189}},
    "curator_inspect": {"frames": 360, "loop": True, "speed": 0.0, "priority": 5,
                        "events": {"step_back_r": 93, "step_back_l": 110, "step_fwd_l": 256, "step_fwd_r": 272}},
    "walk_text": {"frames": 36, "loop": True, "speed": 1.2, "priority": 5},
    "cower_seated": {"frames": 90, "loop": True, "speed": 0.0, "priority": 5},
    "cower_stand": {"frames": 150, "loop": True, "speed": 0.0, "priority": 5, "events": {"flinch_1": 39, "flinch_2": 108}},
    # D3-04 polish (priority 6, _anim_d304). Crew locomotion blend set: 8-way cycles phase-locked to walk / run (same
    # frames, speed and stance share; right foot down at normalised time 0, left at 0.5 in every direction), `dir_deg`
    # = travel direction clockwise from forward (Godot root space (sin a, 0, -cos a)); `walk` / `run` are the forward
    # members. Start / stop one-shots: `handoff` = the walk / run frame the clip hands over to (starts: the clip's
    # last frame == that cycle frame; stops: the clip's frame 0 == that cycle frame), from / to idle frame 0; root
    # travel per frame in SOURCE.txt `curve.<clip>` (A drives the root). Events: foot plants.
    "walk_fl": {"frames": 30, "loop": True, "speed": 1.6, "priority": 6, "dir_deg": -45},
    "walk_fr": {"frames": 30, "loop": True, "speed": 1.6, "priority": 6, "dir_deg": 45},
    "walk_l": {"frames": 30, "loop": True, "speed": 1.6, "priority": 6, "dir_deg": -90},
    "walk_r": {"frames": 30, "loop": True, "speed": 1.6, "priority": 6, "dir_deg": 90},
    "walk_bl": {"frames": 30, "loop": True, "speed": 1.6, "priority": 6, "dir_deg": -135},
    "walk_br": {"frames": 30, "loop": True, "speed": 1.6, "priority": 6, "dir_deg": 135},
    "walk_b": {"frames": 30, "loop": True, "speed": 1.6, "priority": 6, "dir_deg": 180},
    "run_fl": {"frames": 21, "loop": True, "speed": 3.5, "priority": 6, "dir_deg": -45},
    "run_fr": {"frames": 21, "loop": True, "speed": 3.5, "priority": 6, "dir_deg": 45},
    "run_l": {"frames": 21, "loop": True, "speed": 3.5, "priority": 6, "dir_deg": -90},
    "run_r": {"frames": 21, "loop": True, "speed": 3.5, "priority": 6, "dir_deg": 90},
    "run_bl": {"frames": 21, "loop": True, "speed": 3.5, "priority": 6, "dir_deg": -135},
    "run_br": {"frames": 21, "loop": True, "speed": 3.5, "priority": 6, "dir_deg": 135},
    "run_b": {"frames": 21, "loop": True, "speed": 3.5, "priority": 6, "dir_deg": 180},
    "walk_start": {"frames": 18, "loop": False, "speed": 1.6, "priority": 6, "handoff": 3, "events": {"step_r": 15}},
    "walk_stop": {"frames": 18, "loop": False, "speed": 1.6, "priority": 6, "handoff": 0, "events": {"step_l": 14}},
    "run_start": {"frames": 18, "loop": False, "speed": 3.5, "priority": 6, "handoff": 4, "events": {"step_r": 14}},
    "run_stop": {"frames": 20, "loop": False, "speed": 3.5, "priority": 6, "handoff": 0, "stop_m": 0.9,
                 "events": {"step_l": 6, "step_r": 17}},
    # directional hit reacts (with the existing hit_react = shot from the front) and death variety; deaths end lying
    # on the floor (`impact` = the body hits the floor)
    "hit_react_back": {"frames": 15, "loop": False, "speed": 0.0, "priority": 6},
    "hit_react_left": {"frames": 15, "loop": False, "speed": 0.0, "priority": 6},
    "hit_react_right": {"frames": 15, "loop": False, "speed": 0.0, "priority": 6},
    "death_front_b": {"frames": 60, "loop": False, "speed": 0.0, "priority": 6, "events": {"knees": 16, "impact": 38}},
    "death_back_b": {"frames": 60, "loop": False, "speed": 0.0, "priority": 6,
                     "events": {"step_r": 12, "step_l": 21, "impact": 44}},
    "death_side": {"frames": 60, "loop": False, "speed": 0.0, "priority": 6, "events": {"impact": 36}},
    # seated deaths (D-110, Gallery Night): from desk_work's chair; slump = onto the desk top (`impact` = head on
    # the desk, root and hips stay on the seat), fall = off the chair to the left onto the floor (`impact`)
    "death_seated_slump": {"frames": 48, "loop": False, "speed": 0.0, "priority": 6, "events": {"impact": 22}},
    "death_seated_fall": {"frames": 60, "loop": False, "speed": 0.0, "priority": 6, "events": {"impact": 34}},
    # pose-aware deaths (PO6-18, D-114 §7): an NPC killed crouched / kneeling / prone / downed dies in place. Each
    # starts exactly on its source pose (crouch_idle 0, kneel_cuffed 0, surrender's last frame, lie_down 0, downed 0;
    # SOURCE `pose_deaths`), the root never moves, nothing rises above the start; `impact` = the body hits the floor
    # (death_prone: the hit jolt, the body is already down)
    "death_crouch": {"frames": 45, "loop": False, "speed": 0.0, "priority": 6, "events": {"impact": 26}},
    "death_kneel_cuffed": {"frames": 45, "loop": False, "speed": 0.0, "priority": 6, "events": {"impact": 24}},
    "death_kneel": {"frames": 45, "loop": False, "speed": 0.0, "priority": 6, "events": {"impact": 24}},
    "death_prone": {"frames": 30, "loop": False, "speed": 0.0, "priority": 6, "events": {"impact": 3}},
    "death_downed": {"frames": 36, "loop": False, "speed": 0.0, "priority": 6, "events": {"impact": 20}},
    # prone bleed-out drag crawl, the root moving forward (-Z) at `speed`; Wrecker heavy stomp at the Wrecker's
    # advance speed (1.8 m/s on its 1.88 m body = 1.7 m/s native), a step every wrecker_step_interval_s (0.55 s)
    "downed_crawl": {"frames": 60, "loop": True, "speed": 0.3, "priority": 6},
    "dozer_walk_heavy": {"frames": 33, "loop": True, "speed": 1.7, "priority": 6, "events": {"step_r": 0, "step_l": 16}},
    # PO6-17 assault events (priority 7, _anim_assault): helicopter rappel squad (rope line, root plane and land:
    # SOURCE `rappel_assault`; rappel_descend moves the root down at `speed`), heli door sniper (kneel on the cabin
    # floor at the door, SOURCE `heli_door_sill`), turret van crew (`van_exit_step`, root motion `curve.van_exit`),
    # breach charges (`breach_charge`, `curve.breach_standback`). rappel_land / van_exit / breach_place end exactly on
    # idle_alert frame 0, breach_standback on crouch_idle frame 0.
    "rappel_hang": {"frames": 40, "loop": True, "speed": 0.0, "priority": 7},
    "rappel_descend": {"frames": 20, "loop": True, "speed": 2.5, "priority": 7, "axis": "down"},
    "rappel_land": {"frames": 30, "loop": False, "speed": 0.0, "priority": 7, "events": {"touch": 6}},
    "heli_door_idle": {"frames": 90, "loop": True, "speed": 0.0, "priority": 7},
    "heli_door_aim": {"frames": 90, "loop": True, "speed": 0.0, "priority": 7},
    "heli_door_fire": {"frames": 6, "loop": False, "speed": 0.0, "priority": 7, "events": {"shot": 0}},
    "van_exit": {"frames": 36, "loop": False, "speed": 0.0, "priority": 7, "events": {"step_r": 16, "step_l": 28},
                 "root_motion": "curve.van_exit"},
    "breach_place": {"frames": 45, "loop": False, "speed": 0.0, "priority": 7, "events": {"place": 28}},
    "breach_standback": {"frames": 30, "loop": False, "speed": 0.0, "priority": 7,
                         "root_motion": "curve.breach_standback"},
    # D-116 hit-zone flinches (priority 8, _anim_hitzones): non-lethal PD2-style flinch by where the bullet landed
    # (SOURCE `hit_zones`); each starts and ends on idle_alert frame 0, root fixed, `impact` = the peak; the leg ones
    # take a small in-place catch step with the hit foot that returns to its spot
    "hit_head": {"frames": 14, "loop": False, "speed": 0.0, "priority": 8, "events": {"impact": 2}},
    "hit_chest": {"frames": 14, "loop": False, "speed": 0.0, "priority": 8, "events": {"impact": 3}},
    "hit_shoulder_l": {"frames": 14, "loop": False, "speed": 0.0, "priority": 8, "events": {"impact": 3}},
    "hit_shoulder_r": {"frames": 14, "loop": False, "speed": 0.0, "priority": 8, "events": {"impact": 3}},
    "hit_leg_l": {"frames": 16, "loop": False, "speed": 0.0, "priority": 8, "events": {"impact": 3}},
    "hit_leg_r": {"frames": 16, "loop": False, "speed": 0.0, "priority": 8, "events": {"impact": 3}},
    # D-116 third-person weapon holds (_anim_holds): the low ready two-handed outside aiming (SOURCE `weapon_holds`)
    "idle_alert_rifle": {"frames": 96, "loop": True, "speed": 0.0, "priority": 2},
    "idle_alert_pistol": {"frames": 110, "loop": True, "speed": 0.0, "priority": 2},
    "hold_rifle": {"frames": 96, "loop": True, "speed": 0.0, "priority": 2},
    "hold_pistol": {"frames": 96, "loop": True, "speed": 0.0, "priority": 2},
    "idle_alert_smg": {"frames": 92, "loop": True, "speed": 0.0, "priority": 2},
    "idle_alert_sniper": {"frames": 104, "loop": True, "speed": 0.0, "priority": 2},
    "idle_alert_lmg": {"frames": 100, "loop": True, "speed": 0.0, "priority": 2},
    "idle_alert_akimbo": {"frames": 106, "loop": True, "speed": 0.0, "priority": 2},
    "hold_smg": {"frames": 92, "loop": True, "speed": 0.0, "priority": 2},
    "hold_sniper": {"frames": 96, "loop": True, "speed": 0.0, "priority": 2},
    "hold_lmg": {"frames": 100, "loop": True, "speed": 0.0, "priority": 2},
    "hold_akimbo": {"frames": 96, "loop": True, "speed": 0.0, "priority": 2},
    # D-116 audit: the crew's armed interactions (the weapon stays low in the right hand; _anim_holds ARMED)
    "interact_low_armed": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "interact_mid_armed": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "interact_high_armed": {"frames": 60, "loop": True, "speed": 0.0, "priority": 1},
    "throw_bag_armed": {"frames": 30, "loop": False, "speed": 0.0, "priority": 1, "events": {"release": 15}},
    # D-116 (DB-4): seated with a long gun across the lap (cartel / armed guard seat posts; sit_chair's seat and feet)
    "sit_chair_armed": {"frames": 140, "loop": True, "speed": 0.0, "priority": 2},
    # D-116 third-person crew states (_anim_crew3p, SOURCE `crew_states`): akimbo firing set, downed actions, cuffed
    "aim_akimbo": {"frames": 90, "loop": True, "speed": 0.0, "priority": 2},
    "fire_akimbo": {"frames": 9, "loop": False, "speed": 0.0, "priority": 2, "events": {"shot": 0}},
    "fire_akimbo_l": {"frames": 9, "loop": False, "speed": 0.0, "priority": 2, "events": {"shot": 0}},
    "reload_akimbo": {"frames": 60, "loop": False, "speed": 0.0, "priority": 2,
                      "events": {"mag_out": 8, "mag_in": 32, "done": 46}},
    "downed_fire": {"frames": 9, "loop": False, "speed": 0.0, "priority": 2, "events": {"shot": 0}},
    "downed_reload": {"frames": 45, "loop": False, "speed": 0.0, "priority": 2,
                      "events": {"mag_out": 6, "mag_in": 28, "done": 34}},
    "downed_getup": {"frames": 40, "loop": False, "speed": 0.0, "priority": 2, "events": {"up": 34}},
    "downed_arrested": {"frames": 40, "loop": False, "speed": 0.0, "priority": 2, "events": {"disarm": 6}},
    "crew_cuffed": {"frames": 120, "loop": True, "speed": 0.0, "priority": 2},
    "crew_cuffed_enter": {"frames": 18, "loop": False, "speed": 0.0, "priority": 2},
    "crew_cuffed_free": {"frames": 24, "loop": False, "speed": 0.0, "priority": 2, "events": {"free": 8}},
    "mask_on": {"frames": 30, "loop": False, "speed": 0.0, "priority": 2, "events": {"mask_on": 18}},
    "throw_grenade": {"frames": 24, "loop": False, "speed": 0.0, "priority": 2, "events": {"release": 11, "done": 24}},
    # OF-D1 bank customers (priority 9, _anim_bank; Ostrander Federal): a queue at the rails (the group
    # `variants.queue_idle`, own periods so a line never syncs), a teller window, a check desk. In place, speed 0; ledge /
    # desk heights, the contact frames and the marks in SOURCE `queue_variants`, `contact.<clip>`, `*_placement`.
    "queue_idle": {"frames": 150, "loop": True, "speed": 0.0, "priority": 9, "events": {"watch": 100}},
    "queue_idle_b": {"frames": 126, "loop": True, "speed": 0.0, "priority": 9, "events": {"look_up": 80}},
    "queue_idle_c": {"frames": 138, "loop": True, "speed": 0.0, "priority": 9, "events": {"sigh": 34, "look_back": 84}},
    "counter_customer": {"frames": 180, "loop": True, "speed": 0.0, "priority": 9, "events": {"slip_push": 48, "nod": 146}},
    "check_desk_write": {"frames": 150, "loop": True, "speed": 0.0, "priority": 9, "events": {"look_up": 98}},
    # RT-D1 Rolling Thunder (priority 10, _anim_rt; QC-86): vehicle occupants (sit_vehicle, a bucket seat lower and
    # more reclined than sit_chair) and their dismount through the left / right door (vehicle_exit_*: from sit_vehicle
    # frame 0 to idle_alert frame 0, root motion `curve.vehicle_exit_<side>` sideways); seat, sill, door and clearance
    # in SOURCE `rt_vehicle_placement`.
    "sit_vehicle": {"frames": 180, "loop": True, "speed": 0.0, "priority": 10},
    "vehicle_exit_l": {"frames": 45, "loop": False, "speed": 0.0, "priority": 10,
                       "events": {"foot_out": 14, "step_r": 26, "step_l": 37}, "root_motion": "curve.vehicle_exit_l"},
    "vehicle_exit_r": {"frames": 45, "loop": False, "speed": 0.0, "priority": 10,
                       "events": {"foot_out": 14, "step_l": 26, "step_r": 37}, "root_motion": "curve.vehicle_exit_r"},
    # RT-D1 diner (D-148): a booth customer eating (_anim_rt BITES / SIP at 30 fps) and the cook at the griddle (FLIPS,
    # LOOK_UP_C); prop sizes in _anim_rt (booth table top TABLE_Z 0.74 m, griddle top STOVE_Z 0.90 m)
    "sit_eat": {"frames": 240, "loop": True, "speed": 0.0, "priority": 10,
                "events": {"bite": 48, "bite_2": 117, "sip": 183}},
    "cook_stove": {"frames": 180, "loop": True, "speed": 0.0, "priority": 10,
                   "events": {"flip": 48, "flip_2": 102, "look_up": 129}},
    # D-148: the escort / crew driver (sit_vehicle with the hands on the wheel) and the diner waitress's counter wipe
    # (bartender_wipe at the 0.9 m diner counter)
    "sit_vehicle_drive": {"frames": 180, "loop": True, "speed": 0.0, "priority": 10},
    "counter_wipe": {"frames": 180, "loop": True, "speed": 0.0, "priority": 10},
    # AH-D1 Afterhours (QC-74, _anim_ah): the DJ at the 1.0 m booth on the stage, 120 BPM (16 beats per loop), the right
    # hand on the headphone cup at `cue`; booth layout in SOURCE `ah_dj_placement`
    "dj_mix": {"frames": 240, "loop": True, "speed": 0.0, "priority": 10, "events": {"cue": 90}},
    # D polish #2 (_anim_idle_var): idle_alert variety for posted / pausing guards; frame 0 IS idle_alert frame 0 (A:
    # VARIANT_GROUPS, SOURCE `idle_alert_variants`)
    "idle_alert_b": {"frames": 150, "loop": True, "speed": 0.0, "priority": 2, "events": {"watch": 57}},
    "idle_alert_c": {"frames": 174, "loop": True, "speed": 0.0, "priority": 2, "events": {"radio": 44}},
    # D polish #2 (calm posts): idle variety; frame 0 IS idle frame 0 (A: VARIANT_GROUPS, SOURCE `idle_variants`)
    "idle_b": {"frames": 162, "loop": True, "speed": 0.0, "priority": 1, "events": {"watch": 70}},
    "idle_c": {"frames": 198, "loop": True, "speed": 0.0, "priority": 1, "events": {"stretch": 65}},
}
# characters v1.36 locomotion reversals (_anim_reverse, SOURCE `loco_reverse`): fixed facing, run <-> run_b and walk <->
# walk_back through a plant and push (_l = the left foot brakes); frame 0 IS the source loop at u_in, the last frame IS
# the target loop at u_out, root motion `curve.<clip>` (forward-signed)
CLIPS.update(rev.ROWS)
# D-116 frame-locked weapon holds on the move (_anim_loco_holds, SOURCE `locomotion_holds`): hold_<kind>_<gait>, the
# base clip's frames / loop / events
CLIPS.update(loco.rows(CLIPS))
# D-116 police combat movement (_anim_police, SOURCE `police_combat`): per-class reloads, cover peeks, stagger
CLIPS.update(police.ROWS)
LOOPS = sorted(name for name, row in CLIPS.items() if row["loop"])
P1 = sorted(name for name, row in CLIPS.items() if row["priority"] == 1)
#: Clips whose solved frames build() keeps for SOURCE.txt measurements.
KEEP = ("sit_bed_read", "mop", "rappel", "bartender_pour", "bartender_wipe", "teller_count", "curator_inspect",
        "cower_seated", "cower_stand", "walk_text", "dance_a", "dance_b", "dance_c", "bouncer_idle")
#: The P5 set (D3-02): the SOURCE check row also reports contact_slide (planted heel / ball / toe tip, mm per frame).
P5 = sorted(name for name, row in CLIPS.items() if row["priority"] == 5)
#: Contract names not delivered by this asset yet (none since the P3 specials).
NOT_YET = []


def export_name(name: str) -> str:
    """Action / glTF animation name: Godot strips the ``-loop`` suffix and sets the loop mode."""
    return f"{name}-loop" if CLIPS[name]["loop"] else name


def build(ctx) -> None:
    import bpy  # noqa: PLC0415

    height = float(ctx.param("height", rig.DEFAULT_HEIGHT))
    arm = rig.build_rig(ctx, height)
    _proxy(ctx, arm)
    sk = anim.Skeleton.humanoid(height)
    _check_rest(sk, arm)
    solver = anim.Solver(sk)
    clips = lib.clips(sk, CLIPS)
    bpy.context.scene.render.fps = anim.FPS
    report = []
    keep = {}
    for name in sorted(CLIPS):
        baked = anim.bake(solver, clips[name])
        if (name in KEEP or name in d304.KEEP or name in assault.KEEP or name in hitzones.KEEP
                or name in surr.KEEP or name in civ.KEEP or name in holds.KEEP or name in crew3p.KEEP or name in bank.KEEP
                or name in rt.KEEP or name in idlev.KEEP or name in rev.KEEP or name in ah.KEEP):
            keep[name] = baked
        anim.write_action(arm, baked, export_name(name))
        c = baked.checks
        row = (f"{name}: {CLIPS[name]['frames']}f {CLIPS[name]['frames'] / anim.FPS:.2f}s"
               f"{' loop' if CLIPS[name]['loop'] else ''} speed={CLIPS[name]['speed']}"
               f" reach_err={c['max_reach_err_m'] * 1000:.1f}mm step={c['max_joint_step_deg']:.1f}deg")
        if "max_foot_slide_mm" in c:
            row += f" slide={c['max_foot_slide_mm']:.3f}mm/f"
        elif name in P5:
            cs, _low = p5.contact_slide(sk, baked.frames)
            row += f" contact_slide={cs:.3f}mm/f"
        if name in d304.NAMES:
            row += d304.check_row(sk, CLIPS, name, clips[name], baked, keep)
        if name in assault.NAMES:
            row += assault.check_row(sk, CLIPS, name, baked, keep)
        if name in hitzones.NAMES:
            row += hitzones.check_row(sk, CLIPS, name, baked, keep)
        if name in surr.NAMES:
            row += surr.check_row(name, baked, keep)
        if name in civ.NAMES:
            row += civ.check_row(name, baked, keep)
        if name in bank.NAMES:
            row += bank.check_row(sk, CLIPS, name, baked)
        if name in rt.NAMES:
            row += rt.check_row(sk, CLIPS, name, baked, keep)
        if name in idlev.NAMES:
            row += idlev.check_row(sk, CLIPS, name, baked, keep)
        if name in ah.NAMES:
            row += ah.check_row(sk, CLIPS, name, baked, keep)
        if name in rev.NAMES:
            row += rev.check_row(sk, CLIPS, name, clips[name], baked, keep)
        report.append(row)
        print(f"[anim] {row}")
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    bpy.context.scene.frame_set(0)
    (rx, ry, rz), (ox, oy, oz) = anim.grip_offset_godot(sk, "R")
    ctx.source_extra["fps"] = anim.FPS
    ctx.source_extra["clips"] = len(CLIPS)
    ctx.source_extra["loops"] = ",".join(LOOPS)
    ctx.source_extra["loops_marked_by"] = "-loop name suffix (Godot strips it and sets LOOP_LINEAR)"
    ctx.source_extra["handr_weapon_offset_godot"] = (
        f"basis x=({rx[0]:.4f},{rx[1]:.4f},{rx[2]:.4f}) y=({ry[0]:.4f},{ry[1]:.4f},{ry[2]:.4f}) "
        f"z=({rz[0]:.4f},{rz[1]:.4f},{rz[2]:.4f}) origin=({ox:.4f},{oy:.4f},{oz:.4f}) relative to bone hand.R")
    (lx, ly, lz), (px, py, pz) = anim.grip_offset_godot(sk, "L")
    ctx.source_extra["handl_shield_offset_godot"] = (
        f"basis x=({lx[0]:.4f},{lx[1]:.4f},{lx[2]:.4f}) y=({ly[0]:.4f},{ly[1]:.4f},{ly[2]:.4f}) "
        f"z=({lz[0]:.4f},{lz[1]:.4f},{lz[2]:.4f}) origin=({px:.4f},{py:.4f},{pz:.4f}) relative to bone hand.L")
    hx, hy, hz = (float(c) for c in lib.SHIELD_HANDLE * sk.scale)
    ctx.source_extra["shield_grip"] = (
        "shield_idle/shield_walk/shield_bang hold the Bulwark shield at HandL/Socket (the weapon grip convention, "
        "left fist): "
        "the shield pivot = its vertical handle in the fist, socket -Z = the shield face normal (forward), socket +Y = "
        f"up the handle (matches char_bulwark_shield); handle at Godot ({hx:.3f}, {hz:.3f}, {-hy:.3f}) m in the braced "
        f"stance, the shield tilted {lib.SHIELD_PITCH:g} deg top-back and turned {lib.SHIELD_YAW:g} deg; pistol "
        "one-handed at HandR/Socket just outside the shield's right edge")
    _npc_source(ctx, sk, keep)
    for key, text in d304.source_notes(sk, CLIPS, clips, keep).items():
        ctx.source_extra[key] = text
    for key, text in assault.source_notes(sk, CLIPS, keep).items():
        ctx.source_extra[key] = text
    for key, text in hitzones.source_notes(sk, CLIPS, keep).items():
        ctx.source_extra[key] = text
    for key, text in surr.source_notes(CLIPS, keep).items():
        ctx.source_extra[key] = text
    for key, text in civ.source_notes(CLIPS, keep).items():
        ctx.source_extra[key] = text
    for key, text in bank.source_notes(sk, CLIPS, keep).items():
        ctx.source_extra[key] = text
    for key, text in rt.source_notes(sk, CLIPS, keep).items():
        ctx.source_extra[key] = text
    for key, text in idlev.source_notes(sk, CLIPS, keep).items():
        ctx.source_extra[key] = text
    for key, text in ah.source_notes(sk, CLIPS, keep).items():
        ctx.source_extra[key] = text
    for key, text in rev.source_notes(sk, CLIPS, clips, keep, keep).items():
        ctx.source_extra[key] = text
    for key, text in loco.source_notes().items():
        ctx.source_extra[key] = text
    for key, text in police.source_notes().items():
        ctx.source_extra[key] = text
    for key, text in holds.source_notes().items():
        ctx.source_extra[key] = text
    for key, text in crew3p.source_notes().items():
        ctx.source_extra[key] = text
    for name in sorted(CLIPS):
        row = CLIPS[name]
        extra = f"{row['frames']}f loop={row['loop']} speed_mps={row['speed']}"
        if row.get("events"):
            extra += " events=" + ",".join(f"{k}@{v}" for k, v in sorted(row["events"].items()))
        if "turn_deg" in row:
            extra += f" root_turn_deg={row['turn_deg']}"
        if "axis" in row:
            extra += f" travel_axis={row['axis']}"
        if "bpm" in row:
            extra += f" bpm={row['bpm']} beats={row['beats']} beat_frames={row['frames'] // row['beats']}"
        extra += d304.row_extra(row) + assault.row_extra(row) + surr.row_extra(name) + civ.row_extra(name)
        extra += bank.row_extra(name)
        ctx.source_extra[f"clip.{name}"] = extra
    for i, row in enumerate(report):
        ctx.source_extra[f"check.{i:02d}"] = row


def _xform(basis, origin) -> str:
    (x, y, z), (ox, oy, oz) = basis, origin
    return (f"basis x=({x[0]:.4f},{x[1]:.4f},{x[2]:.4f}) y=({y[0]:.4f},{y[1]:.4f},{y[2]:.4f}) "
            f"z=({z[0]:.4f},{z[1]:.4f},{z[2]:.4f}) origin=({ox:.4f},{oy:.4f},{oz:.4f})")


#: Prop conventions in Godot axes (the prop scene's own frame); the grip transform puts that frame relative to
#: HandR/Socket (child Node3D of the Socket with this transform, or prop = socket * grip).
PROP_DOCS = {
    "phone": "phone 0.072 x 0.147 x 0.009 m slab: origin at its centre, +Y = the speaker end, the screen faces +Z, "
             "held to the right ear in phone_call / phone_seated (palm on the back, fingers up the phone)",
    "mug": "mug r 0.041 m, h 0.095 m: origin at the base centre, +Y = up the mug axis, handle toward -X; held around "
           "the body in the right hand (thumb on top); level in mug_carry_walk / mug_idle, tipped to the lips at `sip`",
    "mop": "string mop: origin at the floor end of the shaft (the head's centre on the floor), +Y = up the shaft (length "
           "{length} m), the right fist {r} m up the shaft (the socket, thumb toward the top), the left fist at {l} m "
           "(the HandL weapon-grip convention on the same shaft axes)",
    "book": "open book 0.30 x 0.23 x 0.022 m: origin at its centre, +Y = the top edge, the pages face +Z (toward the "
            "reader); right hand behind the right cover (thumb side over the edge), the left hand behind the left cover "
            "except during the page turn",
    "rag": "bar rag (a folded towel) 0.20 x 0.022 x 0.13 m: origin at the centre of its underside, +Y = up; flat under "
           "the right palm (fingers toward -Z), lying on the bar top in bartender_wipe",
    "bottle": "liquor bottle r 0.04 m, 0.30 m tall (mouth at +Y 0.30): origin at the base centre, +Y = up the axis; the "
              "right hand round the body 0.15 m up from its +X side (thumb up); bartender_pour stands it on the bar at frame 0 "
              "and from `set_down` on",
    "glass": "tumbler r 0.04 m, h 0.10 m: origin at the base centre, +Y = up; the LEFT hand round it from its -X side, "
             "standing on the bar for the whole of bartender_pour",
    "cash": "banknote stack 0.156 x 0.015 x 0.066 m (+X = the long edge, +Y = the face normal, Z = the short edge): origin "
            "at its centre; lying in the LEFT palm (palm on the -Y face, fingers along +X) in teller_count",
    "cigarette": "cigarette r {cig_r} m, {cig_len} m long (filter {cig_filter} m): origin at the filter (mouth) end, +Y = "
                 "toward the ember; between the right index and middle fingers (the filter out on the palm side), "
                 "its filter tip between the lips at each drag in smoke (D-115)",
}


def _npc_source(ctx, sk, keep: dict) -> None:
    """SOURCE.txt facts for the NPC ambient set (props at HandR/Socket, furniture and bed placement)."""
    import numpy as np  # noqa: PLC0415

    for prop, doc in PROP_DOCS.items():
        basis, origin = lib.prop_in_socket_godot(sk, prop)
        doc = doc.format(length=lib.MOP_LENGTH, r=lib.MOP_GRIP_R, l=lib.MOP_GRIP_L, cig_r=lib.CIG_R, cig_len=lib.CIG_LEN,
                         cig_filter=lib.CIG_FILTER)
        hand = "HandL" if lib.GRIPS[prop]["sfx"] == "L" else "HandR"
        ctx.source_extra[f"{prop}_grip"] = f"{_xform(basis, origin)} relative to {hand}/Socket; {doc}"
    ctx.source_extra["npc_seat"] = (
        f"sit_chair, desk_type, desk_work, phone_seated, sit_chair_watch: root on the floor under the seat centre, "
        f"facing the desk; seat top {lib.SEAT_H:.2f} m (pelvis on it, thighs level, feet flat 0.40 m ahead), desk top "
        f"{lib.DESK_Z:.2f} m with its front edge 0.20-0.25 m ahead of the root (keyboard 0.36 m ahead, mouse 0.27 m "
        f"right; phone_seated's note pad 0.10 m left; sit_chair_watch's joystick/mouse 0.21 m right, monitors ahead "
        f"from -25 to +25 deg)")
    bed = keep.get("sit_bed_read")
    if bed is not None:
        s0 = bed.frames[0]
        hips = float(s0.P["hips"][2])
        heel = max(float(s0.P[f"foot.{x}"][1]) for x in "LR")
        probe = anim.probe_for(sk)
        V = probe.posed(s0)
        back = V[(V[:, 2] > 0.15 * sk.scale) & (V[:, 2] < 0.6 * sk.scale)]
        by = float(back[:, 1].min())
        bz = float(back[np.argmin(back[:, 1]), 2])
        v = s0.P["neck"] - s0.P["spine"]
        rec = float(np.degrees(np.arctan2(-v[1], v[2])))
        ctx.source_extra["bed_pose"] = (
            f"sit_bed_read: the root is ON THE MATTRESS TOP under the pelvis (place it at the sleeping surface, e.g. a "
            f"0.55 m bed -> root at y 0.55), facing the foot end; hips joint {hips:.3f} m above the root, buttocks and "
            f"heels on the surface (lowest skin {probe.margin * 1000:.0f} mm above it), ankles {heel:.2f} m ahead "
            f"(mattress >= {heel + 0.25:.2f} m ahead of the root), trunk reclined {rec:.0f} deg on pillows/headboard "
            f"whose face meets the back {-by:.2f} m behind the root at {bz:.2f} m height")
    mop = keep.get("mop")
    if mop is not None:
        pts = np.array([lib.prop_frame(sk, s, "mop")[1] for s in mop.frames])
        ctx.source_extra["mop_sweep"] = (
            f"mop: in place, the head sweeps x {pts[:, 0].min():.2f}..{pts[:, 0].max():.2f} m, "
            f"{pts[:, 1].min():.2f}..{pts[:, 1].max():.2f} m ahead of the root (two sweeps per loop); keep ~1 m clear ahead")
    ctx.source_extra["idle_thug_weapon"] = (
        f"idle_thug: the long gun at HandR/Socket (the weapon grip convention), held low across the body: muzzle "
        f"{-lib.THUG_MUZZLE_PITCH:g} deg below the horizontal, turned {lib.THUG_MUZZLE_YAW:g} deg to the left; the left "
        f"hand loosely under the front of the receiver (0.19 m behind LeftHandIK), not on LeftHandIK")
    _rappel_source(ctx, sk, keep.get("rappel"))
    ctx.source_extra["mug_carry_walk_speed"] = (
        "mug_carry_walk is a careful carry at 1.3 m/s native (walk is 1.6); speed_scale = v / 1.3")
    _p5_source(ctx, sk, keep)


def _p5_source(ctx, sk, keep: dict) -> None:
    """SOURCE.txt facts for the P5 NPC set (D3-02): dance tempo, bar / counter / painting / seat / wall placement."""
    for key, text in p5.source_notes(sk, CLIPS, keep).items():
        ctx.source_extra[key] = text


def _rappel_source(ctx, sk, baked) -> None:
    """SOURCE.txt ``rappel_rope``: where the rope, the fists and the wall are relative to the root (Godot axes)."""
    import numpy as np  # noqa: PLC0415

    if baked is None:
        return
    row = CLIPS["rappel"]
    N, v = row["frames"], row["speed"]

    def grip(s, sfx):
        _r, t_off = anim.grip_offset(sk, sfx)
        return s.P[f"hand.{sfx}"] + s.W[f"hand.{sfx}"] @ sk.B[f"hand.{sfx}"] @ t_off

    def g(p) -> str:                       # Blender (x, y fwd, z up) -> Godot (x, y up, -z fwd)
        return f"({p[0]:.3f},{p[2]:.3f},{-p[1]:.3f})"

    s0 = baked.frames[0]
    gl, gr = grip(s0, "L"), grip(s0, "R")
    ball = max(float(s0.P[f"toe.{x}"][1]) for x in "LR")
    gls = np.array([grip(s, "L") for s in baked.frames])
    zl = np.maximum(gls[:, 2] - gls[0, 2], 0.0)
    rise = v * lib.RAPPEL_CONTACT / anim.FPS
    d = lib.RAPPEL_ROPE_D * sk.scale
    ctx.source_extra["rappel_rope"] = (
        f"rappel: the rope is a vertical line at Godot x=0.000 z={-d:.3f} (root space, {d:.2f} m in front of the root; "
        f"the character faces the wall, -Z). Fists (grip centres = HandL/HandR Socket origins, rope along socket +Y) at "
        f"frame 0: guide HandL {g(gl)} on the line, brake HandR {g(gr)} at the right hip ({gr[0]:.2f} m right of the "
        f"line: the tail runs from the descender at the harness through the brake fist, then hangs). Both fists ride "
        f"the body: 0..+{zl.max():.2f} m above their frame-0 height during the loop (the body is braked "
        f"for the {lib.RAPPEL_CONTACT} wall-contact frames, rising {rise:.3f} m against the root, then drops back). "
        f"Wall: the balls of the feet brace at Godot z={-ball:.2f} (frames 0..{lib.RAPPEL_CONTACT}, world-still at "
        f"speed_mps={v}); a free-hanging drop (skylight) just plays it without a wall. Root at the bottom of the link: "
        f"the feet are {float(min(s.P[f'foot.{x}'][2] for s in baked.frames for x in 'LR')):.2f} m+ above it")


def _proxy(ctx, arm) -> None:
    """1-triangle mesh skinned to ``hips`` so the exporter writes the skin + animations."""
    import bpy  # noqa: PLC0415

    from lib import scene  # noqa: PLC0415

    mat = ctx.material("char_skin_1", "#E3BFA3", roughness=0.55)
    me = bpy.data.meshes.new("AnimProxy")
    me.from_pydata([(0.0, 0.0, 0.95), (0.004, 0.0, 0.95), (0.0, 0.004, 0.95)], [], [(0, 1, 2)])
    me.materials.append(mat)
    me.uv_layers.new(name="UVMap")
    obj = bpy.data.objects.new("AnimProxy", me)
    scene.link(obj, arm)
    vg = obj.vertex_groups.new(name="hips")
    vg.add([0, 1, 2], 1.0, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def _check_rest(sk, arm) -> None:
    """The solver's rest matrices must match Blender's (align_roll) to 1e-5."""
    import numpy as np  # noqa: PLC0415

    for b in arm.data.bones:
        m = np.array([[b.matrix_local[i][j] for j in range(3)] for i in range(3)])
        if float(np.abs(m - sk.B[b.name]).max()) > 1e-5:
            raise AssertionError(f"rest frame mismatch for {b.name}")
