# ENV P status (Playability)

Newest entry first. Owner: ENV P. Scope: D-076. D-077: commit every 20–30 min; this file says where to resume.

## To the LEAD: (updated 2026-10-23 18:15 UTC; r306-r309, D-167)
- **Resume here:** deck feel `--test=all` is on copycat (5/5) on the main checkout (`$S/dk/all.log`); the `--open`
  legs (lifeline, veil, buddy; `$S/dk/open_legs.sh`, logs `$S/dk/open_<deck>.log`) run in sequence. Report each
  deck's rows, one shot, and a PD2 judgement. Commit the captures under captures/deck_feel_2026-10-23/.
- **PO-21 / PO-22 / PO-23 CONFIRMED** windowed on trunk (r306 80ca7d568): no capture release held, mouse turns the
  camera; crosshair alpha 1.00 at the hip and 0.00 aiming down sights (ads_blend 1.0); before/after crop in
  captures/po_confirm_r306/. Hub stations 9/9 F.
- **AH-P1 loud (Routine) FULL PASS** twice; C's f5349e97 cleared HallDoorsE (keycard trip 47 s -> 13 s). Bag-carry
  STUCK rows were bodies in the firefight, not the map. Those runs used the default kit (harness bug below).
- **AH Hazardous fairness: read #4 is the done check, ACCEPTED: harsh but fair** (trunk 6f88db99f + A 01a29e29, seed
  6501): every row PASS to the carries; wave-2 wipe at t~361 from a full-cap special pulse (2 stingers + phantom +
  4 bulwarks) downing all three bots, then the pilot's bleed-out (D-167 as ruled). Reads #1 (tase / cloak chains:
  bots ignored a tasing stinger -> A 0585920d) and #3 (a Wrecker cuffed the downed pilot -> D-167) led to the fixes.
  A also fixed the SafeLoot bag inside the safe (ef468abe). Evidence: captures/ah_g1_2026-10-23/.
- **Harness bugs (mine), fixed:** loadouts were keyed on Net.local_slot() before any session (-1), so the deck / kit
  never applied (14dfbf204; the offline peer is already authority, so key off Net.crew being empty); the hacker
  result read EcmSystem's live dict (copy now); _in_custody() only saw the blown flow's signal (now the live state
  and an ENDED heist, ace97d1e8); danger rows lost the attacker positions (PackedStringArray copy, 9f4e6c591);
  carry rows blamed "A secure zone" for a carrier downed mid-carry (DOWNED now, d1d17fb12).
- **Deck feel so far:** hacker PASS (pocket ECM feedback, 1 of 2 near enemies stunned, 7 kills / 60 s). Lifeline,
  veil, buddy: the item works (ampule window 9.1 s 10/10 segments; smoke cloud at the feet; G tags the aimed bot)
  but the standing pilot was never hit (all damage on bot slot 3) -> `--open` legs; the zero-hits-on-human
  observation is with A as a target-selection check.

