## Payout and heist-XP tuning (pd2_fidelity S10.4, S7.3, C6). Data: res://content/data/tweak/payout.tres.
## Consumed by PayoutCalculator. Every number here is balance data; ◇ = our choice, not PD2-verified.
## Contract pay and loot bags are ALWAYS scaled by DifficultyDef.payout_mult (D-020).
class_name PayoutTweak
extends Resource

# --- Cash ---------------------------------------------------------------------
## Multiplier on the cash subtotal when no crew member (human or AI) ends in custody (PD2: 110%).
@export var crew_alive_bonus_mult: float = 1.1
## Fraction of the gross payout sent to the stash (offshore). The rest is spending cash (PD2: 80/20).
@export var stash_fraction: float = 0.8
## ◇ Small loot (cash bundles, counter jewelry) is scaled by DifficultyDef.payout_mult like bags.
@export var small_loot_scaled_by_difficulty: bool = true
## ◇ Civilian kill penalties (DifficultyDef.civilian_kill_penalty per kill) also apply to failed heists.
@export var civilian_penalty_on_failure: bool = true

# --- XP (applied in C6 order) ----------------------------------------------------
## ◇ Base heist XP for a successful heist (before loot XP).
@export var base_xp_success: int = 2000
## ◇ Base XP on failure = base_xp_success x this. No loot XP on failure.
@export var base_xp_failure_fraction: float = 0.25
## ◇ Base XP per secured loot bag (bags in xp_loot_excluded_ids don't count).
@export var xp_per_loot_bag: int = 250
## Loot ids that never earn bag XP (body bags are loot bags, but not profit).
@export var xp_loot_excluded_ids: Array[StringName] = [&"loot.body_bag"]
## Pro job XP multiplier (PD2: +20%).
@export var pro_job_xp_mult: float = 1.2
## Fraction of XP lost by a player who ends in custody (PD2 CONFLICT: -30% vs ~5%; we use 30%).
@export var custody_xp_penalty_frac: float = 0.3
## Additive crew-alive XP bonus per surviving teammate (PD2: +10% each, up to +30%).
@export var crew_alive_xp_bonus_per_teammate: float = 0.1
@export var crew_alive_xp_bonus_cap: float = 0.3
## ◇ AI teammates count as surviving teammates for the XP bonus (solo with AI is first-class).
@export var crew_alive_xp_counts_ai: bool = true
## ◇ Multiplicative stealth XP bonus, applied last, on a successful stealth heist (PD2: 0-25%,
## carried to the NEXT heist; ours applies to the same heist).
@export var stealth_xp_bonus_mult: float = 1.2
