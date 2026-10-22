# Rolling Thunder: early-alarm balance review (LEAD r277 ask; proposal only, nothing applied)

Owner: ENV B. Data: ENV A's two auto_loud runs (seed 1001, masked at t≈7, so `police_delay_s` = 0, design D-075). Headless,
4 crew (the pilot + 3 bots). References: `docs/research/pd2_research.md` §2.1 (assault cycle) and the spawn-cap list,
`DirectorTweak` (systems/director/director_tweak.tres), and `DifficultyDef` (content/data/difficulty/*.tres).

## What the runs show
| | Hazardous (full damage) | Cataclysm (harness damage ×0.25) |
|---|---|---|
| Wipe | t = 118 | t = 103 |
| Peak alive | 11 (cap 24) | 11 (cap 36) |
| Police spawned | 29 | 19 |
| Specials | bulwark 1, stinger 1, longshot 1, phantom 1 | stinger 3, longshot 1, corpsman 1 |
| Where the crew went down | t≈80, a dead-end corner of the padlocked site (pilot stuck lockpicking t = 70-111) | t = 70-82 at (-12, -10), inside the first BUILD |

- **Timing is PD2's:** CONTROL 20 s, then ANTICIPATION 30 s, then BUILD 35 s, then SUSTAIN. This is PD2's cycle (§2.1:
  Anticipation 30 s, Build ~35 s), started at the alarm. The first SUSTAIN lands about 55 s after the alarm, which is
  well before the convoy (`convoy_eta_s` 150 / 180 / 210 s).
- **Force size is not the problem:** peak alive 11 is about half of Hazardous's cap and under a third of Cataclysm's.
- **The specials match PD2's caps:** Cataclysm stinger 3 is PD2's "Tasers 3 on Mayhem and above". Hazardous saw 4
  specials in 118 s.
- **Both wipes have harness causes:**
  - Hazardous: the pilot's dead-end routing (A has fixed it).
  - Cataclysm: the taser bypasses the harness damage ×0.25 (the stinger's lock is not damage), so that run was harsher
    than the multiplier suggests. Also, 3 stingers can arrive together (no per-stage limit).

## What is RT-specific (the real issue)
After an early alarm, the crew has **no objective until the convoy arrives**. They hold an open junction through all of
wave 1 (up to about 150 s of a 210 s ETA) before the trucks exist. PD2's transport jobs alarm *with* the target in
reach. Here the punishment is mostly dead time under fire, not the decisions D-075 meant to tax (crash stop, lockdown
saws ×1.5).

## Proposals (numbers; each independent; none applied)
1. **Convoy pushes through sooner (A, mission; recommended).** On an early alarm, set the arrival to
   `min(convoy_eta_s, alarm_t + 75 s)`. The convoy then arrives during wave 1's BUILD, and the crew fights over the
   trucks, not an empty street. It fits the doc's "Vaultline pushes through to the depot". `police_delay_s` stays 0
   (D-075). Expected: the same wave, but the saws (×1.5 lockdown) start about 75-135 s earlier.
2. **Wave-1 stinger pairing on Lethal+ (A, director data/schema).** At most 2 stingers alive during the first assault
   after an early alarm (PD2 tasers deploy in pairs). Later waves keep the DifficultyDef caps (3). If A prefers no new
   field: Cataclysm `control_special_chance` 0.3 -> 0.2 for RT's first CONTROL only. I prefer the pairing rule.
3. **No change** to `police_delay_s` weights, `enemy_cap`, `force_pool_per_force` or the special caps. The runs give no
   evidence for them.
4. **Re-measure before deciding (A harness):** 5 seeds per cell, Hazardous and Lethal, early alarm, with the fixed pilot.
   - The stinger lock must not bypass the harness multiplier (or report the stinger-down share separately).
   - Target shape: Hazardous early alarm survived (no wipe before the trucks open) on ≥ 3 / 5 seeds; Lethal on 1-2 / 5;
     Cataclysm on ≤ 1 / 5. Apply 1 (and 2 if Lethal+ still wipes in BUILD), then re-run.
