# Afterhours: ENV B content stub (B6-01)

Owner: ENV B. Heist row 8 of `docs/design/game_overview.md`: `afterhours`, **Afterhours**, the Velvet
nightclub. PD2 analog: Nightclub. Stealth + loud, size M, phase P5.

**Status: groundwork (data side, 2026-10-17).** The G0 doc is `docs/design/heists/afterhours.md` (D-075).
Hidden from the menus, the Board and the broker until its def, its map **and** its mission script exist
(`heist_list.tres` `requires`: `afterhours_mission.gd`; `HeistCatalog.is_ready`; `test_heist_readiness.gd`).
**V** = taken from a doc or the PD2 research, **◇** = our choice.

| What | Value | Where |
|---|---|---|
| Contact | `contact.accountant` (D-075) | `data/board/city_map.tres` |
| Board spot | district `midtown`, anchor `(0.665, 0.61)` | `data/board/city_map.tres` |
| Accent | velvet magenta `#F76BD3` ◇ (raw WCAG AA for text: 4.9:1 or better on our panels) | `data/ui/heist_accents.tres` |
| Heist list | `solo_ai_teammates` 3 | `data/ui/heist_list.tres` |
| Strings | `heist.afterhours.name` / `.subtitle` / `.brief` | `data/strings/strings.csv` |
| Base payout (`HeistDef.base_payout`, unscaled) | **$75,000 placeholder**; **$40,000 proposed** (D-120 shape, QB-AH1) ◇ | this doc (the def carries it) |

## Contact: The Accountant (D-075)
The G0 ruling gives Afterhours to the Accountant (Reyes keeps Rolling Thunder): the Velvet's back office
keeps the books and the count room for its owners, which is the Accountant's trade (banks, books, data).

## Payout ◇
PD2's Nightclub is one of the cheaper contracts, with the loot carrying the value. Ours is the lowest of
the M heists: $75,000.

| Routine | Tense | Hazardous | Brutal | Lethal | Cataclysm |
|---|---|---|---|---|---|
| $75,000 | $150,000 | $195,000 | $315,000 | $540,000 | $690,000 |

## Loot (proposed for ENV C)
| id | Weight | Base | Role |
|---|---|---|---|
| `loot.cash_bricks` (existing) | MEDIUM | $8,000 | count-room money (the roadmap's "money MEDIUM") |
| `loot.parcels` | LIGHT | $7,500 | back-office product ("coke LIGHT" in the roadmap; named tastefully) |
| `loot.small_valuables` (no def) | — | prefab | till and VIP-lounge small loot (S10.3) |

## Waiting on ENV C (G0 doc)
Answered by the G0 doc (D-075); what remains open is in the audit below.

## Required loot (D-075)
3 bags of safe cash to escape; the rest is bonus.

## Audit vs the G0 doc and D-120 / D-130 / D-140 (2026-10-17, ENV B)
* **Loot values.** The G0 loot table still lists pre-D-120 bag values ($1,600 / $1,500 / $1,200). The live LootDefs are the
  D-120 values: `loot.cash_bricks` MEDIUM **$8,000**, `loot.parcels` LIGHT **$7,500**, `loot.cash` LIGHT **$6,500**. No
  new LootDef. Small loot at the doc's prefab values (tills $600 ×4, drop safe $900 ×3, bottle service $800, desk drawer
  $1,200, tip jar $300: ≈ $7.4k), inside D-068's range.
* **Payout (D-120 shape).** Expected Routine bags: safe 4.8 × $8,000 = $38.4k; count room ($13k at 0.6, or +1 safe bag
  at 0.4) ≈ $11k; product 4 × $7,500 = $30k: ≈ $79k of bags + ≈ $7k small loot. Required run = 3 safe bags = $24k.

  | base | Routine full clear | bag share | required-only run |
  |---|---|---|---|
  | $75,000 (placeholder) | ≈ $161k | 49 % | $99k |
  | **$40,000 (proposed)** | ≈ $126k (between DB/RT ≈ $135k and GH) | 63 % | $64k |

  PD2's Nightclub is a cheap contract carried by its loot. Per difficulty (×1/2/2.6/4.2/7.2/9.2): $40,000 / $80,000 /
  $104,000 / $168,000 / $288,000 / $368,000. `test_p5_catalogue` keeps $75k until the lead rules.
* **Stealth bonus (S11.1, D-141):** size M → `stealth_bonus_mult = 1.15` in C's def.
* **D-130 §1** (M stealth: guards and civilians scale): civilians already scale (`crowd` 12-20 + `dance_clusters` 4-6).
* **D-140 does not hold as drafted.** Guards (pager carriers present at load, min over seeds) are 2 fixed + rovers
  1/1/2/2/3/3 (+ the operator 60-75 %, not counted in the minimum): **3 / 3 / 4 / 4 / 5 / 5** against the default cap 4, so
  Tense-Brutal break (c) "guards > cap from Tense". Proposed lever **PAGERS** (as ND/SL: the club is crowded and the doc
  already calls the door bouncer untouchable): guards exactly **4** on every difficulty (door + rope + 2 rovers;
  `guard_post` pick 2, no `difficulty_add`), `pager_max_by_difficulty` **[4, 3, 3, 2, 2, 1]**. Alternative GUARDS:
  4 / 5 / 5 / 6 / 6 / 7 needs 5 rover posts (the doc has 4). QB-AH2.
* **Escape:** the proposed def says `escape_options [van, walk]`, but D-075 ruling 9 is "no walk-out" → `[van]`. QB-AH3.
* **Mode label:** STEALTH_OR_LOUD plus `start_mode civilian`: the loadout already shows the civilian-start notice (B5-05);
  no `mode_key` override proposed. QB-AH4 if the Board should say "Stealth or loud (civilian start)".
* **Strings skeleton (this round):** `heist.afterhours.briefing`, the 12 `objective.afterhours.<tag>` lines (`secure` reads
  `{count}/{total}`), `music.afterhours.name` "Velvet Rope", `item.asset.gear_drop` / `count_window` names.
* **Pre-planning (this round):** `asset.gear_drop` (force_variant on `pp_gear_wc/cloak/booth/van`, $1,000 / 1 favor) and
  `asset.count_window` (force_variant on `pp_count_window`, $1,500 / 1 favor): point-limited, so they show only on
  Afterhours. **Held back:** `asset.intel_safe_code` (reveals `code_note`) and `asset.intel_product` (reveals
  `product_location`): as library assets they would also appear on GH / GN / ND / SL (`code_note`) and DB
  (`product_location`). QB-AH5.
* **Not yet (waits on A's mission / C's G1):** VO (`vo.accountant.*`, Mercer, the new `dj` speaker), preplan point labels
  `ui.preplan.point.afterhours.*`, blueprint room labels, the `ClubSound` / crowd cue ids.

### Open questions (QB-AH, to the lead)
1. **QB-AH1** base_payout $40,000 (proposed) or keep $75,000?
2. **QB-AH2** D-140 lever: PAGERS (4 guards fixed, cap 4/3/3/2/2/1; proposed) or GUARDS (needs a 5th rover post)?
3. **QB-AH3** `escape_options`: `[van]` per D-075 ruling 9 (the G0 def still lists `walk`)?
4. **QB-AH4** A "civilian start" mode label on the Board / heist select / briefing, or the loadout notice only?
5. **QB-AH5** `asset.intel_safe_code` / `asset.intel_product`: library-wide (they would also show on GH/GN/ND/SL and DB,
   a new intel option there) or Afterhours-only (needs a per-heist asset allow-list, or C's def `disable` on the others)?