## To the LEAD: (updated 2026-10-23 10:00 UTC; D-165 Afterhours)
- **AH-P1 harness ready (waiting on C's greybox):** `game/tests/p/_review/ah_g1_pass.gd/.tscn` (extends rt_g1_pass).
  `--test=casing`: the civilian start, the whole front of house (D-075 set: guest doors open, the 4 staff doors answer
  ui.blocked.civilian), peak fill 0. `--test=stealth`: route 1 (gear -> east bar service door -> keycard + code note
  -> mask in G23 -> staff stair -> office keycard door -> keypad -> 3 bags to the van -> escape, no alarm).
  `--test=loud` [--build=loud]: gear + keycard, mask, a burst in the hall, office, drill (jams), the van's return, 3
  bags, escape. Positions from docs/design/heists/afterhours.md's grid; props found by type. Parse-checked; no
  afterhours map / HeistDef on trunk yet (r302).
- RT: throws 36/36 PASS (f1297cd19); c4 rerun: magazine C4 fetched, clean stop, T3 opened by C4 19 s after F;
  blown_confirm2 still running.

## To the LEAD: (updated 2026-10-23 09:40 UTC; trunk r298 merged)
- **Resume here:** blown_confirm2 (bag-race fix, worktree acore3, `runs_ac3/blown_confirm2`) is still running under
  llvmpipe (~70x); send the LEAD its bag count as a one-line delta. Then c4 rerun, traversal remainder, setup from the
  car park / underpass, toggle interact (B's interact_mode), OF ghost follow-up.
- **RT confirm (seed 4101, Hazardous, loud build, r291-equivalent):** clean PASS: T1 opened t=372.8, 3 bags at E1
  (legs out 25.9 / 22.9 / 22.8 s, back 19.5 / 18.3 / 17.6 s), then a wave-2 crew wipe at t=556 (longshots 80 per hit
  at 73 m). Blown: escort down +53 s, T1 opened t=294, 0 bags (harness race, fixed; rerun pending). Captures in
  captures/rt_g1_2026-10-22/d158c_*.
- **FP deck-item use pose DONE (r298, A's deck_item_used):** FpViewmodelDeck (`fp_viewmodel_deck.gd`, Action.DECK):
  injector / leech ampule stab to the thigh (cap off, serum drains), flask to the mouth (cap off), pocket ECM thumb
  press (LED blinks), gas dispenser point + canister press, smoke bomb thrown (pin at pin_pull@, gone at release@);
  then the gun's draw. test_p_fp_deck_item 2/2 (real input G for the ampule); windowed sheet
  captures/deck_items_2026-10-23/ (deck_items_capture.tscn).
- **Toggle interact DONE (B's interact_mode):** PlayerInput._toggle_interact: a tap of F at something usable latches it;
  a second tap cancels it (no shout); it drops when the session ends (done / moved or looked away) or none starts in
  3 ticks. test_p_toggle_interact 4/4 headless + windowed; core_loop 16/16, a404 5/5.

## (2026-10-23 00:30 UTC; trunk r284 merged; reports to session_01XAPqmFJ32zHKLK9Sezymym)
- **Resume here:** c4 (magazine C4 fetched in the setup, T3 by C4) and ambush_crash (mixer row, r280 mixer) are
  running. Then: sprint-cancels-reload (A's CrewWeapons.cancel_reload, r285/286), then the traversal remainder (throws,
  underpass, kerbs, escapes, fences, lift walk-in), then setup from the car park / underpass spawns. Runs go through
  scratchpad `rtrun2.sh <test>` (copies into captures/rt_g1_2026-10-22/<test>/ at the end). Never edit a wrapper a
  run is executing. Parse-check `rt_g1_pass.gd` with `--test=parsecheck` before every launch.
- **RT truck rows (r278+):** ambush_clean PASS, ambush_crash PASS, east_e1 PASS (HEAVY T1 -> E1), east_e2 PASS (HEAVY
  T3 -> E2, 40 m, 0 STUCK). breach: T1 placed saw on the SawPoint PASS (130 s, 1 jam), T2 thermite PASS (about 36 s
  burn). Magazine: the nav path ran through MagWallN (fixed by C, r282); loud, its padlock's place_saw failed at once
  (c4_loud_padlock/, diagnostic added).
- **Setup (real detection, human mask timing):** from the plaza, rig hacked at t=66 (84 s spare), but the gate guard
  (post_site_gate) hit 1.00 at the rig 0.2 s before it finished: FAIL. A ~20 s hack doesn't fit his loop from a plain
  wait (question to the LEAD / C).
- **Hazardous verdicts (kit corsair_ar + kestrel + heavy_vest + doctor bag, no skills; 3 AI bots):**
  - clean_haz: seen from T3's seated cab 1.5 s after the stop; all 4 down within 23 s at Pier-40 cover; custody;
    no truck. UNFAIR at Hazardous.
  - blown: escort down from cover 20 s after the crash stop (fair). Wave 1 lands 15 s after the stop; the pilot is
    Phantom-kicked 3 s after leaving cover for T1. BORDERLINE-UNFAIR.
  - The default kit (pistol + suit) runs were worse (blown_default_kit/, clean_haz_default_kit_partial/).
- **A4-04 skill hooks DONE (67b66fd3, round 285):** weapon.ads_speed_mult, movement.ads_speed_penalty_mult (new PD2
  ADS walk cap 0.53, humans only, LEAD: ungated), shoot_while_sprinting, reload_while_sprinting,
  sprint_any_direction; test_p_a404_skill_hooks 5/5 headless + windowed.

## (2026-10-22 18:40 UTC, D-153 handover)
- **RT-P1 harness: `game/tests/p/_review/rt_g1_pass.gd/.tscn`** (extends of_g1_pass; real input only). One ROW per item
  (PASS / STUCK / FAIL + owner) and rows.md per run. Traversal: stairs, ramps, lift, site, throws, underpass, kerbs,
  escapes, fences (`--test=all`). Truck phase: ambush_clean, ambush_crash, breach, east_e1, east_e2, setup
  (`--test=trucks`). Evidence: game/tests/p/_review/captures/rt_g1_2026-10-22/<test>/ (run.log, rows.md, PNGs).
- **Done on r273 greybox (seed 4101, Routine, windowed):**
  - stairs PASS: A and B ground -> Deck 2 -> roof -> ground, 0 STUCK; stair A to the roof with a MEDIUM bag.
  - ramps PASS: R1 + R2 up/down by straight W at 3.48 m/s, with a HEAVY bag at 1.75 m/s, no snag.
    **One STUCK (C bake):** with the HEAVY bag, Deck 2 south -> R1 top pinned 2x on `Strip2GuardW2`'s south end at
    (42.8, 3.5, -19.7): the nav corner (42.5, -26) hugs the guard closer than the crew's 0.35 m radius.
  - site PASS: man-gate padlock (lockpick), through it, FrameLadder up/down, a bag refused on it (S10.1b), the
    scaffold stair up/down with a MEDIUM bag.
  - lift: car floors flush at all 3 landings (+0.001 m). **Finding (C content):** GoodsLift `car_size_m` is 2.2 m
    deep in a 3 m car room, so a 2nd bag thrown in rests against the back wall at z -49.6, visibly in the car but
    not counted or carried (OF's CashLift had the same). Walk-in rerun pending (harness now opens LiftDoorG).
- **Truck-phase facts from code (r275), to confirm by run:** the mixer does nothing (`_mixer_move` swaps
  `mixer_gone` / `tannery_open` layouts that don't exist; SiteTanneryGateW/E stay BARRED); no C4 pickups on the map
  (C4Box1/2 are TODO(A5-03) markers), so C4 needs a pre-plan item.c4 drop.

## (2026-10-21 23:45 UTC)
- **D-152 ack: OF done.** Now on Rolling Thunder: preparing `rt_g1_pass` (from of_g1_pass) for the G1 windowed/real-input pass (traversal,
  interact sweep, the ambush stop, the truck breach, the mixer, the escape, STUCK/snag rows); it runs once A's pilot plays RT end to end.
  OF ghost evidence and route note stay below for the record.
- **OF ghost, time box result (23:25 UTC): no continuous run reached the escape. Step-wise evidence below for your D-151 call.**
  Steps 1-5 pass unseen in ONE continuous run (haz_zd). Step 6's sub-moves each pass unseen; lift cycle 1 (bags 1-2 staged in LD, the
  lift back down) passes unseen in ghost6_m, ghost6_t and ghost6_u. Cycle 2 dies the same way in ghost6_t and ghost6_u: bag 3 going out
  at t≈1004. The run starts with the vault guard deep in RC (≥ 25 m by path). 15 s later he is back east down BB and meets the gate → CQ
  dash. **Not a game/AI bug; a margin problem.** On Hazardous seed 1002 his loop (b)/(c) absences are ~30-40 s, every ~200 s
  (ghost6_u_r263/vault_guard_positions.txt). A bag out needs ~20-25 s of BB clear, gate to CQ, plus rover_basement's sweeps (every
  20-40 s). Six bags means six such windows in a row. If you want the line harness-provable on Hazardous: lengthen the vault guard's
  loop (b) RC dwell (as you offered C/A for rover_basement), or stage the bags in VT and run fewer crossings. Route note for the GPU
  box's human check: ghost_route_note_hazardous.md. A full run needs ~2.5 h wall, so none fits before 02:00.
  r272 (76b3ae401): C's cash-lift fix confirmed by real input (`--test=liftdoor`, liftdoor_272: 2/2 plain door throws land in the car);
  step 6 uses the plain throw again and the low-throw workaround is gone. Last attempt running on r272: out-trips also need the vault
  guard not closing on the gate.
- **OF ghost on Hazardous, seed 1002, trunk r263 (67260f0b): step table**:

  | step | pass run | heist time | evidence (game/tests/p/_review/captures/of_g1_2026-10-20/) |
  |---|---|---|---|
  | 1 lane | haz_zd | t=33.0 | ghost_haz_zd_r263/run_excerpt.txt |
  | 2 dock | haz_zd | t=200.5 | same |
  | 3 keycard (manager shouted from the WC hide, tied unseen) | haz_zd | t=357.2 | same |
  | 4 code (pc_exec hack) | haz_zd | t=466.4 | same |
  | 5 vault (gate, lasers, code, time lock in CQ's corner) | haz_zd | t=1483.8 | same |
  | 6 bags | partial: bags 1-2 VT → cash lift → staged by LD's personnel door unseen (2/6, t=398), back down and the lift recalled (t=424; ghost6_m). ghost6_t/u: cycle 1 again (2/6 staged t≈825-832, lift back t=892), then bag 3: the vault guard back down BB at the gate → CQ dash (t≈1004, both runs). Debug `--test=ghost6`, a SHORTCUT start at CQ | 115-585 s per bag, ~230 s per lift cycle | ghost6_m_r263/, ghost6_t_r263/, ghost6_u_r263/ |
  | 7 lift, throw, escape | not reached yet | | |

  Route note for the steps not yet reached (positions, cues, timings, what failed), per the LEAD's fallback:
  game/tests/p/_review/captures/of_g1_2026-10-20/ghost_route_note_hazardous.md (for C to fold into the design doc, which P doesn't own).

  No game/AI bug found in steps 1-6 so far: every failure was harness timing or route choice. Minor content notes for C: CashLift's car count
  box is 2.2 m deep in GL's 3 m room, so a bag thrown in from the door rests against GL's back wall just outside it (the harness throws low
  from 3.2 m back instead); the LK partitions are already fixed (bbe1c600).
- **Latest (r260 ghost, Hazardous, seed 1002):** steps 1-3 pass (haz_o/haz_p: dock t≈208, keycard t≈343). haz_p then FAILED at t=355:
  guard_radio by rover_basement with no DETECT on the pilot (hidden at (1.7, -4, 4.1)), most likely because he saw the tied manager in LockerDoor's
  sight line (a tied civilian is a `restrained` stimulus: 15 m, LOS). haz_q waited for him to leave BB's sight before shouting, and he saw the
  pilot in the LK hide from LockerDoor at 5 m and ran to rover_basement (alarm t=352). NPCs see all round within 1.5 m and ~120° wide at 5 m,
  so no open LK spot hides from him. Fix: lkprobe now also samples his walk to his WC stop (ManagerLKWC (7.25, 2.2), 40-70 s). (8.5, 0.5),
  behind WCPartitionLK2, is the one floor point hidden from his walk and from BB. The pilot waits there and shouts once he's dwelling. haz_r: the pilot stuck 60 s on WCPartitionLK2. **For C (minor):** the LK navmesh
  runs through both WC partitions (they aren't in the bake), so nav paths into the cubicles go through the partition. The harness now goes
  round its open end (8.7, 2.3) first. haz_s: hidden all the way, he reached his stop unaware (t=341.5). The pilot stood and stepped out
  at 1.7 m, he filled 1.0 at once and ran (a panicking civilian only goes down on a 50% roll), and guard5 cuffed the pilot in BB (t=363).
  Now the pilot shouts from the hide: the all-round shout reaches a civilian within 6 m by a navmesh path, without LOS. It ties him once
  he's down (blind), after rover_basement is away. lkprobe also found every point on his walk is seen by at least one BB eye at lying
  height (the WC stop by 1, west of LockerDoor). **haz_t: steps 1-4 PASS** (keycard t=367: shouted DOWN from the hide on the first tap,
  tied unseen; code t=529). Step 5: the BB → gate wait ran 300 s (t=642-946) with no window (vault guard on VC or rover_basement in BB), then
  cleared on attempt 2 at t=981. Gate, lasers both ways, code entered t=996.5. The pilot then walked to the RC time-lock wait and met the vault
  guard coming back from his loop (b) through RC (radio t=1008). Now it waits out the time lock in the LK hide, crouched, and peeks before
  each leg back. haz_u: same path to t=1000.8, then the vault guard came out of RC (6.6, 10) heading for the gate while the pilot held in BB at
  (13.8, 8.2), standing in his walk (radio t=1021). Now the time-lock refuge is CQ's SE corner (12.5, 3.5): lkprobe says no BB corridor
  point (x 0-47) sees it, and CQ's door is 2 m from the gate, so the pilot goes there at once. **From haz_v on, runs are on r263
  (67260f0b, with C's partition fix).** haz_v (r263): step 2 FAIL with no alarm. All 5 smoke windows were skipped: the queue-rail bake fix moved
  rover_hall's loop (LD checks now t≈11, 96, 185, 269, 361, 449), and at every smoke cue (78, 149, 259, 317, 401) he was on BC at x 31-34
  walking back to LD, 9-36 s from his check. Now at a cue with him heading in, the pilot lets his LD check pass inside that smoke window
  (≤ 25 s), then goes, as r260's passing run did by luck. Walkers block only while closing on the corridor door. **haz_w (r263): step 2 PASS at t=183.6** (window 1 skipped: he was still inside LD at t=104 when the 25 s
  ran out; window 2 taken). Step 3 alarm at t=185: done 24 s sooner, the pilot stepped out of SA into BB as the vault guard walked down BB on
  his loop (b) (seen at 7.7 m). Step 2 had no stair peek (the stair waits are step 4+), so step 2 now ends on SA's basement landing and waits
  for BB (12 m, walkers 15 m). haz_x: same to t=183, then waiting on the B landing behind SA's door, the vault guard walked east down BB
  past the door and saw the pilot at 2 m (t=189). lkprobe: SA's half landing (14.5, -2, 2) is seen from no BB or BC corridor point; the
  pilot now waits there. **haz_y (r263): steps 1-3 PASS** (dock t=192, after a 10 s half-landing wait; keycard t=357). Step 4 alarm at
  t=388: the LK → SA leg waited on the B landing for rover_hall on G, and rover_basement walked past SA's door and saw it at 1.5 m. That
  phase-2 wait is now on the half landing too, and it climbs straight up from there (it used to step back out into BB). **haz_z (r263): steps 1-4 PASS** (dock 192, keycard 357, half-landing wait 26 s, code 466). Step 5 alarm
  at t=515: coming down from E, the pilot stepped out of SA into BB with the vault guard walking BB 9 m off (the upper-floor core check
  doesn't count BB). The descent to B now waits on the half landing too. haz_za: steps 1-4 again, then the half-landing core check let the vault guard
  through: standing in BB 6.5 m off, no LOS to the core. He saw the walk to LK (t=519). Both half-landing → BB waits now use a BB rule:
  no basement guard in BB's strip west of x 32 or within 6 m of SA's door, two samples running. haz_zb: BB clear on the half landing at t=181-183, but the vault guard was just inside RC's door. He stepped out
  into BB as the pilot reached the foot of SA, and step 3's "not clear" walked the pilot down BB to the LK hide past him (t=185). Now the
  BB rule counts RC's front (x < 14, z < 14), and step 3 backs up to the half landing instead of walking BB. **haz_zc (r263): steps 1-4 PASS again** (BB wait 17 s after the dock,
  dock 199.5, keycard 357, code 466). Step 5: BB was clear at t=517.5, then the vault guard walked out of VC into BB 5 m off as the pilot came
  down (t=520). Now VC walkers count (his VC post standing doesn't). Every descent into BB shares one helper: half-landing wait → foot of SA →
  back up if any basement guard is within 10 m (up to 4 tries). **haz_zd (r263): steps 1-5 PASS**, the first Hazardous run through the vault:
  dock 200.5, keycard 357, code 466. The foot-of-SA check backed up once (t=519), then the gate: attempt 1 aborted (rover_basement 6 m),
  then two 300 s waits with no gate window (t=599-899, 899-1199). That's the "no BB window on Hazardous" data the LEAD asked for. It went
  on the last attempt (code entered t=1214, time lock in CQ's corner, vault open t=1484). Step 6 alarm at t=1489: after the time lock the
  vault guard was back on his VC post (25.6, 11.0), 4 m from VT's door, and the first bag trip walked into him. Now every VC crossing
  waits for his loop (b) (in from CQ's corner, out with the bag from VT's blind corner (24.5, 20.5), lkprobe) with no other guard in VC
  or within 15 m of the gate. 6 bags = 12 such windows. Steps 6-7 are being debugged with `--test=ghost6` (a SHORTCUT start at CQ: debug
  only, not the acceptance). **Also: ladder step-off soft-lock fixed (cb8be306d, ENV A confirmed ND 1001 PASS).**
- **Ghost on Hazardous per D-150** (trunk 9f90a3f4 + P; harness default is now Hazardous, `--diff=` overrides; 5ec63837). haz_a: step 1 PASS. Step 2: after the
  dock door, the pilot opened DockCorridorDoor (LD → BC) with rover_hall standing 1.7 m behind it. Harness: wait inside LD, 3 m back, until BC is clear.
  haz_b: the corridor-door wait held, but rover_hall's loop (b) then walked into LD and found the pilot waiting there. So now the pre-lockpick
  'LD occupied' check also counts guards within 10 m of DockCorridorDoor, and that smoke window is skipped (≤ 4 tries). haz_c: the same path
  (deterministic); he was > 10 m off at the cue but 6 m off once the pilot was in, after ~15 s of mask + ECM + lockpick. Now 20 m at the cue, and
  a 10 m re-check right before the lockpick. haz_d: the 20 m radius caught the lobby guard at his hall post (10.9, 0, 21.8), and every smoke window
  was skipped. Now only the BC/LD side (z < 12) counts. haz_e: smoke windows at t≈78, 285, 430, 544 were all skipped, two of them by a posted guard
  standing at (19.5, 0, 1.1) (the Cataclysm runs walked past that spot). Now within 20 m only walkers count; standing guards count within 8 m of either
  door. haz_f: the pre-checks passed (rover_hall was still in the hall, z > 12, at the cue), then he came through BC into LD again and found the pilot
  waiting inside (t=111, as in haz_b/c). Now when BC isn't clear, the pilot backs out to the lane beside the dock door (6, 0, −1.5), not inside LD.
  Ghost runs from here on are on r260 (3a3885ad), per the LEAD. **haz_g (r260): waiting outside works.** rover_hall did his LD check (t≈108-118)
  and missed the pilot beside the door. But by then the smoke window had ended, and rover_dock walked back and saw the pilot (t=139). That window
  was never real: now the cue check also tracks rover_hall by tag (heading for DockCorridorDoor from ≤ 25 m means a loop (b) LD check → skip),
  and the corridor-door wait counts building-side guards only. haz_h: he was only flagged at the late re-check, 24 m out heading for LD, after mask + ECM
  were spent, and the run followed haz_g's path. Tracking radius is now 35 m so the cue check catches him. haz_i: the same. He turns toward LD between
  the cue (t=78) and t=83. Restructured step 2 into one loop per smoke window: cue → LD clear → lane clear → mask → LD clear again → only then the
  ECM and lockpick; a busy LD at the second check keeps the ECM for the next window. haz_j: that second check (~t=80) came 1-3 s before he turned
  (~t 81-83). Now there's a 5 s watch after the mask, sampled every 0.5 s, before the ECM (the 20-40 s smoke window leaves ~10 s of slack). haz_k: the watch caught
  rover_hall heading for LD (t=82) and kept the ECM, but the pilot then waited for the next window MASKED behind the dumpsters, and rover_dock walking
  back from his smoke saw it at 14 m (t=118). The mask can't come off, so the 5 s watch now runs before the mask (unmasked in the public lane).
  **haz_l: the harness is right, but no dock window on Hazardous seed 1002 (sent to C).** rover_dock's smoke windows: t≈78-118, 162-195, 285-322,
  347-385, 429+ (every 85-120 s, 33-40 s long). rover_hall's loop (b) LD check falls inside 4 of the 5 (t=82 heading in, in LD ~108; 285 in BC;
  348 / 430 heading in). Window 2 (t=168, him at 34 m east) may have been a false skip. After 5 windows: FAIL _g2_dock (no alarm). The dock
  step has the same two-patrol clash as BB. C asked for window numbers: these are they. **C's answer (ostrander_federal.md 8c034cdb):** rover_hall
  isn't random. A's hub_loops cycle him (a) TW/hall → (b) LD check → MO → (c) stair B / fire exit, so go in a smoke window only once he has LEFT LD
  for MO (east, x > 40, two loops from the next LD visit). Harness: a watcher records his LD visits; a window counts only if his last LD check was
  ≤ 90 s ago and he's now at x > 25. haz_m: he spawns into loop (b), with an LD check at t=11, so at the t=78 window he was on loop (a) at (35.3, 11.5) and
  came back to LD at t=96 into the pilot. Timing alone can't tell the phases apart (both windows ~67 s after a check); position can: east now = x > 38
  and z < 9.5 (BC corridor east = MO / loop (c)). **haz_n: step 2 PASS on Hazardous (t=207.7)**, C's cue working: the t=78 window was skipped
  (rover_hall on loop (a)), the t=162 window was taken (him at BC east), and he passed DockCorridorDoor at t=185 while the pilot waited outside, unseen.
  Step 3: the manager wait was still at GHOST_LK_WAIT (in LockerDoor's sight line), and rover_basement saw it through the door (t=267). Now step 3 waits
  crouched in the probed LK hide too. **haz_o: steps 1-3 PASS on Hazardous** (dock t=207.7 again, keycard t=342.7). On the way to step 4, the BB-only core
  check cleared at once, then rover_basement came west down BB and saw the LK → SA walk at 12 m (t=350). That BB crossing now uses the gate's window
  (rover_basement in RC or far east, no walker closing in). haz_p is running. If no window turns up in ~6-8 min, C will put a Hazardous patrol change to
  the LEAD and A with the numbers.
  The BB window log (count/lengths) will go here for C if step 5 finds no window.
- **Ghost §5 design question (needs C/LEAD).** On r256/r257, seed 1002, Cataclysm solo: steps 1-4 PASS every run. Step 5's actions work unseen once the
  pilot is at the gate (swipe, lasers, time lock code; r256b/c). The blocker is crossing BB from LK to the gate. rover_basement sweeps BB x 5-35
  every 20-40 s; the vault guard's only long absence is loop (b) RC (~30 s); Cataclysm's extra guards (Npc_guard7/9) walk BB east. In r257d no
  moment in 300 s had both the vault guard and rover_basement away. Is §5 meant to be timed on Cataclysm with these patrols? If yes, rover_basement's
  loops may need a longer away leg (A/C). If no, which difficulty should the ghost acceptance use? I'll keep iterating the harness meanwhile.
- **GAME BUG FIXED (P's own, 0d0a1ab0): crew capsules were shared.** crew_member.tscn's CapsuleShape3D sub-resource was one shape for every
  crew member. Whenever anyone crouched, all the others' capsules shrank to 1.2 m under their 0.9 m standing offset, and they sank 0.30 m into the
  floor (until that crew member stood). Found with a watchdog in GH Tense 4502 (C showed the kerb itself is only 0.15 m and clean): at t=11.8,
  17.0, 21.3 and 63.4, every grounded crew member dropped exactly 0.30 m in the same move_and_slide. Embedded, the 0.15 m kerb became a 0.45 m wall,
  so the r255/r256 early STUCK-and-downed. It hits humans in co-op too. Fix: each crew member duplicates its shape in _ready. New
  test_crouch_does_not_sink_other_crew fails before (shared shape, 1.20 m, y −0.299) and passes after; test_p1_01_ground 13/13. **Please put it in
  the next round;** I'll re-run GH Tense ×3 on it.
- **OF loud interact sweep DONE, no failures** (windowed, r255 e9c8744f + P, `--test=interact`, captures/of_interact_r255). **BondSafe: a player CAN
  use it.** The crosshair lands on it from the UsePoint at 1.43 m and the hold STARTED (lockpick; place_drill OK). GPU-15's 'aimed <none> at 2.22 m' means that
  pilot stood further back than the UsePoint gives, so it's the pilot's stand, not the safe. STARTED (6): PresidentSafe 0.92 m, BondSafe 1.43 m, Hoist
  send_lift 0.74 m + LandingPanel1 call_lift 0.76 m, CashLift send_lift 1.09 m + LandingPanel1 1.01 m. Gated by design: LidDrill aims
  correctly at 1.51 m but is `ui.blocked.requires_item` (drill parts); the 40 Hall/Vault deposit boxes are saw-opened (take_loot is enabled after the
  cut); TimeLockConsole is disabled because the shortcut opened the vault door. The vault door itself was not swept (the shortcut opened it).
- **GH Tense on r257 (70471c50, with the capsule fix): 2/3 WIN, downs 1/3/3, median 3**, still over the D-145 target (≤2). The sink is gone (the pilot never
  goes below the road, y ≥ −0.1), and so are the t≈82 downs (first downs t=270/275/131). What remains is loud difficulty plus pilot snags in A's
  auto_loud pilot (9-10 STUCK per run: the stairs at (9.9, 0, 5.0) toward a point 4.4 m up, Bulwark shields). The bots now move differently, so
  each run's path differs from r256. Your call: is median 3 on Tense with this pilot acceptable, or a tuning ask for A? Table: tense_r257/.
- **GH Tense on r256 (3312326b + P): 2/3 WIN, downs 2/3/3, median 3**, still over the D-145 target (≤2). The Longshot cap/timing didn't bring
  it back to r251's median 1. 4502's first down is still very early (t=82 vs ~245 on r251; on r255 t=79), so whatever moved it is in r255, not r256.
  4502 won with the pilot in custody. Suspects (LEAD): the nav-cap lift (cops path differently) or the GPU-17 hitch regression.
  **Cause of 4502's early down: a GH map snag, sent to C.** The pilot is STUCK ~15 s at the street (21.5, −0.4, 0.3) under fire, heading to a nav corner on
  the sidewalk (20.7, 0.2, 0.8); its knee rays hit Glasshouse …/Ground/PellSidewalkW_N. The navmesh steps up a curb the capsule can't. The snag is on r251 too
  (2× STUCK at t≈188), but since r255 the loud route reaches it at t≈86 (4-5× STUCK). Fixing the curb (C) should bring 4502 back.
  Table + tense_r256/ in captures/d145_gh_2026-10-20.
- **GH Tense on r255 (e9c8744f + P) is harder: 2/3 WIN, downs 3/3/2, median 3**, which misses the D-145 target (≤2). r251 was 2/3 with median 1, and
  all 3 won with A's revive fix. First downs come much earlier (4502: t=79 vs ~245 on r251). Per the LEAD, the Longshot cap is not in r255, so the
  suspects are the nav-cap lift or the GPU-17 hitch regression. I'll re-run ×3 on r256. Table: captures/d145_gh_2026-10-20/table.txt + tense_r255/.
- **Ghost with A's guard_vault loops** (r255 + a-core 46551745 + P). r255a: steps 1-3 PASS. Then the vault guard now walks BB (loops (b)/(c)), and
  rover_basement saw the LK → SA walk at 8 m (t=109) after a 4 s core wait that ignored BB's own guards. Harness: leaving the basement, the pilot waits
  crouched in the probed LK hide and counts BB's guards (≤10 m standing, ≤15 m walking). r255b: counting every floor at once, the busier loops
  never cleared in 180 s. Now it's two phases: BB only from LK, then a ≤60 s peek up the flights from the foot of SA.
  **r255c: steps 1-4 PASS** (BB clear 16 s, flights 6 s, code done t=202.6, ~50 s faster than r252/253). Step 5 failed on the way out:
  rover_gallery came up SA and dropped out of the count the moment he reached the Executive floor, and the pilot left E3 into him. Now
  same-floor guards within 25 m count for every ghost floor change. **r255d: steps 1-4 PASS again, and the E3 departure held 96 s and went
  unseen.** Step 5: the pilot arrived (~t=303) inside the vault guard's 4 s pass-through window (A's probe: he opens it at t=299.3, and it auto-closes
  and stays locked after 4 s). So it was a tailgate, not a bug (A confirmed; since r256 an NPC open doesn't complete [vault_gate]). The harness had skipped its
  gate wait because is_open was true, and walked into him. Harness: the gate wait now runs whether it's open or not. **Ghost now on r256** (3312326b + P).
  r256a: step 1 PASS. Step 2: guard timings shifted on r256 (smoke cue t=88 vs 66), and rover_hall (Npc_guard3) stood in LD 5 m inside the dock door
  when the pilot lockpicked it (doc: rover_hall loop (b) checks LD). Harness: a smoke window with a guard in LD is skipped for the next one.
  **r256b/c: steps 1-4 PASS, and step 5's core works**: gate swiped with the keycard (t=505), laser crossed, code entered at the time lock (t=513),
  laser recrossed, all unseen. Both runs were then seen leaving: the vault guard had only been on BB's east leg, 13-20 s from the gate. Harness: wait
  until he's deep in loop (b) (RC, x < 12 or z > 13.5; in r256c that leg ran t 347-377). r256d: steps 1-4 PASS. He made two RC trips (t 347-377 and
  557-597), but both windows were held by Cataclysm's extra BB guards walking x 28-36 (counted within 20 m with no LOS). Walkers now count
  within 12 m, or within 20 m with LOS. r257a (r257 70471c50 + P): steps 1-4 PASS, and the gate cleared after 36 s on the vault guard's first RC trip.
  rover_basement, out of LOS east at that moment, turned back west down BB and saw the pilot at the gate (t=358). Now walkers within 20 m that are
  closing on the gate count too (doc: 'rover_basement is east'). r257b: the same failure (he was likely standing in SD, out of LOS, when the wait cleared).
  No snapshot rule predicts that, so now the pilot walks LK → gate in legs (BB west, the core, the gate), peeks before each one, and retreats
  to LK if a guard shows up (≤ 4 tries). r257c: the peek caught rover_basement coming back down BB at 12 m, but the retreat runs west along the
  same straight 48 m corridor and he filled 1.0 anyway. His positions (r256d/r257c) show him sweeping BB x 5-35 every 20-40 s; his only long stops
  are RC (blind aisles per doc) or far east at SS. Now the gate window also requires rover_basement in RC or past x 36. **r257d: steps 1-4 PASS. Over
  ~700 s of waiting in LK there were 3 windows (t≈784, 986, 1006); each closed within 3-4 s at the first peek (vault guard/rover back, or guard9
  on BB east), and the pilot retreated unseen each time.** After the 4th try the harness goes anyway and was seen (harness give-up, not a finding).
  At Cataclysm the BB-crossing window is effectively absent with these patrols. See the design question above.
  **If this doesn't hold, my read is that at Cataclysm (extra BB guards + rover_basement's short loops) the doc's step-5 window is very
  tight. I'd then like a design call (C/LEAD) on whether ghost §5 is meant to be timed on Cataclysm, or at a lower difficulty.**
- **Ghost line**, on r251 + c-worlds 9d00c55b + P, windowed, seed 1002: **steps 1-4 PASS** (r251g). C's door-throat bake fix is verified.
  Harness fixes on env/p-play: peek at the SA core before EA → E3; code-hack restart. Step 5 (vault gate) was seen by the vault guard;
  the gate-clear wait went in at 88e06f40. r251h: the wait held for the vault guard, but the pilot waited in BB and rover_basement
  walked down BB and saw it. r251i: it waited in LK (doc §3), but at (3, −4, 4), in line with LockerDoor, and standing; rover_basement
  passing BB at 6 m filled the meter. r251j: the NW corner (0.8, −4, 6.2) snapped through the wall to BB (0.8, −4, 7.5), and the pilot pushed
  into the wall for 60 s until rover_basement saw it. Harness only: it now picks the first LK corner that snaps onto the navmesh within 0.4 m,
  and waits there crouched. **Ghost runs now use r252** (e91fa3c0 + P). r252a: steps 1-4 PASS again. The chosen corner (0.9, −3.8, 6.3) was
  a bench-top navmesh island 0.2 m up, the path ended in BB again, and the pilot was seen. Now the candidate must be at floor height and
  the nav path must end on it. r252b: no corner passed (LK's navmesh sits at y −3.8, so the 0.1 m height check was wrong). The pilot fell back to
  (3, 4) and was seen through the door, crouched. New headless probe `--test=lkprobe`: it samples LK's floor navmesh and ray-checks 8 BB eyes.
  (1.5, 4.0) and its neighbours are hidden from all 8, while (3, 4) is seen by 2. Hide set to (1.5, 4.0).
  **r252c never ran**: my edit in 426f0bf9 cut ~45 lines (GHOST_RC_WAIT, GHOST_CQ_AT, GHOST_LD_STAGE, EXPECT) and the script failed to parse.
  gdlint passed (it doesn't resolve identifiers), and the window hung for 70 min. Restored in the next commit and parse-checked by a headless
  load (lkprobe PASS, 0 script errors). From now on I parse-check every harness change headless before a windowed run.
  **r253a** (trunk f35ccb81 + P): steps 1-4 PASS. The LK hide (1.5, 4.0) works: 300 s crouched, unseen (one 0.16 tick). **Step 5 is blocked by a GAME
  gap, sent to A**: GuardTweak.hub_loops has no guard_vault entry. The doc's post_vault loops (b) BB→RC→BB and (c) BB→SD→BB→CP→BB never
  happen, so the vault guard only shuttles VC (25.6, 11) ↔ (19, 11) every ~30 s and the gate never clears. The doc's 'vault guard on (b)/(c)'
  window doesn't exist in the build. The pilot went after 300 s and was seen at the gate. Next ghost run: on the round with A's guard_vault loops. A headless ghost run cannot work (the pilot's mouse needs a window).
- **GPU-box ghost command**. It needs `game/tests/p/_review/of_g1_pass.gd` from env/p-play (≥ 88e06f40), which is newer than trunk's:
  `git checkout origin/env/p-play -- game/tests/p/_review/of_g1_pass.gd`, then
  `%G% --path game --resolution 1280x720 res://tests/p/_review/of_g1_pass.tscn -- --test=ghost --seed=1002 --out=%CD%\gpu\renders\p\of_ghost > gpu\renders\p\of_ghost_run.txt 2>&1`
  It is only useful once my r251h result is in; I'll say here if it passes.
- **OF §7 G2: 10/10 PASS, accepted by P** (GPU box, origin/gpu/renders b538099a, C final 3c9b2fdf): laser ×4 (default + lz_static/lz_sweep/
  lz_timed, each confirmed forced), throws, fire_escape, hole, dock, fire_exit, burn. 0 script errors and no real stalls (the 'STUCK rows 0' lines are
  summaries). The burn/hole alarms are the harness going loud on purpose (the hoist is loud-only). **One GAME bug, sent to A**: a camera
  disabled via GameplayPrefab.set_enabled(false) still observes. SecurityCamera.can_observe() ignores prefab_enabled, so in throws
  'CameraC9 disabled' at t=2 raised the alarm at t=35.9 (in G1 too). The fix is one line in A's file; it also matters for cameras placed with
  enabled_at_start=false. **A fixed it in env/a-core 3dbea1c4** (can_observe requires prefab_enabled; new test_s8_1_disabled_camera_sees_nothing; test_s8_ 31/31).
- **D-145 GH**: Tense on trunk r251 is 2/3 WIN, median 1. The 4501 loss is fixed by A's e640362d (passes on a-core 441b6870); please merge it.

## 2026-10-21: GH Tense ×3 on trunk r251 (c04cb710), pointer to A's GPU-box lines
- **GH Tense ×3 on pure trunk r251**, headless, solo + 3 bots: **2/3 WIN, downs 1/2/1 (median 1)**, the same as on 4a6780f4 (the seeds are deterministic).
  4501 has the same no-revive bleedout (pilot down t=249, custody t=279). r251 lacks A's e640362d (bot revives from ≤2.3 m), and
  4501 PASSES on env/a-core 441b6870 (A's run). **Merge e640362d and all 3 seeds win.** Table: captures/d145_gh_2026-10-20/table.txt, tense_r251/.
- **Ghost on r251 + c-worlds 9d00c55b + P** (windowed, seed 1002). C's door-throat bake fix (a9fc8631) **works**: the pilot leaves
  EA cleanly, with no STUCK (the r250 stall was the AssistantDoor west jamb vs a throat 5 cm off-centre). Steps 1-3 PASS. Step 4: rover_gallery
  (Npc_guard4) came up SA at t≈151 as the pilot crossed the core EA → E3, and filled 1.00 at 3.5 m. Harness fix: peek at the core
  (same-floor guards included) before EA → E3, per doc §4 ('wait in E3 while rover_gallery passes').
  r251d: the peek held 17 s while guard4 passed east. Then guard4's loop turned back west down XC (z 8) and saw the pilot walking to E3 at
  13 m. r251e: LOS isn't enough (guard4 was in a side room at the check), so any same-floor guard within 25 m now holds the crossing.
  **r251f: no alarm through step 4** (peek 88 s while guard4 looped; at E3 unseen at t=243). It failed on a harness bug: the PC use
  predicate `state != IDLE` passed on INTERRUPTED, so 3 'restarts' did nothing. Fixed (restart only when needed, also during
  the peek).
  **r251g: steps 1-4 PASS** (code hack done t=254, no alarm; first time past step 4). Step 5: the vault guard Npc_guard2 in VC
  (25.6, −4, 11.0) saw the pilot open the vault gate at t=363. The harness never waited for the doc's 'vault guard off VC' window,
  so step 5 now waits for the gate to be clear (no guard within 8 m, or within 20 m with LOS). After the alarm the pilot STUCK 25 s at
  (30.0, −4.0, 11.4) on SlabB_00; it goes to C if it recurs before an alarm. r251h re-run in progress.
  Evidence: captures/of_g1_2026-10-20/ghost_251c.
- A's GPU-box command lines (OF stealth/loud real-menu, OF Haz feel clip) and open items are in docs/status/env_a.md (top) on
  env/a-core. A's replies to the lead fail with the same trusted-device error. P's lines are in the entry below.

## 2026-10-20 (late): GPU-box command lines for the LEAD (P still cannot send_message the lead)
Run from the repo root in cmd.exe; `G=godot\Godot_v4.7.2-stable_win64_console.exe`. Every run is windowed (no
`--headless`, no xvfb). `--out` / `--po5-out` take an absolute path; `%CD%` keeps it inside the repo so the box can
commit `gpu\renders\p\...`. Without the flag, of_g1_pass writes to `user://of_g1_pass` and po5 to `user://po5`.
Capture names are Windows-safe since c6c096dd (PCaptureName); trunk's of_g1_pass differs only by that wrap.
1. **OF ghost line** (Cataclysm solo, seed 1002). It needs trunk ≥ r250 (A's hub loops b7052ebd), which trunk already has:
   `%G% --path game --resolution 1280x720 res://tests/p/_review/of_g1_pass.tscn -- --test=ghost --seed=1002 --out=%CD%\gpu\renders\p\of_ghost > gpu\renders\p\of_ghost_run.txt 2>&1`
   It writes PNGs to that dir; the verdict is the `[OFP] RESULT` line and the `GHOST step ... done` lines in the run txt.
   On a FAIL, the window keeps running after RESULT. Close it once RESULT is printed.
2. **D-145 GH Tense feel clip** (~5 min loud, solo + 3 bots). It needs A's env/a-core 4a6780f4 (Tense tuning) and
   2daa35d6 (po5 harness) on trunk first; neither is on trunk at 59a2924b. Better: take env/a-core 441b6870, which adds
   e640362d (the bot no-revive fix from Tense 4501) and 441b6870 (Cataclysm past the menu).
   `%G% --path game --resolution 1280x720 --fixed-fps 30 --write-movie %CD%\gpu\renders\p\gh_tense\clip.avi res://tests/a/e2e/po5_runner.tscn -- --po5-flow=auto_loud --po5-out=%CD%\gpu\renders\p\gh_tense --po5-budget=300 --po5-heist="Golden Hour" --po5-difficulty=Tense --po5-seed=4502 > gpu\renders\p\gh_tense_run.log 2>&1`
   (Create `gpu\renders\p\gh_tense` before the run, because the movie writer does not make dirs.) Seed 4502 was a WIN on 4a6780f4
   headless. For Routine, swap in `--po5-difficulty=Routine --po5-seed=4501` and a `gh_routine` dir. The .avi is MJPEG and large;
   transcode before committing, or commit only the PNG steps and log.
3. **OF §7 G2 pass**: same harness, one run per test, after C says G2 is final:
   `%G% --path game --resolution 1280x720 res://tests/p/_review/of_g1_pass.tscn -- --test=<t> --seed=1002 --out=%CD%\gpu\renders\p\of_g2_<t> > gpu\renders\p\of_g2_<t>.txt 2>&1`
   with `<t>` = laser, throws, fire_escape, hole, dock, fire_exit, burn. Run laser three times, adding
   `--pattern=lz_static`, `--pattern=lz_sweep` and `--pattern=lz_timed`. If G2 needs harness changes, P pushes them first and names the commit.
- **Ghost line on r250 + c-worlds 18239f73 + P** (windowed, seed 1002): steps 1-3 PASS again (lane 29.7 s, dock 62.1 s, keycard 10.8 s).
  Step 4: the stair-core wait worked (clear after 18 s) and CodePC started at t=146. Leaving the assistant office, the pilot was STUCK for
  about 15 s at (18.8, 8.6, 6.1), walking into a low wood panel toward the nav corner (18.8, 8.8, 6.6). Velocity was 1.4 m/s with no displacement and
  no probe-ray hits. Npc_guard4 (gallery hub loop) walked up and filled 1.00 at 1.9 m (alarm guard_radio t=166). This looks like a navmesh/collision
  mismatch at gallery level, so it is C's. Sent to C; evidence in captures/of_g1_2026-10-20/ghost_250. A headless ghost run can't work
  (mouse capture needs a window): the pilot never moves.
- **OF full real-menu run PASS** (lead queue item 6), windowed via `run_po5.sh of_stealth 1002`, Routine, on r248 + c-worlds + A + P. It clicked main menu → SAFEHOUSE →
  planning table → Ostrander Federal/ROUTINE → briefing → pre-planning → loadout → Start Heist → stealth heist → payday
  ($112,303, clean, 7:35) → back in hub; 14 shots in captures/of_menu_2026-10-20. The flow sets crew.stealth_hidden (a detection
  shortcut), so this proves the menu path and the objective chain, not stealth. The 10-34 s HITCH frames are xvfb software GL.
- **D-145 GH Tense ×3** on r250 + c-worlds + A 4a6780f4, headless, solo + 3 bots: **2/3 WIN, downs 1/2/1 (median 1)**.
  The target is met (Routine was already 3/3 WIN, median 1). In 4501 the pilot bled out 30 s after one down with no bot revive (slot 1 tased),
  which is a bot revive-priority question for A. Table: captures/d145_gh_2026-10-20/table.txt + tense_4a6780f4/.
- Relay from A, 23:55 UTC: OF real-bot hard runs (headless auto_loud through the real menus, crew damage ×1.0, solo + 3 bots, a-core head).
  Haz 0/3: seed 5 custody at 603 s (after drill, burn-through and the vault in/out); seed 1 custody at 287 s. Cata 0/2: seeds 5 and 6 downed at
  t≈18-20 s (auto_loud goes loud at t=6 from spawn), custody 1-2 s later. A's reading: OF loud at ×1.0 is not winnable on Haz+ with this
  pilot + bots; the LEAD decides intent (PD2 DS) vs a tuning ask. A confirmed the 1-2 s Cata custody is bleedout drain: state 1→5
  direct (no CUFFED 4, no tase). The harness pilot fires from the floor on Haz+, which makes it a legal target (L2.5), and ~12 police at Cata
  damage empty the 100-point pool in ~1 s. A human holding fire would be cuffed (revivable) instead. A offers ~15 min: pilot holds fire
  with 4+ enemies in range, for a fairer Cata read. LEAD's call. A is running the hit-grace-on-Haz+ comparison (GH 4501, Haz/Brutal/Lethal/Cata, grace on vs off).
- Relay from A, 23:52 UTC: GH Tense 4501 on env/a-core 441b6870 (headless auto_loud, solo + 3 bots) PASS. The pilot went down once and a bot revived them.
  Bot downs 0/0/2, 3 bot revives. So all 3 GH Tense seeds now have a win on A's current head (with P's 4502/4503 on 4a6780f4).
- Relay from A, 23:45 UTC: env/a-core is at 441b6870. e640362d (GAME, bots): a bot in REVIVE that stops closing in for 1 s now
  revives from up to 2.3 m. A body or prop had kept bots at 2.1-2.2 m vs revive_range 1.2 m in Tense 4501. The new test
  test_l6_1_ai_revives_over_an_obstacle fails without the fix; test_l6_ 14/14 and d134/a3_05/give_way/p1_sandbox/d145_bot_regen are green.
  8aea4ae3: the pilot climbs ladders like a player via P's free climb (OF Haz 5 had stood 15 min at the hole).
  test_po5_special_visuals now launches on Hazardous. 441b6870: Cataclysm gets past the menu (the resource cache lost the in-memory unlock).
- Relay from A (could not reach the lead): env/a-core is at 2daa35d6. auto_loud no longer reports "marker unreachable" when the objective
  ended mid-walk (7b91a005). auto_loud fetches the OF drill parts a DrillPoint is owed (bcafd612; Haz seed 5 had stalled
  1100 s). po5 opens build-locked Lethal/Cataclysm in memory (2daa35d6). OF hard so far: Haz 5 FAIL (drill stall),
  Haz 1 FAIL (custody 287 s), Cata 5/6 did not start (menu lock); re-runs queued on A's side.

## 2026-10-20 (evening): OF §7 G1 complete, ghost steps 1-3, D-145 GH, lead unreachable
- **Lead unreachable from P since ~22:50 UTC** (send_message: "needs proof of a trusted device"); A hit the same.
  Undelivered relay from A: D-145 Tense tuning on env/a-core 4a6780f4 (hit grace 0.45 s / bots 0.35 s on
  Routine+Tense; TAC Light + Stinger 8 dmg on Tense, 6 Routine; TAC Light 80 HP, Patrol/Security 40; tase downs after
  10 s; bot regen 25 %/s after 3 s). P runs GH Tense x3 on r250 + c-worlds + 4a6780f4 (running).
- §7 G1 (of_g1_pass, seed 1002): laser x3, throws, fire_escape, dock, fire_exit, burn, hole: all PASS; PO-3 snags 0.
- Ghost line (Cataclysm solo): steps 1-3 PASS since r246 (smoke-pause cue, A's pilot corner fix, lambda fix); step 4
  caught by rover_gallery (Npc_guard4) on SA. A's gallery/hall hub loops (b7052ebd) are on r250: re-run queued.
- D-145 GH (headless auto_loud, real menus, solo + 3 bots): Routine 3/3 WIN median 1 down; Tense 0/3 on every A fix so
  far (latest: all legit custody after 3 downs / crew wipe; 4501 pilot stall at (7.9, 0, 5.0)). Evidence:
  captures/d145_gh_2026-10-20/.
- Ladder free-climb + run bob confirmed on trunk r245 (captures/feel_r245_2026-10-20).
- Running: OF real-menu of_stealth + 2 GH loud clips (windowed chain), Tense x3 on 4a6780f4 (headless).

## 2026-10-20: OF-P1 resumed (D-144): burn/hoist PASS on C f385a22c + A 6f70122a
- Tree: local trunk 8ed5fa93 + env/a-core + env/b-content + env/c-worlds + env/d-art + env/p-play (b12118ca, not
  pushed; round 245 not on trunk yet). of_mission 15/15, p_ladder 5/5 headless.
- of_g1_pass --test=burn, seed 1002: run 1 FAIL rope ladder down (harness: pre-D-145 ladder driving), run 2 FAIL rope
  ladder up (harness: the facing-side approach is inside the hoist shaft once the car is up), run 3 **PASS**: lockdown,
  parts at (14, 0, -4), both parts on the lid (54.7 / 65.4 s HEAVY), burn-through 367 s (1 jam), rope ladder 4.00 m
  down 1.8 s, bag into the hoist car (24.0, -4.0, 15.3), hoist ride to landing 1, ladder up 2.4 s, take-out at
  (25.0, 0.0, 14.7). Evidence: captures/of_g1_2026-10-20/burn_r3 (burn_r2 = the shaft stall).
- Harness fixes (env/p-play 8b9822ea, 5d8c0091, 787a6a11, 94d24396): free-climb ladders (look up / down + W,
  CrewLadderClimb on the ladder counts), stray watch reads the real attach state, approach side with a knee-clear nav
  path, `_lift_to` landing from the stand (C's diagnosis). A fixes `_use_stand` per landing (8d486d5c, pending push).
- Open to C: the nav path ran through Hoist/Rig/ShaftE at (24.6, -3.9, 15.4) (shaft walls not in the nav bake?).
- Next: ghost line (running), the rest of §7 + PO-3, real-menu run, G2 pass, D-145 loud runs (12).

## 2026-10-17: D-135 close-out: ND-2 stealth route, SL-P1 PASS, D-128/D-130 feel check, DB-P1 (carried)
- ND-2 (nd_stealth_route, seed 21, Routine, trunk r236-r239): the stealth route runs clean to the vault and through one
  lift trip. Fast mode (render loop + HUD canvases off between shots) took the run from ~80 to ~3 wall-s per game-s.
  The route: lot -> grate -> ladder -> B3 mask; gate guard knifed on his walk west, out of C6's view through the
  gate bars (folding knife loadout; the earlier "30 of 50" hits were the gun bash, A); pager; body bagged into the janitor
  closet (BODY_HIDE); keycard + code via RecordsDoor; vault gate; C6 shot from inside the gate; laser bypass gap;
  60 s time lock (x4 stated shortcut); bags: B1 hatch throw into the cash lift, send to G1, ladder out, sally door
  (lockpick), C4 shot, unload, van. A pilot hook shouts down and ties a civilian who starts noticing (the L-ground cleaner
  walks B5 at t~505 and pressed the alarm button in 3 runs). Trip 1 secured 2 bags in run 20. The last runs ended at
  the B1 approach (navmesh route through LockerRoomDoor pins the pilot at (12, -4, 5.1)); now corridor waypoints.
  No full 4-bag win yet -> carried. Logs: tests/p/_review/captures/nd2_route_2026-10-17/run*.txt.
- D-128 reality on ND: <= 2 m uncover is instant (PlantDoor), 3-4 m in view fills in ~1 s; C6 sees B5 through the
  vault-gate bars at x 14.4-17; crouched cameras lose you beyond ~9.7 m (DR 4).
- SL-P1 (sl_pass seed 13): PASS in stealth on the G2 map (round 232, t=373); every bag secured on the first throw (C's
  full lift-car zone). Stair B half-landing ramp row fixed by C (confirmed on r237). New on r237: doorway stalls (SL
  SecurityDoor, ND LockerRoomDoor / InspectionWestDoor) and "blocked by StairBGate" with a path that never crosses it:
  C probed the maps clean -> A's pilot door rule (45706c9e). captures/sl_p1_recheck_2026-10-17, sl_p1_confirm_2026-10-17.
- D-128/D-130 feel check (GH, d128_feel.tscn): fill times within ~2-5 % of A's PD2 formula at DR 4 (guard 4-5 m 1.13 s,
  C4 5 m 3.89 s both difficulties, decay 1.17-1.23 s); civilians uncover at once; careful crouched route clean on
  Routine and Lethal; Lethal: pagers_max 2, titan C4 survives 6 rounds; Routine C3 breaks. SL camera: C4 11.8 m standing
  3.1 s, crouched never. No deviations for A or B. captures/d128_feel_2026-10-17/d128_feel_results.txt.
- DB-P1 (db_pass seed 1792194538, r236): snag tour 28 legs: all OK except the mezzanine count-room doorway (16.5, 3.6,
  5.1; the pilot door rule) and two 30 s leg timeouts on 35 m+ legs (harness); loud to t~427: breach t=74 (A's fix),
  cartel t=120; then the thermite bag re-pickup read "disabled" and the run was stopped for the D-135 cutoff -> carried.
- Tools: AnimCoverage FROZEN needs two identical comparisons in a row (A 2b97d701); flash_check.tscn (PO-7).

## 2026-10-16 (evening): pistol hip levelled, D-126 secondary shotgun, ND stealth route
- PO pistol hold: `set_hip_rot_deg` pistol / revolver (14, 3, -4) -> (-2.5, -8.5, -3.5), akimbo (-1, -1, -4). The hip
  bore now matches each gun's ADS pitch (within 0.2 deg) with a 2.8 deg inward yaw; before it was 14.5 left and
  +10..11.5 up. Evidence and table: game/tests/p/_review/captures/pistol_level_2026-10-16. Guard: test_p_pistol_hold:test_hip_bore_level,
  which fails on the old values. Still one-handed (D-116) pending the LEAD's answer on the support hand. Thumb wrap: D.
- D-126: test_p_secondary_shotgun (mule_12 secondary) is green 3/3 for swap both ways, reload, ADS on axis, and a
  downed draw + fire. 94f5d219 had a parse error, fixed in 340a8f81. The tests now fire after the 0.45 s equip timer;
  the VM settles a few frames earlier, and a pump needs a fresh press (PD2).
- ND stealth route (seed 21, lot + vent preplan): the vent, ladder and B3 mask went clean, and PlantDoor and
  LockerRoomDoor opened. Three held-melee swings from behind did not kill the unalerted gate guard (alert 0, t=47).
  Next: check the knife damage vs guard HP before rerunning. The run is about 48 wall-s per game-s under load.

## 2026-10-16 (night): GN-P1 rerun, ND stealth coverage, D's one-handed reloads
- GN-P1 (gn_pass.tscn, real menus, seed 1792002290, env/p-play 5b9d681e): stealth casing tour unmasked; last call
  warning t=439, Public -> RESTRICTED + 4 patrons leaving at t=484, guest stayed to t=535 with detection 0.00 (not
  spotted this time, round 187 was); loud at t=538 (guard_radio). STUCK (harness, A): po5_flow_auto_loud `_pick`
  puts `hack` first because `_has_path` routes through the closed CODE ServerDoor (`server_door` drill is active);
  pilot re-pressed the Argus terminal through the wall for t=597..1143, out of ammo (pilot never reloads); run killed.
  Errors: `unknown weapons id weapon.npc_rifle / npc_pistol / npc_sniper` x46 on assault spawns
  (anim_driver.refresh_weapon -> npc_weapon_models.weapon_def). Observer: CREW_STACK 8 (t=544-588, AI inside the
  player while following upstairs), then spacing 2.5 m. Anim: 123 moving clips, no static / no_clip / mismatch;
  frozen crew_ai walk_bl / walk_fr, civilian tased; slides tac_heavy breach_standback, rappel_descend (heavy, light),
  longshot heli_door_idle. test_p_gn_traversal 8/8. Evidence: captures/gn_p1_2026-10-16/.
- ND-2 close-out (A's auto_loud, Nightfall Depository, seed 1002, real menus, trunk ad54b5fe): blocked at the
  basement VaultGate: the pilot stands on the ground floor right above it and re-presses through the slab
  (po5_pilot.gd:326 Door branch near-check is horizontal only); routed to A. captures/nd2_2026-10-16/.
- Scoped ADS (LEAD 2026-10-16): FpScopeOverlay (vignette + duplex / mildot / chevron / dot reticle, sways with the
  look-lag spring + breathing), gun + ocular hidden at full ADS, B's is_scope / scope_reticle(_color) fields;
  test_p_scope 3/3; captures/scope_2026-10-16/. Laser readability bump (D-118). PO6-18 re-shot (game time): PASS.
- GN-P1 loud rerun on A's 04f79b18 (scratch merge 9f629838, gn_pass, seed 1792002290, 4800 s budget): stealth to last
  call t=486 again; loud from t=540: server door, keycard, server code, hack (restart), treasury + art store t=985,
  centrepiece t=1017, 1 painting secured t=1056; then "Cut one more listed canvas" with the pilot outside the
  BronzeDoorsE leaf (STUCK x4 on LeafBody2 at (22.3, 30.0)) and 1200 s "waiting at canvases" -> budget FAIL.
  STUCK rows: StaffDoor (recovered after 8 s), StudioDoor (closed, no prompt, lockdown-barred? 80 s+), BronzeDoorsE
  leaf. captures/gn_p1_2026-10-16/loud2_*.
- nd_stealth_pass (budget 180): civilian_call went loud at t=53 before any intimidate: 28 clips, no slides; the
  intimidation / pager / bag clips unexercised -> new `--intimidate-first` mode (dae0680f): rerun went loud at
  t=51 again (guard_radio right after the first shout; the tie kind was wrong, `cable_tie`, fixed).
- stealth_clip_coverage.tscn (new, unit map, real input): tied 2 (3rd: requires_item, PD2 2 ties), knifed 1,
  pager answered 1, body bagged / carried / thrown 1; civilian lie_down + tied moving, no frozen / slides /
  no_clip (captures/d111_cov/stealth_clip_coverage_2026-10-16.*). Knife from 1.3 m flat behind the guard misses
  (4 swings, 0 hits); 0.8 m one-shots -> test_p_knife_reach (red until A's fix, 57713e0f).
- PO6-15 re-check on trunk 6c8083c8 (bot_strength_probe, glasshouse, passive human, 240 s): bot kills 15 / 17 / 15
  (was 21 / 16 / 16 on A's wiring), acc 0.87 / 0.81 / 0.83 (was 0.3-0.5) on fewer shots (92 / 156 / 81), dmg/hit
  14.5 / 9.1 / 14.0; every crew member down by t~100 and in custody by ~140 (unchanged). No retune.
  captures/po6_15/r225_*.txt. Knife reach green with A's 9f3e7480 (scratch merge).
- stealth_clip_coverage + C) guard domination (skill forced) + D) loud cop surrender (chance forced) + tie: all 8
  steps pass. Guard kneel_cuffed reads right. Police: `surrender` one-shot ends and the player stops (PLAYER_MISMATCH
  driver 'surrender', player '', FROZEN); after the cable tie the cop stands upright, hands in front (no kneel).
- D 107b16dd one-handed reloads (scratch merge): test_p_pistol_hold 3/3; Kestrel reload in frame, Marshal eject
  hand too close (palm across the top third, forearm wall): captures/d116/reload_107b16dd/. motion_clip `--reload-only`.

## 2026-10-16 (later): D-118 gadgets + vgrip, D-119 dark guns, ND spawn view, GN ladder test
- D-118 gadgets (d8e8dbe6, f901e122): PlayerInput intent.gadget = just_pressed(gadget_toggle); FpViewmodelGadgets
  (systems/anim/fp_viewmodel_gadgets.gd, world-space next to the crew): laser beam + dot from the apparent LaserOrigin,
  SpotLight3D flashlight (no shadows, spot_angle = gadget_light_angle_deg as a half-angle, same as A's 3P) from
  LightOrigin; Muzzle fallback; reads CrewWeapons.gadget_on (A 348daa39, verified on a scratch merge), local fallback
  via the intent edge otherwise. B's rail_combo: beam leaves the lens (Kestrel under-barrel, Corsair side rail).
  Tests test_p_gadgets; tools gadget_capture (--mods). Evidence captures/d118/.
- D-118 vgrip (73d76f04): vertical-grip mod -> left-hand IK on the mod's LeftHandIK at D's wrist offset (weapon axes
  -> marker axes), fingers from <set>_vgrip_hand frame 0, hand orientation vs the weapon from that clip (HandRestore).
  test_p_vgrip (skips until D's clips are on the branch); D approved the contact.
- D-119 (PO): viewmodel gun fill off by default (72ed6d48; code + gun layer kept); with C's finish revert the guns are
  near-black again (captures/d119/black_gun_vs_reference.png).
- ND spawn void (b4155aa5): the four CasingSidewalk spawns face a wall 1.0 m away (C's layout PLAYER_SPAWNS); routed
  to C with a fix + tests/p/_review/spawn_view_probe.tscn (other heists fine).
- test_p_gn_traversal ladders (6edd7798): AreawayLadder is gated by its grate (A b25c8dc5); the test opens it first.
- nd_stealth_pass coverage running (~60x slower than real time on llvmpipe); GN-P1 pass next.

## 2026-10-16: D-116 one-handed FP pistol / revolver + organic motion (with ENV D)
- One-handed FP: one_handed_fp_sets [pistol, revolver] skip the left-hand IK; LeftArmHide drops upper_arm.L out of view
  (eases back for the reload clips). D's clips (env/d-art up to b65aeb04: one-handed, re-seated grip
  FPSet.grip_adjust). P owns the runtime framing (agreed with D): hip offset (0.025, -0.015, 0.05), rot pitch 14 /
  yaw 3 / roll -4 about the firing hand; ADS eye relief +0.08 pistol / +0.05 revolver. Hip vs the FNV ref: muzzle
  (62 %, 58 %) vs (61 %, 58 %), grip (73 %, 89 %) vs (72 %, 88 %). ADS: back of the hand + thumb under the gun, no
  sleeve. set_ads_rot_deg (rotation about the AimPoint) exists, off.
- Organic motion (all weapons): bob on the camera's footstep phase (figure-8 + roll/pitch, x1.6 sprinting), sway on an
  underdamped spring (3.2 Hz, 0.55), landing dip + pitch on the arms; breathing / recoil spring / ADS arc + settle as
  before. Tests: test_p_pistol_hold (D-116), test_p_po13_hold (overshoot, footstep bob; windowed).
- Evidence: tests/p/_review/captures/d116/side_by_side_refs_glasshouse.png (5 guns), side_by_side_refs_unitmap.png,
  kestrel_p9.mp4 / marshal_357.mp4 / corsair_ar.mp4 (idle, turn, walk, sprint, jump-land, fire, ADS in/out).
- Next: D-118 gadgets (waiting on the LEAD's gadget_toggle InputMap action + CrewIntent field), nd_stealth_pass
  coverage (~1 heist s per wall min here), D-115 GN-P1 windowed pass.

## 2026-10-15: D-111 coverage re-run (GH loud), PO6-11b / smg pairing, fill fade
- D-111 anim_coverage (gh_loud, seed 1792097579, trunk r213-era + P): 56 distinct clips (was 30 of 102). All five
  "never fired" rows from 2026-10-14 now fire: hit_react_left/_right (+ hit_react; _back not seen this run),
  walk/run start/stop, 8-way walk_*/run_* (crew + police), death_side / death_back_b / death_front_b, crew
  crouch_idle / crouch_walk. STATIC 0, SLIDE 0, NO_CLIP 0, FROZEN 0, PLAYER_MISMATCH 0. Not exercised by this flow:
  intimidation (surrender / hands_up / tied / kneel_cuffed / cower_stand), pager_answer, drill_place (the human
  placed the drill), bag carry clips. Flow FAIL is harness/nav (A): after the first bag at 681 s the pilot
  "could not reach WorkshopSafe/SafeLoot" (loot inside the safe since PO6-05). JSON:
  tests/p/_review/captures/d111_cov/gh_loud_2026-10-15.json.
- faa90a79: D's PO6-11b pistol/revolver grips merged; the IK targets moved to D's fitted wrists. 3f9d34f6: smg grip.
- e245d85a / 294c7c03: gun fill hip 0.7 -> ADS 0.45 (probe: off 36.5, 0.45 54.4, 0.7 62.6, 0.85 67.0; arms ~93-97).

## 2026-10-15: PO6-09 pair, PO6-15 on A's wiring, GN-P1 re-run
- PO6-09 (c9d2c012, with env/d-art 6524e268): D's long-gun grip offsets; test_p_finger_clip hard-asserts <= 2 mm.
  Deepest support-hand skin inside the gun, hip/ADS: Corsair 0.0/0.0, Bastion 0.8/0.8, Mule 0.8/0.8, Anvil 0.6/0.8,
  Condor 0.9/0.8, Reaper 0.9/0.9, Shrike 0.9/1.0, Brute 0.7/0.7 mm (r192: thumb 4-12 mm).
- PO6-15 on A's env/a-core b9133590 (scratch merge, shipped defaults): bot kills 21/16/16 in 240 s (4-5/min, was ~9.4),
  ~14 dmg/hit, every crew member down/custody by t=100-140 s in all 3 seeds. Accepted by the LEAD; trunk re-run when
  A's batch lands.
- GN-P1 re-run (gn_pass.tscn, seed 1792002290, trunk r211 + P): last call warning t=439, Public -> RESTRICTED t=480;
  loud objectives progress (lockdown, find_canvases, keycard, server_code, centrepiece, secure -> 1 at t=954).
  CREW_STACK now transient (38 observations over ~450 s, never the same spot for long; was one 0.01 m stack for
  300+ s). Harness only: A's pilot still gives up on legs through the casing-blocked ArtDoorEG, and circled a
  bag_loot 27 m away after t=954 (the `use` re-press finds nothing aimed); stopped there.

## 2026-10-15: PO6-10 viewmodel side (gun fill light), PO6-12 asks
**PO6-10:** CrewView.VIEWMODEL_GUN_LAYER (1 << 21) on every mesh inside the FP WeaponVisual (not the arms); a
camera-attached DirectionalLight3D `ViewmodelGunFill` culled to that layer (FpViewmodelTweak.viewmodel_gun_fill_*:
energy 0.85, warm-neutral colour (1, 0.96, 0.9), specular 0.6, euler (-20, -15, 0)). vm_light_probe --fills (Glasshouse,
Corsair, opengl3, with C's dielectric finishes c7a99c64 merged in a scratch worktree): weapon / arms mean luminance
fill 0: 36.5 / 89.5; 0.85: 66.8 / 92.2; 1.0: 71.4 / 92.2; 1.5: 83.0 / 92.5; 2.5: 100.4 / 89.6; 4.0: 120.7 / 90.8 (arms
unchanged: the fill never reaches them). 1.0 read cold/plastic with the earlier bluish colour; 0.85 warm chosen.
Test test_pp_p11_viewmodel_fov.test_gun_fill_light_only_lights_the_gun.
**PO6-12 (B asks):** CrewView.refresh_weapon applies the loadout weapon finish on the FP gun; FpViewmodel.play_draw().
Test test_p_range_vm_api.

## 2026-10-15: PO6-15 bot tuning (P side) + PO6-13 FP flash wiring
**PO6-15:** CrewTweak "AI teammates" group (PD2 team AI preset): ai_damage_mult 0.4, ai_reaction_time_s 0.8,
ai_shot_interval_s 0.45, ai_head_aim_chance 0.05, aim error 0.15 m + 0.025 m per m of range, engage 30 m.
**Read by ENV A's code** (CrewWeapons.damage_at, CrewAiBrain scan/aim/fire): the wiring is a patch for A,
tests/p/_review/captures/po6_15/a_wiring.patch (prototyped locally to measure, not committed by P).
Probe tests/p/_review/bot_strength_probe.tscn (Golden Hour loud, 3 bots, passive human, 240 s, 3 seeds; raw lines in
captures/po6_15/): before 36 / 38 / 39 bot kills (~9.4 per min), 0-1 downs, police held at 9-12;
after 11 / 13 / 12 kills (~3 per min), 13-14 hits per kill -> 14 dmg per hit, every crew member downed, the crew
collapses during the first assault sustain (~100-140 s) with a human that does nothing. Mid setting (0.5 / 0.6 s /
0.02 per m) gave 16-26 kills and held the first assault in 2 of 3 seeds (rejected: still carries the start).
**PO6-13 (FP side):** FpViewmodelFx passes the set's class to C's MuzzleFlash (flash_class_by_set), fp_scale(true) once,
burst_end() burst_end_after_s (0.25 s) after the last shot; P's muzzle light halved (energy 1.25, 0.034 s). FP size
stays vfx_muzzle_size: C's scene is already ~0.6x (SIZE_K) and 2 frames (env/c-worlds e9e3b96e), so no double cut; the
flash sits at the `Muzzle` marker, which B moves to the brake face. Test test_p_d105_fp_fx (new
test_flash_class_fp_scale_and_burst_end). Evidence: captures/po6_13_fp_flash_before_after.png (windowed, top = trunk
scene, bottom = C's e9e3b96e scene; Corsair, Kestrel, Mule, Anvil, Heron; shot frame).

## 2026-10-15: PO6-11 pistol hold + ADS (session_01VxQPFh6PypoyUxg94gmMGH, new LEAD session_01XAPqmFJ32zHKLK9Sezymym)
**Done (PO6-11):**
- Cause of the "one-handed / inorganic" pistol: the pistol / revolver clips' idle and ads_idle share the finger pose
  but their left arm chains differ by 25-38 deg, so the FK crossfade swung the support hand ~45 mm off the gun (the
  fingers read flat beside the slide mid-transition), and pistol/revolver were in left_hand_ik_skip_sets.
- Fix (FpViewmodelTweak + FpViewmodel): pistol / revolver back on the left-hand IK with their per-set grip offset =
  the clip's own wrist in LeftHandIK space (measured identical at hip and full ADS on all 4 pistols + the revolver),
  so the IK is a no-op at the end poses and holds the isosceles two-hand grip through the blend;
  `left_hand_hold_rel_sets` keeps the hand's orientation from hip / full ADS during the blend.
- New tunables: `set_hip_rot_deg` (hip pose about the firing hand: pistol/revolver pitch 4 / yaw -2 / cant 3),
  `set_ads_arc_roll_deg` (7 deg roll arc into the sights), ADS settle spring (`ads_settle_hz` 4.5, damping 0.45,
  `ads_settle_pitch_deg` 7, all sets; returns on axis: test). Pistol hip raised (grip y -0.149 -> -0.109 m; it sat on
  the bottom edge), ADS eye relief 0.42 -> 0.37 m. Sway / bob are the shared rifle values.
- Test: tests/p/test_p_pistol_hold.gd (real input; wrist sampled post-IK in skeleton_updated: Kestrel 48.9 mm /
  Marshal 26.9 mm off before, < 10 mm now). Review tool: tests/p/_review/ads_seq_capture.tscn (hip, walk, 8 frames in,
  3 out; prints grip / aim / bore angles / wrist-in-marker).
- Evidence (windowed opengl3): tests/p/_review/captures/po6_11/ (before_* / after_* hold sheets, closeups, per-weapon
  hip->ADS->hip sequences for kestrel_p9, warden_45, wren_380, sparrow_mp, marshal_357 + corsair_ar reference).
- Open (D, clip-side): at full pistol ADS the two sleeves still fill the lower third (the clip's forearms rise steeply
  to the gun); a lower-elbow isosceles ads_idle would read better. Not blocking.

## HANDOFF 2026-10-14
**Branch head:** (this commit, on env/p-play) the handoff notes on top of 69211232 (vm_light_probe material
isolation). Trunk merged at r198; nothing red. No wip branches.

**Done since last trunk merge (not yet on trunk):**
- 035eee7f: D's per-set long-gun support grips in FpViewmodelTweak.set_left_hand_grip_offset (rifle, shotgun, lmg,
  sniper, break_action, lever, shotgun_box: values from D's LONG_GUN_GRIPS in tools/blender/characters/_arms_clips.py);
  test_p_grip_offset is per set. Green: p_grip_offset 2, po4_feel 10, p1_01 12, p1_03 5, po4_viewmodel 1,
  p_finger_clip 3 (self-check threshold relaxed to 2x + 30 for the new grip). Merge with D's char_arms_fp push
  (the clip and these offsets belong together).
- b5703ddb, 69211232: tests/p/_review/vm_light_probe.tscn (the FP black-gun probe, see In progress).

**In progress:**
- FP "black gun" (lead priority, PO "untextured gun"), 90%. Cause found: the gun's MATERIAL. Proof (Glasshouse,
  Corsair, mean luminance 0-255 of weapon-only viewmodel pixels; Compatibility and Forward+ agree): shipped 8
  (Forward+ 11); unshaded 87; the arms' skin material on the gun 83-87 (so lights / layers / shadows / normals / env
  are fine); skin material + ONE gun texture: ORM 23, albedo 39, normal 80 (Forward+ on lavapipe, full run: shipped 11, arms
  material 87, +ORM 34, +albedo 41, +normal 85, no ORM 22, env colour 8.7: same picture). C's library ORMs give anodized
  aluminium / blued steel / bare steel / brass metal = 1.0 (rough 0.35-0.39); a metal only reflects, and the FP
  viewmodel (and dim interiors) give it almost nothing to reflect. Sent to C (owner of world/materials + texgen):
  coated finishes (anodize, bluing, cerakote) as dielectric (metal 0-0.15, rough 0.45-0.55, anodized black albedo
  ~0.2 sRGB), bare steel / brass / chrome stay metallic. C agreed and recorded it as In progress #4 in docs/status/env_c.md (env/c-worlds 6b533f0b) for the next C session. Next: (1) the env_bgcolor / env_bgcol_amb variants are NOT measured yet (my run timed out sharing the CPU):
  rerun `vm_light_probe.tscn` ALONE (opengl3, ~15-20 min, timeout >= 2400 s) and read those lines: a transparent BG_COLOR (alpha 0) with
  REFLECTION_SOURCE_BG in the viewmodel environment (crew_view.gd _build_viewmodel_camera) gives metals a
  reflection while the overlay stays transparent: if it lifts the gun without changing the coverage px, add it
  there (P owns crew_view.gd) as a viewmodel_reflection_color tweak; (2) after C's material change, rerun the probe
  and render the Glasshouse before/after (hold_capture --heist=glasshouse --closeup) for the PO.
- PFingerClip (support-hand skin vs gun), 100% tool / waiting on D: game/tests/p/p_finger_clip.gd +
  test_p_finger_clip.gd (report-only "[FINGERS]" lines). Trunk r192 numbers: thumb inside the gun 4-12 mm on every
  long gun, index up to 6.4 mm; middle/ring/pinky clean. Next: when D's new char_arms_fp lands, rerun; when clean
  turn test_report_long_guns into an assert (e.g. 0 vertices deeper than 2 mm).
- D-113 FP muzzle flash, 10%: API agreed with C (muzzle_flash.tscn: flash(size, suppressed, weapon_class := &"",
  variant := -1), burst_end(), fp_scale(on), children Sparks / Wisp kept visible, Smoke hidden). Waiting on C's
  scene. Next: in fp_viewmodel_fx.gd flash(): pass the set's class (map anim_set -> pistol/rifle/shotgun/lmg/
  sniper/smg in FpViewmodelTweak), call fp_scale(true) once on _make_flash, call burst_end() ~0.25 s after the last
  shot (tick), keep po4_feel / d105 green, send a windowed sequence.
- Lit hold sheet + close-ups on trunk (PO "before"), 0%: superseded by the black-gun fix; run after it.

**Queued next:**
1. Black-gun viewmodel reflection (above) + before/after (lead priority 2026-10-14 20:00).
2. Lit hold sheet + close-ups after D's grip clip and C's materials (lead r190/r192 asks).
3. D-113 FP flash once C's scene lands (lead D-113).
4. GN loud pass rerun with A's door warp 0680ddab + Po5Pilot barred-door fix (gn_pass.tscn), check CREW_STACK
   gone and the loud objectives progress (lead GN-P1).
5. D-111 coverage rerun when A's anim triggers land (directional hit react, death variants, 8-way, start/stop,
   crew crouch): anim_coverage runs + nd_stealth_pass (now with intimidate/tie/swap) (lead D-111).

**Cross-env dependencies:** C: weapon material fix, muzzle_flash.tscn (D-113). D: char_arms_fp long-gun grip clip
(must merge with 035eee7f). A: anim triggers (D-111), door warp 0680ddab, Po5Pilot barred-door fix, GN last-call
cue / loud first objective (routed by the lead). B: Jay in roster.tres.

**How to validate your area:**
- Unit: `godot --headless --path game res://tests/framework/runner.tscn -- --dir=p --filter=<name>` (dir is the
  env letter, not a path). Viewmodel guard set: test_po4_feel, test_p1_01, test_p1_03, test_po4_viewmodel,
  test_p_interact_lower, test_p_grip_offset, test_p_finger_clip, plus a/test_fp_viewmodel, b/test_pp_left_hand_ik,
  d/test_arms. Run `godot --headless --path game --import` first after any merge (new class_names).
- Windowed (xvfb-run -a -s "-screen 0 960x540x24", add --rendering-driver opengl3 for speed; Forward+ works on
  lavapipe but is ~3x slower): hold_capture.tscn (--weapons, --heist, --closeup), vm_light_probe.tscn,
  gn_pass.tscn (real menus, GN stealth to last call then A's auto_loud), anim_coverage.tscn (rides A's PO-5 flows:
  --po5-flow=..., --anim-out), nd_stealth_pass.tscn (--anim-out, --obs-out), po_observer (on the root via the boot
  scenes), spike_probe.tscn, nav_path_probe.tscn, coop_fx_capture. All headers carry their usage lines.
- Before push: gdlint changed files, tools/ci/check_ownership.py p, tools/ci/check_banned.py.

**Gotchas:**
- llvmpipe renders a lit heist at minutes per frame: every windowed tool turns RenderingServer.render_loop_enabled
  off between shots; never run two windowed runs at once (both crawl).
- `pkill -f` / `awk '/pattern/'` kill lines match your own shell when the pattern is in the command: kill by pid
  from a separate command.
- Modifier (IK / HandRestore) results are only in the skeleton pose inside Skeleton3D.skeleton_updated.
- Godot front faces wind clockwise: the outward normal is (c - a) x (b - a).
- The FP weapon hangs under the arms skeleton (weapon bone): "arms meshes" must exclude weapon_visual's subtree.
- GN: the PUBLIC MapZone Area3D sits at the origin (use its CollisionShape3D children); last call flips the
  same zone node to RESTRICTED.
- HeistRuntime.npcs() returns the living only (group G.NPC for the dead).

**Your session id:** session_01FYVVhNtxKAoQmyfnZ9rb3t (ENV P).

## 2026-10-14 19:45 UTC: support-hand clip probe, GN-P1 round 187 pass, Marten + Jay, per-set grip offset
- Per-set left-hand grip offset (1738fe7e; A's line on trunk r192): D's PD2 long-gun wrist for 7 sets.
- PFingerClip / test_p_finger_clip (190327b8): finger skin vs gun mesh in the real game pose (CPU skinning in
  skeleton_updated, nearest face + 3-axis parity; self-check: grip 4.5 cm left -> 44 -> 262 inside). Trunk r192,
  hip ~= ADS, inside vertices / depth: thumb Condor 58 / 12.1 mm, Mule 43 / 10.0, Anvil 24 / 10.6, Reaper 18 / 10.8,
  Bastion 45 / 9.9 (index 33 / 6.4), Corsair 36 / 7.7, Brute 30 / 6.3 (index 8 / 5.9), Shrike 13 / 3.8; middle /
  ring / pinky 0 everywhere. Thumb on the near side + index tip (D). Report-only until D is green, then an assert.
- GN-P1 round 187 (gn_pass.tscn, real menus, seed 1792002290, 2 runs): last call works (warning subtitle,
  Public -> RESTRICTED at 480 s, patrons out); a guest who stays is spotted (force mask) then guard_radio alarm
  (D-075). Open: objective still "Case the gala" + no off-limits cue after last call (A/B); AI crew stacked
  0.01 m apart at (22.2, 0, 30.5) for 300+ s loud (A); loud first objective "Find the listed canvases" (A?);
  A's pilot cannot route round the barred ArtDoorEG (harness).
- Marten (5d638e84) and Jay (d2386db1) wired (sleeves + bodies), test_p_roster_wiring reads B's roster.
- nd_stealth_pass: render loop off between shots, intimidate + tie, weapon swap (D-111 coverage, not rerun yet).
- Open: lit GH hold sheet + close-ups on trunk (hold_capture --closeup, rendering; llvmpipe minutes per frame).

## 2026-10-14 18:30 UTC: D-111 animation coverage, long-gun hold diagnosis
Probe: tests/p/_review/anim_coverage.tscn (rides A's PO-5 flows) + nd_stealth_pass.tscn, `--anim-out=DIR`. Runs:
GH stealth (676 s), GH loud (partial, to bag 1), ND loud (partial, ~390 s heist), ND stealth (direct launch). Bodies:
civ 14, guard 8, patrol 39, tac_light 61, tac_heavy 2, bulwark 6, longshot 2, AI crew 9.
**Verdict on "almost zero animations play": not true for the pipeline, true for what the PO sees.** No STATIC body
(real launches), 0 SLIDE, 0 interaction without a clip, and in GH loud (the run with the pose probe) 0 PLAYER_MISMATCH,
1 FROZEN sample (crew_ai fire_pistol, 1 s) vs 1000+ moving samples; 30 of 102 authored clips seen. Why it reads as "nothing": (1) the AI crew stands in
`idle` 675/676 s in stealth (correct per D-014, but PD2 bots follow/crouch/shuffle); (2) the variety is in
clips nobody gets close to (desk_work, browse, cower...), while the moments in your face (getting hit, guard
noticing, start/stop, turns at walk) have no clip or no trigger; (3) the local body is FP only and the pilot never
switched weapons (fp:rifle only). Direct-launch crew are capsules (STATIC, dev-only launch artifact, low priority).

Ranked (PD2 shows it often, never fired here; "trigger should live"):
| # | clip(s) | authored | trigger in code | seen | owner / where |
|---|---|---|---|---|---|
| 1 | hit_react_back/_left/_right | yes | no (only `hit_react`, which also never fired) | 0 | A: AnimDriver one-shot from the damage direction (like _pick_death_clip); check NpcHealth emits the hit for non-lethal damage |
| 2 | walk_start/stop, run_start/stop | yes | no | 0 | A: AnimDriver locomotion, on speed crossing 0 |
| 3 | walk_fl/fr/bl/br, run_fl/fr/bl/br | yes | no (4-way only) | 0 | A: AnimDriver _locomotion (8-way by angle) |
| 4 | death_side, death_back_b, death_front_b | yes | no (front/back only, no variant) | 0 | A: _pick_death_clip (side by dot, variant via GameRng) |
| 5 | crouch_idle / crouch_walk (AI crew + guards) | yes | yes | 0 | A: crew AI brain never crouches (PD2 bots crouch in cover) |
| 6 | surrender, hands_up, tied, kneel_cuffed, cower_stand | yes | yes | 0 | flow coverage: the PO-5 flows never intimidate; my ND pass skips `tie`. Not a bug yet: P adds an intimidate step |
| 7 | pager_answer (guard side) | yes | yes | 0 | flow: no pager fired in these runs |
| 8 | interact_mid/high, drill_place, throw_bag, carry_bag_walk (AI crew) | yes | partial (drill_place none) | 0 | A: AI crew never interacts/carries in these flows; drill_place has no trigger (map to drill kind) |
| 9 | reload_rifle (enemies) | yes | yes | 0 | A: police reload never seen (police aim+fire only 25 s in total; cause not yet checked) |
| 10 | downed, downed_crawl, tased (crew) | yes | downed/tased yes, crawl no | 0 | flow (no one went down) / A for crawl (downed + move input) |
| 11 | shield_bang, kick_charge/kick_hit, dozer_walk(_heavy) | yes | yes/no(heavy) | 0 | flow (no dozer/kicker spawned at Routine) |
| - | bartender_*, bouncer_idle, dance_a-c, teller_count, death_seated_* | yes | no | 0 | A: ambient hints not mapped (needs C's GN/club placements), seated deaths need a seated flag |
| - | walk_l/walk_r | yes | no (strafe_l/r used instead) | 0 | D/A: duplicate, pick one |
Not missing (my first table was wrong): fire_ads, fire_auto(_ads), fire_hold, reload_start/loop/end, melee_knife/
blunt/blade, throw/throw_low/throwable are FP-set clips (separate libraries), phone_grip is a grip pose,
death_end_poses a SOURCE name. FP side seen: draw, holster, idle, fire, reload, reload_empty, swing, charge_start.
**Top asks: A rows 1-4 (direction + start/stop + 8-way + death variety are what the player sees at close range);
P extends the flows (intimidate/tie, pager, weapon switch) and reruns.**

Long-gun hold (Corsair, weapon-bone space): palm (-0.011, 0.021, -0.261) on the fore-end; middle fingertip
(+0.017, 0.090, -0.302) inside the fore-end (y 0.056..0.104). IK on vs off within 1 mm: the clip's hand shape is the
cause (D). Black guns: B's ORM materials are metallic 1.0 (polymer too) with near-black albedo, so on a map with
no environment/reflections they render black: a material issue (B), not lighting. D arms 7b59e713 + my branch:
po4_feel, po4_viewmodel, p1_01, p1_03, interact_lower, A fp_viewmodel/real_arms, B pp_left_hand_ik, D arms all
green; hold sheet re-rendered (6 weapons). Waiting on D's finger fix to re-render.

## 2026-10-14 16:25 UTC: GN-P1 on trunk, custody hide, pistol left-hand IK
- GN-P1 (trunk 55ce4d2a+): test_p_gn_traversal 8/8 (doors >= 1.0 m, balcony throws, Mews -> LD heavy bag, both
  ladders, Treasury static/timed/sweep, pool with a heavy bag), PO-3 snag 0/0 (open/closed), menu path PASS. Feel
  (gn_feel_capture.tscn, compatibility renderer): hall/balcony read well; Treasury/dock floors pitch black; pool and
  Mews near black at night (viewmodel unreadable, §7.11); portico haze. Sent to C.
- 69bfb6ba custody hides the viewmodel (downed keeps it); 3ee2bc79 pistol/revolver skip the runtime left-hand IK
  (D's finding; captures/pistol_left_ik_skip_before_after.png). D's ADS depth question: no override, 52 deg
  viewmodel FOV vs 75 deg review camera (D tapers sleeves next).
- Closed: casing-follow (A could not reproduce). Open: ND stealth pass run (CPU-bound), coop_fx rerun after A's
  ghost-round fix, LobbyDoor rerun after A's AI corner fix.

## 2026-10-14 15:30 UTC: po_observer rerun on r157/r158 (A crew AI, B prompt verbs) + GN-P1 step 1
- GH loud (to t=244) + ND auto_loud (to t=110) + ND stealth (nd_stealth_pass.tscn, P script; A's runner has no ND
  stealth flow), observer flags:
  1. Bot spacing while holding is good (mean 1.4-3.8 m, 2.4-5.4 m from the player, 0-14% in clear LOS of the
     nearest enemy). In transit they still stack (0.13-0.49 m pairs: GH t=26/41, ND t=51-73). A bot also stands
     INSIDE the player (GH workshop door t=30 on screen; ND stealth spawn, 0.34 m). A.
  2. ND stealth: during casing the bots follow the unmasked player into the bank (3 m behind). D-014 says solo AI
     waits at the van in stealth. A.
  3. Police pair stuck 0.23-0.33 m apart (ND t=83; GH t=202-222, same spot 20+ s). A.
  4. Prompts: break_glass has its verb. ui.prompt.interact is still on the GH WorkshopDoor (8 s open_door) and an ND
     object at t=18. A/B. The cue.npc_melee_swing beep is fixed in r158 (C).
  5. Positive: weapon-down during the 8 s workshop interaction confirmed on screen (55b5bba6).
- GN-P1 (env/c-worlds 5050eca7, scratch merge): PO-3 snag 0/0 (doors open/closed). Balcony throws PASS (land x
  22.2/22.7/23.9; C fixed the doc strip to x 22-28). Mews -> LD with a heavy bag PASS. §7.7 route doors FAIL (8 at
  0.9 m), C fixing in step 2 with the pool, ladders and lasers. test_p_gn_traversal (skips until GN lands).
- D split agreed: D owns _arms_* and char_arms_fp*; P keeps fp_viewmodel* and the viewmodel guards.

## 2026-10-14 13:55 UTC: product-owner fresh-eyes pass (trunk r146), ranked
Runs: A's PO-5 flows played by input, windowed. GH stealth x2 (one PASS; one observed by po_observer.tscn, 58 rendered
frames, went loud at t=200 when an intimidated, untied civilian pressed the alarm) and ND loud (auto_loud, stuck at the
vault drill). CPU spikes: spike_probe.tscn, headless (llvmpipe frame times in the windowed runs are not usable).
Ranked by what a player would hit, with owner and file:line guess.
1. FIXED by A (cae0d9c6, confirmed with spike_probe): ND 1 Hz stutter for the whole stealth phase: hud_model 45-87 ms every ~1.03 s (50-108 ms frames). The `code`
   marker tag never resolves in the code_on_manager variant (world/heists/night_deposit/night_deposit_mission.gd:67,
   :207) and LocalHudModel re-resolves every tag ~1/s through a full-tree find_by_tag
   (systems/hud_model/local_hud_model.gd:567-580, heist_runtime.gd find_by_tag). Also: no marker for the code.
   A (routed by the lead).
2. RETRACTED: the ND vault drill did finish (objective -> 2 at t=477; the pilot's "waiting N s" is wall time on
   llvmpipe). Left over, minor: a running drill shows "Hold F to interact" + red "Can't do that right now" (no reason). A/B.
3. AI teammates stack inside each other: slots 1-3 within 0.1-0.2 m (TEL crew positions), two heads merged on screen
   in the ND antechamber. A (crew AI follow spacing).
4. First loud frame: 243 ms on ND, 98 ms on GH. assault_director 22-24 ms; ~200 ms outside FrameProf's keys (alarm
   cue/stream load? police spawn instancing?). A (lead routed the profiling). The HUD part of it IS gone (r144
   UiSfx.warm confirmed: hud_model no longer in the first-loud top systems on GH or ND).
5. FIXED (P, 55b5bba6): the weapon stayed up during timed interactions (rifle canted across the view mid-lockpick).
   PD2 holsters it: now lowered after 0.12 s of an interaction, drawn on completion/cancel.
6. GH U2: the knifed camera operator's body lies through the desk and under the chair. A/D (death pose placement).
7. Sound: cue.npc_melee_swing has no definition, so every NPC melee windup plays the placeholder beep
   (systems/combat/npc_gunner.gd:33; missing from the cue registry). Audio-registry owner.
8. HUD: an off-screen objective marker clamps onto the bottom-right ammo / inventory cluster (its label overlaps
   "27 / 120"; "3 m" sits on the item icons). B (content/ui/hud/widgets/objective_markers.gd edge inset, ~:10/:108).
9. HUD: subtitles sit low and faint behind the bottom HUD band (GH "Workshop door's open..."). B.
10. Text: "Your ride's 300.0 seconds out" (float in VO). strings.csv:1712 via night_deposit_mission.gd:332
    (wait_s float; same pattern GH/DB van ETA :1697/:2387). A (mission) or B (format ints).
11. Text: "Secured: 1 bags" (strings.csv:136, hud.gd:402: no singular). B.
12. Payday: "Clean job. Nobody knew we were there." next to 1 civilian killed and a cleanup cost
    (content/ui/results/payday.gd:475 keys only on stealth). B.
13. Prompt: the workshop lockpick shows the generic "Hold F to interact" (ui.prompt.interact) instead of naming the
    action. B/A (prompt_key on the door's InteractableComponent).
14. ND heist start: the camera spawns facing a brown wall at point-blank. A (ND player spawn yaw).
15. Heist start: a 72 ms frame at t~0.22 (hud_model first refresh 26-46 ms), both maps. A.
16. Low: GH, an intimidated civilian who was never tied later pressed the alarm button. Likely PD2-faithful (untied
    civilians recover); A to confirm the rule. Also GH a parked car body over the kerb line by a bollard (low
    confidence, one frame). C/A.
Tools: game/tests/p/_review/po_observer.tscn (frames + automatic flags), spike_probe.tscn (CPU spikes, unresolved markers).

## 2026-10-14 11:20 ET: lit PO-13 sheet, P-FP-STATES, Options hooks, sweeps
- PO-13 lit sheet captures/po13_hold_before_after_lit.png (GH street, 6 classes; Corsair row predates 7a61cd7e).
  7a61cd7e fixed my round-2 regression: rifle hip z -0.135 (stock was inside the 2 cm near plane, test_po4_feel).
- P-FP-STATES (9b915b3d, b4912280): CrewFpStates + eye_downed 0.8 m (eye_position follows; A told), tase jitter /
  buckle, kick fall + roll, hit punch; Reduce Motion; sheet captures/p_fp_states_sheet.png. test_p_fp_states 6/6.
- Options hooks (7babb171): ads_sensitivity on aimed look, screen_shake on camera shakers (duck-typed);
  test_p_options_hooks 2/2. FOV stays vertical (lead ruling, B relabels).
- (e) co-op FX: coop_fx_capture.tscn; A has the full-auto ghost-round bug, C fixed the TP flash (frame guard).
- PO-3 probe skips ladder grab cones (effe1d06); closed-door sweep on trunk r134 + c-worlds: 0 snags x 4 heists.
- Pre-push batch rule (lead): anything touching fp_viewmodel* also runs test_po4_feel and test_p1_01.
- Resume: LobbyDoor rerun after A's AI corner fix; coop_fx rerun after A's ghost-round fix; GN G1 at the freeze lift.

## 2026-10-14 09:00 ET: PO-13 round 2, (e) co-op FX, (d) C-grip clips
- Round 2 (a0b07f70): all-class hip framing (+3 cm right, +2 up, 4 closer; lens guard kept), pistol/revolver sprint
  lowered + canted on screen, pistol ADS shoulders lower/forward (reach ok). D arms/anims 18/18, viewmodel tests green.
- (e) coop_fx_capture.tscn (windowed host + client loopback, dev_sandbox, real heister bodies): own shots FP on both
  peers, the other crew TP, no doubling; captures/e_coop_fx_sheet.png. Sent: A, client full-auto ghost rounds
  (2 client shot_fx per tap vs 1 host replay); C, TP MuzzleFlash never drawn on frames > 50 ms.
- (d) C-grip in draw / reload / reload_empty verified, no change (captures/po13_cgrip_rifle_reload_draw.png).
- Resume: lit before/after sheet (scratchpad hold_lit / hold_lit_before renders) ->
  captures/po13_hold_before_after_lit.png; LobbyDoor rerun after A's AI fix; GN G1 when C's greybox lands.

## 2026-10-14 07:15 ET: D-105 sheets, gate-3 traversal, LobbyDoor, PO-13 round 1
- D-105: six-class gunplay sheet (captures/d105_gunplay_sheet.png; Glasshouse loud, 0 bit1 doubling); C's
  MuzzleFlash/TracerFx in FP (alpha-blended, FP smoke), drop-in mask rpc via net_sync.replicates_to (A confirmed).
- Gate 3: test_p_gh_traversal 3/3 (G8 stairs on C's ramps with/without heavy bag, fire-escape ladder, door-window
  route + bag thrown out). LobbyDoor snag: test_p_gh_lobby_door, player input passes all 15 diagonals; the stall is
  AI steering (A fixing: door-opening corners to the centre line + stall repath). No controller change.
- PO-13: PD2 look sway + breathing (310b4c19), long-gun support hand C-grip (72498a0f), pistol ADS 0.35 m + elbow
  spread (f7fce321), pistol hip framing (56255bb3); before/after sheet captures/po13_hold_before_after.png.
  Open: pistol ADS forearms still dominate (rig arm length caps ads_dist ~0.35: sh / forearm / sleeve rig work).
- KR-9: po13 skips headless. check_ownership char_arms_fp*/** patch applied by the lead.

## 2026-10-14 03:00 ET: D-107 stamina, D-105 in real heists, G1 harness
- D-107 (a6e67fc6, round 81): stamina/jump faithful to PD2 (sprint start > 4, run to 0; regen 1 s after the sprint;
  jumps never blocked, run-jump costs 2; 0.55 s jump cooldown; crouch + jump stands). test_p_d107_stamina 5/5; A's
  QB-60 jump test rewritten under the carve-out (13/13), B HUD green.
- D-102 follow-up 05f65d09: pickup calls CrewWeapons.equip(slot, true) (fire waits the equip time).
- D-105: C's MuzzleFlash / TracerFx used in FP (0c093371): MIX materials (additive is invisible in the viewmodel
  SubViewport), FP-sized smoke (C's world-space smoke fills the screen), C fixed billboard_keep_scale at source.
  gunplay_capture.tscn: Glasshouse loud, real-input fire at distinct surfaces, bit1 doubling check (0 doubled),
  corsair sheet in captures/d105_gunplay_corsair_gh.png; all-classes run in progress (llvmpipe ~17 min/weapon).
- G1 harness (D-104): game/tests/p/p_traversal.gd (PTraversal: gap, crouch bar, balcony throw, ladder, carry) +
  test_p_g1_traversal 5/5 on a synthetic course. Ready for Gallery Night's greybox.
- TODO: re-run test_pp_p12_door_snag alone (glasshouse; interrupted, A's door swing landed in r75).

## 2026-10-14 01:30 ET: Dockside pacing, carry presentation, D-105 FP weapon FX (WIP)
- Round 69 merged D-102. 33407473 removes bag_can_jump (A dropped its fallback, e2d5cf6f).
- Lane (c) Dockside pacing: game/tests/p/_review/bag_run_probe.tscn (real input, nav routes, --old compares).
  36 routes x 2 value sets (seeds 1/1002/2 -> E1/E2/E3): 0 stalls. Heavy x1.5 time, medium x1.75; worst case
  4 crates -> E3 4.2 min solo (was 3.1). Verdict accepted: no tuning; heist docs fixed by lead.
- Lane (a) re-scoped from the decompile (PD2 does not holster on carry): f27019c1 -5 deg camera roll while carrying
  (150 deg/s, Reduce Motion off) + weapon draw on pickup. Asked A for CrewWeapons.re_equip() (fire block).
- Gallery Night traversal review adopted as next_heist.md §7 (D-104); I own the G1 traversal tests.
- D-105 WIP: FpViewmodelFx (muzzle burst + smoke, casings incl. pump/lever/bolt timing, FP tracer from the apparent
  muzzle on EventBus.shot_fx bit1), per-shot viewmodel kick (exact critically damped). test_p_d105_fp_fx 3/3.
  fx_capture.tscn sheet (stand-in shot_fx until A emits). C told to skip bit1 tracers/muzzle.

## 2026-10-14 00:30 ET: D-102 bag carry, melee feel
- 2862fde1: melee-hit camera punch + closed-form landing dip. Pistol ADS closed (matches PD2); left-hand cup PARKED
  (D backlog). PO-3 snag re-run: 0 snags on all 4 heists.
- a890055b D-102: CrewTweak bag_speed_mult 1/0.75/0.5/0.25, bag_can_sprint light only, new bag_jump_mult
  1/1/0.5/0.25 (jump velocity; bags never block a jump), throw 4/4/2/1.2 m, head bob x raw move_speed_modifier
  (speed term normalised to the carried walk speed). bag_can_jump kept all-true (deprecated) until A moves
  test_s10_1_sprint_and_jump_limits_per_weight; test_s10_1_throw_distance_ordering needs <= (light == medium).
  Windowed real-input tests: test_p_d102_bag_carry (4/4).

## 2026-10-13 23:50 ET: lanes done, capture sheets, PD2 data
- Pushed through 338cea18 (trunk round 59 merged). Since 21:30: PP-P-12 door (9bea4dde, subagent: floor-height
  doorway probe, back-off, jamb-gated reach), D-097 recovery timing (recoil_wait), ADS eye relief + enforced band
  (96c142ef), ADS time from WeaponStats.ads_time_s + full-transition crossfade (dd03fe58), PD2 sprint->fire 0.4 s
  (8ea19d09), crouch camera easing (be592ac2), head bob behind B's GameSettings.head_bob() (4f4cfa6d), framing
  follows the playing set + melee_knife framing for B's knife (efe10f6f), d084 de-flakes.
- PD2 data from the Lua decompile (scratchpad pd2src) sent: per-class table (B applied, D-096), vmid / mod steps /
  ADS times (B), LMG drift as camera kick (A consumed, D-099).
- Lane 3 capture sheets: game/tests/p/_review/captures/ (ND + Dockside through the real menu, knife, AR). Harness
  lessons: `--heist=` is MenuFlow's direct-launch flag (use --po_heist); hold keys >= 1 tick (xdotool `key` at
  ~0.1 fps is sub-tick); llvmpipe heists run ~0.1-1 fps, use --fixed-fps 60 and wait in ticks.
- Pistol ADS hands: not fixable P-side (per-set FOV / depth only 27% -> 23% coverage); pose fix proposed for D.
- Running: PO-3 snag probe re-run on all heists (scratchpad po3b/). Open proposals: melee hit feedback, bag carry feel.

## 2026-10-13 21:30 ET: lanes L1/L2/L4/L5, D-095, recoil, landing, d084
- Pushed through 77e198ef (trunk round 50 merged). Done: all-class hip framing (f11b4df1, test_po4_viewmodel_classes),
  late ADS alignment modifier (42dfaf93), D-095 viewmodel_lit = layer 21 (1<<20; layer 20 is FIRST_PERSON_HIDDEN)
  + per-shot muzzle light (13da95e8), PD2 recoil punch (dff06548) + PD2 recovery (77e198ef: the whole burst kick
  returns after release, v 9/s h 5/s, cap 20 deg), landing dip (d638fad3), d084 de-flake, L4 pad ramp (897c39aa).
- PD2 recoil/spread reference table (from the PD2 Lua decompile) sent to B (D-096 data owner); design call to lead:
  PD2 ADS spread is ~3x looser than ours; A's crouch spread mult is backwards (0.75 vs still 0.5; PD2 1.0 / 0.4).
- A pushed bag throws following look pitch (02935de8, bias 25 deg).
- WIP: ADS eye relief per set. res://tests/p/_review/ads_sweep.tscn (`--fixed-fps 60 ... -- --out=DIR
  [--only=ids] [--ads_z=set:z,...]`) measures viewmodel coverage in ADS + thumbnails. Rifle: z -0.06 shows the
  buttstock slab, 0.0..+0.05 shows rear aperture + receiver sliver (PD2). Sweep of 17 weapons x z {0, .03, .06}
  running. L3 door subagent (worktree) still running.
- Windowed tips: `--fixed-fps 60` for any transition capture (llvmpipe ~1 fps otherwise collapses transitions).

## 2026-10-13 20:30 ET: rounds 35-42 merged, viewmodel lanes
- Merged trunk round 42 (892c64b9). Pushed 2c8cc473.
- AR hip pose (61d9e075): measured with res://tests/p/_review/vm_probe.tscn (`-- --out=DIR --primary=weapon.corsair_ar
  --slot=primary [--heist=glasshouse] [--no_ik]`, Vulkan windowed, dumps markers/AABB in camera space): authored rifle
  hip had the gun's rear 0.11 m behind the lens. FpViewmodelTweak.set_hip_offset / set_ads_offset_z per anim_set
  (rifle (0.02,-0.03,-0.16), ADS -0.06). Rifle left hand fingers-up is the authored clip (same with IK off): D's pose.
- L4 (897c39aa, subagent): PD2 pad yaw ramp (PlayerInput gamepad_ramp_*), test_p_l4_look_feel.gd; Options mouse
  slider confirmed a pure multiplier on D-091's 0.0016 gain.
- L3 PP-P-12 door head-on: subagent in a worktree (pending). Next: pistol hip cant / brute_12 left hand (L2),
  movement/ADS transitions review (L5), glasshouse AR capture.

## 2026-10-13 ET: team v3 dispatch (D-086), PO-2 mouse capture
- Queue: PO-2 mouse capture -> PO-1 casing exit -> PO-3 bump/step snags on all 4 heists -> feel pass.
- PO-2: game/systems/player/mouse_capture.gd (`MouseCapture`, D-087, input_focus.md 1.0) is the only writer of
  Input.mouse_mode. PlayerInput registers itself as the gameplay owner while `enabled` (paused / disabled /
  freed = not active), reads mouse look in `_input` (a Control under the captured cursor can no longer swallow
  it), and latches held buttons on capture (the click that captures never fires). Capture drops any stale GUI
  focus. Test game/tests/p/test_po2_mouse_capture.gd (logic headless; capture + real XTest mouse turn +
  release/focus windowed). PInputDriver.capture_mouse no longer writes the mode.
- Windowed runs: `xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game
  res://tests/framework/runner.tscn -- --dir=p --filter=po2`. Vulkan/llvmpipe deadlocks on exit after the runner
  quits (WSI swapchain futex), so wrap in `timeout` and read the `== N tests` line, or use
  `--rendering-driver opengl3`. xdotool (apt) gives real X pointer events.
- Still writing the mode (ENV B migrates): menu_flow.gd:749, menu_options.gd:51/63, join_request_dialog.gd:232/234,
  safehouse_host.gd:348, and range: range_spectator_input.gd:68, range_mode_input.gd:27/44.
- PO-1 (casing exit) ROOT CAUSE, windowed real-flow repro (game/tests/p/_review/po_playthrough.tscn: main menu ->
  2D hub (3D safehouse scene not on this branch) -> planning -> glasshouse -> briefing -> preplanning -> loadout
  "Start Heist", all xdotool clicks; then mouse look, hold real G, W): P/A side works: CAPTURED at spawn, no GUI
  focus owner, G held masks up in 57 ticks (0.9 s game). The gap is UI (ENV B, sent): no "Hold G to mask up" hint
  (ui.hud.mask_up_hint defined, never rendered), no mask progress bar, objective "{count}/{total}" unformatted.
  First repro "failed" only because llvmpipe glasshouse runs ~1 fps = ~1 physics tick/s (30 s wall < 1 s game):
  windowed harnesses must wait in physics ticks, not wall clock.
- PO-3: game/tests/p/_review/po3_snag_probe.tscn (headless, `--fixed-fps 60`, `-- --heist=<id> [--stance ...]
  [--approach=touch] [--selftest]`) sweeps every reachable walkable edge with the real controller: ~150k trials on
  all 4 heists x walk/sprint/crouch/touch: 0 step snags (kerbs 0.10-0.36 m all climbed; one false positive between
  G6 CoffeeTable_1/Armchair_1). Likely the PO played a build before P1-01 step-up (round 35). Notes for C/D: every
  prop has two colliders (X/Collision box + X/Model/Collision convex); quay edges QuayE/QuayW (10.9,-0.47,32.9) and
  Pier9East (57.8,-0.64,41.4) are 0.47-0.69 m drops, check they are meant to be.
- PO-3 windowed: po_playthrough now also turns 180 deg by real mouse, walks W off the glasshouse sidewalk kerb
  (0.25 m, at ~(4.4, 0, 13.2)) and back up it: PASS (y 0.00 -> 0.23).
- PO-4 (b9383a9d): look divides by CrewView.zoom_factor while aiming (PD2 zoom sensitivity); default mouse gain
  0.0025 -> 0.0016 rad/count. test_po4_feel.gd.
- test_p3_loud:test_10_ai_orders_during_assault ("follow: the AI caught up") fails on the pre-PO-2 base 7a417116 too:
  pre-existing, A's (crew AI follow), not caused by P.
- Viewmodel lighting ROOT CAUSE (06fd0301): Camera3D.cull_mask also culls LIGHTS by their `layers`. The PP-P-11
  viewmodel camera sees only VIEWMODEL_LAYER, so no world light ever reached the arms/gun (ambient only: near-black
  at night, pure black on maps without sky ambient). Fix: CrewView adds `ViewmodelKeyLight` (DirectionalLight3D,
  layers = light_cull_mask = VIEWMODEL_LAYER, no shadows) + viewmodel_ambient_mult (FpViewmodelTweak). Verified
  windowed with res://tests/p/_review/vm_probe.tscn (unit map: skin, sleeves, gun highlights now visible).
  Open (QP-2 to lead): world lights (muzzle flash, flashlights, lamps) still never light the viewmodel; options: a
  render-layer bit for lights (C/D set it, vm camera includes it) or P tagging Light3D layers at runtime.
- Still seen: ADS forearms fill the lower third (pose + 52 deg vm FOV), hip pistol sits low-right and reads canted
  (D's anim / lead PP-P-11 ruling). Next: that, ADS transitions, sprint/crouch/jump, door snag
  PP-P-12, brute_12 left hand, 1920x1080 review.

## 2026-10-12 20:25 ET: merge round 34, renders, loud run
- a2ddb786 merge trunk db22c24c (--no-ff). P suite 53 (only the opt-in E2E failed, now skipped by default),
  p4_progression 9/0, slice_b 6/0, b5_01 1 fail pending A's mask patch (ruling: ADS blocked unmasked).
- Viewmodel: gun already rides the `weapon` bone (FpViewmodelTweak.weapon_bone); measured hip pose within ~5 deg
  of camera axes, so the "tilt" is perspective. No P pose change made. New: brute_12 hip left hand floats at the
  barrel tip (LeftHandIK marker ~0.52 m out) - B marker / P IK, open.
- Loud run (CNC_E2E=1): MainEntrance+SalonDoor lockpicked by real input, drill placed on the Safe, 1 jam fixed by
  real input, but the safe was not open after 400 s game time; police down/cuff the AI crew. Open.
- Renders: /workspace/cnc-team/p/renders/01..10 (20:06-20:21 ET).

## 2026-10-12 19:50 ET: PT-02 Glasshouse E2E, PT-03 FP renders, PI-08, lead interrupt
- PT-02 game/tests/p/test_p_glasshouse_e2e.gd (real input; setup: isolate_npc, cameras removed in stealth run).
  Stealth run reaches the escape (keycard, workshop lockpick, safe reader, 2 bags thrown into the van, escape);
  fails only on the casing finding below. Loud run blocked (drill, SalonDoor snag).
- PT-03 renders: /workspace/cnc-team/p/renders/01..09 (scene res://tests/p/_review/fp_capture.tscn).
- PI-24 FIXED 0e1315a8: swap_weapon desynced after 1/2 keys or a failed equip (no-op swap).
- PI-25 FIXED 839c0330: jump latch armed on any held jump, so jump pressed in the air/after teleport was eaten
  (slice step 3 'bot jumped').
- PI-08 FIXED: CrewTweak.deceleration 50 for grounded braking/reversing (sprint stop 0.19 -> <=0.16 s incl. input).
- Routed: C - MainEntrance (glasshouse.tscn:10518) casing_allowed=false: a casing player cannot open the shop's
  public front door. A - Safe._inner_loot (safe.gd:129-130, 386-398) disables the child SafeDrill DrillPoint as if
  it were loot: drill point unusable (the Safe's own place_drill still works). A/C - loud walker stuck on the
  SalonDoor frame at (12.5,0,9.6) (LeafBody overlaps there). A - test_b5_01 line 91 aims unmasked (patch in
  /workspace/cnc-team/p/handoff_env_a/). Viewmodel (P/D): hip pistol canted ~40 deg, ADS forearms fill the lower
  corners with wrists through the grip; no crosshair in renders (HUD not in the capture scene - unverified).

## 2026-10-12 19:xx: PT-01 core-loop playtest (real input)
- No separate "Aaron's playtest list" exists; the P rows in docs/process/playability_pass.md (PP-P-1..3) are done
  via P1-01..03. Played the core loop by real input instead: game/tests/p/test_p_core_loop.gd, 12/12 pass
  (spawn, casing, mask-up hold, walk/sprint/crouch speeds, jump + no bunny-hop on held jump, F while casing,
  aim+fire+reload, sprint vs fire, melee, throw, gamepad bindings, pad mask-up + jump).
- No new P bugs found. Open: throw test is vacuous if the unit-map loadout carries no throwable; ledge (mantle)
  not covered - no mantle mechanic exists to test. Next: PI-08 tuning, PP rows as other envs log them.

## 2026-10-12 22:45 UTC — P1-02 casing audit, P1-03 ADS, D-084, D-085, UI focus, fire_rate_mult
### Done
- 200949ba/b0fceb0c D-084 CrewView.zoom_factor + local_zoom_factor() + zoom_factor_changed.
- 091ea17e P1-02 casing tests: PI-11 (alarm with AI crew) and PI-12 (AI keeps casing) NOT reproduced (pass);
  PI-13 casing_blocked(action) signal added (HUD hint source for ENV B). PI-10 hop patch verified: handoff test
  fails on trunk, passes with /workspace/cnc-team/p/handoff_env_a/pi10_casing_hop_heist_runtime.patch (ENV A).
- 8b770a5a PlayerInput: a focused visible Control (payday grab_focus, menus) blocks ALL polled gameplay input;
  actions held through the UI stay ignored until released (real gamepad LB/RB test).
- a1916bdb fp_viewmodel shot interval x weapon.fire_rate_mult (1.0 when unset) + test.
- d5186bc7 ADS: CrewView.is_aiming(crew) (aim, masked, mobile, not sprinting, not reloading); camera and arms
  share target, FpViewmodelTweak.ads_rate and smoothstep ease (PI-16/17/18) + real-input tests.
- (this commit's parent) D-085 edge assist + door tests: head-on frame-edge hits stalled dead before
  (probe: offsets 0.40-0.60 m stuck at the wall face); now slides to the opening within 0.45 m.
- Casing hides the FP viewmodel (PD2), shown with the draw on mask-up.
- `run_tests.sh p` 32/32; b hub_3d 13/13, b range 35/35; a: fp_viewmodel 15/15, crew_controller 8/8, l6_ai_teammates 11/11, a3_05 12/12.
### In progress
- PI-15 mask-up grace: left as is (PD2 resets on release; design call). PI-19 AimPoint audit DONE (all WeaponDefs have AimPoint; missing one warns once), PI-21 arms step lag DONE (FpViewmodelTweak.step_lag_mult 0.6). Tests: test_p_viewmodel_sights_steps (3/3); run_tests p 35/0; tests/a test_fp_viewmodel 15/0.
### Blocked
- Push of commits after 091ea17e: approval requests interrupted; not pushed (local only).
### Questions for lead
- QP-4: ENV A: CrewWeapons spread uses intent.aim (crew_weapons.gd:514) even while sprinting/reloading; should
  use CrewView.is_aiming(crew) for consistency.
### Ready for integration
- yes; check_all not run (lead rule).

## 2026-10-12 22:20 UTC — P1-01 mouse gain, PI-06, PI-03, UI shoulder gating; LOD bias question
### Done
- Mouse sensitivity bug (real, not headless-only): PlayerInput used InputEventMouseMotion.relative, which the
  canvas_items stretch scales by 1920/window width (xvfb probe: 1080p x1, 1440p x0.75, 4K x0.5, 720p x1.5,
  headless x30). Now screen_relative + test_degrees_per_mouse_count (fails on the old code with 30x). 1328183f.
  Probe project: /workspace/cnc-team/p/mouse_probe. Same bug in ENV B content/range/range_spectator_input.gd:98.
- PI-06 teleport keeps facing + test (failed before fix): 75ccbead. PI-03 diagonal/strafe/standstill: passes, not
  reproduced. PI-02: not reproduced; floor_snap_length unchanged.
- LB/RB shared with ui_payday_prev/next: paused input already blocks them; but a shoulder held through the UI
  close meleed/threw on resume (test failed). Fixed: resume-gated actions until released. p_input_driver gains
  joy_button(). `run_tests.sh p` 17/17; tests/b hub_3d 13/13; gdlint clean on P files.
### In progress
- LOD zoom bias: on hold, see Questions.
- Next: P1-02 casing audit, then P1-03 ADS.
### Blocked
- Push: 403 (permission denied to LeviticusFigglebottom).
### Questions for lead
- QP-3: Godot already divides mesh LOD by zoom (Projection::get_lod_multiplier = 2*tan(fov/2), used for mesh LOD
  selection), so scaling Viewport.mesh_lod_threshold with zoom would double-count (a 4x scope at 40 m would pick
  the LOD of ~2.5 m, not 10 m). Visibility ranges (HLOD, used in world/props/**) are NOT FOV aware and have no
  viewport bias. Proposal: no mesh_lod_threshold change; for HLOD, a P-side zoom factor published by CrewView that
  ENV C/D props read, or accept pop-in through scopes. Which?
### Ready for integration
- yes; check_all not run (lead rule).

## 2026-10-12 22:05 UTC — P1-01 (step-up/snap, PI-04, PI-05), PInputDriver, PI-10 handoff
### Done
- PInputDriver (game/tests/p/p_input_driver.gd) + self-test 5/5: a43d33b7, uids 6b858a0b. PlayerInput gets a
  test-only `test_assume_captured` (headless cannot capture the mouse). Mouse gain is calibrated at run time
  because headless stretch scales motion ~30x.
- CrewController.mask_forced for ENV A's hop fix: 4860fdbc. Handoff for ENV A (owner of heist_runtime.gd):
  /workspace/cnc-team/p/handoff_env_a/ (patch + test_p1_02_casing_hop.gd, which fails on trunk: STEALTH -> LOUD).
- P1-01: WIP step-up/snap passes as written; test_p1_01_ground ported to real input (human); PI-05 jump latch and
  PI-04 uncrouch headroom fixed with tests. `run_tests.sh p`: 13 tests, 0 failed (local run).
- PI-23 was wrong: slot 1 IS an AI in that launch (test passes).
### In progress
- Next: PI-02 snap length, PI-03 step probe, PI-06 teleport look resync.
### Blocked
- check_all not run (lead rule 17:55 ET). Push: see report.
### Questions for lead
- none new
### Ready for integration
- yes for P1-01 items above; check_all not run by rule; `run_tests.sh p` 13/13.

## 2026-10-12 21:55 UTC — P1-01 / P1-02 / P1-03 issue list + queue (code read only, Godot not installed)
### Done
- Playability issue list + 2h+ fix queue below (this commit). Built by reading code only; nothing run.
### In progress
- P1-01: WIP step-up/snap (6d447827) + test_p1_01_ground.gd still UNTESTED. Exact next step: once Godot is on
  the box, `tools/ci/run_tests.sh a,p`, then fix whatever test_p1_01_ground reports, then PI-01..PI-05 below.
### Blocked
- All runtime verification: Godot 4.7.2 not installed on the box (lead is setting it up).
- Push: P does not push (D-077); lead merges env/p-play locally.
### Questions for lead
- QP-1: The casing->STEALTH hop fix (PI-12) is in game/systems/heist/heist_runtime.gd (ENV A / lead file). OK for P
  to send the 3-line patch to you, or does A take it?
- QP-2: Real-input tests (PI-20) need a helper that injects InputEventAction into PlayerInput instead of
  HeistRuntime.set_bot_intent. Proposed: game/tests/p/p_input_driver.gd (P-owned). Agree?
### Ready for integration
- no; `check_all.sh --env p` result: not run (no Godot)

### Playability issue list
Legend: P0 = blocks normal play, P1 = clearly wrong feel, P2 = polish. "Verified" = confirmed by reading the code
path end to end; "Hypothesis" = needs a run to confirm. Line numbers are at dbfc7281.

#### Movement, step-up, floor snap (P1-01)
- **PI-01 [P0, Verified-by-read, unrun]** crew_controller.gd:429-447 / test_p1_01_ground.gd (whole file). The
  step-up/snap-down WIP has never run. Symptom today on trunk: curbs, door sills and stair risers block a walking
  player (no jump while casing, so casing players are stuck). Fix: run the test, iterate on `_step_up_rise`.
- **PI-02 [P1, Hypothesis]** crew_controller.gd:105-107 + 481-488. Engine `floor_snap_length` = 0.35 m AND the
  custom `_snap_down` both pull the body down. Symptom: a double snap / small stutter walking off curbs; also
  move_and_slide may snap 0.35 m down after a jump's first tick lands near a ledge. Fix: set floor_snap_length to
  ~0.05 (or 0) and leave step-down to `_snap_down`; re-run the step series.
- **PI-03 [P1, Hypothesis]** crew_controller.gd:452-476. Step probe uses one tick of motion (~6 cm at walk,
  ~10 cm sprint) and requires >= 25% forward travel at step height (l.466). Symptom: diagonal approach / strafing
  into a curb, or very low speed (just started walking), fails to step and grinds on the face. Fix: probe with
  max(h_motion, capsule_radius*0.5) along the wish direction, then move only the real h_motion.
- **PI-04 [P1, Verified-by-read]** crew_controller.gd:548-559 `_apply_stance`. Un-crouching has no headroom check.
  Symptom: standing up under a desk/vent pushes the capsule into the ceiling (stuck or popped through). Fix:
  test_move up by (height_standing - height_crouched) before growing; stay crouched if blocked.
- **PI-05 [P1, Verified-by-read]** crew_controller.gd:411-415. `_jump_latch = i.jump and not grounded` releases the
  latch on the landing tick, so holding Space auto-bunny-hops (one stamina cost each). Fix: latch = i.jump (release
  required). Add a test that holds jump for 2 s and counts takeoffs == 1.
- **PI-06 [P1, Verified-by-read]** crew_controller.gd:325-331 vs player_input.gd:29-30, 103-107. `teleport()` sets
  look_yaw, but PlayerInput keeps its own `_yaw/_pitch` (synced only in _ready / set_paused), and the next intent
  overwrites the crew's yaw. Symptom: after spawn-at-van, custody release or any server teleport the view snaps
  back to the old facing. Fix: PlayerInput re-syncs from the crew when a `teleported` signal fires (add signal).
- **PI-07 [P1, Hypothesis]** player_input.gd:48-56, 89-100; crew_controller.gd:368-372. Mouse look is accumulated
  in _unhandled_input but only applied to Head/body in _physics_process (60 Hz) with no interpolation. Symptom: look
  feels laggy/juddery on 120-240 Hz monitors. Fix: apply the local human's yaw/pitch to the camera every rendered
  frame (presentation only, in CrewView._process) and keep physics on the tick value; enable physics interpolation
  for the body.
- **PI-08 [P2, Verified-by-read]** crew_controller.gd:401-405. Same `acceleration` (30 m/s^2) for start and stop,
  air_control 0.3 scales both; no friction distinction. Symptom: slight ice on stop at sprint (0.19 s), floaty air
  strafing. Fix: separate `deceleration` tweak (~40) - tuning item after playtest.

#### Casing mode (P1-02)
- **PI-10 [P1, Verified-by-read]** heist_runtime.gd:572-575 + stealth_director.gd:327-335. Getting spotted while
  casing force-masks (`set_masked(true)` l.329) -> crew_masked -> `_on_crew_masked` moves CASING -> STEALTH before
  the alarm. When that detection then raises the alarm (camera countdown, guard call), the phase goes
  CASING -> STEALTH -> LOUD: this is the STEALTH hop players see (HUD/music flash "stealth"). The comment at l.573
  claims no hop but only the `went_loud` path is guarded. Fix: `_on_crew_masked` ignores forced masks (pass
  `forced` through EventBus.crew_masked or check a `forced` flag); only a voluntary mask-up enters STEALTH; detection
  stays CASING until alarm -> LOUD. Needs lead/A sign-off (QP-1).
- **PI-11 [P1, Hypothesis]** heist_runtime.gd:557-562 vs crew_ai_brain.gd:259-261. If any alarm_raised listener
  masks a crew member before HeistRuntime's handler runs (signal connection order), `went_loud` is still false
  and the hop happens too. Fix: set went_loud at the very top (it is), and in addition make `_on_crew_masked`
  defer phase change by one tick / check alarm. Verify with a test: casing -> alarm, record every
  heist_phase_changed, assert exactly [CASING->LOUD].
- **PI-12 [P1, Verified-by-read]** crew_ai_brain.gd:259-261. An AI teammate outside STEALTH_WAIT masks itself on
  its first think while the humans are still casing -> CASING -> STEALTH immediately at heist start. Symptom: AI
  crew "breaks" casing for everyone. Fix (A file, via lead): AI mirrors leader.masked in casing.
- **PI-13 [P1, Verified-by-read]** crew_controller.gd:376-410. Casing blocks crouch/sprint/jump silently. Symptom:
  player presses Ctrl/Shift/Space and nothing happens, no hint. Fix: HUD hint (ENV B) driven by a new
  `casing_blocked(action)` signal from CrewController (P side).
- **PI-14 [P2, Verified-by-read]** crew_tweak.gd:48-49. `mask_slowmo_duration_s/scale` exist but nothing reads them
  (grep). Symptom: mask-up has none of the PD2 slow-mo beat (S1.2 mask-up feel, moved to P by D-076). Fix: local
  presentation-only time effect (camera FOV punch + audio) - do NOT touch Engine.time_scale in co-op.
- **PI-15 [P2, Verified-by-read]** crew_controller.gd:513-519. Releasing G at 99% resets mask_progress to 0 with no
  grace. Fix: decay at 3x rate instead of reset.

#### Aiming / ADS / viewmodel (P1-03)
- **PI-16 [P1, Verified-by-read]** crew_view.gd:145-147 vs fp_viewmodel.gd:637-639. Camera zoom follows intent.aim
  always, but the arms drop out of ADS during RELOAD/SWAP. Symptom: zoomed-in FOV with the gun at the hip while
  reloading. Fix: one shared ADS weight (CrewView reads FpViewmodel.ads_weight when the arms exist).
- **PI-17 [P1, Verified-by-read]** crew_view.gd:146 (CrewTweak.ads_zoom_rate 8/s) vs fp_viewmodel.gd:639
  (FpViewmodelTweak.ads_rate). Two rates, linear move_toward. Symptom: FOV and sights arrive at different times,
  linear (robotic) ADS. Fix: one rate, smoothstep ease on the shared weight.
- **PI-18 [P1, Verified-by-read]** player_input.gd:108-112; crew_controller.gd:380-385. Aim and sprint can both
  be held: viewmodel plays sprint (fp_viewmodel.gd:626) while the camera zooms. Fix: aim cancels sprint (PD2), in
  `_simulate` (`can_sprint and not i.aim`), aim while casing ignored.
- **PI-19 [P2, Verified-by-read]** fp_viewmodel.gd:650-656. ADS alignment silently skipped when the weapon has no
  `AimPoint`. Symptom: sights off-axis on those guns. Fix: Log.warn once per weapon + a test over every WeaponDef.
- **PI-21 [P2, Hypothesis]** fp_viewmodel.gd:642-649. Bob is driven by horizontal speed only; step-ups now move
  `Head` (crew_controller.gd:421) but the arms get no matching dip/lag. Symptom: arms rigid vs camera on stairs.
  Fix: small vertical lag from `_step_offset` into the viewmodel offset.

#### Tests that use bot shortcuts instead of real input
- **PI-20 [P0 for D-076]** game/tests/p/test_p1_01_ground.gd:48,68,75,220 and every test under tests/a +
  tests/integration: movement is driven through `HeistRuntime.set_bot_intent`, which bypasses PlayerInput entirely
  (player_input.gd:97-99 returns early). So input mapping, toggles, look, the F/G contextual keys and PI-05/PI-06
  are never exercised. Fix: P-owned driver that presses actions via Input.parse_input_event(InputEventAction) and
  mouse motion, used by all P tests (QP-2).
- **PI-22 [P1]** test_p1_01_ground.gd:211 `c.set_masked()` and :212 teleport onto the block: mask by holding G for
  mask_up_time_s and reach the block by walking a ramp/stairs.
- **PI-23 [P1, Hypothesis]** test_p1_01_ground.gd:168-203 asserts slot 1 is AI but the launch passes
  `crew_ai: false` (l.15); the AI half is driven by bot intents, not CrewAiBrain. Likely fails or tests nothing AI.
  Fix: launch with crew_ai true and order the AI to follow over the stairs.
- **PI-24 [P1]** Shortcut load elsewhere (set_bot_intent / teleport_crew / isolate_npc call counts):
  integration/test_p1_vertical_slice_b.gd 26, integration/test_p3_loud.gd 24, a/test_p1_sandbox_gate.gd 19,
  a/test_a3_05_ai_orders.gd 16, integration/test_p1_vertical_slice.gd 13, a/test_a1_02_crew_controller.gd 13.
  Those are A/lead files: P writes a real-input "walk the slice" test in tests/p instead of editing them.

### Fix queue (ordered; estimates are hands-on time with Godot available)
1. P1-01a (30 min) run test_p1_01_ground, fix failures in the WIP; PI-23 test fix; commit.
2. P1-01b (20 min) PI-02 snap length, PI-03 probe length; re-run step series + stairs.
3. P1-01c (20 min) PI-05 jump latch + test; PI-04 uncrouch headroom + test.
4. P1-01d (30 min) PI-20 input driver; port test_p1_01_ground to it; PI-22.
5. P1-01e (20 min) PI-06 teleport/look resync + real-input test; PI-07 render-rate look (measure first).
6. P1-02a (30 min) casing audit test: casing -> spotted -> alarm, casing -> alarm, AI crew present; record phases
   (PI-10/11/12); patch to lead (QP-1).
7. P1-02b (20 min) PI-13 signal, PI-15 mask grace, PI-14 mask-up beat (presentation only).
8. P1-03a (30 min) PI-16/17 shared eased ADS weight + test (FOV and arms reach 1.0 together, drop together on reload).
9. P1-03b (20 min) PI-18 aim cancels sprint; PI-19 AimPoint audit over all WeaponDefs; PI-21 arms step lag.
10. Then PI-08 tuning and Aaron's playtest list.
Total ~4 h.

## Previous: Current (resume here)
1. **P1-01 step-up and ground feel**: IN PROGRESS.
   - Done (WIP, untested): CrewTweak `step_height_m` 0.35, `max_slope_deg` 45, `step_smooth_rate` 14;
     CrewController `_move_grounded` (step-up via test_move up/forward/down + walkable ray, snap-down
     along step/ramp edges, `_grounded` flag, camera-only `_step_offset` on `Head`).
   - Next: write game/tests/p/test_p1_01_ground.gd (5/10/15/20/30/40 cm step series, ramp, steep
     ramp, stairs up/down, AI slot, camera jitter) with real intents; iterate; run `run_tests.sh a,p`.
2. P1-02 casing-mode audit: not started.
3. P1-03 ADS audit: not started.
- Baseline `tools/ci/run_tests.sh a` before any change: `== 627 tests, 1 failed, 1 skipped ==`
  (failing test name cut off by my log tail; identify on the next full run).

## 2026-10-11: created
- ENV P created by the lead (D-076). Queue: step-up/floor snap, casing-mode audit, ADS audit, then the product
  owner's playtest list.
