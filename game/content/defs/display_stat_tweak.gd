## Parameters StatCalculator uses to map physical WeaponStats to PD2-style UI numbers
## (pd2_fidelity.md L3.1). Owner: ENV B. Data: content/data/tweak/display_stats.tres.
## UI only: gameplay always uses the physical values.
class_name DisplayStatTweak
extends Resource

## damage shown = damage * pellets^(pellet_exponent) * damage_scale (exponent 0 = per pellet).
@export var damage_scale: float = 1.0
@export var damage_pellet_exponent: float = 0.0
## Accuracy 0..accuracy_max: linear in ADS spread between best (=max) and worst (=0) degrees.
@export var accuracy_max: float = 100.0
@export var accuracy_spread_best_deg: float = 0.0
@export var accuracy_spread_worst_deg: float = 2.5
## Stability 0..stability_max: recoil metric = kick + horizontal * horizontal_weight.
@export var stability_max: float = 100.0
@export var stability_recoil_best_deg: float = 0.0
@export var stability_recoil_worst_deg: float = 3.0
@export var stability_horizontal_weight: float = 0.5
## Threat = suppression * threat_scale, clamped to 0..threat_max (PD2 caps threat at 43).
@export var threat_scale: float = 1.0
@export var threat_max: float = 43.0
## Display keys where a smaller number is an improvement (green when lower).
@export var lower_is_better: Array[StringName] = [&"reload", &"reload_empty"]
## Display keys compared by StatCalculator.delta (order = UI order).
@export var delta_keys: Array[StringName] = [
	&"damage", &"accuracy", &"stability", &"concealment", &"threat",
	&"mag", &"total_ammo", &"rof", &"reload", &"reload_empty",
]
