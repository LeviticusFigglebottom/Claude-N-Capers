# ENV B status: Content & Progression

Owner: ENV B. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

## To the LEAD: (updated 2026-10-21 19:25; send_message to you is refused, so read this)
-21. **Top-3 #3 done: the payday says when unlocks sit below the fold.**
     - **Change:** with more unlocks than one line holds (3), the panel header now reads **"ACHIEVEMENTS UNLOCKED: 6
       (3 MORE BELOW)"**; with 3 or fewer it stays the plain header. New string
       `ui.results.achievements_header_more`, plus `PaydayScreen.achievements_header`.
     - **Shot:** `r266_status_scrim/payday_d5_more_below_1920x1080.png` (OF Cataclysm, 1080p).
     - **Test:** `test_ui_payday` gains `test_header_counts_unlocks_below_the_fold` (6 vs 2 unlocks).
     - **Green:** `ui_payday` 15, `strings` 22, `ui_strings` 3, `achievements` 31.
     - **All three top-3 items are closed:** #1 scrims (53e3ce91); #2 a guard only, PD2 red kept (01bb2b2e); #3 this.
-20. **Top-3 #2 (jam colour): measured, smaller than I claimed; only a guard landed.**
     - **I was wrong in -18:** the colourblind palettes already turn `objective` into a light yellow, and PD2's
       red jam clears the CVD pair check (CIE76 >= 20 under every simulation) against every palette's objective.
       I proved it by putting the old red into every palette: `test_options_palettes` still passes.
     - **What landed:** `HudPalette.device_jam`, mapped to `HudTweak.device_jam_color`. It is **PD2 red in every
       palette** (no visual change), and [`objective`, `device_jam`] is now one of the CVD pairs the test guards,
       so a later palette or jam colour change cannot make them collide. Documented in `content/docs/options.md`.
     - **Green:** `options_palettes` 6 and `hud_palettes_new` 2.
     - **Next:** #3, the payday's "+N more" line for unlocks below the fold.
-19. **New: top-3 #1 done, HUD status text readable on bright scenes.**
     - **Fix:** a new strong label scrim (`UiBuild.LABEL_SCRIM_STRONG_ALPHA` 0.75; names keep the 45% one) under:
       - the vitals ARMOR / HEALTH captions (the value stays on the right, after a spacer);
       - a teammate's status line (Down / In custody / Last down / Civilian; hidden when empty, so no empty pill);
       - the downed overlay's DOWNED caption (hugging the word).

       The 45% scrim alone was not enough: on the bright backdrop ARMOR still measured 1.75:1.
     - **Fill gate before -> after:** HEALTH 2.94 -> pass, In custody 1.99 -> pass, DOWNED 1.27 -> pass, ARMOR
       (`hud_bright`) 1.75 -> pass. Contrast PASS on the loud and hud mocks; only the crosshair "+" keeps a note.
       These labels are scrimmed, so the gate now **fails** if any of them regresses.
     - **Shots:** `game/content/ui/_review/r266_status_scrim/`.
     - **Test:** the new `test_hud_status_scrim.gd` (3 tests) pins the scrims headless, and fails 3/3 on the old
       widgets.
     - **Green:** `hud_feedback` 7, `hud_frame_budget` 3, `hud_palettes_new` 2, `hud_queue` 7, `heisters` 9,
       `options_palettes` 6, `pp_hud_720p` 4, `pp_live_hud_720p` 4, `pp_subtitles_720p` 3, `ui_hud` 17,
       `ui_theme` 19, `ui_scoreboard` 13, `dropin_wiring` 9, `onboarding_card` 10.
     - **Next:** #2, the device jam colour in the colourblind palettes.
-18. **New: B's top 3 improvements for the shipped heists (your round 266 ask). Starting #1 now.**
     1. **HUD status text readable on bright scenes (accessibility, measured).**
        - **Problem:** the contrast worker's fill check still notes two live HUD labels under 3:1 on the bright
          backdrop: a teammate's **"In custody" at 1.99:1** (red status text, no scrim) and the vitals caption
          **"HEALTH" at 2.94:1**. Teammate names already got the r249 label scrim; their status line (Downed / In
          custody / Last down) and the vitals captions did not.
        - **Value:** "a teammate is down / in custody" is the call a crew must not miss. Bright scenes (DB at
          dawn, GN's white galleries, OF's limestone hall) are exactly where it fades.
        - **Fix:** scrim those labels; the fill gate then fails if they regress.
     2. **Device jam colour follows the colourblind palette.**
        - **Problem:** `HudTweak.device_jam_color` (red) is not in `HudPalette`, so deuteranopia / protanopia
          players get a red jam bar against the gold objective accent and the yellow paused one. The palettes
          remap detection, health and markers, but not the drill / saw / hack jam state.
        - **Value:** the jam is the most frequent loud call ("fix the drill"). It keeps its text cue, but the bar
          colour is the at-a-glance signal.
     3. **Payday: say when more unlocks sit below the fold.**
        - **Problem:** a Cataclysm OF clear unlocks 6 achievements, and only 3 show without scrolling.
        - **Value:** a "+3 more" line on the panel. It tells players their best moment has more to it; the focus
          scroll already works, but nothing says to use it.
-17. **New: the screen-text walk now covers every heist; all clean.**
     - **The test:** `test_of_screens_text` is renamed to **`test_heist_screens_text.gd`** (8 tests). It loops over
       `HeistCatalog.ids()` (GH, ND, SL, DB, GN, OF; a new heist in the catalogue is walked automatically) and checks:
       - the Board broker at 6 difficulties and every contract card;
       - the briefing at 6 difficulties;
       - the pre-planning board on every blueprint point, plus the crew assets;
       - the HUD line for every objective, each one waited for until it shows, with its `{args}` filled from its
         own string;
       - the Tab sheet;
       - the payday with all of the heist's achievements;
       - the achievements screen with every heist set unlocked.
     - **Result:** green on trunk r263, **no string problems in any heist**.
     - **Proof:** I broke one key per heist, each caught on its own screen:
       - GH `objective.glasshouse.keycard`: HUD line and Tab sheet;
       - ND `ui.preplan.point.pp_drop_quay`: that preplan point;
       - SL `heist.shadow_ledger.briefing`: briefing d0-d5;
       - DB `achievement.db_all_hands.name`: payday and achievements screen;
       - GN `heist.gallery_night.name`: broker d0-d5 and briefing.

       The file was restored afterwards (no diff).
-16. **Your two questions, answered.**
     1. **What the OF string sweep found: nothing.** I found no missing key, raw id, `{placeholder}` or dev tag on
        any OF screen: the Board broker / cards, the briefing at 6 difficulties, the preplan board on all 14 points,
        the HUD line for every objective, the Tab sheet, the payday with every OF achievement, and the achievements
        screen. The walk is `test_of_screens_text` (item -14). It is proven by breaking two keys on purpose, which it
        caught.
     2. **D-148 regression on trunk b0bd47a0: green, nothing out of reach.** Each suite ran once:
        - payday / progression: `of_payday_e2e` 7, `payout_calculator` 20, `xp_curve` 4, `heist_freshness` 14,
          `payday_sum` 2, `payday_cards` 10, `ui_payday` 14, `ui_progression` 3, `difficulty_unlock` 3;
        - menu reach: `menu_reach` 2, `reach_today` 5, `heist_readiness` 9;
        - briefing: `briefing` 38, `briefing_cap` 3, `briefing_intel` 14.

        **New `test_d148_pace.gd` (3 tests):**
        - **Every heist's first-clear level is pinned to progression_pace.md** at all 6 difficulties (L2...L19 for
          GH; L4...L22 for ND / SL / DB / GN; L6...L25 for OF), and it asserts every offered heist is pinned.
        - **Every level gate is reachable:** 36 weapons + 7 armors (max L45), the Board's L80 Lethal / Cataclysm
          gate and Notoriety's L100 all sit inside 0-100, with a finite XP cost (23.28 M to L100), and each is
          reached at its XP.
        - **A new player reaches every item unlock within 40 clears** (Routine, Tense, Hazardous rotations, then
          Brutal; the pace doc says ~32).

        The only gate that moved is the one already flagged: Board L80 now takes ~230 Brutal clears (it was 131). It
        is still the PO's call, kept at 80; B suggests 70.
-15. **New: AH values on paper, `game/content/docs/ah_b1_values.md`** (the same shape as RT-B1, for C's generator).
     - **What's in it:** HeistDef values; variant rows with per-difficulty weights (guard posts 1 / 2 / 3, crowd
       12-20, dance clusters 4-6, safe bags, lasers, camera operator); the 6 rare events with 4 surprise strings;
       the pre-planning block (**every AH asset already exists, nothing to build**); briefing steps; the
       `heist_tag_characters[&"afterhours"]` rows from the doc's roster; 15 point labels; ~28 voice lines; and 6
       achievements on existing condition keys.
     - **Corrections found** (all on paper; nothing in data):
       (a) **base_payout is $40k** (D-143, pinned by `test_p5_catalogue`), not the doc's and my plan's $75k.
       (b) The doc's HeistDef `escape_options [van, walk]` contradicts its own Escape section and D-075: should be
           `[van]` (C).
       (c) The doc's loot table still has the pre-D-120 values (C).
       (d) `ah_last_call` ("safe opened by code") needs the AH mission to record `open_method` on `[safe]`, as
           Glasshouse's does (C).
