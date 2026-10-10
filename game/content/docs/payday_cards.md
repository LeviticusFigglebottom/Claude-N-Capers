# PAYDAY cards: card pick design (B4-05, pd2_fidelity P9 / C6)

Owner: ENV B. Authority for the card drop rules, the drop table and the card pick UI.
Research: `docs/research/pd2_research.md` §4 "Card drop". No real money is involved anywhere, and there
is no gambling with offshore money (PD2 had it; we leave it out).

## Rules
* After a **successful** heist (PD2: no card on failure), the payday screen's Continue opens the
  card stage. Three face-down cards are dealt; the player picks one with the mouse, keyboard
  (arrows + Enter) or gamepad (d-pad/stick + A). After **30 s** (`pick_time_s`) the card
  `auto_pick` is taken. All three are then revealed, the picked reward is granted and the profile is
  saved. Continue is disabled until the pick.
* Each player rolls and picks their own cards locally (their crew slot); nothing is networked.
* The preview payday (`apply_to_profile = false`, e.g. the launcher stub's sample) has no card pick.
* Leaving with an unpicked card (QB-PC1, D-049) auto-picks it with the same deterministic `auto_pick`
  as the timeout: the screen leaving the tree, an app quit (`NOTIFICATION_WM_CLOSE_REQUEST`), a new
  result replacing it, or MenuFlow leaving the heist (`PaydayScreen.finish_card_pick()`). No save change.

## Card types
| Type | Reward | Grant |
|---|---|---|
| `cash` | `cash_by_tier[tier] × cash_difficulty_mult[d]`, rounded to $1,000 | `PlayerProfile.cash` (spending cash) |
| `xp` | `xp_by_tier[tier] × xp_difficulty_mult[d]`, rounded to 100 | `PlayerProfile.xp`, level via `XpCurve.level_for_xp` |
| `weapon_mod` | one mod the profile does not own (stock parts in `WeaponDef.default_mods` never drop) | append to `owned_mods` (sorted with `ContentDB.sort_ids`) |
| `mask_part` | one mask part (base, material, colours, pattern) that is not `default_owned` and not owned | `MaskLocker.grant_part` |

PD2's **stat boosts** and **weapon skins** have no system in our game yet. They are not in the
table; add a type plus a pool and grant in `PaydayCards` when those systems exist.
PD2 allowed up to 2 unused copies of one mod. Our `owned_mods` is a set (a mod is owned or not), so a
card never offers an owned item, and one deal never shows the same item twice. When a type's pool is
empty (everything owned), the card becomes `fallback_type` (`cash`) at the rolled tier.

## Quality tiers
Tier 0 Common, 1 Uncommon, 2 Rare (`ui.payday_cards.tier.<n>`). Each card rolls a tier from the
difficulty's `tier_weights` row. Then, up to `quality_max_steps` (1) times, a roll below the player's
`progression.card_drop_quality_add` raises it one tier. That value is the perk deck completion bonus
(+0.1 per completed deck card 9, D-031), read with
`PaydayCards.quality_add_for(profile)` = `LoadoutResolver.resolve(profile.loadout).modifiers`.
Cash and XP scale with the tier. Items carry their own tier (`item_tiers`; unlisted = 0). An item
card takes an item of the rolled tier, else the nearest lower tier, else the nearest higher one, and
the card shows the item's real tier.

## Drop table (`data/payday/card_table.tres`, `PaydayCardsTable`)
Rows run in `Enums.Difficulty` order (Routine … Cataclysm). All numbers are ◇ (invented; tune freely)
except the cash range ($20k–$100k, V research §4), 3 cards and 30 s (V P9).

| Difficulty | cash / xp / weapon_mod / mask_part | tier weights C / U / R | cash × | xp × |
|---|---|---|---|---|
| Routine | 30 / 30 / 25 / 15 | 80 / 17 / 3 | 1.00 | 1.0 |
| Tense | 28 / 28 / 27 / 17 | 75 / 20 / 5 | 1.08 | 1.8 |
| Hazardous | 26 / 26 / 28 / 20 | 70 / 23 / 7 | 1.16 | 3.5 |
| Brutal | 24 / 24 / 30 / 22 | 64 / 27 / 9 | 1.24 | 6.0 |
| Lethal | 22 / 22 / 31 / 25 | 58 / 30 / 12 | 1.32 | 7.0 |
| Cataclysm | 20 / 20 / 32 / 28 | 50 / 34 / 16 | 1.43 | 8.5 |

Base cash per tier is $20k / $40k / $70k, so the range is $20,000 (Routine Common) to $100,000
(Cataclysm Rare). Base XP per tier is 1,000 / 2,500 / 5,000. The file also holds the visuals:
`tier_colors` and `type_colors`.

## Determinism (seed source)
GameRng streams are seeded per run, and the payday screen runs after the run (GameRng may already hold
another seed, or none in tests). So `PaydayCards.roll` builds its own `RandomNumberGenerator` with
the **same formula as GameRng's named stream** `payday_cards.<slot>`:
`seed = hash([HeistResult.seed, "payday_cards.<slot>"])` (`PaydayCards.seed_for`). If
`GameRng.run_seed` still equals the heist seed, `GameRng.stream(&"payday_cards.<slot>")` gives the
same sequence. Draw order per card: type, tier, quality step roll(s), item index (item cards only).
After the three cards, one more draw sets `auto_pick`. Equal run seed, slot, difficulty, owned items
and quality always give the same deal. Owning more items changes the pools, so the deal can change.

## API
* `PaydayCards.roll(run_seed, slot, difficulty, profile, quality_add = 0.0, table = null) -> {seed, slot, cards, auto_pick}`;
  card = `{type: StringName, tier: int, item_id: StringName (&"" for cash/xp), amount: int}`.
* `PaydayCards.grant(profile, card) -> bool` (false = nothing granted: owned item or unknown type);
  the caller saves. `pool(type, profile)`, `amount_for(table, type, tier, d)`, `quality_add_for(profile)`,
  `weapon_for_mod(mod_id)`, `table()`.
* UI: `PaydayScreen` (`ui/results/payday.tscn`) has `cards_enabled`, `card_roll`, `has_card_pick()`,
  `show_cards()`, `pick(i)`, `tick(delta)` (timer; `_process` calls it), `picked_index`,
  `auto_picked`, `card_views`. `PaydayCardView` (`ui/results/payday_card_view.gd`) is a Button drawn in
  code: an original card back (gold lattice + nested diamonds) and a face with a type band, a drawn icon
  (bills / star / gear / mask), the reward, a detail line and tier pips. No art assets.
* Strings: `ui.payday_cards.*` in strings.csv.

## Questions (for the lead)
* QB-PC1: should an unpicked card survive a quit (a `pending_card` save field + re-show on boot)? **Answered (D-049):** no; leaving auto-picks (Rules).
  This needs save v5. Not done.
* QB-PC2: boosts and skins have no systems yet. They are left out of the table until they exist.
