## Cartel gunman tunables (QC-36, L4.10, D-064). Owner: ENV A. Data: cartel_tweak.tres. All ◇ (PD2 gangster shape).
class_name CartelTweak
extends Resource

@export_group("Waking")
## Sighting: a crew member inside sight_range_m and the fov cone with line of sight for sight_time_s.
@export var sight_range_m: float = 25.0
@export var sight_fov_deg: float = 120.0
@export var sight_time_s: float = 0.8
## DB-12: a corpse in the same cone (range, LOS, sight_time_s) wakes the gunman; LOS aims this far above it.
@export var wake_on_body: bool = true
@export var body_sight_up_m: float = 0.3
## A noise of one of these kinds (HeistRuntime.noise_made) whose radius reaches the gunman wakes him.
@export var wake_noise_kinds: Array[StringName] = [&"gunshot", &"explosion", &"alarm", &"glass"]
## A waking gunman shouts: every sleeping gunman within this radius wakes too.
@export var alert_share_radius_m: float = 20.0

@export_group("Patrol")
@export var route_tag: StringName = &"guard"
@export var route_min_points: int = 2
@export var route_max_points: int = 5
@export var route_attempts: int = 6
@export var nearest_graph_max_m: float = 20.0
@export var patrol_speed: float = 1.5

@export_group("Holding the post")
## Gunmen fight from their post: cover within cover_search_m of the post, never further than post_leash_m.
@export var cover_search_m: float = 10.0
@export var post_leash_m: float = 12.0
@export var cover_min_m: float = 4.0
@export var cover_max_m: float = 35.0
@export var fire_range_m: float = 40.0
@export var retarget_s: float = 0.6
@export var run_speed: float = 3.6
