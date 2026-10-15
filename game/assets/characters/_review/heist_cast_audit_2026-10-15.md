# ENV D heist cast audit (D-115): design roles vs delivered characters and clips

Read-only audit, 2026-10-15, working tree `env/d-art` @ 144eec9d (includes trunk merge 2d357da0; trunk tip seen locally: e6754c32 r214).

## Method and how visuals resolve today
- **What exists:**
  - Characters: 102 assembled ids in `game/world/characters/characters.json` (every id referenced anywhere exists, so there are no dangling ids).
  - Clips: 107 in `char_anim_humanoid` (SOURCE.txt `clips: 107`).
  - Hand-prop grips in SOURCE: phone, mug, mop, book, rag, bottle, glass, cash and shield. There is **no cigarette grip**.
- **How an NPC gets its look:**
  - `game/systems/ai/npc/npc_visuals.gd` (ENV A) tries, in order:
    1. the SpawnPoint tag in `game/systems/ai/npc/npc_visual_tweak.tres`: `heist_tag_characters[heist]` first, then `tag_characters` (**exact tag match**);
    2. the EnemyDef;
    3. `role_characters`: guard = `security_officer`/`_b` (Halden), civilian = `civilian_customer_a/b`, `bank_customer/_b`.
  - Guards spawn with **no EnemyDef** (`heist_runtime._spawn_npc_at(&"guard")`), so every un-tagged guard in every heist wears Halden.
- **Who owns what:** the tag map is owned by ENV A. ENV D owns `game/world/characters/p5_cast.json`, which today covers only P5 heists (gallery_night, ostrander_federal, rolling_thunder, afterhours).
- **How clips play:**
  - `game/systems/anim/anim_driver.gd` `HINT_CLIPS`/`FALLBACK_CLIPS`: every clip name it references exists in the library.
  - `game/systems/ai/civilian/civilian_brain.gd` `KNOWN_ACTIVITIES`: browse, phone, desk_work, queue, sit, mug, mop, phone_seated, inspect, text, bartender, bartender_pour, bouncer, dance, teller. **Any other spawn `idle_activity` plays plain `idle`.**
- **Hand props (all heists):** no runtime code attaches any hand prop. No `*_grip` is read in `game/systems`/`game/world`. There are also no hand-held phone, cigarette, string-mop, tray or clipboard assets (only `prop_mug`, `prop_mop_bucket`, desk/wall phones). So every phone call, smoke, mop and teller count is mimed.

---

## 1. Golden Hour (`glasshouse`): design `docs/design/heists/glasshouse.md` §Civilian roster

**(1) Roles → character**

| Design role | Spawn tag | Character today | Verdict |
|---|---|---|---|
| Floor guard, BOH/upper rovers, alley smoker (Halden) | guard_post_floor / guard_rover_boh / guard_rover_upper / guard_alley_smoker | role → `security_officer`, `security_officer_b` | OK |
| Camera operator (P2) | security_operator | `security_officer` (peaked cap, seated) | OK. The bare-headed `npc_bank_guard` would read better seated (optional) |
| Sales associate ×2 (counter, floor) | civ_staff_counter, civ_staff_floor | both `civilian_sales` | **Identical twins**: there is only one associate look |
| Admin clerk (upstairs) | civ_staff_admin | `civilian_sales` | **Wrong role look**: a third copy of the shop-floor dress |
| Jeweler | civ_staff_workshop | `civilian_jeweler` | OK |
| Manager **Greta Vossberg** (rare `nervous_manager`) | civ_staff_manager | `civilian_manager` = **male**, navy blazer (gender 0.0) | **MISMATCH**: the design names a woman |
| Customers 2–5 | civ_customer | `civilian_customer_a/b` (2 looks) | Thin: 5 customers from 2 looks. The tag ignores `bank_customer/_b` |

**(2) Clips/activities**
- Present: desk_work, browse, phone→phone_call, sit→sit_chair, queue→idle, smoke (guard pause), cower/flee/hands_up/tied, seated deaths.
- No clip is missing.

