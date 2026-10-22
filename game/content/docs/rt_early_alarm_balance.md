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

## LEAD r278 ruling on the above
(1) approved (A implements), (2) held until after (1), (3) and (4) agreed.

## Addendum (LEAD r278): the Bulwark (shield) share
Data (A, auto_loud headless, 4 crew):
| Run | Length | Police spawned | Bulwarks | Share | Per minute |
|---|---|---|---|---|---|
| Routine seed 1002 | 877 s | 151 | 23 | 15 % | 1.6 |
| Hazardous 1001 (planned ambush) | 534 s | 85 | 13 | 15 % | 1.5 |
| Hazardous 1001 (full damage) | 546 s | 86 | 14 | 16 % | 1.5 |

**Cause: the director's general tables, not RT.** Every heist shares these. RT only shows it more because its holdouts
are long.
- A BUILD/SUSTAIN squad brings specials with probability `assault_special_share[stage]` (0.35 / 0.45 / 0.55) ×
  `special_share_difficulty_mult` (Routine 0.5, Tense 0.75, then 1). A special group is then picked by weight among the
  groups whose special is under its cap.
- **Routine / Tense:** only `special_bulwark` (weight 0.6 / 0.8) and `special_longshot` (0.3 / 0.4, and only with a free
  perch) have weight. Stinger is 0 on Routine; corpsman, phantom and wrecker are 0 on both. So about 2/3 or more of all
  special rolls become a Bulwark, and the cap (2 / 3 alive) refills as they die.
- **Hazardous:** the other specials hit their low caps quickly (phantom 1, stinger 2, longshot 2, corpsman 2), and the
  remaining rolls funnel into the Bulwark, whose cap (4) is the highest.
- **PD2 shape** (research §2.4 caps; shares are not in the wiki, so this is a judgement): shields are a minority special
  that rides with squads, rare on Normal / Hard, common from Overkill. A target of **about 5-8 % of police on
  Routine / Tense, 10-12 % on Hazardous and above** reads as PD2.

### Proposal (numbers; general data, so every heist is affected; nothing applied)
| Data (owner) | Now | Proposed | Effect (estimate) |
|---|---|---|---|
| `special_bulwark.weights` (A, groups) | 0.6, 0.8, 1, 1.2, 1.4, 1.6 | **0.25, 0.4, 0.8, 1.0, 1.2, 1.4** | Bulwark's share of Routine special picks drops from ~67 % to ~45 % (vs Longshot 0.3) |
| `special_share_difficulty_mult` (A, director) | 0.5, 0.75, 1, 1, 1, 1 | **0.35, 0.6, 1, 1, 1, 1** | fewer special rolls on the low tiers |
| `special_limits[enemy.bulwark]` (B, difficulty) | 2, 3, 4, 4, 4, 4 | **1, 2, 3, 4, 4, 4** | ends the cap-refill churn on Routine / Tense / Hazardous |

- Together on Routine: about 0.7 × 0.68 of today's picks, so **~11 Bulwarks per 877 s (0.7 / min, ~7 %)**.
- Hazardous: the cap of 3 plus the 0.8 weight gives about **10-11 %**. Lethal and Cataclysm are unchanged.
- To verify: A re-runs the same seeds (Routine 1002, Hazardous 1001) and reports the Bulwark share. Then the r266-style
  loud sweep on GH / ND / DB checks the older heists (their tuning shared these tables).

### Also flagged: the Cataclysm convoy alone wiped the crew
- A counted **10 Vaultline security_officers** at the stop. The doc's convoy table says **2 per truck, 4-6 in all**. The
  count needs checking first; it is A's spawn code or the variant table.
- With 6 crew, the Cataclysm stop is 6 × (200 HP / 40 dmg) + 4-5 escorts. That is PD2-shaped for Death Sentence
  (guards get the difficulty table).
- The run used harness damage ×0.25. A 20 s wipe means the dismount puts the crew in the open: check that the ambush
  window (8 s) and the seat dismount leave the crew in cover before the convoy shoots.
