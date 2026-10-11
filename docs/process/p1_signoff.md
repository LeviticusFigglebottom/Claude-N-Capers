# P1 sign-off: vertical slice (Glasshouse)

Date: 2026-10-11. Signed off by: LEAD. Decision: D-061.

## Gate (roadmap P1) and evidence
| Gate item | Evidence | Result |
|---|---|---|
| `test_p1_vertical_slice.gd` (+ `_b`): all 11 roadmap steps end-to-end on the real map | `tools/ci/run_tests.sh integration`: 10/10, two identical runs, cameras live, SafeLoot locked in the safe | PASS |
| Glasshouse at level gate G2 | `validate_level glasshouse [final]`: all 18 checks; lead review of 23 shots (D-059) | PASS (G3 punch list open) |
| Characters for the slice | security officers, patrol, TAC, civilians, crew, approved at 30 m silhouette + close-up (ENV D) | PASS |
| Full CI | check_all on trunk: 1275+ tests, 0 failed; gdlint, banned patterns, ownership, import validity | PASS |

## Lead playthrough notes
The lead cannot play interactively in this environment; these notes come from the automated gate runs, the
walkthrough report (852/852 spawn→target walks) and the review shots.
- Stealth loop works as designed: casing is safe in PUBLIC, RESTRICTED raises detection, no footstep noise,
  pagers (answer / early release → alarm), body bags hide bodies through 60 s of patrols, cameras (1–3 on Routine).
- Loud loop: the alarm switches to LOUD without a scene change; the director cycles CONTROL → FADE; AI teammates
  revive a downed player in ~12.7 s game time.
- Economy: escape with the mission's 2 bags pays contract + loot × difficulty (92 400 at Tense in the gate run).
- The map reads at human scale; the G4 sightline, the workshop door and the safe are the stealth cruxes, as designed.

## Known gaps carried forward (not P1 blockers)
- Glasshouse G3 punch list (D-059): the plaque lettering, desk decals, fence posts, garage shot, admin framing,
  a monitor warning.
- The gate uses stated shortcuts (isolate_npc, teleports, an injected down in step 10). A human playtest by the
  product owner is recommended before P5 content scaling.
- Odile's contact portrait is provisional (ENV D pass in progress).
- Alarm-while-casing emits a spurious STEALTH hop (ENV A, low priority).

## State of later phases at sign-off
P2 stealth systems done; P3 specials, Brandt, director, custody, AI orders done (Dockside Burn heist and the
`test_p3_loud` / `test_coop_loopback` gates pending); P4 progression largely done (90 skills, 14 decks with all
hooks, 36 weapons, workshop, range, masks, save v5, achievements); Night Deposit and Shadow Ledger at G1.
