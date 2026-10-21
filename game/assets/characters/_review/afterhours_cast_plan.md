# Afterhours cast plan, reuse-first (D-147; ENV D, 2026-10-21; PAPER ONLY, nothing built)

Sources: `docs/design/heists/afterhours.md` "Staff, civilian and guard roster" and "Specials" (trunk 7c1061b2),
`world/characters/` (200 looks), the char_anim_humanoid SOURCE clip list, D-130 (no twins while a tag's live count is at
most its looks), and D-147 (variants come from finishes, not meshes). This supersedes the Afterhours half of
`next_heist_cast_notes.md`: that estimate (8 new patron meshes, 3 bouncers, 2 bartenders) did not apply D-147.

**Bottom line: 0 new meshes, 16 finish swaps (5 bouncer, 4 bartender, 6 patron, 1 off-duty), 1 new clip (`dj_mix`).** A finish swap is what RT's
street_pedestrian g-i are: the same body params, hair style, age and garment meshes, with a new skin tone, hair colour
and garment materials (`recolor`). Each is a new face for the D-130 pool checks. It costs one build and assemble, and
skirt drape and cower offsets carry over from the base look.

## Roles, counts and where each look comes from

| Role (spawn tags) | Live max | Looks today | Plan | New |
|---|---|---|---|---|
| Bouncers: door, rope, floor / BOH / upper rovers, alley smoker, camera operator (`guard_*`, CAMERA_OPERATOR) | 7 (Lethal+: 2 fixed, 3 rovers, smoker, operator) | `club_bouncer`, `_b` | 5 finish swaps (`club_bouncer_c`-`_g`): skin and hair, with the bomber / tee in other near-blacks (charcoal, graphite, black-brown). The SECURITY print and radios stay. | 5 swaps |
| Bartenders: main 2, east 1, VIP 1, box office / cloak, counter (`civ_bar_*`, `civ_box_office`, `civ_count`) | 6 | `club_bartender`, `_b` | `gallery_waiter` / `_b` as finish swaps into Velvet colours (Halberd wine waistcoat / jacket → violet, the Halberd pin → black, so it reads as a button) for the VIP bar and the box office / cloak; plus 2 finish swaps of `club_bartender` / `_b`. | 4 swaps |
| DJ (`civ_dj_stage`, `civ_dj_green`) | 1 | `club_dj` | Reuse as is. | - |
| Patrons: bars, booths, foyer, WCs, passage, balcony, VIP (`civ_patron`) | 20 (Lethal) | `club_patron` a-d | Reuse the 10 `gallery_patron` gala looks (cocktail dresses, dinner jackets) as the dressier VIP / balcony crowd. Add 6 finish swaps of `club_patron` a-d (`club_patron_e`-`_j`, satin / knit colours from the club palette). That makes 10 club + 10 gala = 20 looks, so 20 live has no twins. | 6 swaps |
| Dancers, 4-6 clusters of 5 (`civ_dancer`) | 30 | (patron looks) | The 10 club looks (a-j), with no twin inside a cluster of 5. Across clusters looks repeat: 30 live on 10. D-130 allows that, because the tag's live count exceeds its looks. **LEAD ruling 2026-10-21:** accepted, with no twins inside a cluster and no extra swaps. | - |
| Off-duty cop, rare (`civ_offduty`) | 1 | `frd_agent` / `_b` | The roster says plain clothes, but both looks wear the FRD navy windbreaker with frd marks. Plan: 1 finish swap of `frd_agent` with the windbreaker in black leather and the marks recoloured to match (if the marks are a separate material; check at build). The gold belt badge stays as the tell. | 1 swap |
| Co-op couriers, rare (`cartel_courier`) | 2 | `cartel_gunman` a-l | Reuse (12 looks). | - |
| Police and specials (Phantom, Stinger, Bulwark, Wrecker, Corpsman, Longshot, Brandt + `bulwark_aegis`) | director | all exist, with frd / sentinel / zero reskins and the D-145.3 duty looks | Reuse via A's resolver (EnemyDef looks, as on RT). No tag rows. | - |
| Crale (not in tonight), the Accountant (never seen), the bartender on the payroll (one of the bartenders) | 0 | - | Nothing to build. | - |