- No data change proposed until the 10-vs-6 count is explained.
- **Resolved (A, 19:15):** no double spawn. 6 convoy crew (2 per truck x 3) + 2 lead + 2 rear + 1 TAC Heavy at the stop;
  "10" was cumulative (+3 site guards, +1 marshal). The Vaultline crew stay on `enemy.security_officer` (QC-83; PD2's
  armoured-transport guards are the difficulty's guard stats). No new def: a Cataclysm stop is meant to be lethal if the
  crew is in the open at the dismount. Proposal (1) (push-through, A 1c626447) and the re-measure stand; if the clean
  ambush still wipes at Cataclysm, look at the 8 s window / dismount timing (A), not the guards' values.

## Revision of (1) (LEAD r279: the alarm + 75 s push measured WORSE, 0/3 on Hazardous)
**Why it failed:** after an early alarm, the director's clock runs CONTROL 0-20 s, ANTICIPATION 20-50 s, BUILD
50-85 s, then SUSTAIN from +85 s (`first_control_s` 20, `anticipation_s` 30, `build_s` 35). The convoy needs about
10 s from its arrival to the stop, so "+75" stopped it at about +85. That is wave 1's SUSTAIN start: 11 convoy units
dismounted onto the assault peak (17 alive at t = 93).

**The quiet window is before BUILD.** A's first Hazardous run had 2-5 police alive from +20 to +50 s (CONTROL keeps at
most `control_alive_max` 4 plus first responders). The convoy must stop and dismount inside it.

| Option | Numbers | Stop at | Before SUSTAIN | Cost |
|---|---|---|---|---|
| **A (recommended): push early** | arrival = min(`convoy_eta_s`, alarm + **25 s**) | about +35 s (mid ANTICIPATION) | **50 s**: the escort + crews with about 3-5 police, then BUILD's ramp | A: one mission constant; no director change |
| B: push into BUILD | alarm + 45 s | about +55 s (BUILD start) | 30 s, while BUILD squads arrive | the two forces still overlap; not recommended |
| C: hold wave 1 | keep +75; SUSTAIN of wave 1 waits until the convoy has stopped **+ 30 s** | about +85 s | 30 s, and the crew has waited 85 s with nothing to do | A: director hook, a scripted hold that is not PD2-like |

**Recommend A, push to alarm + 25 s.**
- It keeps the PD2 cycle untouched, and the crew fights the convoy first and the assault second, as in a clean ambush.
- Lockdown saws (x1.5) still start about 50 s before SUSTAIN, so the penalty D-075 wants stays: the crew opens trucks
  under the first assault, not before it.
- If the alarm comes later than `convoy_eta_s - 25`, the min() keeps the normal ETA; nothing changes.

**Re-measure (A):** the same 5 seeds per cell. Report the convoy stop time and the alive count at the stop and at
+30 s.
- Target as before: Hazardous ≥ 3/5 reach a truck opening.
- If A still fails, add C's hold (+30 s after the stop) on top. Do not push earlier: at under 25 s the convoy would
  arrive while the crew is still reacting to the alarm (CONTROL).

## D-154 follow-up (LEAD r280): the Hazardous seed 1003 outlier (20 "Bulwarks" of 77 police)
- **Half of it is Brandt.** `aegis_captain.gd` spawns his 10 Aegis shields on `enemy.bulwark` (flagged `META_AEGIS`), and
  A's STATS counted them as Bulwarks. The special cap already skips them (`EnemyRoster`: "Aegis squad members never
  count").
- **Ruling (B): Aegis do not count toward the Bulwark share either.** They are PD2's Winters event (a separate,
  once-per-day captain squad), not the special funnel. A's STATS should report them as their own line
  (`META_AEGIS`). No data change.
- **Without them:** seed 1003 is 10/67 = 14.9 %, and the RT Hazardous pool is 18/200 = **9.0 %**. That is at the bottom
  of the 10-12 % target, as D-154's amendment (Hazardous cap back to 4) intends.
- **Respawn cooldown / per-wave total: no change.**
  - 10 funnel Bulwarks over about 250 s of assault is 2.4 / min with 4 alive at most. PD2 refills shields with the
    squads that carry them; there is no shield cooldown in PD2 (the cap is the limit).
  - One seed at 14.9 % is inside run-to-run spread for a cap-4 special.
  - Revisit only if a pick-logged re-run shows a seed above 15 % with the Aegis excluded. Then the knob is a per-wave
    total of 6 (Hazardous) rather than a cooldown, which would also slow the other specials' refills.
