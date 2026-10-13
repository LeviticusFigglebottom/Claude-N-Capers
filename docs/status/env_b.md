# ENV B status: Content & Progression

Owner: ENV B. Update at the end of **every** work session (template in docs/process/communication.md §3).
Newest entry first, keep the last 10.

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

## 2026-10-11 UTC (6): HANDOFF (session shut down, project moving accounts)
### Done
- B7 accepted by the lead at e443d998, the last validated push. This entry is docs only.
### In progress (not started in code, no local work lost)
- The lead's answers to the B7 questions, all still to implement:
  1. **`profile` station:** add `st_profile` to data/ui/hub_stations.tres (`target = &"career"`, `icon_kind = &"profile"`).
     - MenuFlow: `TARGET_CAREER` in TARGETS, mapped to `_open_career()`.
     - HubStationIcon: a `_profile` glyph.
     - strings: `ui.hub.station.profile`, `.desc`, `ui.prompt.station.profile`.
     - test_hub: add `&"profile"` to STATION_IDS.
     - Spec: hub_map.md v1.1 (trunk 930e6013). C places it with A's `hub_station` prefab.
  2. **ProfileValidator:** drop unknown finish ids in `weapon_finishes`, the same pruning as for unknown masks.
     - Replaces the TODO(B7-04) in profile_validator.gd `_career`; use `WeaponFinishes.is_known`.
  3. **Payday card drops:** exclude achievement-reward mask parts. They stay achievement-only, as in PD2.
- Trunk 930e6013 is not merged into env/b-content yet. Merge it first.
### Next
- **P5 contract data** (gallery_night, ostrander_federal, rolling_thunder, afterhours) from ENV C's G0 docs, which are APPROVED on trunk (e8df4b7, round 30).
  - Start from test_p5_catalogue.gd; objective strings are still deliberately absent.
### Notes
- Run suites under `timeout`. A script parse error hangs the runner; detect it by the log's age, not the CPU load.
- After check_all, run `git checkout -- docs/levels`.
### Ready for integration
- yes (e443d998)

## 2026-10-11 UTC (5): B6 follow-ups, D-074/D-075, B7-01..B7-04
### Done
- B7-03 contact radio: `ContactRadio`, `RadioLinePicker` (GameRng `radio` stream), `RadioTweak`, `SubtitleOverlay`.
  - The heist contact speaks objective / alarm / assault / escape / loot facts (one voice per heist, lead).
  - Guard and crew subtitles sit behind `accessibility/subtitles_all_speakers` (default off).
  - Mercer's old generic alarm / assault / loot / escape lines are retired.
- B7-01 career + save v7: `PlayerProfile.career` and `weapon_finishes`; `Career.record` on the payday path; career screen; v7 golden fixtures.
- B7-02 achievements: 41 achievements; reward masks via `MaskPartDef.unlock`.
  - clean_lines, headhunter and trigger_discipline stay locked until shots/hits/headshots reach HeistResult.
- B7-04 weapon finishes: 12 finishes (`finish.<name>` ↔ `unlock.finish.<name>`), `FinishApplier`, workshop picker, `Loadout.weapon_finishes` (D-074).
  - The persistence test now saves and loads the real v7 field.
- D-075: Ostrander Federal rename, Afterhours contact = Accountant, `loot.painting_study`.
- Drop-in: `DropInFlow.apply_live_policy` applies a host's Options change mid-heist.
- `check_all.sh --env b` @ 541a21dc (trunk 2eb3b2e merged): PASS (1673 tests, 0 failed, 5 skipped).
### In progress
- —
### Blocked
- P5 contract data waits for ENV C's G0 docs to be marked APPROVED.
### Notes
- A test runner whose script fails to parse hangs instead of failing. Run suites under `timeout` and watch the log's age, not the CPU load.
### Questions for lead
- Placement of a `profile` hub station (C/A).
- Should ProfileValidator drop unknown finish ids?
- Should achievement reward parts be excluded from payday cards?
### Ready for integration
- yes

## 2026-10-11 UTC (4): B5-01..B5-05 pull-forwards
### Done
- B5-01 options (merge f3340b8).
  - `GameSettings` saves to user://settings.cfg and has key/pad rebinding with conflict detection, plus audio, video and accessibility settings.
  - Five colour-blind HUD palettes, tested for contrast under simulated colour blindness (Machado).
  - In a heist, `pause` opens options as an overlay.
  - Hooks for A and C are in content/docs/options.md and were routed by the lead.
