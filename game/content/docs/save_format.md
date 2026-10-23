# Profile save format (B4-16, save v8)

Owner: ENV B. Code: `content/save/` (`SaveService`, `PlayerProfile`, `ProfileSchema`, `ProfileValidator`).
Default profile: `content/data/save/default_profile.json`. Golden fixtures: `tests/b/fixtures/save/`.

The roadmap calls this "save v2" (P4 gate). The file format's internal `version` is **7** (B7-01).

## Files
`user://profiles/profile_<slot>.json` (pretty JSON, keys sorted), `.bak` = the previous good save,
`.tmp` only while writing. A save writes `.tmp`, moves the current file to `.bak` and renames `.tmp` into
place (atomic).

## Load pipeline
1. Read `profile_<slot>.json`. If it is missing, unreadable, empty, truncated or not a JSON object, try `.bak`;
   if that fails too, use the default profile (`Log.error`).
2. `version` > current: refused. The default profile is returned and the file is left untouched.
3. `SaveService.migrate`: each step runs in order (0→1→2→3→4→5→6→7). A missing or non-numeric `version` is v0.
4. `ProfileSchema.sanitize`: every field below is present with its JSON type. A missing field gets its
   default silently. A wrong type (e.g. `"cash": "lots"`) gets its default and a `Log.warn`. A bad element
   in a list or map (a number in `owned_weapons`, a string skill level) is dropped with a `Log.warn`.
   Unknown top-level keys are dropped.
5. `PlayerProfile.from_dict`.
6. `ProfileValidator.validate` checks content ids and logs a `Log.warn` for each repair (never an error):
   * Unknown weapon, mod, preset, mask part, perk deck, skill and achievement ids are pruned.
   * A custom mask naming an unknown part is emptied.
   * An unknown loadout item id falls back to the default profile's item.
   * A mask that can't be equipped falls back to the default mask.
   * Skill sets with unknown ids are pruned first. A set that is still illegal for the level
     (`SkillPoints.validate`) is reset to empty.
   * Perk card counts are clamped to the deck size.
   * Malformed unlock ids and lock keys are dropped.
   * Presets behind a recorded unlock are owned.
   * `notoriety` is clamped to 0..25 and `notoriety_xp` to 0 or more. A rank unlock id
     `unlock.notoriety.rank_<n>` for a rank the profile has not reached is dropped.
   * `notoriety_choices` entries are dropped for an unreached rank, a rank without a choice, or an id the
     rank does not offer.
   * `held_skill_sets` loses unknown skills, levels other than 1 or 2, and entries past the last skill set.
   * Every reached rank's rewards are re-granted (`Notoriety.apply_rewards`).
   * `music_choice` is type-checked only. The launch resolves it against `MusicCatalog` (B5-03).
   * `career.weapons` loses unknown weapon ids. Heist and loot ids in `career` are kept (history).
   * `weapon_finishes` loses entries with an unknown weapon id or an unknown finish id (`WeaponFinishes.is_known`).

## Fields
Types are JSON types. `id` = a `String` content id (`domain.snake_name`). "Since" = the first version
that has the field. v0 is the pre-versioned dev save; its `money` became `cash` in v1.

