# Afterhours: ENV B content stub (B6-01)

Owner: ENV B. Heist row 8 of `docs/design/game_overview.md`: `afterhours`, **Afterhours**, the Velvet
nightclub. PD2 analog: Nightclub. Stealth + loud, size M, phase P5.

**Status: stub.** ENV C's G0 level doc does not exist yet. Until a HeistDef and a map scene ship, the
heist is hidden from the menus, the Board and the broker (QB-55, D-049; `test_p5_catalogue.gd`).
**V** = taken from a doc or the PD2 research, **◇** = our choice.

| What | Value | Where |
|---|---|---|
| Contact | `contact.reyes` (Hollis "Hammer" Reyes) | `data/board/city_map.tres` (B4-06) |
| Board spot | district `midtown`, anchor `(0.665, 0.61)` | `data/board/city_map.tres` |
| Accent | velvet magenta `#F76BD3` ◇ (raw WCAG AA for text: 4.9:1 or better on our panels) | `data/ui/heist_accents.tres` |
| Heist list | `solo_ai_teammates` 3 | `data/ui/heist_list.tres` |
| Strings | `heist.afterhours.name` / `.subtitle` / `.brief` | `data/strings/strings.csv` |
| Base payout (`HeistDef.base_payout`, unscaled) | **$75,000 placeholder** ◇ | this doc (the def carries it) |

## Contact: Hollis "Hammer" Reyes
The city map (B4-06) already gives the Velvet to Reyes. The brief makes the club a laundering front for
the Ortega Fisheries Co-op, Reyes' running feud from Night Deposit and Dockside Burn, and its back office
holds cash and product, which are Reyes' trade rather than Vance's (art, jewelry) or the Accountant's
(banks, data). The Accountant is the alternative if the G0 doc makes it a books-and-data job.

## Payout ◇
PD2's Nightclub is one of the cheaper contracts, with the loot carrying the value. Ours is the lowest of
the M heists: $75,000.

| Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|
| $75,000 | $150,000 | $195,000 | $315,000 | $540,000 | $690,000 |

## Loot (proposed for ENV C)
| id | Weight | Base | Role |
|---|---|---|---|
| `loot.cash_bricks` (existing) | MEDIUM | $1,600 | count-room money (the roadmap's "money MEDIUM") |
| `loot.parcels` | LIGHT | $1,500 | back-office product ("coke LIGHT" in the roadmap; named tastefully) |
| `loot.small_valuables` (no def) | — | prefab | till and VIP-lounge small loot (S10.3) |

## Waiting on ENV C (G0 doc)
* Objective `[tag]`s → `objective.afterhours.*` strings and the briefing placeholder (none yet).
* Safe/count-room layout, bag counts and the required bags; small-loot values.
* Escape options, `HeistDef.contact` (Reyes proposed), music track, pre-planning points and assets.
* Long briefing text (`heist.afterhours.briefing`) and briefing/mission VO.
