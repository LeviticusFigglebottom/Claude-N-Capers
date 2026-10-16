# Gallery Night: ENV B content stub (B6-01)

Owner: ENV B. Heist row 5 of `docs/design/game_overview.md`: `gallery_night`, **Gallery Night**, Halberd
Gallery. PD2 analog: Framing Frame (the gallery day). Stealth + loud, size M, phase P5.

**Status: stub.** ENV C's G0 level doc does not exist yet. Until a HeistDef and a map scene ship, the
heist is hidden from the menus, the Board and the broker (QB-55, D-049; `test_p5_catalogue.gd`).
**V** = taken from a doc or the PD2 research, **◇** = our choice.

| What | Value | Where |
|---|---|---|
| Contact | `contact.vance` (Odile Vance) | `data/board/city_map.tres` (B4-06) |
| Board spot | district `uptown`, anchor `(0.47, 0.36)` | `data/board/city_map.tres` |
| Accent | lilac `#B79CF2` ◇ (raw WCAG AA for text: 5.6:1 or better on our panels) | `data/ui/heist_accents.tres` |
| Heist list | `solo_ai_teammates` 3 | `data/ui/heist_list.tres` |
| Strings | `heist.gallery_night.name` / `.subtitle` / `.brief` | `data/strings/strings.csv` |
| Base payout (`HeistDef.base_payout`, unscaled) | **$57,000** (D-120) | D-120 (the def carries it) |

## Contact: Odile Vance
`game_overview.md` names Vance the fence for "jewelry/art jobs". A gallery of canvases is her job;
Glasshouse is the precedent.

## Payout ◇
D-120 (economy pass): the bags carry most of a run, as in PD2. Gallery Night's contract is $57,000, under
Shadow Ledger's ($70,000, the objective heist) and over Night Deposit's ($26,000); with its canvases and
studies a full clear pays the most of the five (≈ 53% bags).

| Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|
| $57,000 | $114,000 | $148,200 | $239,400 | $410,400 | $524,400 |

## Loot (proposed for ENV C)
| id | Weight | Base | Role |
|---|---|---|---|
| `loot.painting_tidewater_saint` | LIGHT | $5,200 | canvas |
| `loot.painting_widow_in_blue` | LIGHT | $6,000 | canvas |
| `loot.painting_salt_orchard` | LIGHT | $6,800 | canvas |
| `loot.painting_lantern_bearer` | LIGHT | $8,000 | centrepiece |
| `loot.painting_study` | LIGHT | $2,800 | Calloway's study for the centrepiece (D-075; D-081's $700 ×4 in the D-115 balance pass) |
| `loot.small_valuables` (no def) | — | prefab | office and gift-shop small loot (S10.3) |

PD2 cuts canvases out of the frame and carries them rolled, as a light bag. Shadow Ledger's framed
`loot.painting` stays MEDIUM and is not used here.

## Waiting on ENV C (G0 doc)
* Objective `[tag]`s → `objective.gallery_night.*` strings and the briefing placeholder (none yet).
* Which canvases spawn, how many, and how many are required; small-loot values.
* Escape options, `HeistDef.contact` (Vance proposed), music track, pre-planning points and assets.
* Long briefing text (`heist.gallery_night.briefing`) and briefing/mission VO.

## Required loot (D-075)
The Lantern Bearer plus one more canvas to escape; the rest is bonus.
