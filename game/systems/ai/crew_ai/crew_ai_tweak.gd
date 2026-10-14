## AI teammate (CrewAiBrain) tunables (A1-10). Owner: ENV A. Data: crew_ai_tweak.tres.
## Fidelity rows: L6.1 (follow / revive / fight / cover; stealth: wait at the van, D-014), L2.7
## (revive time comes from CrewTweak.revive_time_s, not from here). Values marked ◇ are design choices.
class_name CrewAiTweak
extends Resource

@export_group("Follow (L6.1)")
## Start moving toward the leader beyond this distance (m) ◇.
@export var follow_max_m: float = 8.0
## Stop once within this distance of the leader (m) ◇ (between follow_min_m and follow_max_m).
@export var follow_stop_m: float = 4.5
## Never path closer than this to the leader (m) ◇.
@export var follow_min_m: float = 3.0
## Sprint when the movement goal is farther than this (m) ◇.
@export var sprint_beyond_m: float = 6.0
## Loud (PD2 bots stick close in a fight): start following beyond / stop within these distances (m) ◇.
@export var follow_max_loud_m: float = 5.5
@export var follow_stop_loud_m: float = 3.5
## P PO-pass #3 / ND attempt 21: each AI follows to its own formation slot, fanned this far apart around the
## leader-to-me direction (deg) ◇, so bots never stack.
@export var follow_spread_deg: float = 55.0
## An idle AI closer than this to another crew member (horizontal, m) steps to its own slot ◇.
@export var unstack_m: float = 0.7
## P PO-pass: a bot (waiting at the van or idle) steps out of a human's personal radius (m) ◇.
@export var personal_radius_m: float = 0.6
## P PO-pass: in transit a bot keeps this gap (m) behind a moving teammate ahead on its line (single file
## through doors and corridors) ◇. Lower slots lead, so two bots never wait on each other.
@export var trail_gap_m: float = 1.0
## PD2 bots warp: a bot held this long (s) at a closed door it may not open (relocked, BARRED) while the leader
## is beyond warp_min_dist_m teleports to its formation slot by the leader (P's GN pass: three bots stacked at the
## relocked bronze doors) ◇.
@export var warp_after_blocked_s: float = 4.0
@export var warp_min_dist_m: float = 8.0
## A following AI stops within this of its own formation slot (m) ◇.
@export var follow_slot_arrive_m: float = 0.8

@export_group("Cover (L6.1)")
## Cover points (TacticalPoint COVER) considered must be within this distance of the leader (m) ◇.
@export var cover_search_radius_m: float = 8.0
## PO-5.3 ◇: eye height used for the cover point -> leader line-of-sight check (m).
@export var cover_eye_height_m: float = 1.1
## PO-5.3 ◇ (L2.5): a downed AI teammate does not shoot (police then ignore it for the full bleedout).
@export var downed_hold_fire: bool = true
## A cover point is taken if another crew member stands within this distance of it (m).
@export var cover_taken_m: float = 1.0
## Reached the cover point within this distance (m).
@export var cover_arrive_m: float = 0.6

@export_group("Revive (L6.1, L2.7)")
## Get this close (horizontal, m) to a downed crew member before holding interact.
@export var revive_range_m: float = 1.2
## L4.4 (P3 gate): a Stinger tasing a crew member scores its distance x this when the AI picks a target
## (lower = preferred; 0.25 = shot first unless something is 4x closer) ◇.
@export var tasing_stinger_score_mult: float = 0.25
## Start holding interact only below this horizontal speed (m/s) so the session is not cancelled
## by the deceleration slide (InteractionTweak.cancel_move_m).
@export var revive_settle_speed: float = 0.3

@export_group("Fight (L6.1)")
## Enemies farther than this are ignored (m) ◇.
@export var engage_range_m: float = 40.0
## Seconds between enemy scans (LOS rays) ◇.
@export var scan_interval_s: float = 0.2
## Delay between acquiring a new target and the first shot (s) ◇.
@export var reaction_time_s: float = 0.35
## Minimum time between trigger pulls (s) ◇ (the weapon's own fire rate still applies).
@export var shot_interval_s: float = 0.3
## Aim error radius at the aim point (m), re-rolled every shot on GameRng &"crew_ai" ◇.
@export var aim_error_m: float = 0.12
## Chance per shot to aim at the head instead of the chest ◇.
@export_range(0.0, 1.0) var head_aim_chance: float = 0.25
## Chest aim height above the NPC origin (m).
@export var chest_height_m: float = 1.15
## Only pull the trigger when the view is within this angle of the aim point (deg).
@export var fire_cone_deg: float = 4.0
## Turn rate of the view (deg/s) ◇.
@export var turn_speed_deg: float = 720.0
## Tactical reload below this magazine fraction when no enemy is visible ◇.
@export_range(0.0, 1.0) var tactical_reload_frac: float = 0.5

@export_group("Navigation")
## Re-plan the path this often (s), or when the goal moved more than repath_goal_move_m.
@export var repath_interval_s: float = 0.5
@export var repath_goal_move_m: float = 1.0
## Advance to the next path corner within this horizontal distance (m).
@export var waypoint_reach_m: float = 0.45
## D-085: interior path corners are pushed this far away from the inside of the turn (the wall corner the
## navmesh path hugs), so the 0.35 m crew capsule clears a corner baked for a 0.30 m nav agent.
@export var corner_margin_m: float = 0.1
## A bot steering along its path below this horizontal speed (m/s) for stuck_time_s is blocked by a body the
## navmesh does not carve (e.g. a variant's van) ◇.
@export var stuck_speed: float = 0.3
@export var stuck_time_s: float = 0.4
## A blocked bot side-steps along the blocking surface for this long (s), then re-plans ◇.
@export var stuck_detour_s: float = 0.6

@export_group("Orders (L6.1, A3-05)")
## D-014 "P4 option": a follow / carry_bag / revive order in STEALTH un-hides the AI so it follows and
## is detectable like a player. false = stealth orders are ignored and the AI keeps waiting at the van.
@export var stealth_follow_enabled: bool = true
## An AI (or bag / downed crew) within this angle of the human's aim is "aimed at" (deg) ◇.
@export var order_aim_cone_deg: float = 10.0
## Orders reach this far along the aim (m) ◇.
@export var order_range_m: float = 30.0
## PlayerInput keeps a tapped order on its intent this long (s) so the 30 Hz unreliable send carries it.
@export var order_latch_s: float = 0.25
## Hold: walk back to the hold point beyond this distance (m).
@export var hold_arrive_m: float = 0.6
## Hold: still revive downed crew within this distance of the hold point (m) ◇.
@export var hold_revive_radius_m: float = 6.0
## carry_bag without a bag id: the free bag nearest the aim point within this distance (m).
@export var bag_search_radius_m: float = 4.0
## Pick a bag up within this horizontal distance (m).
@export var bag_pickup_range_m: float = 1.2
## Carrying: head for a known SECURE_LOOT zone whose centre is within this distance (m) ◇.
@export var secure_seek_radius_m: float = 10.0
## Carrying: drop the bag within this distance of the secure point (m), facing the zone centre.
@export var secure_arrive_m: float = 0.8
## Drop only when the view is within this angle of the zone centre (deg).
@export var secure_face_deg: float = 20.0
