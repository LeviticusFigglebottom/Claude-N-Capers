## Mask customisation tuning (`content/data/masks/mask_tweak.tres`). Owner: ENV B. Has no `id`
## property, so ContentDB skips it.
class_name MaskTweak
extends Resource

## Number of custom mask slots (`mask.custom.0` .. `mask.custom.<n-1>`).
@export var custom_slot_count: int = 6
## Composition shown when the mask screen has nothing else to show.
@export var default_composition: Dictionary = {}
## Placeholder mesh grid resolution (quads per side).
@export var placeholder_grid: int = 40
@export_group("Preview")
@export var preview_spin_deg_s: float = 18.0
@export var preview_drag_deg_per_px: float = 0.4
@export var preview_stick_deg_s: float = 140.0
## One ui_left/ui_right press while the preview has focus.
@export var preview_key_step_deg: float = 15.0
@export var preview_pitch_limit_deg: float = 35.0
## Seconds after the last manual turn before the auto spin resumes.
@export var preview_idle_s: float = 2.5
@export var preview_camera_distance_m: float = 0.55
@export var preview_background: Color = Color(0.06, 0.07, 0.09, 1)
