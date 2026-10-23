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
## Civilian kill penalties (DifficultyDef.civilian_kill_penalty per kill) also apply to failed heists. D-120 addendum
## (LEAD r228): a failed heist pays nothing AND costs nothing, so this is off.
@export var civilian_penalty_on_failure: bool = false

# --- XP (applied in C6 order) ----------------------------------------------------
## ◇ Base heist XP for a successful heist (before loot XP).
@export var base_xp_success: int = 2000
## D-148 (PO, option D): base success XP by heist size (PD2: a bigger job pays more XP); heists not listed use
## base_xp_success. Failure XP scales from the same base. See content/docs/progression_pace.md.
@export var base_xp_by_heist: Dictionary = {&"glasshouse": 1500, &"night_deposit": 2000, &"shadow_ledger": 2500,
	&"dockside_burn": 2000, &"gallery_night": 2500, &"ostrander_federal": 3000, &"rolling_thunder": 2500,
	&"afterhours": 2500}
## ◇ Base XP on failure = base_xp_success x this. No loot XP on failure.
@export var base_xp_failure_fraction: float = 0.25

## ◇ Base XP per secured loot bag (tool bags, LootDef.is_tool (D-068), and bags in xp_loot_excluded_ids
## don't count).
@export var xp_per_loot_bag: int = 250
## Loot ids that never earn bag XP besides tools (body bags are loot bags, but not profit).
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
## ◇ Stealth bonus banked by a successful stealth heist and applied (multiplicatively, last in C6
## order) to the XP of the NEXT successful payday (pd2_fidelity S11.1, D-022 QB-13). S11.1: +5..25%
## scaled by heist size: PayoutCalculator.stealth_bonus_for uses the heist's HeistDef.stealth_bonus_mult (per size);
## this value is the fallback for a heist without one.
@export var stealth_xp_bonus_mult: float = 1.2
## D-139 heist freshness (HeistFreshness): the per-player memory of the last `freshness_memory` runs that reached
## payday; a heist in it n times pays x(1 - repeat_step x n), floored at repeat_floor; a completed heist out of it
## gains rotation_step per further run, up to rotation_cap. Money (gross) and XP (an 8th xp line).
@export var freshness_memory: int = 10
@export var repeat_step: float = 0.10
@export var repeat_floor: float = 0.10
@export var rotation_step: float = 0.01
@export var rotation_cap: float = 0.10


## D-148: the base success XP for `heist_id` (base_xp_by_heist, else base_xp_success).
func base_xp_for(heist_id: StringName) -> int:
	return int(base_xp_by_heist.get(heist_id, base_xp_success))
