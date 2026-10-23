## Loud police AI tunables (PoliceBrain: Patrol Officer, TAC Light; L4.2). Owner: ENV A.
## Data: police_tweak.tres. ◇ = design values.
class_name PoliceTweak
extends Resource

## Target re-evaluation interval range (s).
@export var retarget_s: Vector2 = Vector2(0.5, 1.0)
## D-168 ◇ (PD2 attention weighs who is shooting at the unit, not pure distance): a crew member who damaged this unit,
## or a squadmate within threat_squad_m of it, in the last threat_window_s scores distance² x threat_dist_mult.
@export var threat_window_s: float = 3.0
@export var threat_dist_mult: float = 0.5
@export var threat_squad_m: float = 10.0
## D-168 ◇: the current target scores distance² x sticky_dist_mult (no flip-flopping between two near-equal crew).
@export var sticky_dist_mult: float = 0.85
## Cover-lite: a COVER TacticalPoint within this distance band of the target with LOS to it.
@export var cover_min_m: float = 8.0
@export var cover_max_m: float = 20.0
## Cover search only considers points within this distance of the unit.
@export var cover_search_m: float = 35.0
## Standoff band without cover: close in beyond max (or without LOS), back off under min.
@export var standoff_min_m: float = 8.0
@export var standoff_pref_m: float = 11.0
@export var standoff_max_m: float = 15.0
## PO-5.14 ◇ (L1.1 assault push): while an assault is building/sustaining, units without cover close to
## this band instead (PD2 cops rush the room), so they do not hover in the doorway (back off out of
## sight, re-approach, repeat).
@export var assault_standoff_min_m: float = 2.0
@export var assault_standoff_pref_m: float = 4.0
## PO6-16 ◇ (D-114 §5, L1.1 BUILD/SUSTAIN push): while the assault pushes, a COVER point is only taken when it
## is this close to the target (PD2 assault units do not sit on cover outside the room the crew holds).
@export var assault_cover_max_m: float = 6.0
## PO6-16 ◇: push slots = navmesh points on these rings around the target (8 angles each) with LOS to the
## target's eyes, i.e. inside (or at the threshold of) the room the target holds; nearer rings first. The
## doorway on the way is opened / breached by NpcMotor + Door.npc_open.
@export var assault_slot_radii_m: PackedFloat32Array = PackedFloat32Array([2.0, 3.0, 4.0])
## PO6-16 ◇: another unit's slot closer than this counts as taken (adds the penalty, in meters of score).
@export var assault_slot_spacing_m: float = 1.0
@export var assault_slot_taken_penalty_m: float = 3.0
## PO6-16 ◇: a unit closer than this to its push slot holds there (m).
@export var assault_slot_arrive_m: float = 0.9
## PO6-16 ◇: a unit moving slower than this (m/s) toward its slot for assault_push_stall_s is stalled: it holds
## where it is when it sees the target, else it takes another slot.
@export var assault_push_stall_speed: float = 0.3
@export var assault_push_stall_s: float = 1.0
## PO6-16 ◇: the slot is recomputed when the target moved this far from where it was computed (m).
@export var assault_slot_refresh_m: float = 1.5
## PO6-16 ◇: a projected slot must lie within this distance of the candidate (horizontal) and within
## assault_slot_max_dy_m of the target's floor.
@export var assault_slot_snap_m: float = 0.6
@export var assault_slot_max_dy_m: float = 1.0
## X-5 ◇ (GH workshop doorway jam): a unit under the standoff band backs off to one latched stand point at the
## preferred standoff from the target, re-picked when the target moved this far (m).
@export var back_off_refresh_m: float = 1.5
## X-5 ◇: a back-off that gains less than this (m of flat distance from the target) in back_off_stall_s is blocked
## (a teammate holding in the doorway, a wall): the unit side-steps to the next heading.
@export var back_off_progress_m: float = 0.3
@export var back_off_stall_s: float = 1.5
## X-5 ◇: back-off headings tried in order (deg from straight away from the target); none left = hold there.
@export var back_off_side_deg: PackedFloat32Array = PackedFloat32Array([0.0, 60.0, -60.0])
@export var fire_range_m: float = 40.0
## Flank-lite: chance a fresh unit first visits a FLANK point near the target.
@export var flank_chance: float = 0.3
@export var flank_max_from_target_m: float = 30.0
@export var flank_timeout_s: float = 12.0
@export var arrive_m: float = 0.8
@export var fallback_run_speed: float = 3.5