## Clips
Already in the library: `bouncer_idle`, `bartender_wipe` / `bartender_pour` (authored for the 1.05 m bar tops, with staff spawns
0.28 m behind them, as the doc places them), `dance_a` / `_b` / `_c`, `desk_work`, `sit`, `queue_idle`, `smoke`,
`walk_text`, `cower_stand` / `cower_seated`.
**Missing: `dj_mix` (QC-74), the only new build.** Hands on the decks at about 1.0 m (the stage desk height to confirm
with C), alternating jog-wheel and fader moves, a head nod on the beat, and one hand to the right headphone cup now and then
(event `cue`). Built from `desk_work`'s reach to a surface, the way RT's `counter_wipe` reused `bartender_wipe`.

## Data (when Afterhours is picked; for A / C)
- `p5_cast.json` heists.afterhours pools: club_bouncer 7, club_bartender 6, club_patron 20 (with the 10 club looks as the
  dancer sub-pool), off-duty 1, couriers 12.
- `tag_map.afterhours` / A's `heist_tag_characters.afterhours`: `guard_door`, `guard_rope`, `guard_floor`, `guard_boh`,
  `guard_upper`, `guard_alley`, the operator, `civ_bar_main` / `_east` / `_vip`, `civ_box_office`, `civ_count`,
  `civ_dj_stage` / `_green`, `civ_patron`, `civ_dancer`, `civ_offduty`, `cartel_courier`.
- Tests: test_p5_cast pool rows (faces unique, gender floors), test_cower_offsets (the bouncers' and bartenders' roles
  join CIV_ROLES where they are civilians), test_skirt_drape inherits from the bases.

## Watch items
- `gallery_patron_h` (gold satin cocktail dress) is close to `club_patron` (gold satin mini) in one room. If the lineup shows it,
  give `club_patron` a different finish in its swap set, not a new mesh.
- Perf: ≤ 50 civilians alive in one room (doc Budgets). Finish swaps add materials, not meshes. CrowdLod proxies (no
  shadows since D-146) carry the dance floor. Add AH views to `heist_cast_perf` when the map exists.
- Estimate: about half a D day (16 swaps are data + one build / assemble pass; `dj_mix` and its checks are most of it),
  against about 2 days in the earlier non-D-147 estimate.

## Built on prep/d-ah (held for AH's turn)
- `dj_mix` (dfd7ce9bf): see SOURCE `ah_dj_placement`, test_ah_clips, `_review/ah_d1/dj_mix_review.png`.
- The 16 finish swaps: `club_bouncer_c`-`_g`, `club_bartender_c` / `_d`, `club_waiter` / `_b` (gala waiters in Velvet violet;
  defined in char_p5_gallery.py), `club_patron_e`-`_j`, `frd_agent_offduty` (char_police.py). Each one has the same
  per-mesh tri counts as its base. The `recolor` step is now shared (`_outfit_build.apply_recolor`, run after every recipe).
  Three new library colours for the patrons: `char_satin_silver`, `_emerald`, `_coral` (make_materials). Faces moved
  off the gala pool: e skin 3, i skin 6 (they collided with gallery_patron / _d).
- p5_cast: heists.afterhours pools (bouncer 7, bartender 6, patron 20, dancer 10, offduty_cop, cartel_courier 12) and
  `tag_map.afterhours` (18 spawn tags). A mirrors them into `heist_tag_characters.afterhours` when AH starts.
- Review: `_review/ah_d1/ah_{door,bar,patrons}_{sheet,lineup_30m,silhouette_30m}.png`.
- Known limit: the off-duty cop's FRD letters are geometry, so up close on the back they still show as faint relief
  in the black leather. A colour swap can't remove them; dropping them needs a recipe option. That is a small code change, not a new mesh.
