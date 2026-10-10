## Reputation XP curve parameters (pd2_fidelity P1). Data: res://content/data/tweak/xp_curve.tres.
## XP needed to go from level L-1 to L (L = 1..max_level):
##   step(L) = roundi(scale x (first_level_xp + (last_level_xp - first_level_xp) x t^exponent)),
##   t = (L - 1) / (max_level - 1).
## PD2 shape: 900 for 0->1, 1,000,000 for 99->100, ~23M total; the exponent is fitted to that total.
class_name XpCurveTweak
extends Resource

@export var max_level: int = 100
@export var first_level_xp: float = 900.0
@export var last_level_xp: float = 1000000.0
## ◇ Fitted so the unscaled total is ~23M (PD2).
@export var exponent: float = 3.36
## pd2_fidelity P1: same shape scaled x0.5 (PO may revise).
@export var scale: float = 0.5
