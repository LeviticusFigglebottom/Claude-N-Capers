## Notoriety tuning (pd2_fidelity P10, the infamy analog; roadmap B5-02). Owner: ENV B.
## Data: res://content/data/tweak/notoriety.tres. Consumed by Notoriety. Design: content/docs/notoriety.md.
## Every number here is balance data; ◇ = our choice, not PD2-verified.
class_name NotorietyTweak
extends Resource

## ◇ Highest rank (pd2_fidelity P10: Notoriety ranks 1..25).
@export var max_rank: int = 25
## Reputation level needed to go up a rank (PD2: 100).
@export var required_level: int = 100
## ◇ Spending cash cost of rank n at index n - 1 (taken from PlayerProfile.cash). Ranks past the end
## of the list reuse its last entry.
@export var costs: Array[int] = []
## ◇ Additive XP bonus per rank (0.02 = +2 %); PayoutCalculator shows it as its own XP line.
@export var xp_bonus_per_rank: float = 0.02
## ◇ Cap of that bonus (0.3 = +30 %).
@export var xp_bonus_cap: float = 0.3
