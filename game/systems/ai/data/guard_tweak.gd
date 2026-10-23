## Security Officer (guard) behaviour tunables (A1-05). Owner: ENV A. Data: guard_tweak.tres.
## Fidelity rows: S3.2 (P1 simplification), S3.3, S3.4, S5.1, S11.2. Values marked ◇ are design
## choices (pd2_fidelity.md). Radio call length and investigate budget live in StealthTweak (S3).
## Movement speeds come from EnemyDef (move_speed = run; params.patrol_speed / investigate_speed).
class_name GuardTweak
extends Resource

@export_group("Speeds")
## Used only when the NPC has no EnemyDef (EnemyDef.params.patrol_speed / move_speed win).
@export var fallback_walk_speed: float = 1.6
@export var fallback_run_speed: float = 3.5

@export_group("Patrol routes (S5.1)")
## Route length in PatrolPoints, rolled per guard on GameRng &"patrols" ◇.
@export var route_min_points: int = 4
@export var route_max_points: int = 8
## Random walks tried per guard to find a closed loop before falling back to ping-pong.
@export var route_attempts: int = 6
## PatrolPoint tag a guard may use (heist_map.md §4).
@export var route_tag: StringName = &"guard"
## Without a SpawnPoint.patrol_graph, use the nearest graph whose closest point is within this (m).
@export var nearest_graph_max_m: float = 25.0
## Hub-loop patrols (OF-A6, LEAD 2026-10-20): spawn tag -> {"hub": point name (optional; default the graph point
## nearest the post), "loops": Array of Array[point name] (empty = one loop per pause point reachable from the hub)}.
## A guard whose spawn carries one of these tags walks the loops from the hub in turn instead of one random S5.1 walk.
## Optional (D-152, OF playability margin): "dwell_add_s" {point name: seconds} added to that point's pause, on
## difficulties up to "dwell_add_max_difficulty" (default every difficulty).
@export var hub_loops: Dictionary = {}
## PO-10 ◇: guards sharing a patrol graph start staggered, not in lockstep: the k-th guard to start on a
## graph waits k x patrol_stagger_s plus a random [0, patrol_stagger_jitter_s] (GameRng &"patrol_stagger")
## before its first leg; the first guard leaves at once.
@export var patrol_stagger_s: float = 3.0
@export var patrol_stagger_jitter_s: float = 1.5

@export_group("Post / look-around (S5.1)")
## Guards without a graph stand at their post; seconds between look-arounds, random in [x, y] ◇.
@export var post_look_interval_s: Vector2 = Vector2(5.0, 10.0)
## Yaw offset of a look-around glance (deg) and how long each glance is held (s) ◇.
@export var look_around_angle_deg: float = 60.0
@export var look_hold_s: float = 1.2
## Distance from the post at which the guard walks back to it (m).
@export var post_return_m: float = 0.6
## D's AH cast review (the door bouncer walked on the spot all night): a walk back to the post that has not arrived
## after this long (s) takes the spot reached as the post (the crowd / a door left the exact point unreachable) ◇.
@export var post_walk_give_up_s: float = 5.0

@export_group("Curious / investigate (S3.4)")
## "?" beat: stop and face the source before walking over (s) ◇.
@export var curious_beat_s: float = 1.5
## Stop this far from the investigated position (m).
@export var investigate_arrive_m: float = 1.2

@export_group("Combat stub (S11.2, A1-08 shoots)")
## Standoff band to the target (m) ◇; the guard closes to `combat_standoff_pref_m`.
@export var combat_standoff_min_m: float = 6.0
@export var combat_standoff_max_m: float = 15.0
@export var combat_standoff_pref_m: float = 10.0
## wants_to_fire is true when the target is visible and within this distance (m).
@export var combat_fire_range_m: float = 30.0
## Seconds a guard in combat wants to fire without a shot line (the gunner not engaging: crew seen through a pane bullets
## cannot pass) before it closes in for one (PD2: guards move to get a shot).
@export var combat_no_shot_close_s: float = 3.0
## Seconds between target re-evaluations.
@export var combat_retarget_s: float = 0.5
