# Rolling Thunder: ENV B content stub (B6-01)

Owner: ENV B. Heist row 7 of `docs/design/game_overview.md`: `rolling_thunder`, **Rolling Thunder**, an
armored convoy. PD2 analog: Transport. Loud (stealth-start ambush), size M, phase P5.

**Status: groundwork (data side, 2026-10-17).** The G0 doc is `docs/design/heists/rolling_thunder.md` (D-075).
Hidden from the menus, the Board and the broker until its def, its map **and** its mission script exist
(`heist_list.tres` `requires`: `rolling_thunder_mission.gd`; `HeistCatalog.is_ready`; `test_heist_readiness.gd`).
**V** = taken from a doc or the PD2 research, **◇** = our choice.

| What | Value | Where |
|---|---|---|
| Contact | `contact.reyes` (Hollis "Hammer" Reyes) | `data/board/city_map.tres` (B4-06) |
| Board spot | district `southfield`, anchor `(0.14, 0.86)` | `data/board/city_map.tres` |
| Accent | road-sign lime `#B8D648` ◇ (raw WCAG AA for text: 7.8:1 or better on our panels) | `data/ui/heist_accents.tres` |
| Heist list | `solo_ai_teammates` 3 (loud: a full bot crew, as Dockside Burn) | `data/ui/heist_list.tres` |
| Strings | `heist.rolling_thunder.name` / `.subtitle` / `.brief` | `data/strings/strings.csv` |
| Base payout (`HeistDef.base_payout`, unscaled) | **$85,000 placeholder**; **$30,000 proposed** (D-120 shape, QB-RT1) ◇ | this doc (the def carries it) |
| Mode label | "Loud (ambush start)" (D-075): `heist_list.tres` `mode_key` = `ui.heist_select.modes_loud_ambush` | Board, heist select, briefing |

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
| `loot.gold` | HEAVY | $14,000 | truck cargo |
| `loot.cash_bricks` (existing) | MEDIUM | $8,000 | truck cargo |
| `loot.server_drives` | MEDIUM | $7,500 | a courier truck's data cargo, if the doc wants one |

## Waiting on ENV C (G0 doc)
Answered by the G0 doc (D-075); what remains open is in the audit below.

## Required loot (D-075)
4 bags to escape; the rest is bonus.

## Audit vs the G0 doc and D-120 / D-130 / D-140 (2026-10-17, ENV B)
* **Payout (D-120 shape).** The $85k placeholder predates D-120 (DB then paid $95k; D-120 cut it to $24k). Expected Routine
  bags: 2 trucks (0.7) = cash van 4.9 × $8,000 + bullion 3.5 × $14,000 ≈ $88k; 3 trucks (0.3) ≈ $133k; weighted ≈ $102k,
  plus ≈ $3k small loot (pay station, diner till/safe, petty cash). Required run = 4 cash bags = $32k.

  | base | Routine full clear | bag share | required-only run |
  |---|---|---|---|
  | $85,000 (placeholder) | ≈ $190k | 54 % | $117k |
  | **$30,000 (proposed)** | ≈ $135k (≈ DB's full clear; PD2 Transport pays a small contract) | 76 % | $62k |

  Both sit in D-120's 39-81 % band; $30k keeps "greed pays" and DB parity. Per difficulty (×1/2/2.6/4.2/7.2/9.2):
  $30,000 / $60,000 / $78,000 / $126,000 / $216,000 / $276,000. `test_p5_catalogue` keeps $85k until the lead rules.
* **Loot:** no new ids. `loot.cash_bricks` MEDIUM $8,000 (4/5/6 per cash van), `loot.gold` HEAVY $14,000 (3/4 per bullion
  truck), `loot.bearer_bonds` LIGHT $7,000 (2, `bonds_courier`), all D-120 values; `loot.thermite` is a tool bag (D-068,
  $0). Small loot at prefab values.
* **Stealth bonus (S11.1):** none (D-075: no stealth win): `stealth_bonus_mult = 1.0` as DB.
* **D-130 / D-140:** written for stealth heists (no RT win in stealth; an early alarm is a penalty, not a fail). Proposed:
  RT is exempt (the site guard's pager cap stays 4; civilians stay the `civilians` scalar 6/9/12 + `rush_hour`). QB-RT2.
* **Strings skeleton (this round):** `heist.rolling_thunder.briefing`, the 13 `objective.rolling_thunder.<tag>` lines (the
  `trucks` line reads `{opened}/{total}` from `update_objective_data`, `secure` reads `{count}/{total}`), the brief fixed to
  "two or three armored trucks" (it said three), `ui.heist_select.modes_loud_ambush`.
* **Pre-planning (this round):** `asset.signal_insider` (access, force_variant on `pp_signals`, $1,500 / 1 favor) and
  `asset.intel_route` (intel, reveals `convoy_route` + `marshal_walk`, $1,500 / 1 favor) as library assets; they show only
  where those groups / points exist. `asset.c4_drop` waits on the item drop kind (A5-03 / QC-84).
* **Not yet (waits on A's mission / C's G1):** VO text (Mercer + Reyes `vo.reyes.*`), preplan point labels
  `ui.preplan.point.rolling_thunder.*`, blueprint room labels, the `item.c4` HUD count (QC-84 B part), the cue ids for
  audio_cues v1.4 (QC-85).

### Open questions (QB-RT, to the lead)
1. **QB-RT1** base_payout $30,000 (proposed) or keep $85,000?
2. **QB-RT2** RT exempt from D-130 §1 and D-140 (loud heist with a stealth setup)?
3. **QB-RT3** `asset.c4_drop`: B drafts it once A5-03 defines the item drop kind (`drop: item.c4`, `params.count`); OK to
   wait?
4. **QB-RT4** Reyes in-heist radio: speaker id `reyes` with lines `vo.reyes.*` (B7-03 contact radio shape) or mission
   `say(..., &"reyes")` only? Decides where B writes the VO.
5. **QB-RT5** The doc's `ui.preplan.point.rolling_thunder.<point_id>` labels: B writes them with the VO round (after G1)?
