# The Board and the contract broker (B4-06, pd2_fidelity C1)

Owner: ENV B. Our take on PD2's CRIME.NET: a stylised city map in the safehouse with rotating
contracts from our contacts (Odile Vance, Hollis Reyes, The Accountant). Each contract shows its
difficulty, payout and a "pro job" flag. A broker sells any unlocked contract for stash money.

## Files
| What | Where |
|---|---|
| Numbers (rotation, weights, level gates, pro chance, broker prices) | `data/board/board_tweak.tres` (`BoardTweak`, `board/board_tweak.gd`) |
| City map (districts, water, roads, heist spots and contacts) | `data/board/city_map.tres` (`BoardCityMap`, `board/board_city_map.gd`) |
| Generator (pure, static) | `board/board_contracts.gd` (`BoardContracts`) |
| Broker (pure, static) | `board/board_broker.gd` (`BoardBroker`) |
| Screen | `ui/board/board_screen.tscn` (`BoardScreen`), `board_map_view.gd`, `board_pin.gd` |
| Strings | `ui.board.*`, `ui.board.district.<id>`, `ui.board.broker.reason.<reason>` |
| Tests | `tests/b/test_board.gd`, `tests/b/test_board_screen.gd` |

## Screen API (MenuFlow wires it)
`res://content/ui/board/board_screen.tscn`, a `UiScreen`:
* `setup(profile: PlayerProfile)`: call before or after it enters the tree. With null it loads `profile_slot`.
* `signal contract_chosen(heist_id: StringName, difficulty: int, is_pro: bool)`. Emitted by **Take
  Contract** on a pin, or after a broker purchase. For a purchase, the stash has already been charged
  and, when `save_on_buy` is set (the default), the profile saved. Broker contracts always have `is_pro = false`.
* `signal back_requested()` (Esc / gamepad B / Back).
* `clock: Callable` returns Unix seconds; tests replace the system clock with it. `build_gate: Callable(int) -> bool`
  is the build-wide difficulty gate (default `HeistCatalog.is_difficulty_unlocked`).

The flow after `contract_chosen` is unchanged: briefing, then pre-planning, then loadout. The flow
also has to carry `is_pro` through to launch and payday: `PayoutCalculator.compute(..., is_pro)`
applies `PayoutTweak.pro_job_xp_mult`. A pro job has no restart (QB-BRD1, D-049, owned by MenuFlow): when a pro
contract's heist ends with `success = false`, MenuFlow marks it consumed
(`MenuFlow.consumed_contracts[BoardContracts.contract_key(c)]`, key = `"slot:bucket"`). The Board shares
that dictionary: a consumed contract's pin is dimmed, the card shows `ui.board.consumed`, Take is
disabled and `take_selected()` refuses it, so neither the Board nor the briefing can relaunch it. It
stays locked for the rest of its rotation; the slot's next bucket is a new contract. The lock is
session state (not saved): a contract lives one rotation only.

## Rotation and determinism
* There are `slot_count` slots (8). Each slot holds one contract per **time bucket**:
  `bucket = floor((t + offset_i) / rotation_s)`, where `t` is Unix time in seconds and `rotation_s` is 600.
  With `stagger_slots`, `offset_i = rotation_s * i / slot_count`, so one contract expires about every
  75 s (CRIME.NET feel) instead of the whole board flipping at once. A contract lives exactly `rotation_s`.
* **RNG:** each contract uses its own `RandomNumberGenerator`, seeded explicitly with
  `hash([board_seed, slot, bucket])`. It never uses the global RNG. We do not use `GameRng`, because
  that is per heist run and the Board lives outside runs. Rolls happen in a fixed order:
  1. heist (uniform over the pool)
  2. difficulty (weighted over the unlocked ones)
  3. pro roll (always drawn)
  4. contact pick (always drawn)
  5. pin jitter x, then y
  
  The same seed, slot, bucket, level and pool always give the same contract. So a crew whose clocks
  agree sees the same board, apart from level gating.