| Field | Type | Default | Since | Notes |
|---|---|---|---|---|
| `version` | int | 7 on save | 1 | Missing = v0. |
| `profile_name` | string | `""` | 0 | Display name. |
| `cash` | int | 0 | 0 | Spending cash (v0 `money`). |
| `stash` | int | 0 | 0 | Offshore account (S10.4). |
| `xp` | int | 0 | 0 | Total XP. |
| `level` | int | 0 | 0 | 0..100 (P1). Sets the skill point budget. |
| `banked_stealth_mult` | float | 1.0 | 2 | Stealth XP bonus banked for the next payday (D-022 QB-13). |
| `owned_weapons` | id[] | `[]` | 0 | `weapon.*`, including armory batch 2. |
| `owned_mods` | id[] | `[]` | 0 | Flat list of `mod.*` (mod ids are weapon-specific). |
| `owned_masks` | id[] | `[]` | 0 | Locked presets that are owned (`mask.*` with an `unlock`). Presets without an unlock are always owned. |
| `owned_mask_parts` | id[] | `[]` | 4 | Parts owned on top of `default_owned` ones (`mask_base.*`, `mask_material.*`, `mask_colors.*`, `mask_pattern.*`). |
| `custom_masks` | object[] | `[]` | 4 | Slot n = `mask.custom.<n>`: `{"base","material","colors","pattern"}` part ids, or `{}` for an empty slot. |
| `loadout` | object | see below | 0 | Loadout input fields only. Resolved fields are never saved. |
| `skill_sets` | object[] | `[]` (one set after v2→3) | 3 | Each set maps skill id → 1 (basic) or 2 (aced). The active set mirrors `loadout.skills`. |
| `active_skill_set` | int | 0 | 3 | Index into `skill_sets`. |
| `perk_cards` | object | `{}` | 3 | Deck id → cards unlocked (0..deck size). |
| `unlocks` | id[] | `[]` | 5 | Granted unlock ids (`unlock.*`, e.g. `unlock.achievement.cataclysm_clear`; `MaskLocker.grant_unlock`). Sorted. |
| `achievements` | object | `{}` | 5 | Achievement id → `{"progress": int, "unlocked": bool}` (`Achievements`, B4-20). |
| `pro_job_locks` | object | `{}` | 5 | `BoardContracts.contract_key()` (`"<slot>:<bucket>"`) → `expires_at` float (Unix s). A failed pro contract stays locked until its rotation ends (QB-BRD1). Pruned by `ProJobLocks.prune` once expired. |
| `notoriety` | int | 0 | 6 | Notoriety rank 0..25 (`Notoriety`, `content/docs/notoriety.md`). |
| `notoriety_xp` | int | 0 | 6 | XP that rank-ups moved out of `xp`. Perk points count `xp + notoriety_xp`. |
| `notoriety_choices` | object | `{}` | 6 | Rank (as a string key, e.g. `"5"`) → the reward id picked for that rank's choice (`Notoriety.choose`). |
| `held_skill_sets` | object[] | `[]` | 6 | Index-aligned with `skill_sets`: the build a rank-up held, bought back as levels return (`NotorietySkills`). `{}` = nothing held. |
| `music_choice` | string | `""` | 6 | Chosen heist music track id (B5-03). `""` = the heist's default. At most 64 characters; anything longer, or a non-string, falls back to `""` with a warning. Load only type-checks it. At launch `MusicCatalog.resolve_choice` turns an unknown or locked id into `""` (B5-03, `content/docs/music.md`). |
| `career` | object | 5 empty sections | 7 | Lifetime career stats (B7-01, `Career`). See "career" below. |
| `weapon_finishes` | object | `{}` | 7 | Weapon id → finish id (reserved for B7-04 weapon finishes). `""` or no entry = the default finish. Keys and values are strings of at most 64 characters; anything else is dropped with a warning. |
| `freshness` | object | empty memory | 9 | Heist freshness (D-139, `HeistFreshness`): `recent` = the heist ids of the last `PayoutTweak.freshness_memory` runs that reached payday (oldest first), `runs` = runs counted, `last_run` = heist id → the `runs` value of its last run, `completed` = heist ids won at least once. Bad lists / counters are emptied or dropped with a warning. |
| `crew_loadouts` | array | 3 empty entries | 10 | Crew bot loadouts (D-145.4 / PO-19, `CrewLoadouts`): exactly 3 entries, one per bot slot, each `{"weapon": id, "mods": [id], "armor": id, "mask": id, "outfit": id, "ability": id, "boost": id}`; `""` / `[]` = the bot's default (A's default weapon / armor, no mask, any free heister, no ability / boost). `ability` / `boost` (L6.2, BotCrewDef ids) were added inside v10 without a version bump: a missing one reads `""`. Ids are checked when used (an unowned or retired id falls back to the default), not dropped on load. A non-object entry is emptied, extra entries are dropped and a short list is padded, with a warning. |
| `stats` | object | `{}` | 0 | Counter name → int (`heists_completed`, `heists_failed`, ...). |
| `settings` | object | `{}` | 0 | Any JSON values, stored as-is (numbers come back as float). |

### `loadout`
| Field | Type | Default | Notes |
|---|---|---|---|
| `primary`, `secondary` | id | `""` | `weapon.*`. An unknown id falls back to the default profile's weapon. |
| `primary_mods`, `secondary_mods` | id[] | `[]` | `mod.*`. Unknown ids are pruned. |
| `melee` | id | `""` | `melee.*` |
| `throwable` | id | `""` | `throwable.*` |
| `deployable`, `deployable_secondary` | id | `""` | `deployable.*` |
| `armor` | id | `""` | `armor.*` |
| `mask` | id | `""` | A preset `mask.*` or `mask.custom.<n>`. One that can't be equipped falls back to the default mask. |
| `perk_deck` | id | `""` | `perk.*`. An unknown deck is cleared. |
| `perk_deck_cards` | int | 0 | Mirrors `perk_cards[perk_deck]`. |
| `skills` | object | `{}` | The active skill set. |
| `heister` | short id | `""` | D-073, added inside v6 (no migration: a missing key reads as `""`). `rook` / `sable` / `dutch` / `wren`; `""` = no preference (the first free heister at launch). An unknown id is cleared to `""`. Fixture `v6_heister`. |