-14. **New: OF player-facing strings, walked headless on r262+: clean, nothing to fix.**
     - **New test** `tests/b/test_of_screens_text.gd` (7 tests). It instances the real screens and checks every
       visible Label / Button / RichText for raw keys (`objective.` / `ui.` / `item.` / `asset.` / `achievement.` ...),
       `{placeholders}`, dev tags and gate tags:
       - the Board's broker on OF at all 6 difficulties, plus every contract card;
       - the briefing at all 6 difficulties (88 texts on Hazardous, with its security and objective lists);
       - the pre-planning board, every OF point (14) and the crew assets;
       - the HUD line for each of OF's objectives, with the data the mission passes (drill 1/3, secure 2/4,
         time-lock and escape seconds); the test waits until each one's own text shows;
       - the Tab sheet with all objectives;
       - the payday with every OF achievement;
       - the achievements screen.
     - **The test is proven:** with two keys broken on purpose (one objective, one asset name) it fails with
       `hud keycard: 'objective.ostrander_federal.keycard'` and
       `preplan board: 'item.asset.intel_code_pc.name - $8,000, 2 favors'`. Restored afterwards.
     - **Also green:** the data-side string tests, `test_heist_text_audit` 5, `test_strings` 22 and
       `test_ui_strings` 3.
     - **RT allow-list:** noted as ruled "after the OF done check". The two exact lines are in `rt_b1_values.md` §10.
     - **Next:** the AH values on paper.
-13. **New: your payday nit ("Oxblood Her..."), fixed on r262.**
     - **Fix:** an achievement's "REWARD <name>" no longer ellipsises. The entry's top row is now a flow row, so a
       reward that doesn't fit beside the name moves, whole, to its own line under it. Splitting "Oxblood / Herald"
       across two lines looked worse, so I didn't do that.
     - **Shot:** `r262_of_payday_hub/payday_d5_1920x1080_reward_flow.png`.
     - **Test:** the new `test_ui_payday` test, `test_reward_names_are_never_truncated`, checks all six OF Cataclysm
       unlocks at 720p and 1080p. For every reward it asserts no trimming, every line shown, no word split, and the
       label inside its column. It fails on the old code.
     - **Green:** `test_ui_payday` 14, `test_achievements` 30, `test_achievements_in_play` 8.
-12. **New: OF done check, payday / progression on trunk 40ef789d (D-148 in place): PASS, plus one hub fix.**
    1. **`test_of_payday_e2e`: 7/7 green.** It runs the 5 earlier tests plus 2 new ones:
       - `test_d148_first_clear_levels_match_the_pace_table`: a first OF stealth clear (6 bags, crew of 4 alive,
         fresh profile, freshness as PaydayScreen applies it) lands on L6 / 11 / 18 / 23 / 24 / 25 from Routine to
         Cataclysm. That is **exactly progression_pace.md's D-148 table**. XP is 5,850 / 11,700 / 29,250 / 58,500 /
         67,275 / 81,900.
       - `test_coop_every_slot_gets_the_same_payday`: with 4 human slots, every slot gets the same contract, loot,
         total, XP and level at every difficulty.
       - The pace tool re-run on 40ef789d prints the same table: 23.28 M XP to L100, new-player path L17 ... L49,
         408 Cataclysm clears to 100. Also re-run and green: `test_ui_scoreboard` 13 and `test_ui_theme` 19.
    2. **1080p stills for the PO** are in `game/content/ui/_review/r262_of_payday_hub/`. They come from the new
       `tests/b/render/of_payday_hub_capture.gd`, which runs the real PaydayScreen, then the HubMenu, on a scratch
       profile.
       - **Hazardous:** $367,224. 29,250 XP takes the fresh profile 0 -> L18 ("Level up! Now level 18"), and it
         banks the stealth bonus. Unlocked: First Score and No Harm Done (my run answered 1 pager and took 21 min,
         so no Quiet Weekend / Bank Holiday).
       - **Cataclysm:** $1,299,408. 81,900 XP takes the profile to L25. It unlocks 6 achievements; 3 show and the
         rest sit below the fold (the r246 focus-scroll design). One reward name ellipsises ("Oxblood Her...") in
         the 3-column panel.
       - **Hub:** level, XP bar (1,205 / 4,151 to the next level), spending and stash all correct.
       - **Fixed (B):** the Armory card's "20 SKILL POINTS · 58 PERK POINTS" ran past the card at 1080p. The counts
         are now one per line, and the card grows. `test_hub` has a new test, 38/38 green; it fails on the old code.
       - **PO note:** one Hazardous clear gives 58 perk points at L18. Perk points are total XP / 500
         (`PerkPointTweak.xp_per_perk_point`), and D-148's bigger OF XP (5,850 vs 4,550 on Routine) raised them too.
         Worth a look in P6 balance; no change from me.
    3. **RT-B1 on paper, done:** `rt_b1_values.md` gains §7 strings and §8 voice. §7 has the 2 briefing steps, all
       13 `pp_*` point labels (the doc's pre-planning table), the 5 surprise strings and `asset.c4_drop`'s name and
       desc. §8 is a draft list of ~36 Mercer + Reyes lines by phase, using the doc's own two lines. Nothing is in
       data; all of it is ready for when the OF gate opens. Still open: the D-143.5 allow-list question in item -11.
-11. **New: ultrawide 3440x1440 + 16:10 + 1080p HUD pass (your 10:34 follow-up), and RT-B1 values on paper.** Shots: `game/content/ui/_review/r261_ultrawide/`.
    - **Did the 10:34 renders finish?** Only partly. The live OF `ui_audit_capture` at 3440x1440 timed out at 40 min on
      llvmpipe (rc 124) after shot 1 (casing HUD). That shot is fine: the HUD sits on the screen edges, the scrims
      show and nothing stretches. I stopped the 16:10 live run (same cost, no shots). **The live loud OF run at
      3440x1440 needs the GPU box**:
      `ui_audit_capture.gd -- <out> heist - ostrander_federal` with `--resolution 3440x1440`.
    - **Loud HUD mock at 3440x1440, 1920x1200 and 1920x1080** (`hud_contrast_capture.gd -- loud <WxH>`, new
      optional size arg; it uses the game's `expand` stretch, so a wider aspect gets a wider canvas and 16:10 a
      taller one). The banner stack, trade counter, objective, vitals, ammo, teammates, downed timer and prompts are
      all placed correctly at every size; nothing clips.
    - **One fix:** the Tab sheet was 43 px right of centre at every aspect. Its columns needed ~1,326 px, but its
      box was 1,240, so the sheet grew to the right only. I tightened the sheet's gaps and made the box 1,260 and
      centred, so it no longer meets the teammate panel. `test_ui_theme` now checks that the sheet fits its box
      and is centred.
    - The 720p contrast gate still passes. Thanks for the `_visible_rect` hotfix (4a28ff35); trunk r261 is merged.
    - **RT-B1 values** are in `game/content/docs/rt_b1_values.md` (paper, in QB-2 shape, for C). It covers the
      HeistDef values, the variant rows with per-difficulty weights, the 8 rare-event keys and their "surprise"
      strings, the preplan block (`asset.c4_drop` at 2,000 and 2 favors), the briefing steps, and the
      staff_diner / staff_booth tag rows.
    - **Payout correction:** RT `base_payout` is **$30k**, pinned by D-141.1 and `test_p5_catalogue`; the G0 doc
      and my rt_content_plan said $85k.
    - **Your call:** do I add the D-143.5 `heists = [&"rolling_thunder"]` allow-list rows to `signal_insider` and
      `intel_route` now (two lines in existing B files), or after the OF gate?
-10. **New: D-145 DB Tense on r257 (+ the engage fix), both cells done. For your lever ruling:**

    | Cell (headless auto_loud x1.0, solo + 3 bots) | Wins | Player downs (s1 / s2 / s3) | Median |
    |---|---|---|---|
    | Plain | **2/3** (s2 PASS 1226 s, s3 PASS 889 s; s1 custody 642 s) | 3 / 3 / 1 | 3 |
    | `--po5-doctor-bag` | **2/3** (s2 PASS 1273 s, s3 PASS 882 s; s1 custody 684 s) | 6 / 2 / 2 | **2** |

    The doctor bag meets the <= 2 median (s1 still loses: 6 downs, the bag twice). Seed 1 is the hard roll in both
    cells (custody at ~640-690 s). B's read: 2/3 + median 2 with a doctor bag is PD2-normal for Hard; if you want
    seed 1 to pass too, the Bulwark cap 3 -> 2 is the next lever (s2 fought 40 Bulwarks plain).
    Also pushed: **8cdcf64d GPU-19 HUD fix** (device timers / objective badges step below the banner + boss stack).
-9. **New: D-145 DB Tense PLAIN on r257 (+ the engage fix for s2): 2/3.** s1 custody 642 s (3 player downs); s2 PASS
   1226 s (3 downs, 5 revives, a long fight: 40 Bulwarks, 9 Stingers); s3 PASS 889 s (1 down). Player downs 3 / 3 / 1
   (median 3). **Doctor-bag cell running**: s1 custody 684 s after **6** player downs (the bag reset the down
   counter), s2 / s3 in progress; numbers here when done.
-8. **New: D-145 DB Tense on r257 (P's capsule fix), running, not idle.** Plain r257 x3: s1 custody 642 s (3 player
   downs), s3 PASS 889 s (1 down), **s2 crashed (signal 11) in A's harness**: `po5_pilot.gd engage()` resumes on a
   freed enemy after an await (same crash as my r256 doctor-bag s1). A's fix **60d8c6ab (env/a-core, harness only)
   is not on trunk yet: please merge it**. Now running in a scratch worktree (r257 + 60d8c6ab cherry-picked, not on
   env/b-content): plain s2 re-run (at t=683 s, crew all up, no crash), then the doctor-bag cell x3. Numbers here when
   done. r256 doctor-bag partial (before the fix): s1 crash, s2 custody 657 s (all_custody after 1 player down).
-7. **New: D-145 DB Tense on trunk r256 3312326b** (cap 1 Longshot + A's Longshot timing + revive fixes, headless
   auto_loud x1.0, solo + 3 bots, no doctor bag): **1/3**. s3 PASS 873 s (player downs 1); s1 custody 583 s and s2
   custody 664 s, both after the player's 3 downs (revives land: 5 and 3). Police 171 / 186 / 101, Longshots 2-3 per
   run, Bulwarks 11-21. Across the four Tense batches since the revive fix: 1/3, 2/3, 1/3, 1/3: Tense on DB still
   fails on the player's damage over the ~10 min loud phase. Next lever is A's / yours (damage grace, Stinger,
   health, or the opt-in doctor bag in the harness); B's data levers left: Tense Bulwark cap 3 -> 2 or Stinger 1 -> 0.
-6. **New: r255 note + DB Tense on trunk.** Your r255 message says the Longshot cap is on trunk, but **trunk
   e9c8744f still has `tense.tres` longshot 2**: my 8e88e851 (cap 1) and A's f01d11db (Longshot timing) both missed
   r255. env/b-content (417b4a75 = trunk r255 + the cap) is ready to merge. DB Tense x3 on that branch (cap only, no
   A timing, no doctor bag): **1/3** (s3 PASS 805 s, 0 player downs; s1 custody 570 s, 3 downs; s2 all_custody at
   684 s: a tase, a down, custody). With A's timing added (my run on A's f9b86af0 + the cap): **2/3**. So the
   ruling needs both commits on trunk; then I re-run on trunk.
