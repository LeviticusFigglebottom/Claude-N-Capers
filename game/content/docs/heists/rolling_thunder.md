# Rolling Thunder: ENV B content stub (B6-01)

Owner: ENV B. Heist row 7 of `docs/design/game_overview.md`: `rolling_thunder`, **Rolling Thunder**, an
armored convoy. PD2 analog: Transport. Loud (stealth-start ambush), size M, phase P5.

**Status: stub.** ENV C's G0 level doc does not exist yet. Until a HeistDef and a map scene ship, the
heist is hidden from the menus, the Board and the broker (QB-55, D-049; `test_p5_catalogue.gd`).
**V** = taken from a doc or the PD2 research, **◇** = our choice.

| What | Value | Where |
|---|---|---|
| Contact | `contact.reyes` (Hollis "Hammer" Reyes) | `data/board/city_map.tres` (B4-06) |
| Board spot | district `southfield`, anchor `(0.14, 0.86)` | `data/board/city_map.tres` |
| Accent | road-sign lime `#B8D648` ◇ (raw WCAG AA for text: 7.8:1 or better on our panels) | `data/ui/heist_accents.tres` |
| Heist list | `solo_ai_teammates` 3 (loud: a full bot crew, as Dockside Burn) | `data/ui/heist_list.tres` |
| Strings | `heist.rolling_thunder.name` / `.subtitle` / `.brief` | `data/strings/strings.csv` |
| Base payout (`HeistDef.base_payout`, unscaled) | **$85,000 placeholder** ◇ | this doc (the def carries it) |

## Contact: Hollis "Hammer" Reyes
`game_overview.md` names Reyes the fixer for "loud jobs, armored trucks, warehouses". An armored
convoy is the textbook Reyes job.

## Payout ◇
PD2's Transport contracts pay little up front; the trucks' loot is the money. Ours sits under Dockside
Burn ($95,000): $85,000. A loud job gets no stealth bonus.

| Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|
| $85,000 | $170,000 | $221,000 | $357,000 | $612,000 | $782,000 |

## Loot (proposed for ENV C)
| id | Weight | Base | Role |
|---|---|---|---|
| `loot.gold` | HEAVY | $2,800 | truck cargo |
| `loot.cash_bricks` (existing) | MEDIUM | $1,600 | truck cargo |
| `loot.server_drives` | MEDIUM | $1,800 | a courier truck's data cargo, if the doc wants one |

## Waiting on ENV C (G0 doc)
* Objective `[tag]`s → `objective.rolling_thunder.*` strings and the briefing placeholder (none yet).
* Truck count, the cargo roll per truck, the required bags, and whether the stealth start is a
  separate `HeistMode`.
* Escape options, `HeistDef.contact` (Reyes proposed), music track, pre-planning points and assets.
* Long briefing text (`heist.rolling_thunder.briefing`) and briefing/mission VO.

## Required loot (D-075)
4 bags to escape; the rest is bonus.
