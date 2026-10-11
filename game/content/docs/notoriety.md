# Notoriety ranks (B5-02, pd2_fidelity P10)

Owner: ENV B. Notoriety is our version of PD2's infamy: a player at the level cap gives up their level
for a permanent rank, an XP bonus and cosmetics. ◇ marks our own design numbers (not PD2-verified).

Code: `content/progression/notoriety.gd` (`Notoriety`), `content/progression/notoriety_skills.gd`
(`NotorietySkills`). UI: `content/ui/notoriety/notoriety_screen.tscn` (`NotorietyScreen`).
Data: `content/data/tweak/notoriety.tres` (`NotorietyTweak`: cap, required level, costs, XP bonus) and
`content/data/notoriety/ranks.tres` (`NotorietyTable` of `NotorietyDef`: the rewards of each rank).
Save: v6 fields `notoriety`, `notoriety_xp`, `notoriety_choices`, `held_skill_sets` (`save_format.md`).

## Ranks
* Ranks 1..**25** ◇ (`max_rank`). Rank 0 means no notoriety. The UI writes ranks as roman numerals
  (`Notoriety.roman`: I, II, ... XXV).
* Requirements for the next rank: **level 100** (`required_level`, PD2) and **spending cash** of at least
  that rank's cost. At rank 25 nothing more can be bought.
* The cost comes out of spending cash (`PlayerProfile.cash`), never the stash.

### Cost table ◇ (`NotorietyTweak.costs`, spending cash)
| Rank | Cost | Rank | Cost | Rank | Cost |
|---|---|---|---|---|---|
| I | $5,000,000 | X | $19,000,000 | XIX | $46,000,000 |
| II | $6,000,000 | XI | $22,000,000 | XX | $49,000,000 |
| III | $7,000,000 | XII | $25,000,000 | XXI | $52,000,000 |
| IV | $8,000,000 | XIII | $28,000,000 | XXII | $55,000,000 |
| V | $9,000,000 | XIV | $31,000,000 | XXIII | $58,000,000 |
| VI | $11,000,000 | XV | $34,000,000 | XXIV | $61,000,000 |
| VII | $13,000,000 | XVI | $37,000,000 | XXV | $64,000,000 |
| VIII | $15,000,000 | XVII | $40,000,000 | | |
| IX | $17,000,000 | XVIII | $43,000,000 | | |

Sizing (estimate): one climb from 0 to 100 is roughly 11-12M XP on the current `xp_curve.tres`, which is
about 200 Cataclysm heists. Those pay
about 200k spending each (80 % of the gross goes to the stash), so one climb earns around 40M spending.
Early ranks cost a fraction of one climb, and late ranks cost more than one ◇.

## What a rank-up does (`Notoriety.rank_up`)
1. It takes the cost from spending cash.
2. `xp` moves into `notoriety_xp`, and level and XP become **0**. Perk points are earned from
   `xp + notoriety_xp` (`PerkProgress.earned`), so a rank-up never costs perk points or perk cards
   (PD2 keeps perk deck progress).
3. **Kept:** stash, owned weapons and mods, masks and mask parts, custom masks, perk decks and cards,
   achievements, the stealth bank and the loadout.
4. **Skills: the build is kept, and the points come back with levels.** See below.
5. The rank's rewards are granted (see Rewards).

### Skills (PD2 behaviour we chose)
Modern PD2 infamy keeps your skill build, and skill points are tied to your level. Our rule is that a skill
set may never spend more points than the level gives (`SkillPoints.validate`; `ProfileValidator` resets an
illegal set). So instead of leaving a set over budget, a rank-up **holds** the build:
* `NotorietySkills.hold`: each skill set i is copied into `held_skill_sets[i]` (merged with a hold that is
  still waiting, highest level per skill) and then emptied. At level 0 the budget is 0.
* `NotorietySkills.restore` runs on every level gain (`SaveService.apply_heist_payout` and payday card XP).
  It buys the held skills back with the new points: lowest tier first, then by id, basic before aced, and
  only while `SkillPoints.can_unlock` allows it. Every set stays legal at every level.
  Once a set has its whole build back, its hold is dropped.
* A player who edits a set by hand (refund or respec in the skill screen) takes it over, and its hold is
  dropped (`NotorietySkills.release`). Buying a skill keeps the hold, and the restore uses whatever
  points are left.
* The Notoriety screen shows how many points are still held for the active set.

We did **not** choose "respec when over budget". It would throw the build away on every rank, but PD2
keeps it.