-5. **New: D-148 XP option D applied** (xp_curve scale 1.0 = PD2's 23.28 M; `PayoutTweak.base_xp_by_heist`
   GH 1,500 / ND, DB 2,000 / SL, GN 2,500 / OF 3,000, failure XP from the same base; PD2 multipliers kept).
   Tests updated (xp_curve, payout_calculator + a D-148 test, heist_freshness: also fixed its stale v9 pin, the
   save is v10 since PO-19). Pace re-run and the **level-unlock re-check** in `game/content/docs/progression_pace.md`
   (D-148 section): every item unlock (<= L45) still comes within ~32 clears (was 24); **the board's level-80 Lethal /
   Cataclysm gate now takes ~230 clears (was 131)**: PO call, B suggests lowering it to 70 (135 clears = the old
   time-to-Lethal); not changed.
   **pd2_fidelity is yours (docs/design/):** suggested P1 "Ours" text: "Level 0-100, same point formula (120). XP
   curve: PD2's 900 -> 1,000,000 per level (~23.3 M), D-148. Base heist XP by size (S 1,500 / M 2,000 / L 2,500-3,000,
   PayoutTweak.base_xp_by_heist) + 250 per bag, PD2 difficulty multipliers."
-4. **New: D-145 DB Tense with the 1-Longshot cap (8e88e851) + A's Longshot timing (f01d11db) + nav fix: 2/3**
   (s2 PASS 1008 s, s3 PASS 865 s, s1 custody 599 s). Player downs 3 / 3 / 1 (median 3, target <= 2). No doctor bag.
   **New: RT content plan** (paper, no RT data): `game/content/docs/rt_content_plan.md`: def values (base $85k, D-148
   base XP 2,500), strings (13 objective keys exist; ~40 new: preplan points, briefing steps, rare events, mode label),
   ~35-40 VO lines (Mercer + Reyes), briefing/blueprint after C's G1, preplan (all assets exist except
   `asset.c4_drop`, needs A's QC-84), 6 achievements (5 on existing conditions, 1 needs a variant condition).
-3. **New: XP progression pace model for the PO: `game/content/docs/progression_pace.md`** (no data changed;
   docs/design/ is not B-owned). Script `tests/b/tools/progression_pace.gd` drives the real payout / freshness /
   stealth-bank / XpCurve code. Findings: XP is flat per heist (2000 + 250/bag x difficulty); our curve has PD2's
   endpoints (900 -> 1 M per level) at half PD2's 23 M total; 6 Routine clears = L21, one first Cataclysm clear =
   L26-29; level 100 = 221 Cataclysm / 310 Brutal / ~3,100 Routine clears rotating (grinding OF alone ~6x slower,
   D-139). Options A (curve x4), B (flatter multipliers), C (heist-size base), D (curve x2 = PD2 + size base;
   B's pick: first OF clear L6 / L25, 6 Routine clears L17, ~408 Cataclysm clears to 100) with tables.
-2. **New: GPU-9 review (gpu/renders/b): fixed on env/b-content.**
   - 1080p real-input OF (13 shots): clean. Loud OF HUD (6 shots): the Turret Van event marker clamped to the left
     edge drew its label off-screen ("URRET VAN") -> labels of objective and assault-event markers now stay inside the
     screen (ObjectiveMarkers.label_x; test_assault_events).
   - Loud payday at 720p: the third achievement description ran under the fold -> payday descriptions cap at 2 lines
     with an ellipsis (the trimmed tail repeats the REWARD line). Evidence _review/r252_gpu_review (before/after).
   - The 6 "QA ISSUE overlap" lines (payday title / Heist complete x the achievement toast) are rect false positives:
     full-width labels under the toast, no text overlap in the shots.
   - of_run_capture + crew_capture now keep profiles under user:// (they wrote profiles/ into the out dir).
   - For A (not B): with a saw running on the cash-cage padlock the prompt says "Press F to open / Can't do that right
     now" (ui.blocked.state); a device-running reason fits better, and B's ui.blocked.device_running string reads "The
     drill is running", so a per-device key (or a neutral "Already being cut") is needed if A switches to it.
-1. **New: D-144 next-heist prep notes (RT + Afterhours)**: `game/content/docs/next_heist_prep_rt_ah.md`. Both heists
   have only menu stubs on B's side (hidden heist_list entries, board, accents) plus objective strings for every doc
   tag (13 / 12); loot defs and contacts exist. Missing: everything map-derived (no world dir yet: intel, blueprint),
   voice lines (0), achievements (0), briefing step strings, music, def values. Order of work listed there.
0. **New: D-145 DB Tense on A's revive fix 0f317b90 + trunk e91fa3c0: 1/3, revives now land** (player revived 3/4/4).
   s2 PASS 1126 s; s1 custody 451 s and s3 custody 513 s, both after the player's three downs (not unrevived
   bleed-outs). Tense on DB now fails on player damage, not revive logic. r252 merged (c94bed27): briefing_intel 14,
   heist_text_audit 5, heist_readiness 9, of_payday_e2e 5, heist_achievements 13 all green on the final OF art.
1. **OF payday / achievement / progression e2e: PASS, no B data gaps.** New `tests/b/test_of_payday_e2e.gd` (5 tests):
   HeistRuntime-shaped results through PayoutCalculator, apply_heist_payout (XpCurve) and Achievements.on_payday on a
   fresh profile, every difficulty. Contract = $80k x (1 / 2 / 2.6 / 4.2 / 7.2 / 9.2) = the briefing preview; loot from
   the LootDef values; stash + spending = total; XP grows with difficulty; the stealth clear banks OF's x1.25.
   Stealth clear unlocks Quiet Weekend / No Harm Done / Bank Holiday (+ OF Cataclysm on d5) and grants vault_bolts,
   limestone, guilloche (+ vault_dial); loud breach with every bag unlocks Burn and Hoist / Clearing House (bronze,
   keystone); a failure pays and unlocks nothing (D-120); a second clear grants nothing twice.
   Numbers (stealth, 4 cash + 2 bonds, level-1 profile): d0 $138.6k / 4,550 XP / level 9 ... d5 $1.275M / 63,700 XP /
   level 29 (+ Offshore Million). **PO balance note:** one first OF clear takes a new player to level 9 (Routine) /
   21 (Hazardous) / 29 (Cataclysm): the XP curve and xp_mult, not a data gap.
2. **D-145 DB Tense on A's revive fix (df866e99 + trunk c04cb710): 1/3** (s3 PASS 1085 s; s1 custody 331 s, crew wipe;
   s2 custody 753 s). Sent to A: revive sessions open at <= 1.2 m but never complete (bot 3 held `sess=true` ~16 s on
   the downed player in s2; bot 2 ~8 s in s1). Re-run after A's next fix. Routine on r251 was 3/3 (entry below).
3. Windowed command lines for the PO's GPU box: entry 2026-10-21 00:30 below.