- B5-02 Notoriety (merge 2d84679).
  - Ranks I–XXV need level 100 and spending cash ◇; +2%/rank XP, capped at +30%.
  - Skill builds are held after a rank-up and re-bought as levels return. Cosmetic and music unlocks.
  - Save v6 adds notoriety fields and `music_choice`.
- B5-03 music (merge e16c4ff).
  - `MusicCatalog` reads C's table, or a stub list until it lands.
  - Picker in pre-planning and the lobby; the `options["music_track"]` launch option.
  - A jukebox station; Play is disabled until C's `MusicDirector.preview` exists.
- B5-04 Dockside Burn (merge ac2d797): loot, 5 pre-planning assets, 10 objectives, 31 VO lines, a Reyes contract ($95k placeholder), and a HeistDef proposal for C.
- B5-05 civilian UI (f417e8f, strings in 5368092).
  - The HUD follows ui_hud v1.6 `player_mode`: a Civilian badge, gear widgets hidden, teammate mode shown.
  - The loadout screen shows a civilian-start notice.
- `check_all.sh --env b` @ e16c4ff: PASS (1384 tests, 0 failed, 5 skipped).
### In progress
- —
### Blocked
- Thermite → `LootDef.is_tool` waits for D-068 on origin.
### Notes
- check_all rewrites docs/levels/*/validation.md. Run `git checkout -- docs/levels` after every run.
- A "Unexpected NUL character" warning prints at Godot startup in test runs. Nothing fails; source not found yet.
### Questions for lead
- See the B5-03 report: lobby summary `music` field, scrolling hub station list, placeholder track names.
### Ready for integration
- yes

## 2026-10-11 UTC (3): D-057 params, D-058, armor bag gating, ChargingHandle
### Done
- D-057 (ed9f77e, b1123d0): special-weapon `params` with A's numbers. Bow `charge`, Shrike `lever`, and arrow/bolt armor pierce. Both Furnace nozzles carry full flame blocks.
- D-058 (ed9f77e, d6ba8e4): Harrow/Brute use `anim_set` `shotgun_box`. Their chargers are now `ChargingHandle` nodes; the models are rebuilt, the build is deterministic, and there's a test.
- Armor bag (c6253b4): `deployable.armor_bag` plus `DeployableGate`. The loadout picker shows it locked until perk card 6 (Go Bag) grants `deploy.armor_bag`.
- `ui.escape.heli/line/lift` strings.
- 541d542: restored trunk's night_deposit validation.md, which check_all regenerated and b1123d0 picked up by mistake.
- `check_all.sh --env b` @ c6253b4: tests 1246 / 0 failed / 5 skipped, gdlint and validate_level PASS; only ownership failed (that report). Ownership is OK at 541d542.
### In progress
- —
### Blocked
- —
### Notes
- Closed by lead/A: TeamModifiers reads the D-056 fields, the modifier_keys text is fixed, and A's armor bag prompt switches on its next push.
- check_all rewrites docs/levels/*/validation.md. Never `git add -A` after a check run.
### Questions for lead
- Queue is under 2 h. Ready for P5/P6 pull-forwards.
### Ready for integration
- yes

## 2026-10-11 UTC (2): round 7 (D-056), D-052 lobby, A3-08 range, QB-50a
### Done
- D-056 (round-7 merge): MenuFlow no longer calls ModifierPush (A pushes on the server).
  - Every granted key is in test_perk_wiring HOOKED; perk_decks.md coverage is all ✅, with field names checked against modifiers_params.md.
  - `team.damage_reduction_hostage` is now `{absorb_per_hostage, max_hostages}`: Foreman card 9 is 5/4 ◇, Zip & Tie aced is 5/8.
  - Added `ui.prompt.use_armor_bag`.
- D-052: LobbySession uses `Net.connection_failed` (new reason `unreachable`) and `Net.host_lost`, and `Net.join` carries the profile name. Loopback tests added.
- A3-08: the range reads `NpcHitRules.armor_of` only. Removed `_armor_of_mirror`, the stand-in health/headshot arrays and `shield_stopgap`.
- QB-50a: `portrait_texture` set on vance (odile, provisional), reyes (hollis) and accountant.
- data README: Plowman reload numbers per D-045 (3.4 / 4.2 s).
- `check_all.sh --env b`: PASS (1238 tests, 0 failed, 5 skipped).
### In progress
- —
### Blocked
- Batch-3 special mechanics wait on ENV A; anim sets wait on D.
### Notes
- ENV A's TeamModifiers.hostage_reduced still reads `{per, max}` with value-based shape detection. Until A switches to the D-056 fields, the hostage absorption from our data does nothing.
- Proposed: a `deployable.armor_bag` DeployableDef plus loadout-picker gating on `deploy.armor_bag`. A's fallback def covers it for now.
### Questions for lead
- —
### Ready for integration
- yes; `check_all.sh --env b` result: PASS

