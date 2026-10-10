## A local player's persistent progression profile. Owner: ENV B. Persisted by SaveService.
##
## JSON shape (version 2; see SaveService for migrations):
##   version: int, profile_name: String,
##   cash: int (spending cash), stash: int (offshore, "the stash"; pd2_fidelity S10.4),
##   xp: int (total), level: int (0..100; pd2_fidelity P1),
##   owned_weapons / owned_mods / owned_masks: Array[String] of ids.
##     owned_mods is a FLAT list: mod ids are already weapon-specific (`mod.p9_suppressor`),
##     WeaponModDef says which weapons accept a mod.
##   loadout: only Loadout *input* fields (see LOADOUT_FIELDS); resolved fields are never saved,
##     run LoadoutResolver.resolve() after loading.
##   banked_stealth_mult: float (v2, D-022 QB-13): stealth XP bonus banked by the last successful
##     stealth heist, applied to the NEXT payday (PayoutCalculator.compute(..., banked_stealth_mult)).
##     1.0 = nothing banked.
##   stats: Dictionary String -> int counters (heists_completed, ...).
##   settings: Dictionary of JSON values, stored as-is (JSON numbers come back as float).
## StringNames are written as strings and converted back on load.
class_name PlayerProfile
extends RefCounted

const DEFAULT_PROFILE_PATH: String = "res://content/data/save/default_profile.json"
## Loadout input fields that are persisted. Order matters only for readability of the file.
const LOADOUT_ID_FIELDS: Array[String] = [
	"primary", "secondary", "melee", "throwable", "deployable", "deployable_secondary",
	"armor", "mask", "perk_deck",
]
const LOADOUT_LIST_FIELDS: Array[String] = ["primary_mods", "secondary_mods"]

var version: int = 2
var profile_name: String = ""
var cash: int = 0
var stash: int = 0
var xp: int = 0
var level: int = 0
var banked_stealth_mult: float = 1.0
var owned_weapons: Array[StringName] = []
var owned_mods: Array[StringName] = []
var owned_masks: Array[StringName] = []
var loadout: Loadout = Loadout.new()
var stats: Dictionary = {}
var settings: Dictionary = {}


## Fresh profile built from res://content/data/save/default_profile.json (never from code).
static func new_default() -> PlayerProfile:
	var text: String = FileAccess.get_file_as_string(DEFAULT_PROFILE_PATH)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if not parsed is Dictionary:
		Log.error(&"save", "default profile missing or invalid: %s" % DEFAULT_PROFILE_PATH)
		return PlayerProfile.new()
	return from_dict(parsed as Dictionary)


static func from_dict(d: Dictionary) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new()
	p.version = int(d.get("version", p.version))
	p.profile_name = String(d.get("profile_name", ""))
	p.cash = int(d.get("cash", 0))
	p.stash = int(d.get("stash", 0))
	p.xp = int(d.get("xp", 0))
	p.level = int(d.get("level", 0))
	p.banked_stealth_mult = float(d.get("banked_stealth_mult", 1.0))
	p.owned_weapons = _to_names(d.get("owned_weapons", []))
	p.owned_mods = _to_names(d.get("owned_mods", []))
	p.owned_masks = _to_names(d.get("owned_masks", []))
	var ld: Variant = d.get("loadout", {})
	p.loadout = loadout_from_dict(ld as Dictionary if ld is Dictionary else {})
	p.stats = {}
	var st: Variant = d.get("stats", {})
	if st is Dictionary:
		for k: Variant in (st as Dictionary):
			p.stats[String(k)] = int((st as Dictionary)[k])
	var se: Variant = d.get("settings", {})
	p.settings = (se as Dictionary).duplicate(true) if se is Dictionary else {}
	return p


func to_dict() -> Dictionary:
	var st: Dictionary = {}
	for k: Variant in stats:
		st[String(k)] = int(stats[k])
	return {
		"version": version,
		"profile_name": profile_name,
		"cash": cash,
		"stash": stash,
		"xp": xp,
		"level": level,
		"banked_stealth_mult": banked_stealth_mult,
		"owned_weapons": _to_strings(owned_weapons),
		"owned_mods": _to_strings(owned_mods),
		"owned_masks": _to_strings(owned_masks),
		"loadout": loadout_to_dict(loadout),
		"stats": st,
		"settings": settings.duplicate(true),
	}


## Increment a stats counter (e.g. &"heists_completed").
func add_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


static func loadout_to_dict(l: Loadout) -> Dictionary:
	var out: Dictionary = {}
	if l == null:
		return out
	for f: String in LOADOUT_ID_FIELDS:
		out[f] = String(l.get(f))
	for f: String in LOADOUT_LIST_FIELDS:
		out[f] = _to_strings(l.get(f) as Array)
	out["perk_deck_cards"] = l.perk_deck_cards
	var sk: Dictionary = {}
	for k: Variant in l.skills:
		sk[String(k)] = int(l.skills[k])
	out["skills"] = sk
	return out


static func loadout_from_dict(d: Dictionary) -> Loadout:
	var l: Loadout = Loadout.new()
	for f: String in LOADOUT_ID_FIELDS:
		l.set(f, StringName(String(d.get(f, ""))))
	for f: String in LOADOUT_LIST_FIELDS:
		l.set(f, _to_names(d.get(f, [])))
	l.perk_deck_cards = int(d.get("perk_deck_cards", 0))
	var sk: Variant = d.get("skills", {})
	if sk is Dictionary:
		for k: Variant in (sk as Dictionary):
			l.skills[StringName(String(k))] = int((sk as Dictionary)[k])
	return l


static func _to_names(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if v is Array:
		for e: Variant in (v as Array):
			out.append(StringName(String(e)))
	return out


static func _to_strings(a: Array) -> Array[String]:
	var out: Array[String] = []
	for e: Variant in a:
		out.append(String(e))
	return out
