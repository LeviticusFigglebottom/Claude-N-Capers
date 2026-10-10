## Concealment -> detection risk lookup (pd2_fidelity.md S2.3, S2.4). Owner: ENV B.
## Data: content/data/tweak/concealment_curve.tres. LoadoutResolver is the only gameplay consumer
## of `dr_for_total`; ENV A reads `Loadout.detection_risk` and owns the stealth-side multiplier
## (stealth_tweak). `detection_mult` is here for UI previews only.
class_name ConcealmentCurve
extends Resource

## Total concealment that maps to `dr_by_total[0]`; totals at or below it give the max DR.
@export var min_total: int = 91
## DR for each total from `min_total` upward (index 0 = min_total). Totals past the end give the
## last entry (lowest DR).
@export var dr_by_total: PackedInt32Array = PackedInt32Array()
## Per-weapon concealment clamp (PD2: each weapon caps at 30).
@export var weapon_concealment_min: int = 0
@export var weapon_concealment_max: int = 30
## Concealment a missing weapon/melee/armor slot contributes (P1 rule: the P1 loadout has no
## primary; an empty slot counts as fully concealable so a pistol-only loadout is not penalized).
@export var empty_slot_concealment: int = 30
## DR -> detection-time multiplier table (S2.3); linear interpolation between points.
@export var mult_dr: PackedInt32Array = PackedInt32Array()
@export var mult_value: PackedFloat32Array = PackedFloat32Array()


func max_total() -> int:
	return min_total + dr_by_total.size() - 1


func dr_for_total(total: int) -> int:
	if dr_by_total.is_empty():
		return 75
	var i: int = clampi(total - min_total, 0, dr_by_total.size() - 1)
	return dr_by_total[i]


func detection_mult(dr: int) -> float:
	if mult_dr.is_empty():
		return 1.0
	if dr <= mult_dr[0]:
		return mult_value[0]
	for i: int in range(1, mult_dr.size()):
		if dr <= mult_dr[i]:
			var t: float = float(dr - mult_dr[i - 1]) / float(mult_dr[i] - mult_dr[i - 1])
			return lerpf(mult_value[i - 1], mult_value[i], t)
	return mult_value[mult_value.size() - 1]
