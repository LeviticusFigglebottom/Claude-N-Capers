# Ostrander Federal: ENV B content stub (B6-01; renamed from meridian_federal, D-075)

Owner: ENV B. Heist row 6 of `docs/design/game_overview.md`: `ostrander_federal`, **Ostrander Federal**.
PD2 analog: Big Bank. Stealth + loud, size L, phase P5.

**Status: stub.** ENV C's G0 level doc does not exist yet. Until a HeistDef and a map scene ship, the
heist is hidden from the menus, the Board and the broker (QB-55, D-049; `test_p5_catalogue.gd`).
**V** = taken from a doc or the PD2 research, **◇** = our choice.

| What | Value | Where |
|---|---|---|
| Contact | `contact.accountant` (The Accountant) | `data/board/city_map.tres` (B4-06) |
| Board spot | district `financial`, anchor `(0.84, 0.24)` | `data/board/city_map.tres` |
| Accent | banknote green `#6FCF97` ◇ (raw WCAG AA for text: 6.8:1 or better on our panels) | `data/ui/heist_accents.tres` |
| Heist list | `solo_ai_teammates` 3 | `data/ui/heist_list.tres` |
| Strings | `heist.ostrander_federal.name` / `.subtitle` / `.brief` | `data/strings/strings.csv` |
| Base payout (`HeistDef.base_payout`, unscaled) | **$160,000 placeholder** ◇ | this doc (the def carries it) |

## Contact: The Accountant
`game_overview.md` names the Accountant the insider for "bank/corporate/stealth-only data jobs". A
federal bank is the biggest bank job; Night Deposit (the small bank) is the precedent.

## Payout ◇
PD2's Big Bank is the large bank contract, well above the small bank. Ours is the only size-L heist so
far: $160,000, about 1.8× Night Deposit's $90,000.

| Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|
| $160,000 | $320,000 | $416,000 | $672,000 | $1,152,000 | $1,472,000 |

## Loot (proposed for ENV C)
| id | Weight | Base | Role |
|---|---|---|---|
| `loot.cash_bricks` (existing) | MEDIUM | $8,000 | vault money (the roadmap's "money MEDIUM") |
| `loot.gold` | HEAVY | $14,000 | vault gold |
| `loot.bearer_bonds` | LIGHT | $7,000 | vault cage |
| `loot.server_drives` | MEDIUM | $7,500 | optional (server room), if the doc wants one |
| `loot.small_valuables` (no def) | — | prefab, ◇ $800–2,400 per item | deposit boxes (S10.3, QB-52; as Night Deposit) |

## Waiting on ENV C (G0 doc)
* Objective `[tag]`s → `objective.ostrander_federal.*` strings and the briefing placeholder (none yet).
* Vault layout, bag counts and the required bags; deposit-box counts and values.
* Escape options, `HeistDef.contact` (Accountant proposed), music track, pre-planning points and assets.
* Long briefing text (`heist.ostrander_federal.briefing`) and briefing/mission VO.

## Required loot (D-075)
6 bags to escape (4 on Routine); the rest is bonus.
