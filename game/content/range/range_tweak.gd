## Firing range presentation and tooling numbers (B1-05). Owner: ENV B.
## Data: res://content/data/range/range_tweak.tres. No gameplay balance lives here: weapon numbers
## come from LoadoutResolver, dummy HP from RangeDummyTable.
class_name RangeTweak
extends Resource

@export_group("Damage numbers")
@export var number_lifetime_s: float = 0.9
@export var number_rise_m: float = 0.7
@export var number_font_size: int = 56
@export var number_head_font_size: int = 76
@export var number_pixel_size: float = 0.0006
@export var number_body_color: Color = Color(0.95, 0.95, 0.95)
@export var number_head_color: Color = Color(1.0, 0.78, 0.2)
@export var number_kill_color: Color = Color(1.0, 0.35, 0.3)

@export_group("Targets")
@export var target_fall_time_s: float = 0.2
@export var target_fall_deg: float = 82.0
@export var board_color: Color = Color(0.78, 0.66, 0.46)
@export var head_color: Color = Color(0.86, 0.72, 0.5)
@export var stand_color: Color = Color(0.25, 0.26, 0.28)
@export var hp_font_size: int = 40
@export var label_pixel_size: float = 0.005

@export_group("Level dressing")
@export var marker_line_color: Color = Color(0.95, 0.8, 0.2)
@export var lane_line_color: Color = Color(0.85, 0.85, 0.85)
@export var bench_color: Color = Color(0.32, 0.3, 0.28)
@export var sign_font_size: int = 96
@export var sign_pixel_size: float = 0.006
@export var sign_color: Color = Color(1.0, 0.86, 0.3)

@export_group("Range camera (temporary tool)")
@export var move_speed_mps: float = 6.0
@export var sprint_mult: float = 3.0
@export var mouse_look_deg_per_px: float = 0.12
@export var stick_look_deg_s: float = 150.0
@export var stick_deadzone: float = 0.18
@export var fov_deg: float = 75.0
@export var max_hit_range_m: float = 250.0