## XP bonus
`Notoriety.xp_bonus(rank) = min(rank × 0.02, 0.30)`. That is **+2 % per rank** ◇, capped at **+30 %** ◇,
which rank XV reaches.
It is additive (PD2 adds XP percentages). `PayoutCalculator.compute(..., notoriety_bonus)` applies it to the
same running total as the "Crew and gear bonuses" line. The payday shows it as its own line,
`ui.results.xp.notoriety` "Notoriety bonus", between the additive line and the stealth line. Unlike the
crew-alive part, it also applies to failed heists, because it is a permanent player bonus ◇.

## Rewards (`data/notoriety/ranks.tres`)
Every rank records the unlock id `unlock.notoriety.rank_<n>` in `PlayerProfile.unlocks`. That owns every
preset whose `MaskDef.unlock` is that id, and every available mask part whose `MaskPartDef.unlock` is that id
(B7-02: batch-3 bases `doll` at VII, `jester` at XV, `geo` at XX, owned once ENV D's model lands). Reaching a
rank also runs `Achievements.sync` (`notoriety_reached` achievements). A `NotorietyDef` can also add:
* `rewards`: mask part or preset ids that the rank grants.
* `unlocks`: plain unlock ids written into `PlayerProfile.unlocks` (D-062: music tracks,
  `unlock.music.<track_id>`. ENV C's music table reads them, and we do not check them against it).
* `choices`: a reward choice like PD2's infamy tree. The player picks **one** option they do not own yet.
  The pick is stored in `notoriety_choices`. Ranks V, XV and XX share one pool of three colours, so each
  pick shrinks the next choice (3 → 2 → 1).

All Notoriety parts are exclusive. They never drop from payday cards (`Notoriety.exclusive_ids`,
`PaydayCards.pool`). On load, `ProfileValidator` re-grants every reached rank's rewards
(`Notoriety.apply_rewards`), so rewards added to the data later reach old profiles too.

| Rank | Reward ◇ |
|---|---|
| I | Colours: Crown Ember |
| II | Colours: Ash Regalia |
| III | Material: Carbon Weave |
| IV | Colours: Velvet Vault |
| V | **Choice**: Midnight Ledger / Lantern Smoke / Verdigris Crown (colours) |
| VI | Material: Night Anodized |
| VII | Music: `unlock.music.vault_hymn` ◇ (placeholder id, D-062) |
| VIII | Colours: Bloodline |
| X | Preset mask: Ledger Regent (theatre base, Crown Gold, Black Crown, starburst) |
| XII | Colours: Ghost Ledger |
| XIII | Music: `unlock.music.long_con` ◇ (placeholder id, D-062) |
| XIV | Material: Crown Gold |
| XV | **Choice**: the remaining two from rank V's pool |
| XVIII | Colours: Black Crown |
| XX | **Choice**: the last one from the pool |
| XXI | Music: `unlock.music.last_call` ◇ (placeholder id, D-062) |
| XXII | Colours: Heat Shimmer |
| XXV | Preset mask: The Last Word (demon base, Carbon Weave, Crown Ember, brow band) |

Other ranks give the badge and the XP bonus only (PD2's later infamy ranks did the same).

## Co-op
Nothing assumes a single player. Each player's rank travels in the lobby summary
(`LobbyState.summary_from` → `"notoriety": int`). Every peer validates it (0..25) and shows it on the slot
next to the level ("XII · Level 100"). A summary from an older build without the field reads as rank 0. The
XP bonus is per player: each payday uses its own profile's rank.

## UI
* Hub profile panel: a rank badge line ("Notoriety XII" / "No notoriety yet"), the badge next to the level,
  and a **Notoriety** button (`HubMenu.notoriety_requested` → `MenuFlow._open_notoriety`).
* `NotorietyScreen` shows:
  * the current rank and XP bonus;
  * the next rank's checklist (level and cash, or the cap), its cost and a reward preview;
  * pending reward choices as buttons.

  **Rank Up** opens an in-screen confirm panel that warns that level and XP reset and names the cost.
  Confirm ranks up and saves. Esc / gamepad B closes the panel first.
* Strings: `ui.notoriety.*` and `ui.results.xp.notoriety`. Music preview names are
  `ui.notoriety.unlock.<unlock id>`.

## Open points
* PD2 later charged infamy to the offshore account. We use spending cash because the task brief asks
  for it. Switching would only need a flag in the tweak.
* The music unlock ids are placeholders until ENV C's track table lands (D-062).