**(3) Visual tags**
- Present: Halden livery, the associates' brass badge, the jeweler's loupe and apron.
- Missing: Greta herself (owner/manager, female).
- Keycards are world pickups (kc_* slots), so no NPC needs one on its model.

**(4) Code refs to missing ids/clips:** none in glasshouse.tscn.

**(5) Gaps**
- **D-GH-1 (P1):** `civilian_manager_greta` (or rebuild `char_civilian_manager` as a woman per the design): owner/manager, ~55, tailored suit.
  - Build: a variant in `tools/blender/characters/char_civilians.py`, then assemble.
  - Ask A to map `civ_staff_manager` to it.
- **D-GH-2 (P2):** `civilian_sales_b` (male or different-age associate) and `civilian_clerk` (admin office wear, e.g. cardigan + lanyard, a recolour of `gallery_admin`'s cut).
  - Ask A: `civ_staff_floor` → sales_b, `civ_staff_admin` → clerk.
- **D-GH-3 (P3):** add a `glasshouse` block to p5_cast.json (or a new `heist_cast.json`) so the tag→cast map is D-authored and test-checked. Customers can add `bank_customer`/`_b` (no new art).

## 2. Nightfall Depository (`night_deposit`): design `docs/design/heists/night_deposit.md` §Civilian and guard roster

**(1) Roles → character**

| Design role | Spawn tag | Character today | Verdict |
|---|---|---|---|
| Hall / basement guards, rovers (Halden) | guard_hall, guard_basement, guard_rover_* | role → `security_officer/_b` | OK |
| Camera operator | security_operator | `security_officer` | OK. `npc_bank_guard` (Halden **night-shift**, bare-headed, built "also as the seated camera operator") exists but is **unused** |
| Cleaner | civ_cleaner | `npc_bank_cleaner` | OK |
| **Night manager** (code carrier `code_on_manager`) | civ_manager | `civilian_manager` (Glasshouse's male blazer) | **WRONG**: `npc_bank_night_manager` (older woman, bank-red suit, built for this role, D2-02) is **unreferenced** |
| Armoured-car guards ×2 (`armored_car_early`, scripted) | guard_armored_car | role → `security_officer` | Weak: `armored_car_crew/_b` (Vaultline) exists and would read as the cash crew |

**(2) Clips/activities**
- Present:
  - mop: cleaner `browse` → `mop` via `anim_driver._ambient_hint` (`civ_cleaner*`);
  - desk_work;
  - mug (the coffee break in G4) and `mug_carry_walk` both exist. The driver maps `mug_walk` to `mug_idle`, so `mug_carry_walk` never plays (ENV A).
- Missing (optional): the cleaner "works a route with a cart" (design l.493). There is no `cart_push_walk` clip.

**(3) Visual tags**
- Present:
  - the bank livery on the night manager (keyhole lapel badge);
  - the Halden night variant on `npc_bank_guard`;
  - the cleaner's tabard and yellow gloves.
- Missing: none on the models. The only problem is that the existing models are not wired.

**(4) Code refs:** none broken.

**(5) Gaps**
- **D-ND-1 (P1, wiring only, no art):**
  - Cast `npc_bank_night_manager` as the night manager.
  - Request A: `heist_tag_characters.night_deposit = {civ_manager: [npc_bank_night_manager], security_operator: [npc_bank_guard], guard_armored_car: [armored_car_crew, armored_car_crew_b]}`.
  - D records the same in its cast file.
- **D-ND-2 (P3):** a `cart_push_walk` loop (1.0–1.2 m/s, hands on a 0.95 m cart handle 0.5 m ahead) for the ND and SL cleaners, if C/A make the cart move.

## 3. Dockside Burn (`dockside_burn`): design `docs/design/heists/dockside_burn.md` §Cartel, civilian and police roster

**(1) Roles → character**

| Design role | Spawn tag | Character today | Verdict |
|---|---|---|---|
| Co-op cartel gunmen (7 posts, reinforcements) | cartel_* (EnemyDef `enemy.cartel_gunman`, `visual_alternates` b/c) | `cartel_gunman`, `_b` (hood), `_c` (deckhand) | OK |
| **Night-shift workers 1–3** (forklift drivers, a packer; the hostages) | civ_worker ×6 spawns | `npc_bank_teller`, `npc_bank_teller_b`, `bank_officer` | **WRONG**: bank tellers in waistcoats and skirts, and an officer in a skirt suit, on a fish-pier night shift |
| Police / specials | director | police roster + faction variants | OK |

**(2) Clips/activities**
- Present:
  - cartel: `idle_thug` (calm), smoke (gate/quay pause), sit (M2);
  - workers: browse ("forklift / packing"), cower, tied/kneel_cuffed (hostage trades).
- Missing (optional): a packing/pallet-wrap loop (`interact_mid` exists, but no wrap clip). This is not required.

**(3) Visual tags**
- Missing: worker kit, i.e. hi-vis, a freezer jacket or hard hat for the forklift drivers, and a white coat, hairnet, apron and rubber boots for the packer. No character carries it.
- Present: the Co-op gunmen looks.

**(4) Code refs:**
- 11 patrol points use `pause_anim = "look"` (`dockside_burn.tscn`). `look` is in neither HINT_CLIPS nor the library, so they play `idle`; `investigate_look` was probably meant. This is ENV A's to fix, or it can be aliased.

**(5) Gaps**
- **D-DB-1 (P1):** `dock_worker` + `dock_worker_b` (forklift drivers: hi-vis vest over a padded freezer jacket, beanie or hard hat, work trousers, safety boots; a mix of genders and ages).
  - Also `dock_packer` (white processing coat, hairnet, rubber apron, white wellies, blue gloves).
  - New script `tools/blender/characters/char_dock_workers.py`, then assemble and run `test_p5_cast`-style checks.
  - Ask A: `civ_worker` → [dock_worker, dock_worker_b, dock_packer] (at least as `heist_tag_characters.dockside_burn`, since `civ_worker` may be reused).
- **D-DB-2 (P3):** an optional `pallet_wrap` loop for the packer and drivers.

## 4. Shadow Ledger (`shadow_ledger`): design `docs/design/heists/shadow_ledger.md` §Staff, civilian and guard roster

**(1) Roles → character**

| Design role | Spawn tag | Character today | Verdict |
|---|---|---|---|
| **Northgate Executive Protection** guards (reception, L41/L42 rovers, fire watch, roof) | guard_reception / guard_rover_l41 / guard_rover_l42 / guard_stair / guard_roof | role → **Halden** `security_officer/_b` (peaked cap) | **WRONG**: `npc_northgate_guard` and `_b` (charcoal suit, earpiece, gate lapel pin) exist and are **unreferenced** (D-103 §3b.1 named this exact fix) |
| Camera operator (Northgate) | security_operator | `security_officer` (Halden) | **WRONG**: should be `npc_northgate_guard(_b)` |
| Cleaners L41/L42 | civ_cleaner_l41, civ_cleaner_l42 | **role civilian → customers** (exact-match tag lookup misses `civ_cleaner`) | **WRONG**: `npc_cleaner_sl` (Calder teal tabard) exists and is **unreferenced**. Mop still plays (`begins_with("civ_cleaner")`) |
| IT contractor | civ_it | `npc_it_contractor` | OK |
| **Helena Moor** (late partner) | civ_partner | `bank_officer` (Ostrander officer, skirt suit) | **WRONG**: `npc_helena_moor` exists and is **unreferenced** |
| Victor Kessler (rare sleepover) | civ_kessler | `npc_kessler` (robe) + `sit_bed_read` | OK. `npc_kessler_coat` unused (fine) |

**(2) Clips/activities**
- Present: browse→mop (cleaners), desk_work (rack console), phone (Moor), sit→sit_bed_read (Kessler), smoke (roof guard pause).
- None missing.

**(3) Visual tags**
- Missing in game (the models have them, the tag map does not use them):
  - Northgate suit, earpiece and lapel pin;
  - the IT contractor's visitor lanyard (this one is shown);
  - Moor's reading glasses and ivory blouse.
- Moor's phone is "a prop" in her SOURCE, but none is attached (see the props note above).

**(4) Code refs:**
- `pause_anim "desk"` at K3Desk (`shadow_ledger_layout.gd:611`, the seated reception guard) is not mapped, so it plays standing `idle` behind the desk. It should be `sit_chair_watch` or `desk_work`.
- `"look"` at M3West: same problem as DB.
- Both are ENV A's to fix.

**(5) Gaps**
- **D-SL-1 (P1, wiring only):** request A to add `heist_tag_characters.shadow_ledger`:
  - guard_reception / guard_rover_l41 / guard_rover_l42 / guard_stair / guard_roof / security_operator → [npc_northgate_guard, npc_northgate_guard_b];
  - civ_cleaner_l41 / civ_cleaner_l42 → [npc_cleaner_sl];
  - civ_partner → [npc_helena_moor].
  - D records it in its cast file and adds a test that every SL roster role has a cast.
- **D-SL-2 (P2):** `npc_cleaner_sl_b` (a second cleaner face/gender), because Brutal runs 2–3 cleaners in identical outfits.

## 5. Gallery Night (`gallery_night`): design `docs/design/heists/gallery_night.md` §Guard, staff and civilian roster

**(1) Roles → character**
- OK:
  - hall/ground/basement rovers → `gallery_guard`; upper rover, mews smoker, operator → `gallery_guard_b`;
  - inspectors → `gallery_guard` (per QC-58d); Vaultline couriers → `armored_car_crew/_b`;
  - curator → `gallery_curator`; attendants → `gallery_attendant`; conservator → `gallery_attendant_b`;
  - waitstaff → `npc_penthouse_staff`; patrons → `gallery_patron/_b` + `npc_penthouse_guest_a/_b`.
- **WRONG: Admin PA.** The spawn tag is `civ_admin`, which maps to `npc_penthouse_guest_a` (a teal cocktail dress) in `npc_visual_tweak.tres`. `gallery_admin`, built for this role (50265303), is mapped only under the patrol tag `staff_admin`, which the spawn does not carry.

**(2) Clips/activities**
- Clips: curator_inspect, cower_stand, cower_seated, walk_text, smoke, desk_work, death_seated_*, carry_bag_walk (Vaultline bag carry) all exist.
- But three spawn `idle_activity` values are not in KNOWN_ACTIVITIES, so they play `idle` at spawn:
  - `curator_inspect` (curator, gallery_night.tscn; the brain knows it as `inspect`);
  - `walk_text` (waitstaff; the brain knows `text`);
  - `smoke` (the court patron).
- Also: `anim_driver` maps `text`/`walk_text` to `phone_call`, so the `walk_text` clip never plays.

**(3) Visual tags**
- Present: Halberd crest + bottle-green blazer, curator lanyard + keycard (QC-52 carrier), white art gloves, Vaultline patches, the admin's wine staff lanyard.
- Missing (props): a waitstaff tray/glass, and the patrons' cigarettes for the court smokers.

**(4) Code refs:**
- 12 `pause_anim "look"`, including `guard_hall`'s post (design l.506 says `look`). This is unmapped, so it plays idle.

**(5) Gaps: see the GN-D section below.**

## 6. GN-D items (`docs/process/next_heist.md` §6 lists only GN-D1)

| Item | Status | Remaining |
|---|---|---|
| GN-D1 cast: curator, attendants (+conservator), guards, gala patrons, waitstaff, Vaultline, admin PA | **DONE (art)**: every role has a character (`p5_cast.json` v2, test_p5_cast) | — |
| GN-D1 gala clips (curator_inspect, cower_stand/seated, walk_text, smoke, desk_work, seated deaths) | **DONE (art)**, characters.md v1.9/v1.11 | Playback gaps are ENV A's (§5(2)). D should hand A the exact list |
| GN-D1 "+ NpcVisualTweak tag map" | **PARTIAL** | `civ_admin` → `npc_penthouse_guest_a` must become `gallery_admin`. The map lives in ENV A's file, so D files the request |
| GN-D1 polish (heist_completion "cast polish") | OPEN, optional | GN-D-a: a waitstaff tray + glass hand-prop scene (grip already in SOURCE: `glass_grip`). GN-D-b: a cigarette prop + `cig_grip` in SOURCE for `smoke` (also used by GH/DB/SL guards). GN-D-c (P3): a distinct conservator look (lab coat/apron) instead of reusing `gallery_attendant_b` |

## 7. Cross-heist gap list (prioritized, for heist_completion.md rows)

| id | heist | owner | gap | what D builds |
|---|---|---|---|---|
| D-SL-1 | shadow_ledger | D→A | Northgate guards/operator, SL cleaner and Helena Moor exist but are unmapped (they wear Halden, customer and Ostrander-officer looks) | No art. D authors the cast entries; A adds `heist_tag_characters.shadow_ledger` |
| D-DB-1 | dockside_burn | D (+A map) | Night-shift workers wear bank teller/officer outfits | New `dock_worker`, `dock_worker_b`, `dock_packer` |
| D-ND-1 | night_deposit | D→A | Night manager wears Glasshouse's male manager; `npc_bank_night_manager` unused; armoured-car guards are Halden instead of Vaultline; operator could be `npc_bank_guard` | No art. Map request |
| D-GN-1 | gallery_night | D→A | `civ_admin` → `npc_penthouse_guest_a` instead of `gallery_admin` | No art. Map fix |
| D-GH-1 | glasshouse | D | Greta Vossberg (female owner) is played by a male model | New `civilian_manager_greta` or a rebuild |
| D-ALL-1 | all | D + A (+C) | No hand props are attached (phone, mop, mug, cigarette, tray, cash, rag/bottle/glass, book). Grips exist except the cigarette | D: hand-prop scenes under `world/characters/_props/` (D-owned) + `cig_grip` (and a tray grip) in anim SOURCE. A: attach at `HandR/HandL/Socket` per clip |
| D-ALL-2 | all | D | No D-owned cast file for the 4 pre-P5 heists, so nothing tests that every roster role has a cast | Extend `p5_cast.json` (or a new `heist_cast.json`) with glasshouse / night_deposit / dockside_burn / shadow_ledger, + a test |
| D-GH-2 | glasshouse | D | Associates ×2 and the admin clerk all wear `civilian_sales` | `civilian_sales_b`, `civilian_clerk` |
| D-SL-2 | shadow_ledger | D | 2–3 identical cleaners on Brutal | `npc_cleaner_sl_b` |
| D-ND-2 / D-DB-2 | nd, sl, db | D | No cart-push or pallet-wrap loops | `cart_push_walk`, `pallet_wrap` (optional) |
| D-GN-c | gallery_night | D | Conservator reuses the attendant look | Optional new look |

**ENV A follow-ups found (not D's work; for the LEAD to route):**
- `pause_anim "look"`: DB ×11, SL ×1, GN ×12. `"desk"`: SL K3Desk ×1. Both play idle.
- Spawn `idle_activity` `curator_inspect`, `walk_text`, `smoke` are not in `KNOWN_ACTIVITIES` (GN).
- `HINT_CLIPS` maps `text`/`walk_text` to `phone_call` (the `walk_text` clip never plays) and `mug_walk` to `mug_idle` (`mug_carry_walk` never plays).
- Exact-match tags miss `civ_cleaner_l41/_l42`.
