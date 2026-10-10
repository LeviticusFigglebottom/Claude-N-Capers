## Per-heist UI accent colours (docs/art/style_guide.md §3, the "Accent" column). Owner: ENV B.
## Data: res://content/data/ui/heist_accents.tres. Read through UiAccent (common/ui_accent.gd).
class_name UiHeistAccents
extends Resource

const DEFAULT_PATH: String = "res://content/data/ui/heist_accents.tres"

## heist id (StringName) -> Color: the heist's accent (strips, card edges, HUD objective rule).
@export var accents: Dictionary = {}
## Accent for heists without an entry (the house brass).
@export var fallback: Color = Color(0.788, 0.635, 0.153, 1)
## Minimum WCAG contrast for accent-coloured TEXT against the panel it sits on (body text = 4.5).
@export var min_text_contrast: float = 4.5


static func load_default() -> UiHeistAccents:
	return load(DEFAULT_PATH) as UiHeistAccents
