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

@export_group("Cover (L6.1)")
## Cover points (TacticalPoint COVER) considered must be within this distance of the leader (m) ◇.
@export var cover_search_radius_m: float = 8.0
## A cover point is taken if another crew member stands within this distance of it (m).
@export var cover_taken_m: float = 1.0
## Reached the cover point within this distance (m).
@export var cover_arrive_m: float = 0.6

@export_group("Revive (L6.1, L2.7)")
## Get this close (horizontal, m) to a downed crew member before holding interact.
@export var revive_range_m: float = 1.2
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
