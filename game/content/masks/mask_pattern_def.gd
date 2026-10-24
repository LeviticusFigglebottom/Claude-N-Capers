## Mask pattern (pd2_fidelity P8). Owner: ENV B (ids/data); textures come from ENV D.
## When `texture_path` exists its red channel is the pattern mask (0 = color_a, 1 = color_b) over
## mask UV0; otherwise the mask shader draws the procedural pattern `procedural`.
class_name MaskPatternDef
extends MaskPartDef

## Shader ids (mask_surface.gdshader `pattern`); append only, saved data stores the number.
enum Procedural {
	SOLID, SPLIT, BROW_BAND, STRIPES, CHEVRON, DOTS, SASH, DIAMONDS,
	SCALES, CIRCUIT, PROWL, HALFTONE, CRACKLE, STARBURST,
	GUILLOCHE, VAULT_BOLTS, ACANTHUS, FACETS, TIME_LOCK_DIAL, STENCIL,  # round 244 achievement parts (append-only)
	ROAD_LINES, TREAD,  # RT-B1 achievement parts (append-only)
	VINYL_LABEL,  # AH-B1 achievement part (append-only)
}

## Texture id requested from ENV D (e.g. &"tex_mask_pattern_split"); a reference only.
@export var texture_id: StringName = &""
@export_file("*.png") var texture_path: String = ""
@export var procedural: Procedural = Procedural.SOLID
## Repeats across the face (STRIPES / CHEVRON / DOTS / DIAMONDS / SCALES / CIRCUIT / PROWL /
## HALFTONE / CRACKLE); STARBURST: half the ray count.
@export var scale: float = 4.0
