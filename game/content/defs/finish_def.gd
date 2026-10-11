## A weapon finish (B7-04): an earned cosmetic that overrides weapon materials. Owner: ENV B.
## Data: res://content/data/finishes/<name>.tres, id `finish.<name>` (ContentDB kind `finishes`).
## Text: strings.csv `item.<id>.name` / `item.<id>.desc`. Logic: progression/weapon_finishes.gd
## (ownership, equip, loadout stamping), weapons/finish_applier.gd (surface overrides).
##
## Owned when `default_owned`, or when `unlock` (`unlock.finish.<name>`) is in PlayerProfile.unlocks
## (granted by an achievement's AchievementDef.unlock or a Notoriety rank's NotorietyDef.unlocks).
class_name FinishDef
extends Resource

@export var id: StringName = &""
## Debug fallback only; UI text is `item.<id>.name`.
@export var display_name: String = ""
## `unlock.finish.<name>` (same <name> as the id).
@export var unlock: StringName = &""
@export var default_owned: bool = false
## Also recolour attached (non-stock) mod models. Stock parts are part of the weapon model and always follow.
@export var covers_mods: bool = true
## Display order in the workshop picker (then id).
@export var order: int = 0
## Material recipes; a slot named by two layers takes the first.
@export var layers: Array[FinishLayer] = []


## The layer that replaces material slot `slot` (null = the slot keeps its stock material).
func layer_for(slot: StringName) -> FinishLayer:
	for l: FinishLayer in layers:
		if l != null and l.slots.has(slot):
			return l
	return null


## Every slot this finish replaces, in layer order.
func slots() -> Array[StringName]:
	var out: Array[StringName] = []
	for l: FinishLayer in layers:
		if l == null:
			continue
		for s: StringName in l.slots:
			if not out.has(s):
				out.append(s)
	return out
