# In-progress work, consolidated (handoff 2026-10-14)

Read `docs/handoff/README.md` first. This file lists every open work item: owner, status, where the work lives,
the next concrete step and blockers. Each env's own detail (validation commands, gotchas) is in the
`## HANDOFF 2026-10-14` section at the top of `docs/status/env_<x>.md`. Where this file and an env note disagree,
this file wins: the LEAD wrote it after checking trunk (see §0).

## 0. Branches and what is NOT on trunk yet

| Branch | Head | State | Action for the new LEAD |
|---|---|---|---|
| `claude/dreamy-hamilton-pc7vck` (trunk) | see `git log` | round 200: C's D-113 VFX + P's probe + all env status notes | — |
| `env/a-core` | 768faba4 | all code on trunk | nothing to merge |
| `env/b-content` | ec36e060 | **HELD**: 8 green commits (Jay roster, SMG fore-end grip, gore option, deployables + gating, throwables, GN string) | merge **together with D's SMG clip re-time**. f8f17c7a turns `d/test_arms` smg_idle/smg_ads_idle red until then |
| `env/c-worlds` | 33048141 | merged as round 200 (D-113 blood + muzzle flash) | merge C's handoff note when pushed |
| `env/d-art` | 07542fe7+ | skirt seated fix not yet merged; grip rework in progress | see §D |
| `env/p-play` | d9b3e6c4 | probes + notes cherry-picked; **035eee7f held** (per-set long-gun grip offsets) | merge 035eee7f **together with D's new `char_arms_fp`** |

Dependent merges: **B + D (SMG)** and **P 035eee7f + D (long-gun clip)**. Merging either half alone turns
`d/test_arms` or `p/test_p_finger_clip` red. Run the FP set after each: `p test_po4_feel test_p1_01 test_p1_03
test_p_grip_offset test_p_finger_clip`, `d test_arms`, `a test_fp_viewmodel`, `b left_hand_ik`.

**Corrections to the env notes:**
* A's status lists three items waiting on the LEAD: the `&"sensor"` alarm reason, the GN camera-operator spawn tag
  and AS vault courier authorisation. All three are **done** on trunk (events.md, characters.md v1.11, board).
* A's status says A waits on D for `prop_saw_device`. Props are **ENV C's** (D does characters). It does not exist
  yet (checked at handoff). Queue it for C; DrillPoint picks it up for Device.SAW once it exists.
* B's queued item 3 (runtime `DeployableGate`) is **done**: A 4f11fb91, round 199.

---

## A. ENV A: Core systems and AI (session_015kTjrZsUFn7gLqNVwAXdkh)
1. **GN loud e2e (GN-A1, D-103), ~60%.** The probe-3 pilot loops on the unreachable
   `Variants/Group_canvas_orchard/Slot_orchard_calloway/Canvas`.
   Next: in `game/tests/a/e2e/po5_flow_auto_loud.gd` `_pick`, blacklist bag_loot targets that fail with "could not
   reach" (STALL_SKIP_S). Then check the nav reachability of that slot. If it is unreachable, it is ENV C's
   (nav/stairs). Re-run with `game/tests/a/e2e/run_po5.sh auto_loud 1792002290 900 <out> "Gallery Night"`.
