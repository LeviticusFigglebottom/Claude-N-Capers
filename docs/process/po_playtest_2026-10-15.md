# PO playtest list, 2026-10-15 (D-114): TOP PRIORITY for every env

Owner: LEAD. Each item has one **owner** (does the work, reports done) and optional **helpers** (do their slice when
the owner asks, by direct env-to-env message with the LEAD cc'd). Status lives on `docs/process/board.md`.
Verification is windowed (D-086): every visual/feel item needs a windowed screenshot or clip path in the report, and
the LEAD looks at it before telling the PO it is fixed.

Screenshot from the PO: `docs/process/po_shots/2026-10-15_gh_finger_gap_loot_outside_safe.jpg` (Golden Hour,
manager-office storeroom, loud wave 3, AR equipped).

## Golden Hour ("Vossberg Jewelers", `glasshouse`)
| id | owner | helpers | issue → spec | acceptance |
|---|---|---|---|---|
| PO6-01 | A | | **Drill needs placing twice**: the first interact plays the place sound but no drill appears; the second places it. Find the double-path (likely the interact completes the place SFX before the device state commits, or a first interact consumes the "take drill" step). One interact = drill placed + sound. | real-input test: one hold on DrillPoint → device visible, running, one SFX |
| PO6-02 | A | | **Jams too frequent.** D-114 §2: max 1-2 jams per standard drill, none in first/last 10 %. Tune `interaction_tweak` device_jams_* (and saw/thermal equivalents). | unit test on the jam schedule over 1000 seeds: mean ≤ 1.5, max 2 |
| PO6-03 | B | A (exposes progress/time-left if missing) | **No visible drill timer.** PD2-style world-space panel over every running device: time left (mm:ss) + progress bar, "JAMMED" state in red with the fix prompt. Also on the HUD objective line when the device is the current objective. | windowed shot of a running + a jammed drill |
| PO6-04 | A | C (safe/keypad markers, design doc) | **Stealth needs the drill → camera alarm.** D-114 §1: silent stealth route to the manager safe (code/keycard from the manager, lockpick fallback). Drill = loud path; drill noise = investigable noise, not an alarm. Check that cameras don't fire on the drill sound itself. | real-input stealth run opens the safe without a drill and without alarm |
| PO6-05 | A | C | **Loot is outside the safe** (stack of jewelry boxes on the floor in front of the safe, visible on entry, not pickable). Loot must spawn **inside** the safe, hidden/unpickable until the door is open, then pickable. Check every heist's safes/vaults for the same bug. | windowed shot of the closed safe (no loot visible) and the open safe (loot inside, pickable) |
| PO6-06 | A | D (poses) | **Hostages already on the ground on entry** in the manager room (civilians spawn in a downed/cuffed state without being intimidated). Civilians spawn standing/working unless a mission script says otherwise; find the bad spawn state. | windowed shot of the manager office at heist start |

## All heists: audio and pager
| id | owner | helpers | issue → spec | acceptance |
|---|---|---|---|---|
| PO6-07 | C | A (stop calls in pager/assault/alarm systems) | **Audio keeps looping** (pager beep, cop sirens, others). D-114 §3. Audit every cue in `world/audio` for loop flags; one-shots must not loop; any loop needs a stop owner (A's systems call stop on state end). List each looping cue + its stopper in the report. | test: every looping cue has a registered stop path; windowed/headless run shows pager beep stops after answer and sirens stop after assault |
| PO6-08 | A | | **Pager timer doesn't pause when picked up.** D-114 §4: countdown freezes when a player starts answering, ends on answer; releasing early resumes it (PD2). | unit test + real-input pager answer |

## Weapons, viewmodel, firing range
| id | owner | helpers | issue → spec | acceptance |
|---|---|---|---|---|
| PO6-09 | D | P (PFingerClip assert) | **Rifle support hand: a finger is detached from the hand** (screenshot: the support-hand fingers wrap the handguard top but there is a visible gap between them and the palm/wrist; fingers read as floating). Fix the weights/joint chain so fingers stay attached to the palm in every long-gun pose, then finish the existing grip work (Condor index, Bastion/Corsair thumb, in_progress.md §D1). | P's `test_p_finger_clip` hard assert green + lit close-up per long gun, no gap between finger and hand |
| PO6-10 | C | P (vm_light_probe) | **FP weapons render near-black** (carried over, in_progress §C2): coated finishes become dielectric. | probe: weapon mean luminance ≈ arms |
| PO6-11 | P | D (pistol clips if needed) | **Pistol hold and ADS look inorganic.** Two-handed pistol grip (support hand wraps the firing hand, isosceles/thumbs-forward), natural hip offset/cant, ADS pulls the sights to the eye along an arc with a little settle; sway/bob consistent with rifles. Pistol/revolver are in `left_hand_ik_skip_sets` today: that is part of why it looks one-handed. | windowed hip/ADS sequence for every pistol + revolver |
| PO6-12 | B | P (viewmodel swap API) | **Firing range is unfinished:** the gun model doesn't change with the equipped weapon and has no animations. Range must use the real player viewmodel path: equip/swap/reload/fire/ADS animations, the selected weapon's model and attachments. | windowed range clip: swap 3 weapons, fire, reload, ADS |
| PO6-13 | C | P (FP flash scale), B (brake mesh on long-gun glbs) | **Muzzle flash too dramatic** everywhere. D-114 §8: roughly halve flash size/duration/light energy (keep the class shapes), add a muzzle-brake/compensator mesh on rifles/LMGs/snipers/shotguns that the flash emits from (side ports). | before/after sheet FP + TP |

## AI, spawns, bodies
| id | owner | helpers | issue → spec | acceptance |
|---|---|---|---|---|
| PO6-14 | A | | **Bot crew can't carry bags thrown at them.** A bag thrown at/near a bot is caught (or picked up) and carried; bots follow and drop at secure zones on command/when near. | real-input test: throw bag at bot → bot carries it |
| PO6-15 | P | A | **Bot crew far too strong.** PD2 bots: low damage, slower reaction, accuracy falloff with range, can't solo assaults. Tune `crew_tweak` (P) and any crew AI shortcuts (A). Report before/after numbers. | solo-with-bots loud run: bots no longer clear waves alone (kill-share report) |
| PO6-16 | A | C (spawn points/breach markers per map) | **Horde pacing + room entry.** D-114 §5: continuous spawn to a force cap during sustain; units must push into rooms players hold (today they idle outside the GH manager office). Check nav/door handling for enemies (open/breach doors, path through doorways). | windowed loud run: cops enter the manager office within the sustain phase |
| PO6-17 | A | C (turret van, helicopter, breach geometry/props), D (rappel/rope anims if needed) | **RNG assault events:** turret van (armored van parks and deploys a turret), helicopter (circling, drops a rappel squad / sniper), breach points (marked walls/ceilings/windows cops blow open mid-loud). Data-driven per heist (HeistDef rows), GameRng stream `&"assault_events"`. Start with GH. | each event seen in a windowed GH run (seeded) |
| PO6-18 | A | D (death clips from crouch/kneel/prone/downed) | **Death animation stands bodies up.** D-114 §7: pick the death by pre-death pose; a cuffed/kneeling/prone/downed NPC dies in place. | test per pose; windowed shot of a hostage shot on the floor |
| PO6-19 | A | D (PhysicalBone sets on NPC skeletons), C (blood at hit point) | **Ragdoll / body propulsion:** explosions and close-range shotgun hits send bodies flying (PD2 "shotgunning"); corpses take small nudges and bleed at the hit point when shot. Physical-bones ragdoll on death with impulse; cap active ragdolls; settle into a static corpse after ~3 s for perf and net sync. | windowed clip: shotgun a guard point-blank, grenade a group, shoot a corpse |

## Carried over (still open, behind the list above)
In `docs/handoff/in_progress.md`: D SMG re-time (unblocks B's held branch), GN e2e flows (A), GN G2 art (C), SL/DB prop
art `wip/c-sldb-props` (C), `prop_saw_device` (C), ND gate 2 attempt 24 (A), D-113 FP flash wiring (P, now part of
PO6-13).