## 2026-10-11 UTC: B4-14, B4-16..B4-20, D-050/D-053/D-055 follow-ups
### Done
- B4-14 QB-L2 (afacf75): `ModifierPush.push(loadouts)` sets the per-slot `loadout` source and the TEAM sources at launch (solo and co-op host). D-050: Warden akimbo flag.
- B4-16 (9ca14ff): save v5 with unlocks, achievements and pro_job_locks; ProfileSchema type sanitizing; ProfileValidator pruning; golden migration fixtures v0..v4 plus a damaged v5; save_format.md.
- B4-17 (a713639): Workshop 3D orbit view with picker, turntable, slot focus, live deltas and DR preview, equip/buy.
- B4-19 (e6ba2a7): StaminaBar on ui_hud v1.4 plus MockHudModel demo steps.
- B4-20 (495cafb): achievements stub (8 defs), hooked on the payday apply path; the cataclysm_clear unlock; achievements screen.
- B4-18 (merge 91f947d): armory batch 3 with 19 weapons (36 total), 89 mods, models on the pipeline, previews, strings and tests.
- B4-12/B4-04 (8ac82cd, acd8fea): `fire_cue_suppressed` only on weapons with a SUPPRESSOR slot; test_armory enforces it.
### In progress
- Round-7 follow-ups once A's server-side push is on trunk: drop the MenuFlow ModifierPush calls, hooked keys and coverage, `ui.prompt.use_armor_bag`, D-056.
### Blocked
- Batch-3 special mechanics (bow/crossbow, launcher, flamethrower, saw, minigun, lever) wait on ENV A's answers. Anim sets wait on D.
### Notes
- The batch-3 tests tolerate missing anim sets.
### Questions for lead
- —
### Ready for integration
- yes; `check_all.sh --env b` @ 91f947d: PASS (1202 tests, 0 failed, 6 skipped)

## 2026-10-10 20:20 UTC — D-043..D-047 follow-ups, B4-07 hub + GSR theme
### Done
- D-045 (35b3bcc): shell-fed reload times are derived by LoadoutResolver after mods (Plowman 0.4/0.4333/0.4/1.2 → 3.4/4.2 s); no raw reload deltas on shell-fed mods; test_armory uses the same formula.
- D-043 (8079505): strings and vo.crew.ack_* lines for every CrewOrders.ORDERS entry, with a test.
- D-044 (dfe064d): Rampart FeedCover hinged at the rear, opening 78° about local X; SightRail rides on it.
- D-043 QA-25 (88059db): `Loadout.mask_descriptor` is filled by `LoadoutResolver.resolve(loadout, profile)`.
- HUD v1.2 (25ba839): CustodyPanel. The range reads ammo via `LocalHudModel.track(crew)`.
- D-046 final (beddea7, e9e5e5b): category `spawn`; merge() takes `{favors, disable, assets}` only; favors come from the HeistDef; `resolve_ids` returns {} when nothing is accepted; `asset.inside_keycard` and `asset.propped_door` (force_variant, limited to their points); 9 Glasshouse point strings.
- B4-07 (67e3e1d, merged in fdbea9d): safehouse hub.
  - Stations board, planning, armory, masks and range; `MenuFlow.open_station(id)` for ENV C's 3D hub.
  - Board → briefing → pre-planning → loadout with is_pro threaded into the launch options and the payday XP.
  - GSR theme: warm darks, brass PrimaryButton, chamfers, cyan focus.
  - Per-heist accents via `UiAccent`; WCAG contrast test.
- `check_all.sh --env b` @ fdbea9d: PASS (849 tests, 0 failed, 4 skipped).
### In progress
- —
### Blocked
- —
### Notes
- After the D-047 trunk merge, take the lead's versions of test_masks.test_placeholder_visual (it currently logs a SCRIPT ERROR at :163 with D's real meshes) and test_preplan_screen; review the new lift/hack strings.
### Questions for lead
- Open from the earlier entry: QB-PC1/2 (payday cards), QB-BRD2/3 (board co-op, broker prices), QB-52..55 (small loot, intel_laptop scope, Night Deposit points, placeholder heists in the menus).
### Ready for integration
- yes; `check_all.sh --env b` result: PASS

