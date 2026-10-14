# CAPERWORKS handoff: start here (written 2026-10-14 by the outgoing LEAD)

This folder is the single entry point for a **new Claude session** taking over the project, as LEAD or as a
fresh env session. Read it top to bottom, then the files it points to. Everything durable is in `docs/` on
trunk. If something here contradicts `docs/decisions.md`, the decision log wins.

| File | What it holds |
|---|---|
| `README.md` (this) | Project state, team model, workflow, best practices, lessons learned, what's next |
| `in_progress.md` | Every open work item per env, with status, branch, next step and blockers (from each env's HANDOFF) |
| `lead_playbook.md` | How the LEAD runs the loop: merging, testing matrix, rulings, check-ins, spawning sessions |

Each env's own detailed handoff is the `## HANDOFF 2026-10-14` section at the top of `docs/status/env_<x>.md`
**on that env's branch** (merged to trunk at handoff where possible).

---

## 1. What the project is

**CAPERWORKS**: an original co-op heist game in **Godot 4.7.2** (typed GDScript) with Payday 2–faithful
mechanics. There are no third-party art or audio assets: everything is procedural or built with our own
Blender/texgen/audiogen tools. Third-party *code/tools* are allowed and recorded in `docs/third_party.md`.

Start with `CLAUDE.md`, then `docs/architecture.md`, `docs/roadmap.md`, `docs/design/pd2_fidelity.md`,
`docs/contracts/README.md`, `docs/decisions.md` (newest at the bottom; next id **D-114**).

### Heists
| Heist | Id | Stage | Notes |
|---|---|---|---|
| Golden Hour | `glasshouse` | final art | Gate 1 (loud) + Gate 3 (stealth) PASSED |
| Nightfall Depository | `night_deposit` | final art | Gate 2 (`auto_loud`) not yet passed; failures since attempt 15 were harness/crew-AI, all fixed. Best run: attempt 23 (bag 1 secured, bag 2 in transit, no game bug), budget-bound on llvmpipe |
| Dockside Burn | `dockside_burn` | greybox + full material pass (D-111) | skins + slab/wall tiling done |
| Shadow Ledger | `shadow_ledger` | greybox + full material pass | skins + tiling done |
| **Gallery Night** | `gallery_night` | **G1 greybox + full mission logic + props + lighting** | the heist being built (D-110); G2 art pass next |

### Where the project stands (trunk round 199, `9938fe24`)
* **The freeze is lifted for new content** (D-110). Gallery Night is playable end to end in greybox:
  mission script (last call, lockdown, loud hack, rare spawns, intel), props, lighting, validated on all variants.
* **D-111 polish gate** (must hold before the *next* heist after Gallery Night starts), from the product owner:
  1. Firing range out of "experimental": DONE (B UI + C room dressing).
  2. Menus decluttered: DONE (B, every listed screen; style rules in `docs/design/ui/style.md` §11).
  3. Animations actually play: triggers DONE (A: hit reacts, death variety, 8-way, starts/stops, crew crouch, NPC reload,
     drill_place, downed_crawl, ambient clips). Remaining: P re-runs the coverage probe to confirm.
  4. More masks/heisters: 8 masks DONE (all unlockable once B merges); heisters Marten + Jay DONE (art); Jay's roster
     entry is on B's held branch.
  5. Other heists' props lacked real assets/textures: equipment + throwables DONE (C); SL/DB doors, loot stacks and
     interactable wiring are IN PROGRESS (C, `docs/levels/_art/prop_art_inventory.md`).
* **D-112:** `max_renderable_lights` 256; D-038 amended (library "black" albedo lifted).
* **D-113 (product owner): more blood/gore + gritty muzzle flash.** Plumbing DONE (EventBus `blood_hit` / `bleed_changed`,
  `SHOT_FX_STRONG`, A's BloodFx emits, B's gore option `gameplay/gore`); C's VFX and P's FP flash are IN PROGRESS.
* **Product owner's most visible open complaints** (top priority for the next session):
  1. **FP weapons render near-black** ("untextured"). P proved it's the weapon *material* (not lights/layers): swapping
     the arms' material onto the gun lights it fully. Bisecting which texture (ORM/normal/albedo) is the culprit; the fix
     belongs to C (shared library `world/materials/*.tres` + texgen).
  2. **Long-gun support hand**: fingers clip and the grip doesn't cradle the gun. See the PO reference spec in
     `in_progress.md` §D. P's `PFingerClip` measures it (thumb 4–12 mm inside every long gun, index up to 6.4 mm).
     D owns the rework.

---

## 2. Team model (team v3, D-086 + D-110)

One **LEAD** Claude Code cloud session orchestrates five env sessions. Each is its own cloud container and clone,
and pushes only to its own branch. The LEAD merges env branches into **trunk = `claude/dreamy-hamilton-pc7vck`**.

| Role | Branch | Owns (authoritative: `tools/ci/owners.json`) | Manual |
|---|---|---|---|
| LEAD | `claude/dreamy-hamilton-pc7vck` (trunk) | architecture, `docs/` (except status files), `game/contracts/**`, `game/core/**`, `project.godot`, CI, `game/tests/integration` + `tests/lead` | `docs/process/communication.md` |
| ENV A, Core Systems & Heist Loop | `env/a-core` | `game/systems/**` (minus P's), mission scripts `*_mission.gd` + HeistDef node wiring, `game/tests/a/**` | `envs/a_core/CLAUDE.md` |
| ENV B, Content & UI | `env/b-content` | `game/content/**` (all UI, data defs, strings, weapons, range scene), HeistDef content values, `game/tests/b/**` | `envs/b_content/CLAUDE.md` |
| ENV C, Worlds & Art | `env/c-worlds` | `game/world/**` (maps, generators, props, materials library, VFX, audio), `game/assets/**` except weapons/characters, tools/blender (non-char), texgen, audiogen, levelcheck, `docs/levels/**` | `envs/c_worlds/CLAUDE.md` |
| ENV D, Characters & Animation | `env/d-art` | `game/world/characters/**`, `game/assets/characters/**`, masks, `tools/blender/characters|masks`, `char_*` materials, `game/tests/d/**` | `envs/d_art/CLAUDE.md` |
| ENV P, Player & Feel | `env/p-play` | `game/systems/player/**`, `game/systems/anim/fp_viewmodel*`, `crew_tweak.*`, `game/tests/p/**` (incl. review harnesses `tests/p/_review/`) | `envs/p_play/CLAUDE.md` |

Ownership clarifications made this session:
* **Map generators, layout, scene and level data under `world/heists/**` are C's**; `*_mission.gd` and their node
  wiring are A's; HeistDef *content values* are B's (GH/ND/SL defs are generator output: edit the generator rows).
* Weapon glbs (`assets/weapons`) are B's, but their **materials** come from C's shared library mapped at import.
* `fp_left_hand_ik.gd` is A's (`systems/anim`), not P's (P owns only `fp_viewmodel*`).

Session ids at handoff (they may be stopped/archived; new sessions get new ids):

| Role | Session id |
|---|---|
| LEAD (outgoing) | session_014E3p2DmSYTneJjytGwKKfc |
| ENV A | session_015kTjrZsUFn7gLqNVwAXdkh |
| ENV B | session_0159qCTRV9CsDQs465nGSW28 |
| ENV C | session_013uMHd1Npqkx1reY1pJMaye |
| ENV D | session_01EZDt9WkE187YkB8ANEbuhb |
| ENV P | session_01FYVVhNtxKAoQmyfnZ9rb3t |

---

## 3. How work and communication flow

```
 Product owner ──feedback──▶ LEAD ──rulings (docs/decisions.md), dispatches (send_message)──▶ envs
                               ▲                                                              │
                               └──── "pushed <sha>; checks; evidence; asks" (send_message) ◀─┘
 envs push env/<x> ──▶ LEAD fetches, merges --no-ff into trunk, runs TARGETED tests, updates board, pushes
```
* **send_message** (claude-code-remote MCP) is the transport. Messages arrive on the recipient's next turn: put
  everything needed in one message. Envs report after every push: sha, checks run, windowed evidence path, asks.
* Envs may message **each other directly** for technical coordination (string keys, API shapes, marker positions)
  and cc the lead. Anything touching contracts, ownership or priorities goes through the lead.
* **Rulings**: the LEAD decides unless it truly needs the product owner (scope, taste calls they've expressed,
  external accounts). Every ruling goes into `docs/decisions.md` or a contract on trunk the same turn.
* **Board**: `docs/process/board.md` (lead-only) has the round log (newest at top), sessions, open questions.
* **Each env uses subagents/worktree "lanes"** for parallel work inside its container. Lanes merge into the env
  branch only when green; unfinished lanes go to `wip/<env>-<topic>` branches, never red onto `env/*`.
* **Check-ins**: the outgoing LEAD ran a self check-in routine (`trig_01C54oQhiA9n1rbdYEKhKGMY`, one-shot
  re-armed each check-in, ~50 min). It's disabled at handoff. A new LEAD creates its own (see `lead_playbook.md`).

---

## 4. Best practices (hard-won this session; follow them)

**Merging and testing**
1. **Targeted tests only (D-088)**, but choose them by what the change *touches*, not just the env:
   * FP / viewmodel / arms / weapon scenes: `p test_po4_feel`, `test_p1_01`, `test_p1_03`, `test_p_finger_clip`,
     `d test_arms`, `a fp_viewmodel`.
   * Characters / masks: `d test_masks`, `test_crew`, `test_scenes`, `test_p5_cast`, `test_npcs`, `b test_mask*`.
   * UI broadly (menus/HUD): **the whole `b` dir** (`run_tests.sh b`, ~930 tests, ~10 min).
   * Maps / generators / prefabs / **levelcheck rule changes**: `tools/levelcheck/validate_all.sh` on **all 5 maps**
     (a rule or prefab change affects every map), plus `c test_<map>_map`, `test_generator_determinism`,
     integration `test_heist_readiness`.
   * **A heist going live, or anything enumerating heists**: also `b test_music`, `test_contact_radio`, `test_board`,
     `test_preplan*`, `test_strings`. (Round 165 left `test_music` red because this was missed.)
   * AI / anim / combat: `a anim_driver`, `l6_`, `l2_`, `crew_ai_formation` + integration `test_p3_loud`, `stealth`.
   * Always: `check_banned.py`, `gdlint` on changed `.gd`, `check_ownership.py <env>` (per env branch; it fails
     spuriously when two envs' merges are stacked locally, so check each branch's diff vs trunk separately).
2. `run_tests.sh <dir> <filter>`: dir is relative to `game/tests` (`a`, `b`, `integration`), not `game/tests/a`.
3. **Look at what a branch contains before merging it.** Env branches can carry red WIP (D's Jay WIP) or a change that
   needs another env's change (B's LeftHandIK / SMG markers need D's clip re-time). Then either merge both together
   or `git cherry-pick -x` the green commit. Never push trunk red.
4. **Merge string/test-dependent pairs together** (A's new string keys + B's strings; C's def values + B's strings;
   C music row + B test).
5. **Test runs can re-save `.tres` files of other envs** (Godot property reordering). Check `git status` before every
   commit and `git checkout -- <file>` anything you didn't mean to change. Don't sweep it in with `commit -a`.
6. Long runs (validate_all ~6 min, full `b` ~10 min, `p3_loud` 5–20 min under CPU contention) go in the
   **background**: wait for them to finish before pushing. Don't push a half-tested stack.
7. `check_banned.py` flags hard `res://world/...` paths outside C: use `G.*_DIR` constants in `contracts/ids.gd`
   or class-name lookups.

**Product-owner work**
8. The PO plays the game and reports what *looks* wrong. Before telling them something is fixed, **look at the
   evidence image yourself** (Read the png). Round 190's "fixed" grip still clipped; the PO caught it.
9. Translate reference images into a written spec for the env (envs can't see images in your chat).
10. Send the PO before/after images with `SendUserFile` when a visible change lands.
11. Measure before redesigning: P's probes (anim_coverage, vm_light_probe, PFingerClip, spike_probe) turned vague
    complaints into exact causes several times.

**Rendering facts (Compatibility renderer, llvmpipe in containers)**
12. 8 lights per mesh (`max_lights_per_object`): big floor/wall meshes go dark; C tiles slabs/walls into 6 m pieces.
13. 256 renderable lights per view (D-112). Windowed captures on llvmpipe are slow (minutes per lit frame).
14. Real-GPU perf has never been probed. That's an open risk (VFX, water, triplanar materials, tile counts).

---

## 5. What's next (priority order for the new LEAD)
1. **Collect and merge the handoff pushes** listed in `in_progress.md` (A, B+D together, C, P), with targeted tests.
2. **PO-visible fixes first**: FP weapon material (P→C), long-gun support grip (D with P's PFingerClip as a hard
   assert), D-113 blood/gore + muzzle flash (C VFX, P FP flash). Then show the PO before/after images.
3. **Gallery Night to done**: A's `gn_stealth` / `gn_loud` e2e flows, P's windowed GN pass, C's G2 art pass
   (`docs/process/next_heist.md` §6, GN-C2), D's cast polish.
4. **ND gate 2**: run `auto_loud` attempt 24 on an **empty** box (nothing else running; frames were 2–14 s with
   tests in parallel). If it passes, gate 2 is closed.
5. **Finish D-111**: C's SL/DB prop wiring + doors + loot stacks (`docs/levels/_art/prop_art_inventory.md`),
   P's coverage re-run, real-GPU perf probe.
6. Only after D-111 + Gallery Night: start the next heist (candidates in `docs/process/next_heist.md` / roadmap).