## 2026-10-21 02:00: D-145 DB cells on trunk r251 c04cb710 (headless auto_loud x1.0, solo + 3 bots)
- Routine: 3/3 PASS, player downs 2 / 0 / 0 (median 0 <= 2), no nav give-ups (A's doorway fixes hold).
  s1 926 s police 218 (bulwark 19); s2 1040 s police 135; s3 916 s police 103.
- Tense (after A's tuning): 0/3. s1 custody 331 s (police 46); s2 custody 785 s, 3 player downs, police 154
  (bulwark 27, stinger 7); s3 custody 360 s (police 50).
- Finding (sent to A): in s1 and s3 the player went down ONCE and no bot revived inside the 30 s bleedout
  (s1 down t=301 -> custody t=331, bot slot 1 tased just before; s3 down t=330 at the StairST landing -> t=360), with
  bots up. Tense now fails on bot revive priority / reach, not on damage.

## 2026-10-21 00:30: r251 merged; windowed command lines for the PO's GPU box (lead messages still refused)
- Merged trunk c04cb710 (r251) and imported. D-145 DB Routine + Tense x3 now running headless on trunk.
- edadb8ed evidence (_review/r250_label_scrim): OF facade with the label scrim, LIVE "TIME LOCK 03:27" and
  "ESCAPE 02:27" on the HUD (the escape countdown captured after all).

Windowed captures (from the clone root, after `godot --headless --path game --import`; prefix `xvfb-run -a` only
without a display; repeat with `--resolution 1920x1080`):
1. OF real-input menu pass (main menu to payday to hub, 15 shots):
   `godot --audio-driver Dummy --path game --resolution 1280x720 --script res://tests/b/render/real_input_run_capture.gd -- <out_dir> ostrander_federal`
2. OF HUD timers + label scrim: `... --script res://tests/b/render/of_timers_capture.gd -- <out_dir>`
3. Bot gear live (BOT MISMATCH / BOT DONE <n>): `... --script res://tests/b/render/bot_gear_capture.gd -- <out_dir> ostrander_federal`
4. Bot Crew screen + lobby AI cards (CREW DONE <issues>): `... --script res://tests/b/render/crew_capture.gd -- <out_dir>`
5. Payday achievements fold ("PROBE focused=AchievementsUnlocked"): `... --script res://tests/b/render/payday_fold_capture.gd -- <out.png>`
6. HUD contrast (CONTRAST PASS/FAIL; modes hud | loud | menus): `godot --audio-driver Dummy --path game --script res://tests/b/render/hud_contrast_capture.gd -- hud`
7. Loud OF HUD run with clip scan (too slow on llvmpipe): `... --script res://tests/b/render/of_run_capture.gd -- <out_dir> loud`
Most useful on a GPU: 7 at both sizes; 1 at 1920x1080 (here it hit the 30-min limit at 14/15).

## 2026-10-20 late: D-145 DB cells and HUD label scrim (lead messages blocked: untrusted-device)
send_message to the lead fails (elevated_session_untrusted_device), so this entry is the report.

### D-145 Dockside Burn (env/a-core 98e55725 + trunk fe567f9f merged in a scratch worktree; HEADLESS auto_loud x1.0,
solo + 3 bots, all slots corsair_ar / tailored_suit; downs = player / bot1 / bot2 / bot3)
- Routine: 2/3 wins, player downs 3 / 1 / 1 (median 1 <= 2), no nav give-ups.
  - s1 FAIL custody 610 s (combat: three downs in three places, last not revived). Downs 3/2/0/1. Police 131, peak 14.
  - s2 PASS 1070 s. Downs 1/0/1/0. Police 116, peak 14.  s3 PASS 989 s. Downs 1/0/0/0. Police 125, peak 13.
- Tense (pre-tuning, A softens it next): 0/3, player downs 3/3/3.
  - s1 custody 341 s, downs 3/0/0/0, police 64 (stinger 1).  s3 custody 422 s, downs 3/3/1/2, police 67 (stinger 3).
  - s2 custody 827 s, downs 3/2/3/1, police 133 (bulwark 20, stinger 6); FINDING burn marker unreachable again
    (the ChamberANorth leg, with C / A).
  - Re-run Tense x3 after A's next push.
- Before A's fix (trunk 14838b53) all three Routine seeds failed on pilot nav stalls (StairMezz doorway loop,
  GatehouseNorth shuttle): A fixed both in 98e55725.

### HUD label scrim (LEAD r249 narrow b): 55afe82c, evidence aacfa93e (_review/r250_label_scrim)
- UiBuild.label_scrim (45% black, radius 4) on world-marker labels and teammate names; objective block frameless.
  45% not 35%: white over near-white stone is ~2.4:1 at 35%, ~3.4:1 at 45%.
- contrast_worker fill_ratio >= 3:1 over mid / bright: a gate for scrimmed labels only. Frameless text measures
  1.0-1.4:1 on a flat bright backdrop by construction (a global gate would scrim the whole HUD); it prints NOTEs.
- hud contrast PASS; tests teammate, objective_marker, hud_palettes, pp_hud_720p, ui_theme.

## 2026-10-20: resumed for D-144 / D-145 (lead session_014E3p2DmSYTneJjytGwKKfc)
Resumed on env/b-content 29d30a2d (ff from origin; trunk rounds 204-244 ran in another account).

### Verified (no new content needed)
- OF-B1 already on this branch: e42c0f3b (OF un-hidden in heist_list, VO allowlists shrunk), 68e3e000 (r245 QA: HUD
  time-lock countdown, achievement fix, briefing intel). D-145 B items: 29d30a2d PO-19 Bot Crew loadouts (save v10),
  1f4d0594 PO-17 Routine/Tense corpsman/wrecker limit 0.
- Targeted tests green: heist_readiness 9, briefing_intel 14, p5_catalogue 7, crew_loadouts 8, crew_screen 3,
  save_golden 17, heist_text_audit 5, achievement 43, achievements_in_play 8, payday 55, strings 67, content_data 17;
  A's test_l4_11_special_caps 4, test_po5_director_caps 5.
- RED, not B's: test_vo_coverage (vo.mercer.ostrander_federal_captain_arrived, vo.accountant.radio_objective_new_1/2)
  until A's f326ad00 (origin/wip/a-of-a6) merges in the same round as e42c0f3b.
- Real-input OF run (real_input_run_capture.gd ostrander_federal) at 720p/1080p: exit 0, 15 shots, 0 RUN NOTEs.
  Bot Crew (crew_capture.gd) at 720p/1080p: 0 QA issues. Evidence: game/content/ui/_review/r246_of_real_input,
  r246_bot_crew.

### Later the same day (trunk r245 e219930b / r246 181957dd merged)
- 297e6624, 14b81ef3 PO-19 bot gear live check (tests/b/render/bot_gear_capture.gd): bots carry and fire the assigned
  primary / mods / armor / mask / outfit, 0 mismatches at 720p and 1080p; evidence _review/r246_bot_gear. LEAD then
  ruled default bots carry a rifle (A 09a2a165).