## 2026-10-10 19:40 UTC — B4-05, B4-06, B4-08, B4-09, B4-10, QB-50b; B4-07 in progress
### Done
- B4-08 (49d6cc7, 7df8a7a, 539c53d), D-038/D-039 follow-ups:
  - Glasshouse objective ids come from the G0 `[tag]`s; the guessed keys are removed and the rule is in the README.
  - QA-14 strings added, plus keys A's code already used but we lacked. A test scans systems/world/core for prompt, blocked and voice keys and fails on any missing one.
  - `ui.prompt.blocked.*` renamed to `ui.blocked.*`.
  - QA-16: the deprecated key is rejected by validation and a data-scan test.
  - PreplanResult v1 exactly per preplanning.md: drops[].kind, spawn_tag, escape_tag, reveals, force_variants, cash_spent; `resolve_ids()`; points from `<Map>/Preplan` instanced off-tree; split payment for voted assets; votes via `Net.lobby_send`.
- B4-05 payday card pick (f7e51d6):
  - Three cards (cash, XP, weapon mod, mask part), deterministic from (run seed, slot), with tiers per difficulty. The `progression.card_drop_quality_add` shift applies.
  - Never offers an owned item. 30 s auto-pick; successful heists only.
- B4-06 the Board + broker (d9f8377):
  - City map drawn in code; 8 staggered rotating contracts (600 s), deterministic from the time bucket.
  - Lethal and Cataclysm need level 80; pro jobs 20% from Tense up.
  - Broker costs $12k–$360k ◇ + 5% of the payout.
- B4-09 Night Deposit (5d44618):
  - `loot.cash_bricks` (MEDIUM, $1,600 ◇).
  - 12 objective strings from the doc's tags, plus Accountant briefing lines and Mercer's closing line.
- B4-10 Shadow Ledger (6ab8a80):
  - Loot `ledger_laptop` (LIGHT), `ledger_drives`, `ledger_books` and `painting` (MEDIUM), values ◇.
  - Assets `intel_laptop`, `gondola_left_hung` and `riser_panel` per the doc.
  - 13 objective strings, plus briefing lines.
