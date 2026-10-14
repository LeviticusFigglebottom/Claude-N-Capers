## The playable heisters (D-073; data: res://content/data/heisters/roster.tres). Owner: ENV B.
## `ids` is the roster order: the order a conflicting or generic pick falls back through and the order AI
## teammates fill the unused heisters (Heisters.assign). Names are strings.csv `crew.<id>`.
class_name HeisterRoster
extends Resource

const DEFAULT_PATH: String = "res://content/data/heisters/roster.tres"

## Heister ids in roster order (Loadout.heister values; &"" = generic crew is not listed).
@export var ids: Array[StringName] = [&"rook", &"sable", &"dutch", &"wren"]
## id -> accent Color for the picker swatch and the lobby slot (never the reserved focus cyan).
@export var accents: Dictionary = {}
## D-111: id -> unlock id (MaskLocker.grant_unlock / profile.unlocks) for heisters that are earned; ids not
## listed are free from the start. A locked heister shows disabled in the picker (AI teammates may still fill it).
@export var unlocks: Dictionary = {}
## Accent of the generic crew (&"").
@export var generic_accent: Color = Color(0.55, 0.53, 0.5)
## Folder of ENV D's 2D crew portraits (`<portrait_dir>/<id>.png`); a missing file shows the name + accent only.
@export var portrait_dir: String = "res://assets/characters/portraits"


static func load_default() -> HeisterRoster:
	var r: HeisterRoster = null
	if ResourceLoader.exists(DEFAULT_PATH):
		r = load(DEFAULT_PATH) as HeisterRoster
	return r if r != null else HeisterRoster.new()
