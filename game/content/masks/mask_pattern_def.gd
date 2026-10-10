## Mask pattern (pd2_fidelity P8). Owner: ENV B (ids/data); textures come from ENV D.
## When `texture_path` exists its red channel is the pattern mask (0 = color_a, 1 = color_b) over
## mask UV0; otherwise the mask shader draws the procedural pattern `procedural`.
class_name MaskPatternDef
extends MaskPartDef

enum Procedural { SOLID, SPLIT, BROW_BAND, STRIPES, CHEVRON, DOTS, SASH, DIAMONDS }

## Texture id requested from ENV D (e.g. &"tex_mask_pattern_split"); a reference only.
@export var texture_id: StringName = &""
@export_file("*.png") var texture_path: String = ""
@export var procedural: Procedural = Procedural.SOLID
## Repeats across the face for STRIPES / CHEVRON / DOTS / DIAMONDS.
@export var scale: float = 4.0
