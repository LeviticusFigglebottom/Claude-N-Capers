## Menu-side heist data (res://content/data/ui/heist_list.tres). Owner: ENV B.
## Which heists exist comes from HeistRegistry (core, D-024); HeistDefs belong to ENV C. This list
## only holds UI data keyed by heist id (no placeholders: QB-55, D-049).
class_name UiHeistList
extends Resource

## heist id (StringName) -> per-heist UI data, every key optional:
##   "solo_ai_teammates": int            overrides the default below for "Play solo"
##   "requires": Array[String]           res:// paths that must exist before the menus offer the heist (readiness gate,
##                                       on top of HeistCatalog's def + map; e.g. the mission script a new heist waits on)
##   "glazing": bool                     D-142: notable clear glass (storefront, tower); the briefing says glass does not
##                                       hide you (behind HudTweak.d142_glass_tips)
##   "mode_key": StringName              the Board / heist select / briefing mode label instead of the HeistMode's
##                                       (D-075: Rolling Thunder "Loud (ambush start)")
## Display text is always strings.csv `heist.<id>.name` / `.subtitle` / `.brief`.
@export var heists: Dictionary = {}
## Difficulties selectable in this build (Enums.Difficulty values); others show as locked (C4: P1 = 2).
@export var unlocked_difficulties: Array[int] = []
## D-117 §2: difficulties unlocked by progression: each opens once any heist is won on the difficulty just below it
## (Lethal after a win on the top pickable one, Cataclysm after a Lethal win). Shown locked until then, never hidden.
@export var progression_difficulties: Array[int] = []
## Default AI teammates added by "Play solo" (contracts/test_hooks.md options.ai_teammates).
@export var solo_ai_teammates: int = 3


## AI teammates for a solo launch of `heist_id`.
func solo_ai_for(heist_id: StringName) -> int:
	var d: Dictionary = heists.get(heist_id, {}) as Dictionary
	return int(d.get("solo_ai_teammates", solo_ai_teammates))


## Readiness gate paths for `heist_id` ("requires"; empty = def + map are enough).
func requires_for(heist_id: StringName) -> PackedStringArray:
	var d: Dictionary = heists.get(heist_id, {}) as Dictionary
	var out: PackedStringArray = PackedStringArray()
	for p: Variant in d.get("requires", []) as Array:
		out.append(String(p))
	return out


## The mode label key override for `heist_id` ("mode_key"), or &"" for the HeistMode's own label.
func mode_key_for(heist_id: StringName) -> StringName:
	var d: Dictionary = heists.get(heist_id, {}) as Dictionary
	return StringName(d.get("mode_key", &""))


## D-142: true when `heist_id` is marked "glazing" (notable clear glass).
func has_glazing(heist_id: StringName) -> bool:
	return bool((heists.get(heist_id, {}) as Dictionary).get("glazing", false))