- f0a3c7ac test_heist_text_audit covers ostrander_federal (all clean). OF briefing on all 6 difficulties matches the
  def (guards follow D-140's GUARDS table 4/5/6/6/7/8, pager cap 4, Titan from Lethal, [secure] 4 Routine / 6).
- 06ca21f0 Tab sheet top -260 -> -350: OF's sheet clipped the ARMOR / HEALTH values (real-input OF pass on trunk).
- 6f3f62e9 Bot Crew / lobby AI cards: "Standard: Corsair" / "Standard: Tailored Suit" (was "Standard issue" / the
  wrong "Standard vest").
- Real-input OF on trunk: 720p RUN DONE 15 shots; 1080p 14/15 (the time limit before the last hub shot). One
  windowed Godot at a time: two at once stalled both after mask-up. Evidence _review/r246_of_trunk.
- Reported to C via the lead: world/props/multimesh_tiles.gd:35 "Instance count must be 0" x6 per OF load.

### Fixed
- Payday: three OF achievements (one grid line) wrap under the fold at 720p and 1080p and the panel was not
  focusable, so pad/keyboard could not see the last line. The panel now also takes focus once the laid-out summary
  scrolls (payday.gd _focus_achievements_if_clipped). Windowed: tests/b/render/payday_fold_capture.gd, both sizes
  "focused=AchievementsUnlocked"; evidence game/content/ui/_review/r246_payday_fold.

## 2026-10-17 01:30 UTC: new lead session (session_01HwYKRgCdkLfJCt4ZM6rfTk): D-115 strings audits, D-128 rings, r229 fixes
Resumed on origin 0ddba6f8 (the old container's unpushed work is lost; nothing was missing on origin).

### Reconstructed since the 10-14 HANDOFF (old session, all on origin)
- D-115 strings audits, first pass: GN cc5e386b, DB/SL 5e19fb4a, GH/ND 0f2528fc; new-player flow 40681c25, ebff80f4.
- D-128 rings fe4af657; D-126 secondaries 2a8b1ee2, 15b054ce; D-120 failed heist pays nothing 8c50d7f5; D-124 balance
  b4099ae3, 578540db, dab95877, weapon_balance.md 6db2698f; payday 648c7fae, 57a96f53; HUD crowding cb2dbb7f, 7071fae4,
  91aa94e5, b5c38672; scoped ADS e3d30dcb, cbe3a4f4; reach/pad passes 6792cf1a, ac21c141, 5ff659ca; options tips reset
  127dfea5; r229 real-input fixes 8fd6fdff, a4bdb47e, 0ddba6f8.

### Done (this session)
- 7f86b156 B-GN/B-DB/B-SL strings audit, second pass. ContactRadio: a heist's own objective radio line waits out a
  mission say() in the same frame instead of being dropped (12 Reyes / ~11 Accountant lines were never heard;
  RadioTweak.defer_events, test_radio_defer). 19 strings (GN "A Study", inspectors/Vaultline interim, guests_gone; DB
  containers hint/tip, burn_done, breach, required_secured; SL study_safe, casing, crew_masked_1, Accountant brief 3,
  painting desc). SL failed payday recaptured ($0; the -$2,000 was stale).
- 5d117a2e QB-1 (LEAD): 9 heist escape radio lines a mission escape line always covers deleted (SL keeps its heli-arrival
  line); GN briefing step strings ui.briefing.step.gallery_night.access / .cut; vo_coverage.md regenerated.
- d8ac958e, e7576c21 r229: briefing tests follow the approved def lists (cap from the def; dotted ui.briefing.step.*
  keys are strings, not objectives) in test_gn_strings_audit, test_heist_text_audit, test_gn_drafts.
  1f757337 test_range hotfix folded in.
- 98c39e44, 293a8e17 D-128 readability from the live GH/SL check: ring 34 px / stroke 8 on a darker disc, outlined fill,
  crosshair arcs at r150; an observer whose ring sits on the arc band gets no arc (LEAD-approved addendum; clearance
  counts both strokes). Tool: tests/b/render/detection_live_capture.gd (real heist, real guard, real meter; ahead /
  side / camera). Live 720p: SL ring fills ? -> red ! (detected ~1.3 game s at 3.5 m), GH ~2.9 s with two observers.
- 224f5ee1, a7ee6ea1 r229 blocker: pre-planning tab row wraps (4-floor DB row pushed Confirm off a 1920 canvas since
  8fd6fdff); buttons named; test_every_heist_fits_the_screen.

### In progress
- D-128 live re-check at 1080p + camera frames (SL 720p camera, GH 1080p camera): renders queued after a container restart.
- Item 3: real-input UI runs, 5 heists x 720p/1080p (real_input_run_capture.gd now takes a heist id). Contact sheets to
  the LEAD.

### Blocked
- A (game/world/heists is A's): GN extras count only store studies; keycard / vault_drill / server_door stay ACTIVE in
  loud; inspectors/Vaultline doc behaviour. DB: product_found lines at burn start, containers_hint repeats, [cartel] with
  0 gunmen, [product] trigger, Reyes payday line timing. SL: drives_secured seed, generic casing bark doubles the intro,
  small_valuables not in the def. C: briefing_objectives lists (approved), GN/DB/SL doc values (D-120), SL `lift`.
- test_vo_coverage LEAD hotfix (reyes objective_failed out of the reserve) waits for A 4b4fef68 on trunk.

### Questions for lead
- none open (QB-1 ruled).

### Ready for integration
- yes (293a8e17 + a7ee6ea1); targeted checks only (D-088), full check_all is the LEAD's.

## HANDOFF 2026-10-14

**Branch head:** `env/b-content` ec36e060: "[D-111] throwables: ENV C's models on all six ThrowableDefs". The working tree is clean, there are no stashes and no wip branches.

**Done since last trunk merge (not yet on trunk):** trunk round 195 is merged into the branch, so these are the only B commits missing from trunk.

| Commit | What | Green before push |
|---|---|---|
| 6c2b8a2f | Heister **Jay**: roster entry (cobalt accent, 6th in roster order), unlock = new achievement *Wheelman* (5 loud wins → `unlock.achievement.wheelman`), 22 voice lines (speaker `jay`), `crew.jay`; heister/voice tests cover 6 heisters; achievement count bound 35–50 | b heister 12, voice 11, voice_lines 10, achievement 21, strings 38, lobby 48, ui_loadout 5 |
| f8f17c7a | **SMG grip:** LeftHandIK under the fore-end on hornet_9 / lancet_45 / tern_556 (x 0, 12 mm low, a third forward), glbs rebuilt. wasp_pdw keeps its vertical grip | b left_hand_ik, armory_batch3 13; p test_po4_feel 10, test_p1_01 12; a test_fp_viewmodel 15. **d test_arms is red on smg_idle/ads (palm 0.052 m from hornet) until D re-times** |
| 26a9c15d | Weapon materials before/after sheet (`game/content/ui/_review/d111/weapon_materials_before_after_1280x720.png`): C's texture lift barely changes the FP gun (mean luminance ~13→15), so the FP weapon gets almost no light (handed to P) | n/a (review image) |
| 04306eec | **D-113** Options → Gameplay "Blood & gore" `gameplay/gore` (full/reduced/off, default full), `GameSettings.gore()` + `GORE_*`; C's VFX read it by class name | b options 56, strings 38 |
| 0696cd47 | **Deployables:** C's models on doctor/ammo/body-bag/armor bags; new `ecm` / `fak` / `trip_mine` defs (values = A's DeployableTweak fallbacks) | b deploy 5, loadout 50, strings 38, armory 39; a deploy 8, a ecm 14 |
| 82fce830 | GN `objective.gallery_night.casing_last_call` = "Gala's over. Stay out of sight" (A's last-call relabel) | b strings 38 |
| 53779680 | **Deployable gating** (lead ruling, PD2): ECM ← Jammer Jockey (`stealth.ecm_extra`), trip mine ← Extra Charges (`deploy.extra.trip_mine`), FAK ← Field Kit (`deploy.extra.fak`); picker shows "locked: skill <name>" (`DeployableGate.unlock_skill`) | b deploy 6 (new skill-gate test), loadout 50, strings 38, pp_lobby_720p 4 |
| ec36e060 | **Throwables:** C's `prop_throwable_*` set as `model` on all six ThrowableDefs | b throwable 7, loadout 50, strings 38, deploy 6 |

Earlier D-111 work (style.md §11 menu rules, menu declutter 1–4 for hub, loadout, payday, board, options, main menu, mask bench and workshop; range UI polish; the 8 masks; Marten) is already on trunk (rounds 177–188).

**In progress:**
- *SMG fore-end grip (f8f17c7a):* 100 % on B's side. It's held by the lead until D's smg clip re-time lands; the two merge together.
- *Range with C's dressing:* C's `RangeDressing` + `range_environment.tres` are on trunk, and B's hooks are in (`FiringRange._dress` finds `RangeDressing` by class name, builds it, and applies `environment()`/the sun-off). C's tips are applied: 8 m lane-line segments, bench/line colours, brightness. Next step: a windowed `ui_audit_capture.gd -- <out> range` at 720p and 1080p, a look at the dressed range, then tweak values for any colour clashes. About 90 % done; nothing blocks it.
- *Dark FP weapons:* B has nothing left to do here (diagnosis and the sheet are delivered). P owns the fix (FP weapon lighting / layers).

**Queued next:**
1. Range windowed review with the dressing (D-111 item 1: "out of experimental").
2. Re-verify the hub, loadout and lobby with 6 heisters at 720p (portraits for marten/jay from D; P wires the FP arms and bodies).
3. Optional: ask A to enforce `DeployableGate` at runtime (A's DeployableSystem only checks the armor bag, so a stale save with ECM/FAK/trip mine and no skill still gets units).

**Cross-env dependencies:**
- **env/b-content is HELD only on D's SMG re-time** (d/test_arms smg_idle/smg_ads_idle). Everything else on the branch is green, and the lead merges B and D together.
- B waits on P: the FP weapon lighting fix (the material sheet shows lit albedo isn't the problem).
- Others wait on B: nothing open. C has the gore key, A has the last-call string, D has the SMG marker positions (hornet Godot (0, 0.016, −0.150)).

**How to validate your area:**
- `gdlint <changed .gd>`; `python3 tools/ci/check_ownership.py b`; `python3 tools/ci/check_banned.py`.
- Tests: `tools/ci/run_tests.sh b <filter>` (the first arg is the env letter). Common filters: `options`, `strings`, `heister`, `voice`, `achievement`, `deploy`, `throwable`, `loadout`, `test_hub`, `payday`, `board`, `test_range`, `range_d111`, `workshop`, `weapon_finishes`, `mask`, `briefing`, `gn_drafts`. For weapon models also run `p test_po4_feel`, `p test_p1_01`, `a test_fp_viewmodel`, `d test_arms`.
- Run `godot --headless --path game --import` after merges, model rebuilds and strings.csv edits; the strings only update after an import.
- Windowed (xvfb, `--resolution 1280x720` and `1920x1080`):
  - `tests/b/render/ui_audit_capture.gd -- <out> menus|screens|range|heist|...`
  - `briefing_capture.gd -- <out> [heist ...]`
  - `gn_capture.gd`
  - P's `tests/p/_review/vm_probe.tscn -- --out=<d> --primary=weapon.<id> [--heist=glasshouse]` for FP weapons.
- Weapon models: `python3 tools/blender/build.py --category weapons --asset wpn_<id>` (Blender 4.5, deterministic; an unchanged rebuild is byte-identical).

**Gotchas:**
- llvmpipe is slow. A heist capture takes about 5 min per Glasshouse vm_probe run, and a full `menus` audit about 10 min per resolution. Run them sequentially, at most 2 windows, and in the background with long timeouts (a 30 min cap killed one run).
- GH, ND and SL `*_def.tres` are **generator output** (C's build_greybox). Hand edits get re-serialised, so send values to C. GN's def is C's file but B owns the content values (agreed split).
- Material library (`world/materials`, `assets/textures`) is C's. Weapon glbs map `M_<id>` slots onto it at import, so they need no rebuild for material changes.
- `check_banned` rejects `res://world/...` paths in B `.gd`. Find C classes by name (`UiNav.global_class`) or use a contracts id. `.tres` may reference world paths, but only once those files are on trunk; otherwise loading breaks. Hold and stash until they are.
- gdlint caps public methods at 20 per file, so put new tests in new files when a suite is full. Private vars go after public ones.
- `pkill -f` / `pgrep -f` match their own shell. Kill by PID.
- A parse error in any test file hangs the runner.
- The first-person IK marker rule is x 0, 12 mm below the fore-end, a third forward of the receiver. Every move turns d/test_arms red until D re-times, so always merge with D.

**Session:** ENV B, session_0159qCTRV9CsDQs465nGSW28. No helper lanes, background runs or worktrees are running.

## 2026-10-14 evening: round 118 lanes (GN capture, audit refresh, C6)
### Done
- **Lane 1, Gallery Night windowed capture.** Harness gn_capture on env/b-gallery-night (094bef25). It runs on a scratch
  copy with the draft def at the registry path and covers the planning table, briefing, every pre-planning floor,
  loadout and the HUD (casing, masked, loud, radio). Findings, fixed for every heist on env/b-content:

| Row | Finding | Status |
|---|---|---|
| GN-U1 | A long briefing VO line grew the contact column and pushed Back / Continue off the screen (720p and 1080p) | FIXED 3d0249fc (test_briefing) |
| GN-U2 | The HUD flashed OBJECTIVE COMPLETE for a step that a new step (Argus lockdown) or a disable pushed back | FIXED 3d0249fc (test_ui_theme) |
| GN-U3 | Pre-planning map hint cut to "Pick" with four floor tabs | FIXED 3d0249fc: shows whole or not at all |
| GN-U4 | Pre-planning markers of points 2 m apart stacked (portico entry under the limo escape) | FIXED 6597b236 (test_preplan_screen) |
| GN-U5 | The briefing lists all 18 objectives, including the loud branch and extras | Asked the lead (keep, or a briefing subset) |

- **Lane 2, audit refresh** (ui_audit_capture, every mode, 720p and 1080p):

| Row | Finding | Status |
|---|---|---|
| AU-1 | Payday crew table under the fold at 720p while the right third was empty | FIXED 8ad4bd90: stacked under the XP panel (test_ui_payday, 4 crew with every column) |
| AU-2 | Loadout item picker sheet started inside the screen title | FIXED f46bfdf7 (test_ui_loadout) |
| AU-3 | Achievements: 4 of 41 cards per screen | FIXED 47b2e636: two columns with a d-pad grid; test_menu_reach now covers it |
| AU-4 | Hub: The Board card description ends in "..." (the side panel shows it whole) | FIXED 9fc56594 + follow-up: START HERE on the title line (test_hub) |
| AU-5 | Board map: contract markers sit on district names (HARBOR, DOCKS) | FIXED 7dbbee13 + follow-up: names step clear of pins (test_board_screen) |
| AU-6 | Workshop weapon list: long names end in "..." ("Thorn Compound Bow · Level ...") | Minor, kept |
| AU-7 | Tab sheet: objective marker labels drew across its text (LOOT SECURED) | FIXED 08585cdd: badges only on the sheet (test_ui_theme) |
| AU-8 | The first-time card sat over the downed screen and cut a marker label | FIXED: it gives way while downed (test_onboarding_card) |
| AU-9 | `fail` mode "hang" after Leave | Not a bug: four llvmpipe processes at once; alone it runs to payday and home both ways |
| AU-10 | Range: far lane distance labels are tiny; one is cut by the readout panel | Minor, kept |

- **Lane 3, PO-B-C6** (30d3ffde): the lobby crew cards show whole without scrolling at 720p. Contract and difficulty
  share a row, as do music and drop-in. A card's level shares the ready row, and Kick sits beside the name
  (test_pp_lobby_720p).

## 2026-10-14 later: rounds 69/70, D-105 / D-106, co-op windowed pass
### Done
- Rounds 69/70 merged (62cec2c5). D-102 text: the gold bag says "barely a jump". The missing 3D safehouse is logged once per session.
- D-105 Effects Quality (68f28ac2): Options > Video Low / Medium / High (default High); `GameSettings.effects_quality()`, one step lower under Reduce Motion; `EFFECTS_SCALE` for C's VfxDirector; options.md.
- D-106 reload indicator (3ced00ed): RELOADING caption + bar under the ammo line (ui_hud 1.12 `reloading` / `reload_progress`).
- D-106 skill-boosted stats (053b10fa): armory and loadout stats with skills + perk deck by default (SkillBoost, read like CrewWeapons reads Modifiers), a "Stats: With Skills / Base" toggle, boosted values marked with * and a legend.
- Co-op windowed pass (coop_capture / coop_worker: two windows over loopback, host + client, real MenuFlow and Net):

| Row | Owner | Finding | Status |
|---|---|---|---|
| PO-B-C1 | A | At heist start the client's ENet connection drops (the host's ~40 s blocking map build here; core/net.gd sets no peer timeouts). The host's Net.crew turns the client's slot into AI; the client is left in a solo replica with Net.crew {} (no objectives, no teammates on its HUD). | Sent to A with the diag lines and a timeout proposal |
| PO-B-C2 | B | The client stayed in that dead replica: MenuFlow did not handle HeistNetSync.host_lost (the contract says the app flow does). | FIXED cce16081: teardown + Net.leave, back to the lobby with "Lost the connection to the host" (test_coop_host_lost) |
| PO-B-C3 | B | The client's lobby focus parked on Leave (it was the only enabled control while joining); one stray Enter / A left the lobby. | FIXED 4fa1fc97 (test_lobby_loopback) |
| PO-B-C4 | B | A human dropping mid-heist was silent on the other peers (the heister just turned AI). | FIXED df4d0dc5: "<name> left the game. An AI plays <heister> now." / "<name> joined as <heister>." toasts |
| PO-B-C5 | LEAD | core/log.gd `_write` calls multiplayer.get_unique_id() after the peer closed: an engine ERROR on every log line during a disconnect. | Reported |
| PO-B-C6 | B | The lobby's crew cards scroll below the contract / chat block at 720p (mask row under the fold). | By design (PQ-B-11b scroll); can compact if wanted |

- Re-run after round 80 (ENet 15-60 s timeouts, threaded map load). Both peers are in the same heist (Net.crew {0 human, 1 human, 2 ai, 3 ai} on both). The client leaves, the host logs the drop and its HUD toasts it; the host leaves and gets a failure payday, then home.

| Row | Owner | Finding | Status |
|---|---|---|---|
| PO-B-C1 | A / LEAD | Client connection dropped at heist start | FIXED round 80 |
| PO-B-C7 | A | The client's LocalHudModel has 0 objectives for the whole run (host: 5). The HUD hides the objective panel and the pause job card has no OBJECTIVES. objective_updated [R] fires at the host's start, before the client's model listens; there is no catch-up. | Sent to A |
| PO-B-C8 | B | Client crew rows read "Host / AI 2 / AI 3" (the heister map was only handed over on the host's launch). | FIXED ebe242ff (lobby assignment; test_lobby_flow) |
| PO-B-C9 | B | The "left the game" toast crossed the onboarding card's title. | FIXED: the card gives way while a toast shows (test_onboarding_card) |
| PO-B-C10 | LEAD (design) | A client who leaves mid-heist goes straight home, with no payday (PD2 does the same). The lead's pass said "payday on both". | RULED: PD2 behaviour (the leaver goes home, no payday) |
| PO-B-C11 | B | A co-op payday's Continue dropped the session (Net.leave, home). | FIXED 2986bcd2 + 8fbe5e76: Continue goes back to the kept crew lobby; end_round clears `started`; a Start spends every ready flag. Windowed proof (coop_worker `success2`): two Glasshouse wins back to back on one session; host and client each get a success payday, a card, then the lobby, twice. Crew {0 human, 1 human, 2 ai, 3 ai} and 5 objectives on both in heist 2 |

### Next
- Gallery Night content when the lead sends the list; C7 re-check when A lands it.

## 2026-10-14: PO-4 lead queue (round 68): pad pass, safety net, firing range restyle
### Done
- Gamepad pass on the new widgets (d9cca06b): the hub's Continue is in the d-pad grid; test_pad_new_widgets.
- Payday per-bag list: this already existed (cash panel, "Jewelry x2 $13,000").
- First-heist safety net (edd28f35): a failed heist on a profile that never completed one (solo, with authority) offers "Try again at Routine" left of Continue, and Continue keeps the focus. MenuFlow relaunches the same job at Routine with the profile loadout. HUD toasts name heisters and hide under the scoreboard and the downed screen.
- A's fields verified windowed (85432277 `feedback` audit mode, r68_*_real shots).
- Firing range Case File restyle:
  - Caption labels over values and a caption + rule for each section; rows at 21 (they were 18, below the floor).
  - A crumb + H2 title; "every weapon is free" moved to a note line.
  - A fixed footer: Leave (ghost) on the left, Reset on the right; d-pad left/right moves between them.
  - Aim mode shows less: the loadout panel hides and the right panel shrinks to the readout + last shot.
  - A key cap hint strip follows the last device: [Tab]/[Start] Aim, [Enter]/[A] Select, [Esc]/[B] Leave. In aim mode: [LMB]/[RT] Fire, [RMB]/[LT] Aim down sights, [R] Reload, [1/2]/[Y] Swap weapon, [Tab]/[Start] Panels.
  - InteractionPanel.action_key_text now names mouse buttons (LMB / RMB / MMB) and falls back to the pad button when the keyboard has no binding.
- Range real-input pass (test_range_real_input: real key / pad events): one bug found and fixed. The overlay never ran UiNav.ensure_pad_ui_actions, so pad A / B did nothing when the range was the first screen. Review shots: r69_range_panel / r69_range_aim.
- Windowed failure-flow capture (`fail` mode, 720p): abort and all-custody both end on the failure payday (reason, what was lost, Retry offered, Continue focused), then home with Continue. One fix: the onboarding card now hides while the pause menu is open, because the job card sits on its spot (test_onboarding_card::test_card_hides_while_paused). Shots: r69_fail_*.
### Next
- Gallery Night content when the lead sends the list.

## 2026-10-13 night: PO-4 lanes 11 / 12 / h02 notes
### Done
- h02 notes (9e54061f): crosshair hidden until masked (fades in); only the current objective's marker unless Tab is held; the objective flash strikes the finished step through, then slides the next one in.
- Lane 11: first-time onboarding cards (OnboardingCard, right of centre), one per situation and shown the first time it arises: casing, stealth (masked, no alarm), loud (LOUD phase or an assault), escape (ESCAPE phase). Each card has 3-4 short rows with key caps (mask up / interact / throw bag / shout), drains over 14 s, H closes it, and a later situation waits for the open card. Seen ids live in the profile's `settings.onboarding_seen` (OnboardingTips), so the save shape and version are unchanged. Writes are blocked inside the test runner and the captures. Windowed contrast `-- onboarding`: PASS.
- Lane 12: the scoreboard names heisters in their colour, is as tall as its rows, is 1240 wide (x1.5 fits 1920; test_pp_hud_720p was red at x1.5), and the markers draw over it while Tab is held.
- Lane 13: stretch aspect "expand" (D-098, lead set it); UiScreen.fit_width keeps menus in a centred 16:9 column; hub station cards grow with their text (16:10). test_pp_hud_720p runs in a real 1280x720 window. Windowed 21:9 (menus + heist HUD) and 16:10 reviewed; shots in content/ui/_review/after/uw_* / w1610_*.
- Onboarding: dismiss_tip action (D-096), a new situation replaces the open card, the card hides under the Tab sheet; h01/h02/h09 recaptured after P's AR hip pose.
- Folding knife model (subagent, scripted, original) wired on melee.folding_knife.
- D-097/098/099: P's PD2 spread / recoil on all 36 WeaponDefs, PD2 ADS times (0.23, AR 0.25), mods on PD2 index steps (accuracy -0.24 hip / -0.192 ADS per step; stability -0.1 x class vmid / hmid), no mod ADS deltas, LMG drift bias. Accuracy display on PD2's scale; Stability 0..12 deg.
- accessibility/head_bob + GameSettings.head_bob() for P.
### Next
- Lead applies the P4 golden values (sent). SafehouseHud restyle only if cheap (lane 10).

## 2026-10-13 late (round 36 merged): PO-4 iteration 2
### Done (b4c291ab..HEAD)
- Round 36 merged; style.md + audit.md committed (docs/design/ui/** is B's).
- KR-5 fixed: MouseCapture ate the payday Continue click as a capture click; PaydayScreen holds &"payday" while shown. KR-6: Board pad test takes the designed path (A on a pin -> Take); the d-pad walk depended on the time-rotating pin layout.
- MouseCapture migration (input_focus 1.1): pause/options &"pause", drop-in &"dropin", safehouse &"station", range panels &"menu", spectator registers as an owner (QB-4 to lead). No Input.mouse_mode writes in game/content.
- QB-1: default profile owns + equips weapon.corsair_ar (tests updated).
- Lead notes: frameless HUD (outline + shadow text, hairline objective edge, thin bars, flush corners), crew rows named by heister + colour (Hud.set_crew_heisters from MenuFlow); loadout slot cards (ItemSlot, OptionButton-compatible API) + ItemPicker grid with diff preview + stat bars + d-pad pairs; main menu hero = equipped mask (MaskPreview); payday total count-up (skippable, Reduce Motion aware); objective-complete flash.
- UI cue list sent to the lead (ui_focus, ui_confirm, ui_back, ui_primary, ui_error, ui_tab, hud_objective_done, hud_hint_appear, payday_tick, payday_total, card_flip).
### Next
- Wire UI cues when ids exist; Board / skills / perks / masks detail pass; hub cards shorter text; HUD crosshair hidden while casing (check with P); preview stats for the primary in the loadout.

## 2026-10-13 (team v3, D-086): PO-4 UI pass "Case File"
Session: Claude Code cloud (env/b-content). Lead: session_014E3p2DmSYTneJjytGwKKfc.
### Done (commits f9b52550..e595f5da)
- Windowed audit (xvfb, not headless) of the real flow at 1280x720 + 1920x1080: `game/tests/b/render/ui_audit_capture.gd -- <out_dir> [menus|heist]`. Findings: docs/design/ui/audit.md (uncommitted until round 35 gives B docs/design/ui/**). Before PNGs: game/content/ui/_review/before/.
- Style spec "Case File": docs/design/ui/style.md (same: waiting for ownership). Tokens: content/ui/theme/ui_tokens.gd; UiThemeFactory builds caper_theme.tres (regenerate: `godot --headless --path game --script res://content/ui/theme/build_theme.gd`; test_ui_theme guards drift). Built-in font only, FontVariation styles.
- HUD: one objective line (caption OBJECTIVE), compact teammate rows, CASING/CIVILIAN chip, key-cap prompts (KeyPrompt), HintStrip (Click to resume / Hold [G] to mask up / throw bag) below the prompt.
- In-heist PauseMenu (Resume / Options / Leave Heist + confirm) over a scrim; Options from it returns to it; Leave Heist moved out of the Options footer.
- Every UiScreen: fade-in, footer control hints ([Enter] Select [Esc] Back, device aware).
- Main menu wordmark, CaseBackdrop, hub START HERE (new profile), heist select, loadout (sections, Primary row, DR hero), payday hero row, pre-planning label overlap fix, options tabs.
### Open / next
- MouseCapture migration (input_focus.md) once ENV P lands it; briefing, Board, workshop, skills/perks, masks, lobby restyle; HUD motion (objective done flash); sound hooks.
- QB-1: new profile owns only a pistol (default_profile.json has no primary). PD2 starts with a primary + secondary. Add a starter primary?

## 2026-10-12 21:50 UTC (8): D-076 playability pass (B-PP)
### Done
- B-PP-1 (a2e2785b): hub side panel no longer has Career / Notoriety buttons (duplicates of the Record / Old Press station cards). Signals kept for API; test_career / test_notoriety_ui now open them via the station cards.
- B-PP-2 (a2e2785b): station list is a 2-column GridContainer of 96-unit cards (was 1 column of 9 x 108 = 1084 units, which overflowed 1080 = 1280x720 under canvas_items stretch). ScrollContainer kept as a fallback.
- B-PP-3 (7da1ce93): the 30 s payday-card auto-pick is correct per pd2_fidelity P9 ("pick 1 of 3 (30 s auto-pick) ... Identical"), so it stays. Timer label turns urgent (colour) in the last 5 s (`PaydayScreen.timer_is_urgent`).
- New game/tests/b/test_pp_input.gd (5 tests, real InputEvents: viewport mouse motion/click, ui_accept action; no set_bot_intent). p_input_driver.gd from Env P did not exist yet; switch to it when it lands.
### Tests seen
- test_pp_input 5/5, test_career 9/9, test_notoriety_ui 8/8, test_ui_payday 8/8 (single-file runs).
### Playability queue (UI/content, ~2-3 h)
1. PQ-B-1 Switch test_pp_input to Env P's p_input_driver.gd once committed (20 min).
2. PQ-B-2 Res sweep: every B screen (board, briefing, preplanning, loadout, workshop, skills, perks, masks, career, notoriety, achievements, jukebox, options, lobby) checked at 1280x720 with an on-screen-rect test like test_hub_cards_fit_720p (60 min).
3. PQ-B-3 Gamepad nav on the 2-column hub grid: verify left/right/up/down neighbours, and side-panel/back reachability (20 min).
4. PQ-B-4 Payday cards: number keys 1/2/3 + gamepad shoulder quick-pick; urgent-timer audio tick (cue via lead/ENV C) (30 min).
5. PQ-B-5 Payday: focus starts on card 0, so a held/mashed ui_accept from the previous screen can pick instantly; add a short input-grace before picks are accepted (20 min).
6. PQ-B-6 HUD readability at 720p: font sizes / overrun in hud widgets, subtitles (30 min).
7. PQ-B-7 Main menu -> hub -> heist select -> loadout -> launch real-input walk test (30 min).
8. PQ-B-8 Tooltips-only station descriptions are invisible on gamepad; show the desc in a focus panel (20 min).

### Queue progress (2026-10-12 ~22:10 UTC)
- PQ-B-1 deferred: p_input_driver.gd is not on trunk yet (per lead: local-only use, no P files committed here). Swap test_pp_input helpers to PInputDriver once it is on trunk.
- PQ-B-2 done 150fdf58: test_pp_screens_720p (8 station screens + achievements on screen at 720p). No offenders found.
- PQ-B-3 done 7101d48b: HubMenu.chain_grid() arrow/d-pad neighbours for the 2-col grid; test_hub_grid_navigation.
- PQ-B-4/5 done 258ba7ab: payday keys 1-3 quick-pick; 0.6 s INPUT_GRACE_S ignores blind player picks (timer unaffected). Urgent-tick audio NOT done (needs a cue from ENV C via lead).
- PQ-B-6 done 7d7db3b3: real bug at hud_scale 1.5: stamina/vitals/teammates/objectives overlapped, interaction overlapped stamina. Hud._stack_left_column() stacks them; test_pp_hud_720p.
- PQ-B-7 done 6751d8ab: test_pp_menu_walk (main menu -> hub -> select -> briefing -> preplan -> loadout -> Launch, real clicks/Enter; level load intercepted).
- PQ-B-8 done 0f1ad18a: hub side panel StationDetail label follows focus/hover.
### Notes
- D-081: painting_study stays at $700. It is P5 content (frozen), so no change now.
- Push: origin rejects with 403 (token lacks write on the repo); all commits local.
### Next queue
- PQ-B-1 (when the driver is on trunk); PQ-B-9 urgent-timer audio cue request; PQ-B-10 gamepad shoulder quick-pick on payday (needs input actions in project.godot via lead); PQ-B-11 720p sweep of in-heist pause/options and lobby co-op states.

### Round 2 (2026-10-12 ~22:15 UTC)
- PQ-B-9/10 c6970fba: payday urgent window requests `cue.payday_tick` once per second, only if ENV C's AudioCueRegistry has it (PaydayCardsTable.urgent_time_s / urgent_tick_cue, data-driven). LB/RB via `ui_payday_prev/next` (guarded by InputMap.has_action) move card focus in `_input`, only while focus is in the payday screen, and consume the event (no throw/melee leak). Verified locally with lead 31307ed2's project.godot (not committed).
- PQ-B-11 5228ae02: 720p tests for all 4 Options tabs (same screen as in-heist pause) and the safehouse pause menu. Lobby co-op states not covered yet.
- PQ-B-12 668e622b: test_pp_heist_ui: interaction prompt names the really-bound key and that key fires `interact`; carried bag + secured toast on screen; Tab scoreboard follows the real key; payday summary -> card (key 3) -> Continue by keyboard.
- 7556091f: RangeSpectator aim look uses `screen_relative` (relative is stretch-scaled: 1.5x at 720p, 30x headless); test_range_mouse_counts (fails on `relative`). workshop_stage / mask_preview drags still use `relative` on purpose: they are GUI orbit drags, where canvas units keep the drag proportional to the screen.
### Next
- PQ-B-1 when p_input_driver.gd reaches trunk; lobby co-op 720p states; drop the RB test skip once lead's input actions are on trunk.

### Round 3 (2026-10-12 ~22:45 UTC)
- 3e13adaa PQ-B-11b: real bug, the lobby host view pushed Leave / Ready / Start to y=1095 (off-screen at 720p). Contract + crew body now scrolls, footer pinned. test_pp_lobby_720p covers connect / host no contract / host ready / client (ENet loopback).
- 7217ee2d PQ-B-13: real bug, gamepad A / B did nothing in any menu: project.godot ui_accept / ui_cancel have no joypad events. UiNav.ensure_pad_ui_actions() (called from UiScreen._ready) adds A / B at runtime when missing; SafehouseHud ignores pad B while walking (B is a gameplay button). **Lead: please add JOY A to ui_accept and JOY B to ui_cancel in project.godot**, then the runtime add is a no-op. test_pp_gamepad_flow: hub -> select -> briefing (B back) -> preplan -> loadout -> Launch, d-pad + A only.
- ddb08e5a PQ-B-14: test_pp_live_hud_720p in a live glasshouse run (direct_launch, real LocalHudModel): found teammate info line 18 units = 12 px at 720p; now 21 (14 px) and wraps. Subtitles default 28 units = 18.7 px, clear of vitals / ammo.
- PQ-B-1 still waiting: p_input_driver.gd not on origin trunk (64f10747).
### Queue (about 4 h)
1. PQ-B-15 Gamepad-only masks, workshop, skill tree, perk deck: reach every tab and Back with d-pad / A / B (40 min).
2. PQ-B-16 Gamepad-only lobby host flow: contract, ready, start (30 min).
3. PQ-B-17 DimLabel is 20 units = 13.3 px at 720p across all menus: sweep for readability, raise to 21 if layouts hold (40 min).
4. PQ-B-18 Subtitles small / large, two-line wrap, clear of the interaction prompt at hud_scale 1.5 (20 min).
5. PQ-B-19 Live heist: press the real interact key on a real interactable and watch the prompt + progress (with PInputDriver once on trunk) (40 min).
6. PQ-B-20 Live heist pause / options with pad Start and B, then resume (30 min).
7. PQ-B-21 Live heist end -> payday -> cards -> Continue -> menus, keyboard and pad (30 min).
8. PQ-B-1 Switch real-input helpers to PInputDriver (when on trunk) (20 min).

### Round 4 (2026-10-12 ~22:45 UTC)
- e4ac7a3a Lead bug: objective "Secure the bags ({count}/{total})" showed raw. UiText.t was called, but the missions pass {"bags": N} with no count / total. ObjectivesPanel.objective_text fills total from bags / required and count from secured bags (EventBus.loot_secured), and drops any still-unfilled "( {x} )" group. Mission-side data (ENV C) could also send count / total; not touched.
- e4ac7a3a PP-A-1: DominatePrompt HUD widget, visible while `dominate_target` != 0 (LocalHudModel on env/a-core), with the shout key and `dominate_window_s`. MockHudModel has the same fields + `dominate_prompt_changed`.
- 24cd3572 PQ-B-15: gamepad-only skills / perk deck / masks / workshop, open with A and close with B from the loadout.
- PQ-B-16 (lobby host Ready + Start, pad only) committed after 24cd3572.
- PQ-B-14 contrast: BLOCKED. The box has no GPU, so only layout / overlap / font px are checked. Contrast needs a rendered capture (lead suggests LIBGL_ALWAYS_SOFTWARE=1 + lavapipe + xvfb-run); not tried yet.
- Tooling note for lead: when a test file has a parse error, the runner prints "Nonexistent function 'new'" in a loop and never exits (hit a 150 s timeout). It should fail fast.
### Queue (about 3 h)
1. PQ-B-17 DimLabel 20 units = 13.3 px at 720p in every menu: sweep, raise to 21 if layouts hold (40 min).
2. PQ-B-18 Subtitles small / large, two-line wrap, clear of the interaction + domination prompts at hud_scale 1.5 (20 min).
3. PQ-B-19 Live heist: real interact key on a real interactable, prompt + progress (PInputDriver once on trunk) (40 min).
4. PQ-B-20 Live heist pause / options with pad Start and B, then resume (30 min).
5. PQ-B-21 Live heist end -> payday -> cards -> Continue -> menus, keyboard and pad (30 min).
6. PQ-B-22 HUD contrast captures via xvfb + lavapipe (40 min, may stay blocked).
7. PQ-B-1 Switch real-input helpers to PInputDriver (when on trunk) (20 min).

### Round 5 (2026-10-12 ~23:10 UTC, D-082 freeze: fixes only)
- b5a228ca PQ-B-17: per-screen readability check (visible text >= 14 px at 720p). DimLabel 20 -> 21 units; small overrides (skill tree 18/20, perk deck 19, preplan 20, blueprint 17, scoreboard 18) -> 21. All screen / layout tests still pass.
- 9641b6b2 PI-13 (ENV P casing_blocked): Hud.watch_crew() connects the local CrewController's `casing_blocked(action)` when the signal exists (no-op otherwise); 1.5 s "Mask up to sprint / crouch / jump ({key})" hint.
- 5cf1224d PQ-B-18: real bug, large subtitles (36 units, 800 wide) wrapped to 225 units and covered the interaction prompt. RadioTweak.max_height_px (300) drops the oldest row; tests for small / medium / large x hud_scale 1.0 / 1.5.
- 2f890e51 PQ-B-22: rendered HUD contrast works without a GPU. Exact command (from repo root):
  `LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --path game --rendering-driver opengl3 --resolution 1280x720 res://tests/b/render/hud_contrast_capture.tscn`
  Renderer: Mesa llvmpipe (OpenGL 4.5 compat), ~1 s. PNGs: ~/.local/share/godot/app_userdata/CAPERWORKS/hud_contrast_{dark,mid,bright}.png. Result: PASS (0 labels < 4.5:1; text vs outline/panel, brightest vs darkest 3% px). Caveat: the metric is coarse; by eye, floating labels with no panel (status "Unmasked: casing", green "Carrying", interaction prompt) are the weakest on the bright backdrop. Candidate fix for lead review: HudLabel outline 6 -> 8 or a panel behind status / interaction.
- 219debc4 PQ-B-20: live heist, pad Start opens Options over the HUD (crew input held, 720p fit), pad B closes and resumes.
- 64b9fd17 PQ-B-21: live heist end_heist -> payday -> key 1 card -> Enter -> main menu.
- PQ-B-19 / PQ-B-1 waiting: p_input_driver.gd still not on origin trunk (64f10747).
### Queue (about 2.5 h)
1. PQ-B-19 Live interact key on a real interactable with PInputDriver (when on trunk) (40 min).
2. PQ-B-1 Switch real-input helpers to PInputDriver (20 min).
3. PQ-B-23 Floating HUD text on bright scenes: lead decision outline 8 vs backing panel, then apply + re-capture (30 min). DONE: lead chose outline 8 + soft dark drop shadow, no panel (UiBuild.float_text on the toast/casing hint, domination prompt and interaction prompt/blocked labels). A faint backing panel goes only on prompts that fail in D's renders over the brightest scenes, re-checked with D's flags.
4. PQ-B-24 Contrast capture for menus (hub, payday, loadout) over the real 3D safehouse backdrop (40 min). DONE over the 2D hub: hub / loadout / payday 0 failures. The real 3D safehouse scene (res://world/hub/safehouse/safehouse.tscn, ENV C) is on no branch (trunk, env/c-worlds), so the flow falls back to the 2D hub; CLOSED: Env C says safehouse.tscn (C4-01) is frozen under D-082. The 2D hub is the shipped hub and its capture stands.
5. PQ-B-25 Live heist: domination prompt + casing hint seen in a real run once A/P fields are on trunk (30 min).
6. PQ-B-26 Gamepad-only Board (contract pick) and Notoriety reward picks (30 min).

## 2026-10-11 UTC (7): B7 loose ends (lead answers); P5 paused (D-076)
### Done
- B7-01 `profile` station (hub_map v1.1, d1a89b5f): `st_profile` (target `career`, icon `profile`) in data/ui/hub_stations.tres.
  - MenuFlow `TARGET_CAREER` → `_open_career()`; HubStationIcon `_profile` glyph (dossier card).
  - Strings `ui.hub.station.profile` ("The Record"), `.desc`, `ui.prompt.station.profile`; test_hub STATION_IDS has `profile`.
- B7-04 ProfileValidator (58459a33): `weapon_finishes` entries with an unknown finish id are dropped (`WeaponFinishes.is_known`), replacing the TODO.
  - The v7_damaged fixture used `finish.gunmetal`, which is not a real finish; it is now `finish.gunmetal_blue`, plus a `weapon.brute_12: finish.retired_rust` entry that must be pruned.
- Payday cards excluding achievement-reward mask parts: already in B7-02 (`PaydayCards.pool` skips any part with `unlock`); tested in test_achievements_b702.
- Trunk 930e6013 (round 33) merged (0771daef).
### In progress
- None. P5 contract data is NOT started (D-076 pause). No local P5 edits.
- Resume point (wind-down): all work is committed. Trunk 4e6c9af6 (incl. a2d82434 flake fix) merged at bb5d7eb9.
  If env/b-content on origin is behind local HEAD, run `tools/ci/check_all.sh --env b` and push.
### Next
- When P5 resumes: read-only notes for it are in the lead report (painting_study value conflict, point-label collisions, Rolling Thunder mode label, Afterhours escape_options, `dj` speaker).
### Notes
- Runs 1 and 2 of check_all (before the a2d82434 merge) also failed on stale origin trunk (ownership) and one gdlint line (fixed in 5d6c920e).
- First full check_all here failed one ENV A test once (test_b4_18_special_weapons:test_parts_animator_drives_named_parts); it passed 2/2 on rerun in isolation. Looks flaky.
### Ready for integration
- see the CHECK_ALL line in the commit/report