* **Pool:** `HeistCatalog.entries()`: registry heists with a HeistDef and a map scene (QB-55; no
  placeholders). The contact comes from `HeistDef.contact`, then the city map's
  `heists[id].contact`, then a deterministic pick from `fallback_contacts`.
* **Payout preview** is `HeistCatalog.contract_preview(base, difficulty)`. It runs through
  PayoutCalculator, so it matches heist select and the payday screen.
* The screen re-generates when the earliest expiry passes, ticking every 0.5 s. Pins are reused per
  slot, so keyboard and gamepad focus survives a rotation.

## Gating, pro jobs, broker
* **Level gate:** `difficulty_min_level = [0, 0, 0, 0, 80, 80]`. Lethal and Cataclysm need level 80,
  as in PD2. When `respect_build_unlocks` is set, the build-wide `heist_list.tres
  unlocked_difficulties` gate (P1: Routine and Brutal) also applies. Locked difficulties are never
  rolled. The broker lists them as disabled, with the level they need.
* **Difficulty weights:** `[1.0, 1.3, 1.3, 1.1, 0.7, 0.45]` over the unlocked tiers.
* **Pro jobs:** `pro_chance` is 0.2. A contract can only be pro from `pro_min_difficulty` (Tense)
  upwards. A pro job means no restarts, and its XP gets `PayoutTweak.pro_job_xp_mult` (+20%). On the
  pin it shows as a red diamond badge, and the card shows "PRO JOB" plus a short rule text.
* **Broker:** `cost = broker_cost_by_difficulty[d] + round(contract preview x broker_cost_payout_fraction)`.
  The table is `[12k, 24k, 48k, 90k, 200k, 360k]` and the fraction is 0.05. PD2 gives no price table
  (research §4), so these numbers are ours. The broker refuses with `unknown_heist`, `locked` or `stash`,
  and a refusal changes nothing. As in PD2, the stash is spent on purchase: backing out of the
  briefing afterwards does not refund it.

## Map art
The map is original vector art drawn in code (`BoardMapView._draw`), in the GSR palette:
* dark land
* muted district tints taken from the heist palettes
* a river and a bay
* avenues and streets
* district names

Pins are `BoardPin` buttons:
* a disc in the contact's colour
* a ring that empties as the contract nears expiry
* difficulty pips, with Lethal and above shown in red
* the pro badge
* a cyan `#4FD1E8` ring (the style guide's interactable accent) while the pin is focused or selected

Contracts for the same heist share an anchor, so pins are pushed apart deterministically
(`BoardMapView.spread`). The map keeps a 1.6 aspect ratio, centred horizontally and aligned to the top.

## Navigation
* Arrow keys, the d-pad or the left stick move spatially between pins: the nearest pin within ±60°.
* Moving right from the map's right edge goes to **Take Contract**. Moving left from the side panel returns to the selected pin.
* Focusing a pin selects it. Pressing it moves focus to Take.
* Tab follows the slot order.
* The layout was checked at 1280×720 and 1920×1080 (`canvas_items` stretch from the 1920×1080 base, so 4K scales the same way).

## Save
No new save fields. The board is a pure function of time, and the broker only changes `stash`.

## Questions for the lead
* QB-BRD1: MenuFlow wiring. Does the Board replace heist select, or sit next to it with heist
  select kept as a debug path? `is_pro` has to reach the launch and payday
  (`PayoutCalculator.compute(..., is_pro)`). It also needs a "no restart" rule on a pro job failure:
  who owns restart, MenuFlow or ENV A? **Answered (D-049):** MenuFlow consumes the contract (above).
* QB-BRD2: In multiplayer, the host's Board is authoritative. Should clients see the host's board
  (seed and bucket sent over `Net.lobby_send`) or their own?
* QB-BRD3: Broker prices and the level gates for Tense through Brutal (currently 0) are placeholders
  pending a balance pass.