### `career` (v7, B7-01)
`progression/career.gd` (`Career`) writes it once per payday (`Career.record`, from `PaydayScreen._apply`
before the achievements) and on spending (`Career.add_spent`). Every counter is an int ≥ 0. **A missing key
means "never counted", not 0**: e.g. `shots` / `hits` / `headshots` only appear once a HeistResult crew row
carries them (D-071), and accuracy is shown only when `shots` exists.

| Section | Keys | Source |
|---|---|---|
| `totals` | `played`, `won`, `failed`, `stealth_wins`, `loud_wins` | HeistResult `success` / `stealth` |
| | `spending_earned`, `stash_earned`, `xp_earned`, `small_loot` | PayoutCalculator `spending`, `stash`, `xp_total`, `small_loot` (cash paid) |
| | `bags` | HeistResult `loot` entries, counted on a success only (secured bags) |
| | `cash_spent` | workshop buys, pre-planning (refunds subtract), Notoriety rank-up cost |
| | `offshore_spent` | Board broker (stash) |
| | `kills`, `specials_killed`, `civilians_killed`, `downs`, `shots`, `hits`, `headshots` | the local player's HeistResult crew row; a counter the row lacks is not counted |
| | `custody` | crew row `in_custody` (heists ended in custody) |
| | `time_played_s` | HeistResult `time_s` (heist time only, rounded) |
| `heists` | heist id → `played`, `won`, `failed`, `stealth_wins`, `loud_wins`, `won_d<n>` (wins on difficulty n), `fastest_win_ms` | per heist; best difficulty = highest `won_d<n>` |
| `difficulties` | `"<n>"` (Enums.Difficulty) → `played`, `won`, `failed` | per difficulty |
| `bags` | loot id → secured bags | HeistResult `loot` |
| `weapons` | weapon id → heists carried | the loadout's primary / secondary at payday (favourite weapon = most carried) |

Not tracked (no source yet, TODO): kills per weapon, melee / throwable kills, payday card cash and XP,
menu time, pagers answered per player.
Sanitizing: a non-object `career` gets the default with a warning; an unknown section is dropped; a counter
that is not an int ≥ 0, a key over 64 characters, or a non-integer difficulty key is dropped with a warning.

## Migrations (each step is kept; never edit a shipped step)
| Step | Change |
|---|---|
| 0 → 1 | `money` → `cash`. Missing lists and objects are created. |
| 1 → 2 | `banked_stealth_mult = 1.0`. |
| 2 → 3 | `loadout.skills` becomes `skill_sets[0]` (active 0). The equipped deck's `perk_deck_cards` becomes `perk_cards[deck]`. |
| 3 → 4 | `owned_mask_parts = []`, `custom_masks = []`. |
| 4 → 5 | `unlocks = []`, `achievements = {}`, `pro_job_locks = {}`. |
| 5 → 6 | `notoriety = 0`, `notoriety_xp = 0`, `notoriety_choices = {}`, `held_skill_sets = []`, `music_choice = ""`. |
| 6 → 7 | `career` = 5 empty sections (nothing was counted before v7), `weapon_finishes = {}`. Fixtures `v6` (migration) and `v7_damaged`. |
| 7 → 8 | No new field (lead, round 64): `owned_weapons` gains the starter `weapon.corsair_ar` (SaveService.STARTER_PRIMARY; new profiles have owned it since round 38) when missing, and an EMPTY `loadout.primary` gets it equipped (with no mods); an equipped primary is kept. Fixtures `v7` and `v7_own_primary`. |
| 8 → 9 | `freshness` (D-139): an empty memory (`runs = 0`); every `career.heists` id with `won > 0` goes into `completed` with `last_run = 0`, so its rotation bonus ramps from the migration on. A save that already has `freshness` keeps it. Fixture `v8`. |
| 9 → 10 | `crew_loadouts` (D-145.4 / PO-19): 3 empty entries, so every bot keeps its default loadout. A save that already has `crew_loadouts` keeps it. Fixtures `v9`, `v10_crew_damaged`. |

### Adding a version
1. Bump `SaveService.CURRENT_VERSION` and `PlayerProfile.version`.
2. Add `_migrate_<n>_to_<n+1>` and register it in `migrate()`.
3. Add the field to `ProfileSchema.FIELDS`, `PlayerProfile` (`from_dict` and `to_dict`),
   `default_profile.json` and this table.
4. Add `v<n>.json` and `v<n>.expected.json` to the fixtures. Update every older `.expected.json` and
   list the new pair in `tests/b/test_save_golden.gd`.
