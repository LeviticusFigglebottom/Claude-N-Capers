## Test-only fixture for staged heists (LEAD r268, as in test_heist_screens_text): a staged heist's WIP def takes over
## the convention def path in the resource cache and the cached heist list un-hides it, for one test file. Nothing in
## data. stage() returns the heists it staged (none once a heist is offered for real; with its real def landed it
## only lifts the hidden switch);
## unstage() puts both back. Not a test file (no test_ prefix).
extends RefCounted

## { heist id: its WIP def path }.
const STAGED_WIP: Dictionary = {&"rolling_thunder": "res://world/heists/rolling_thunder/rolling_thunder_wip_def.tres",
	&"afterhours": ""}  # AH (D-165): its real def has landed; only the hidden switch is lifted

var staged: Array[StringName] = []
var _wip: Array[Resource] = []
## Held so the cached heist list (with the un-hidden entry) is not freed and reloaded from disk mid-file.
var _list: UiHeistList = null


func stage() -> Array[StringName]:
	_list = HeistCatalog.heist_list()
	for h: StringName in STAGED_WIP:
		if not _list.is_hidden(h):
			continue  # offered for real: the plain walks cover it
		if not ResourceLoader.exists(HeistRegistry.def_path(h)):
			if not ResourceLoader.exists(String(STAGED_WIP[h])):
				continue
			var def: Resource = load(String(STAGED_WIP[h]))
			def.take_over_path(HeistRegistry.def_path(h))
			_wip.append(def)
		# else the real def has landed and only the hidden switch holds the heist back ("one flag away")
		(_list.heists[h] as Dictionary)["hidden"] = false
		staged.append(h)
	return staged


func unstage() -> void:
	for h: StringName in staged:
		(_list.heists[h] as Dictionary)["hidden"] = true
	for r: Resource in _wip:
		r.resource_path = ""
	staged.clear()
	_wip.clear()