- QB-50b (1af10b6, 3ec98cb): mask base mesh paths use the pipeline layout; the placeholder UV now has u=0 at +X (matching D's meshes); the mask preview starts at a 35° 3/4 view.
- `check_all.sh --env b`:
  - B4-08 and B4-10 each passed the full check on their own commits (725 tests, 0 failed).
  - The merged HEAD with trunk, after B4-10, is being re-run now.
### In progress
- B4-07: safehouse hub UI layer (stations + `MenuFlow.open_station(id)` for ENV C's 3D hub), Board wired into the flow with is_pro, and the GSR theme / per-heist accent pass.
### Blocked
- —
### Questions for lead
- QB-PC1: should an unpicked payday card survive a quit? That needs a save v5 `pending_card`; today quitting forfeits it.
- QB-PC2: boosts and skins are omitted from the card table until those systems exist. OK?
- QB-BRD1: the Board replaces heist select as the job source (B4-07 wires it; heist select stays at the planning table for now). Who enforces the pro-job "no restart" on failure: MenuFlow or A?
- QB-BRD2: in co-op, should clients see the host's board (seed + bucket via lobby) or their own?
- QB-BRD3: broker prices and level gates are placeholders and need a balance pass.
- QB-52: Night Deposit and Shadow Ledger small loot: add a `loot.small_valuables` def, or just a cash amount via HeistResult `small_loot`? What values?
- QB-53: `asset.intel_laptop` shows on every heist, since generic assets aren't filtered. Should heists without a `laptop` variant `disable` it (ENV C), or should it be a heist-only asset?
- QB-54: Night Deposit's preplan points (`pp_insider_code`, `pp_insider_keycard`, `pp_vent`) have no library asset. Should ENV C define them in HeistDef.preplanning, or should B add library assets?
- QB-55: placeholder heists (Night Deposit, Shadow Ledger) show in the menus but fail to launch until their map and def exist. Keep them visible, or hide them until G1?
- For ENV C: Glasshouse `HeistDef.preplanning` still uses the old shape (ignored with one warning), and its map has no `<Map>/Preplan` node yet.
- For ENV A: PreplanAssets still reads `options["preplanning"]` with the old shape. The contract's DifficultyDef asset-cost multiplier doesn't exist, so it lives in `PreplanTweak.cost_mult` for now.
### Ready for integration
- yes after the HEAD re-run passes (see the next message to the lead)

## 2026-10-10 18:40 UTC — range on A's runtime, HUD adapter removed, D-034 follow-ups, B2-01/02/03
### Done
- Range on ENV A's crew and weapon runtime (6b7c1af).
  - `CrewController.spawn_for_range` + `set_loadout` on every swap. The WeaponVisual viewmodel is on the crew camera.
  - Last-shot readouts come from our targets' `damage_applied`, filtered to the crew's net id. Ammo is read from the crew's weapons.
  - Panel/aim mode pauses `PlayerInput.enabled`. The test camera and debug gun are FALLBACK ONLY.
  - A headless test drives a real CrewIntent shot and checks exactly one `damage_applied` for 35 damage.
- HUD binds LocalHudModel directly; HudModelAdapter deleted (dd1f97e). A new MarkedTargets widget was added. Tested against a real HeistRuntime on a test map (vitals, ammo, Stinger warning, masked).
- D-034 follow-ups (d1dae61).
  - `defense.post_revive_buff` LIST entries are granted per skill.
  - Plowman shell-by-shell reload: start 0.4, per round 0.5, end 0.4 ◇. Its full reload times are now derived from those.
  - Pellet display exponent 1 (Plowman shows 160).
  - `data/tweak/perk_points.tres` (500 XP per point).
- B2-02 briefing screen (38fd559).
  - ContactDef for vance, reyes, accountant and mercer, with drawn placeholder portrait silhouettes.
  - Shows objectives, loot at difficulty, contract pay and escape options.
  - "Play Briefing" emits local `voice_line_requested` with subtitles; 8 original Glasshouse briefing lines.
- B2-01 pre-planning (b149a9a).
  - 10 generic assets (drops, insider info, cable ties, body bags, alternate entry, voted van position). Cost ×1…×13 by difficulty, 10 favors.
  - PreplanPlan validation and `apply()` hand-off dict; PlanVote with host tie-break.
  - A blueprint drawn in code on a placeholder Glasshouse plan (shown with a banner until real map data exists). Doc: `content/docs/preplanning.md`.
- B2-03 mask customization (c110a03).
  - 5 bases, 9 materials (library refs), 10 colour pairs, 8 patterns. Custom masks go in 6 slots; owned parts are tracked.
  - `MaskComposer`/`MaskCatalog.resolve/descriptor/from_descriptor` for ENV A. Save format v4.
  - Mask screen with an orbit preview and an original pattern shader. Doc: `content/docs/masks.md`.
- Tests use a per-process SaveService root (8eeb53c). Parallel runs in several checkouts shared `user://test_profiles` and flaked.
- `check_all.sh --env b` @ 8eeb53c: PASS (551 tests, 0 failed, 8 skipped).
### In progress
- Wiring the flow heist select → briefing → pre-planning → loadout → launch, the Masks button, and the loadout mask-picker fix for custom masks.
### Blocked
- —
### Questions for lead
- For ENV A:
  - QB-46: Please document a way to pause and resume a crew member's input (the range sets `PlayerInput.enabled`), e.g. `CrewController.set_input_paused(bool)`.
  - QB-47: Who makes the crew camera current, and who attaches `CrewController.weapon_visual`? The range does both itself; heists need an owner.
  - QB-48: Could LocalHudModel track a crew member without a HeistRuntime (a `tracked_crew` node)?
  - QB-49: There is no gamepad look on `PlayerInput`.
- QB-PP1: PREPLAN_POINT node contract.
  - Proposal: a Marker3D in `G.PREPLAN_POINT`, named by point id, with metadata category/label/floor/params (spawn_tag, variant_group, variant_slot).
  - Who bakes the menu blueprint resource: ENV C via HeistRegistry, or B under `data/preplanning/blueprints/`?
- QB-PP2: should HeistLauncher take `options["preplan"] = PreplanPlan.apply()`? The shape is in `content/docs/preplanning.md`; applying it is A2-07.
- QB-PP3: who pays for a voted plan? The stub charges the host.
- QB-PP4: co-op plan votes need a lobby message relay in the Net API, e.g. `Net.lobby_send(kind, data)` plus a `lobby_message` signal. Until then: solo/host only.
- QB-PP5: should the `HeistDef.preplanning` merge format (favors, disable, `asset.<id>` overrides) be recorded in heist_def.gd and data_schemas.md? A Glasshouse sketch for ENV C is in the doc.
- QB-50 (art): contact portraits for ENV D/C go in `content/data/contacts/<name>.tres` `portrait_scene`/`portrait_texture`. The mask base meshes are `assets/masks/mask_base_<heron|visage|vulpine|bruiser|owl>.glb` (face-centre pivot, −Z, front-projected UV0), plus optional pattern textures. See `content/docs/masks.md`.
- QB-51: ENV A should rely on content classes `MaskCatalog.resolve/from_descriptor` + `MaskComposer.instantiate` to attach masks. Record this in characters.md?
### Ready for integration
- yes (everything up to 8eeb53c); `check_all.sh --env b` result: PASS

### 2026-10-12 19:05 ET
- PQ-B-26 Board half done (9ebf482a): pad-only Board -> Take -> briefing -> B back. Briefing no longer logs `unknown loot id 'loot.small_valuables'` (skips ids without a LootDef via ContentDB.has). Notoriety reward pick with pad still open.
- PQ-B-1 trial (scratch worktree, discarded, nothing committed): test_pp_input helpers (_accept/_press/_key) switched to PInputDriver from origin/env/p-play plus P's player_input.gd; test_assume_captured=true in before_each, release_all() in after_each. Result: 13 tests, 0 failed, 1 skipped, same as now. Ready to switch for real once round 34 is on trunk.
- Contrast: OFFICIAL now, switched to Env D's flags (the earlier .tscn route is retired).
- PQ-B-26 DONE (9ebf482a Board, e0cc1db8 Notoriety rank-up + reward pick with pad only).

### 2026-10-12 19:20 ET contrast (Env D flags)
- Command (clone root, not --headless, one render at a time):
  `flock /workspace/cnc-team/render.lock xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/godot --audio-driver Dummy --path game --script res://tests/b/render/hud_contrast_capture.gd -- hud|menus`
  SubViewport own_world_3d + UPDATE_ALWAYS, 8 frames + frame_post_draw. PNGs: ~/.local/share/godot/app_userdata/CAPERWORKS/contrast_<shot>.png.
  Gotcha: a --script SceneTree is compiled before autoloads exist (Identifier not found: EventBus / Log), so the launcher loads render/contrast_worker.gd at runtime.
- HUD over dark / mid / bright / white backdrops: PASS, 0 failures. Floating text holds up on white with outline 8 + shadow, so no backing panel was added.
- Fix: the status lines ("Unmasked: casing", "Carrying: ...", hostages, warnings) also float over the world, and they were the weakest text by eye in the captures. They now use float_text too, and the test covers them.
- Tool fix: labels clipped by a ScrollContainer (hub's The Record card, loadout's Mask row below the fold) were false FAILs (ratio 1.0 / 2.1). The check now cuts to the visible rect.
- Pad walk (76238ea5): options, all tabs, pad keybind capture (the A that opens the capture is not captured), B drops unapplied edits. No player trip found.

### 2026-10-12 19:15 ET pad-only + 720p walks (in-heist pause, payday, quit / reload)
- test_pp_pad_walks: payday with the pad (Continue -> cards -> d-pad to card 2 -> A -> Continue, all on screen at 720p) and hub -> main menu -> hub with the pad (the saved profile reloads, B backs out). Both pass, no bug found.
- In-heist pause: Start opens Options over the HUD and B closes it (already covered by PQ-B-20).
- PLAYER TRIP (needs a lead ruling, not fixed because of the D-082 freeze): the in-heist pause (Options) has NO way to leave or abandon a heist. The strings `ui.menu.leave_heist` ("Leave Heist") and `ui.menu.quit_confirm` have shipped since B1-07, and MenuFlow._leave_heist() exists, but no button calls them. A solo player who wants out must finish or fail the heist (or kill the game). Proposed: a Leave Heist button with confirm in the in-heist Options footer, wired to _leave_heist (about 30 min + test). Is this a fix or new content under D-082? -> RULED a fix; DONE in B-PP-41 (see below).
- B-PP-41 Leave Heist (lead ruling, allowed D-082 fix): the in-heist Options footer gains Leave Heist (existing `ui.menu.leave_heist`). It opens a confirm (`ui.menu.quit_confirm`, Confirm / Cancel, focus starts on Cancel, the d-pad stays in the dialog, B / Esc cancels). Confirm -> the existing MenuFlow._leave_heist() -> hub (or main menu if the safehouse was not entered). The menu-side Options is unchanged.
  Test test_pp_live_hud_720p::test_live_heist_leave_with_pad (live glasshouse, pad only: Start, Leave, B cancel, Leave, Confirm -> hub, runtime gone, input pause released). Also green: test_options_screen 8, test_options_bindings 10, test_options_apply 3, test_pp_screens_720p 4, test_pp_pad_walks 3. gdlint clean. Trunk 64f10747 already merged, so no merge needed.
- PQ-B-1 / PQ-B-19 still wait for round 34 on trunk (claude/dreamy-hamilton-pc7vck). PQ-B-25 waits for the A / P fields.

### 2026-10-12 19:55 ET trunk db22c24c merged (round 34)
- Merged origin/claude/dreamy-hamilton-pc7vck db22c24c into env/b-content (03087809), clean, no other env's files touched. Green: test_pp_pad_walks 3, test_pp_live_hud_720p 4, test_pp_screens_720p 4, test_options_screen 8, test_options_bindings 10, test_options_apply 3, test_options_settings 11, test_options_palettes 6, test_pp_input 13 (0 skipped: the payday LB/RB actions are on trunk now, so the shoulder-button test runs for real). gdlint: fixed one ordering error in test_pp_screens_720p.
- BLOCKED, still: PQ-B-1 / PQ-B-19 / PQ-B-25. Trunk db22c24c does NOT contain P's work. There is no game/tests/p/p_input_driver.gd and no PlayerInput.test_assume_captured. A's LocalHudModel domination fields and P's CrewController.casing_blocked signal are not on trunk either. db22c24c is the lead/d078-docs merge (D-078..D-085, audio_cues v1.4, payday LB/RB). P's env/p-play and A's env/a-core still need to land.

### 2026-10-12 20:15 ET PQ-B-1 / 19 / 25 handoff patch (not on env/b-content)
- Scratch: env/b-content c3a62c96 + origin/env/p-play + origin/env/a-core (clean merges, worktree deleted after).
- Patch: handoff/pq_b_1_19.patch (untracked, B test files only, `git apply --check` clean on env/b-content).
  - PQ-B-1: 7 test_pp_* files switch their _pad / _key / _press / _accept helpers to PInputDriver. test_assume_captured is set in before_each, release_all() runs in after_each.
  - PQ-B-19 / PQ-B-25: new test_pp_live_prompts.gd, a live glasshouse run with real input. Sprint while casing shows "Mask up to sprint". A guard in its window in front of the crew shows the domination prompt with the shout key, and it hides afterwards. Mask up (hold G), aim with the real mouse, and holding interact starts a lockpick, with the HUD showing the key and progress.
  - Scratch results: gamepad_flow 4, heist_ui 8, input 13, live_hud_720p 4, lobby_720p 3, menu_walk 1, pad_walks 3, live_prompts 3 (2 runs): all 0 failed. gdlint clean.
  - Test-writing note: setting crew.look_pitch directly gets overwritten by PlayerInput. Aim with PInputDriver.look() instead.
  - Apply with `git apply handoff/pq_b_1_19.patch` once P + A are on trunk.
- Lead playability_pass.md B rows (PP-B-1..3) are all already fixed (PQ-B-2..4). No unblocked B row is left.

### 2026-10-12 20:25 ET lead D-082 queue (fixes only)
playability_pass.md is lead-owned (tools/ci/owners.json gives B game/content/**, game/tests/b/**, docs/status/env_b.md). Proposed PP-B rows are recorded here for the lead to copy:
| PP-B-4 | B | Full loop real input (hub -> heist -> payday -> hub), pad-only and mouse + keyboard |
| PP-B-5 | B | Weapon stats shown in the UI vs gameplay values |
| PP-B-6 | B | Save / quit / reload after a completed and a failed heist |
| PP-B-7 | B | HUD readability under loud play at 720p (software render) |
| PP-B-8 | B | Pad players see keyboard keys in HUD prompts (found in PP-B-4) |

- PP-B-4 DONE: test_pp_full_loop.gd covers main menu -> Safehouse -> Planning -> Night Deposit -> briefing -> pre-planning -> loadout -> Launch (real night_deposit run) -> end (setup) -> payday Continue -> card -> Continue -> hub with focus. Pad-only and keys + mouse clicks both pass (2/0). No dead end or wrong focus found. The co-op lobby legs stay covered by test_pp_lobby_720p.
- PP-B-8 FIX: the HUD prompts (interact, shout/dominate, casing hint) always showed keyboard keys ("Hold F"). InteractionPanel.action_key_text now names the pad button (A/B/X/Y/LB/RB/LT/RT...) after a pad input and switches back on a key or mouse input. The HUD redraws on a switch. Test: test_pp_heist_ui::test_prompts_follow_last_device.
- PP-B-5 DONE, no mismatch: test_pp_weapon_stats checks every weapon, stock and with each of its mods, comparing StatCalculator.display (loadout / workshop panels) with ENV A's CrewWeapons (mag_size, mag + reserve, the 60/rpm shot interval, reload_time_s / reload_empty_time_s, damage_at x pellets). All match. Note for the lead (design, not a bug): the panels show weapon stats without skill modifiers (weapon.mag_extra, ammo_total_mult, reload_speed_mult, damage_mult), which only apply in play. PD2's inventory shows skill-boosted values. Ruling needed if the panels should include skills.
- PP-B-6 DONE, no bug: test_pp_save_reload, for both a completed and a failed glasshouse run. The profile starts with cash, XP and a modded secondary. The payday is keyboard-driven, then back to the hub. Quit (MenuFlow freed) and start again: cash, stash, XP, level, owned weapons / mods / masks, unlocks, notoriety and career match the disk save, and the profile loadout and the armory loadout screen equal the saved loadout. Completed pays and gives XP. Failed pays nothing.

| PP-B-9 | B | LeftHandIK on the fore-end for every two-handed weapon (P: brute_12 support hand floats at hip fire) |
- PP-B-9 (lead quick item): test_pp_left_hand_ik checks every two-handed weapon model (not pistol class, not the pistol / akimbo / bow anim sets). The LeftHandIK must be inside (2 cm) a non-barrel mesh, 0.06..0.46 m ahead of GripMount and >= 0.08 m behind the Muzzle. All 29 pass and no model was moved.
  brute_12: LeftHandIK (-0.026, 0.046, -0.330) is on the Shroud (the fore-end, z -0.25..-0.42), 0.330 m ahead of the grip and 0.126 m behind the muzzle. No mod carries its own LeftHandIK, so WeaponVisual.get_marker returns this one. I could NOT reproduce P's 0.52 m in the model: the extra ~0.19 m is probably on P's side (FpViewmodelTweak wrist offset, hip pose or weapon scale). P should check with the numbers below.
  Per weapon, m ahead of the grip / m behind the muzzle: anvil_lmg 0.300/0.453, bastion_br 0.330/0.271, brute_12 0.330/0.126, condor_50 0.450/0.566, corsair_ar 0.330/0.282, cyclone_rotary 0.090/0.455, drover_762 0.300/0.347, falchion_dmr 0.360/0.399, ferret_9 0.120/0.086, furnace_ft 0.380/0.161, gale_mg 0.300/0.301, harrow_12 0.240/0.231, heron_308 0.400/0.451, hornet_9 0.160/0.093, hush_9 0.215/0.189, lancet_45 0.176/0.095, lark_carbine 0.235/0.126, mastiff_45 0.104/0.209, mule_12 0.290/0.151, osprey_762 0.330/0.371, plowman_12 0.390/0.346, rampart_lmg 0.360/0.346, reaper_db 0.200/0.481, rotor_saw 0.205/0.367, shrike_44 0.250/0.311, tern_556 0.098/0.335, thumper_40 0.170/0.161, vise_crossbow 0.250/0.206, wasp_pdw 0.145/0.111
- PP-B-7 DONE: test_pp_hud_720p::test_loud_hud_readable_720p_scale_{1,max} (4/0). Ammo, bleedout timer, bag and hostage labels are shown, on screen, >= 14 px at 720p and not overlapping, at hud_scale 1.0 and 1.5. Software render (`-- loud`, render.lock, Env D flags): PASS, 0 contrast failures on dark / mid / bright / white.
  Gaps for a lead ruling (new HUD content, not fixed under D-082): (1) the HUD has NO reload indicator, and LocalHudModel exposes no reload state (would need an A field, e.g. `reloading`). (2) There is no throw-bag key hint while carrying a bag, only "Carrying: <loot>". PD2 shows the throw key.