2. **GN stealth e2e**: not started. Build a `gn_stealth` flow from `po5_flow_auto_stealth` plus the GN objectives.
3. Crew stacking recheck in GN corridors (P's finding). Also P's re-run list: single-file transit at ≥ 1 m spacing,
   a ≥ 0.6 m personal radius, and the ND police overlap.
4. **ND gate 2, attempt 24** (`auto_loud`, ND), **on an empty box only**. Attempt 23 reached t = 710 s before the
   budget ran out.
5. Backlog:
   * co-op full-auto "ghost rounds";
   * escape vehicles (van drive, heli rotors);
   * split `HeistRuntime.start()` across frames;
   * GH jeweler bench marker shift;
   * Stinger / tase values vs PD2.

## B. ENV B: Content and UI (session_0159qCTRV9CsDQs465nGSW28)
1. Held branch (see §0): it waits only on D.
2. **Firing range windowed review with C's dressing**, ~90%. Run `tests/b/render/ui_audit_capture.gd -- <out> range`
   at 720p and 1080p, then tweak any colour clashes.
3. Re-verify the hub, loadout and lobby with 6 heisters at 720p once Jay is merged.

## C. ENV C: Worlds and art (session_013uMHd1Npqkx1reY1pJMaye)
1. **D-113 VFX: merged round 200.** Blood spray, exit spurt, wall/floor splatter, drips, growing pools and bag
   smear; gore Full/Reduced/Off; class-shaped atlas muzzle flash with sparks, wisp and light pulse. Evidence is in
   `docs/levels/_art/vfx_d113/{before,after}/`. Next: the PO looks at the sheets; then tune the values.
2. **FP "black gun" material fix (PO's #1 complaint).** P's finding: the library ORMs give the coated finishes
   (anodized aluminium, blued steel, cerakote) metal = 1.0. A metal only reflects, and the FP viewmodel has
   nothing to reflect. Proposal: coated finishes become dielectric (metal 0–0.15, rough 0.45–0.55, anodized black
   albedo ~0.2 sRGB); bare steel, brass and chrome stay metallic. Owner: C (`world/materials/*.tres` + texgen).
   Re-run P's `vm_light_probe.tscn` after the change. Target: the weapon's mean luminance near the arms' (~80/255),
   up from 8–11 now.
3. **D-111 item 5:** SL/DB interactable wiring, doors and loot stacks (`docs/levels/_art/prop_art_inventory.md`).
4. **Gallery Night G2 art pass** (`docs/process/next_heist.md` §6, GN-C2).
5. `prop_saw_device` (the saw drill-point model, for A's DrillPoint Device.SAW).
6. If A finds `Slot_orchard_calloway` unreachable: fix the nav/stairs to that gallery.

## D. ENV D: Characters and animation (session_01EZDt9WkE187YkB8ANEbuhb)
1. **Long-gun support grip rework (PO's #2 complaint).** Spec, from the PO's reference photos of a proper rifle hold:
   * the support palm cradles the fore-end from **below and the left**, not the top;
   * the fingers wrap the far side, **below the top edge**;
   * the thumb runs along the near side;
   * the grip sits mid-handguard;
   * keep 2–5 mm skin clearance everywhere.
   Acceptance: P's `test_p_finger_clip` passes as a hard assert (0 vertices deeper than 2 mm) on every long gun.
   Today the thumb sits 4–12 mm inside, the index up to 6.4 mm. D's joint-only test is not enough. Rebuild
   `char_arms_fp` and merge it with P's 035eee7f.
2. **SMG clip re-time** for B's fore-end markers (hornet_9, lancet_45, tern_556; hornet marker at Godot
   (0, 0.016, −0.150)) so `d/test_arms` smg_idle/smg_ads_idle go green. Merge with B's branch.
3. Skirt seated-band fix (07542fe7): merge after a `d test_` run (characters + LOD).
4. FP pistol left hand: pistol/revolver are in `left_hand_ik_skip_sets` on trunk (done).

## P. ENV P: Player feel (session_01FYVVhNtxKAoQmyfnZ9rb3t)
1. **Black gun, viewmodel side**, 90%. Re-run `vm_light_probe.tscn` (opengl3, ~15 min) and read the env_bgcolor
   lines. If a transparent BG_COLOR with REFLECTION_SOURCE_BG in the viewmodel environment
   (`crew_view.gd _build_viewmodel_camera`) lifts the gun without changing the coverage, ship it as a
   `viewmodel_reflection_color` tweak. After C's material fix: before/after Glasshouse close-ups for the PO
   (`hold_capture --heist=glasshouse --closeup`).
2. **PFingerClip**: the tool is done. When D's arms land, turn `test_report_long_guns` into an assert.
3. **D-113 FP muzzle flash**, 10%. C's `muzzle_flash.tscn` is now on trunk (round 200). API:
   `flash(size, suppressed, weapon_class := &"", variant := -1)`, `burst_end()`, `fp_scale(on)`. Wire it in
   `fp_viewmodel_fx.gd` (map the anim set to the weapon class), keep `po4_feel` green, and send a windowed sequence.
4. A lit hold sheet plus close-ups after the grip and material fixes.
5. GN loud pass re-run (`gn_pass.tscn`). D-111 animation coverage re-run (`anim_coverage`, `nd_stealth_pass`).

---

## LEAD-owned open items
* Merge the held pairs in §0 when D lands. Then show the PO the before/after images: black gun, grip, D-113.
* The next decision id is **D-114**.
* B's GN-U5 question is still open: should the briefing list all 18 objectives, or a subset? Ask the PO or rule on it.
* Real-GPU perf probe (D-111): it needs hardware outside the cloud containers. Ask the PO.
* The self check-in trigger was disabled at handoff. Re-arm one (`lead_playbook.md` §4).
