## A local player's persistent progression profile. Owner: ENV B. Persisted by SaveService.
##
## JSON shape (version 7; see SaveService for migrations). Every field, type, default and since-version:
## content/docs/save_format.md (ProfileSchema sanitizes types, ProfileValidator prunes unknown ids on load).
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
##   skill_sets: Array of skill dicts (v3, PD2 P2 "multiple skill sets"): id -> 1 basic / 2 aced.
##     active_skill_set: int index into skill_sets. The active set is ALSO loadout.skills, which is
##     authoritative: to_dict() writes loadout.skills into skill_sets[active_skill_set] and from_dict()
##     reads it back the same way. Switch sets with switch_skill_set(); the UI pads the array to its
##     configured count (ProgressionUiTweak.skill_set_count).
##   perk_cards: Dictionary deck id -> unlocked card count 0..9 (v3, PD2 P4: each deck has its own
##     progress). loadout.perk_deck_cards mirrors the active deck's entry (PerkProgress.sync()).
##   owned_mask_parts: Array[String] (v4, P8/P9): mask part ids owned on top of the parts flagged
##     `default_owned` in data (MaskLocker.grant_part; payday card drops later).
##   custom_masks: Array of composition dicts (v4, P8): index n = custom slot `mask.custom.<n>`,
##     {"base", "material", "colors", "pattern"} part ids, {} = empty slot (MaskLocker / MaskCatalog;
##     content/docs/masks.md). loadout.mask may hold a preset id or a custom slot id.
##   unlocks: Array[String] (v5): granted unlock ids (`unlock.*`, e.g. `unlock.achievement.cataclysm_clear`);
##     MaskLocker.grant_unlock records them, and every preset with a recorded unlock is owned.
##   achievements: Dictionary achievement id -> {"progress": int, "unlocked": bool} (v5, Achievements).
##   pro_job_locks: Dictionary BoardContracts.contract_key() -> float expires_at (Unix s) (v5,
##     QB-BRD1): failed pro Board contracts, locked until their rotation ends (ProJobLocks prunes them).
##   notoriety: int 0..NotorietyTweak.max_rank (v6, B5-02, P10): Notoriety rank (Notoriety.rank_up).
##   notoriety_xp: int (v6): XP moved out of `xp` by rank-ups; perk points count xp + notoriety_xp.
##   notoriety_choices: Dictionary rank (int; JSON string key) -> chosen reward id (v6, Notoriety.choose).
##   held_skill_sets: Array of skill dicts (v6), index-aligned with skill_sets: the build held by a
##     rank-up and re-bought as levels return (NotorietySkills); {} = nothing held.
##   music_choice: StringName (v6, B5-03): chosen heist music track id, &"" = the heist default.
##   career: Dictionary (v7, B7-01): lifetime career stats, JSON-shaped (String keys, int counters);
##     shape and sources in Career (progression/career.gd). Missing counter = never counted.
##   weapon_finishes: Dictionary weapon id -> finish id (v7, reserved for B7-04 weapon finishes);
##     &"" (or no entry) = the default finish.
##   stats: Dictionary String -> int counters (heists_completed, ...).
##   settings: Dictionary of JSON values, stored as-is (JSON numbers come back as float).
## StringNames are written as strings and converted back on load.
class_name PlayerProfile
extends RefCounted

const DEFAULT_PROFILE_PATH: String = "res://content/data/save/default_profile.json"
## Loadout input fields that are persisted. Order matters only for readability of the file.
const LOADOUT_ID_FIELDS: Array[String] = [
	"primary", "secondary", "melee", "throwable", "deployable", "deployable_secondary",
	"armor", "mask", "perk_deck", "heister", "perk_mimic_deck",
]
const LOADOUT_LIST_FIELDS: Array[String] = ["primary_mods", "secondary_mods"]

var version: int = 10
var profile_name: String = ""
var cash: int = 0
var stash: int = 0
var xp: int = 0
var level: int = 0
var banked_stealth_mult: float = 1.0
var owned_weapons: Array[StringName] = []
var owned_mods: Array[StringName] = []
var owned_masks: Array[StringName] = []
var owned_mask_parts: Array[StringName] = []
var custom_masks: Array[Dictionary] = []
var loadout: Loadout = Loadout.new()
var skill_sets: Array[Dictionary] = []
var active_skill_set: int = 0
var perk_cards: Dictionary = {}
## Granted unlock ids (v5), sorted.
var unlocks: Array[StringName] = []
## Achievement id (StringName) -> {"progress": int, "unlocked": bool} (v5).
var achievements: Dictionary = {}
## Contract key (String) -> expires_at (float, Unix seconds) (v5).
var pro_job_locks: Dictionary = {}
## Notoriety rank 0..max_rank (v6).
var notoriety: int = 0
## XP earned before the last rank-ups (v6); perk points count it.
var notoriety_xp: int = 0
## Rank (int) -> chosen reward id (StringName) (v6).
var notoriety_choices: Dictionary = {}
## Held skill builds (v6), index-aligned with skill_sets ({} = nothing held).
var held_skill_sets: Array[Dictionary] = []
## Heist music track id (v6); &"" = the heist's default.
var music_choice: StringName = &""
## Lifetime career stats (v7, Career); JSON-shaped: String keys, int values.
var career: Dictionary = Career.empty()
## D-139 heist freshness memory (save v9; shape and rules in HeistFreshness).
var freshness: Dictionary = HeistFreshness.empty()
## Weapon id (StringName) -> finish id (StringName) (v7, B7-04); &"" = default finish.
var weapon_finishes: Dictionary = {}
## D-145.4 / PO-19 (save v10): the crew bots' loadouts, one {weapon, mods, armor, mask, outfit} per bot slot (CrewLoadouts;
## StringName ids, &"" = the bot's default). Always ProfileSchema.CREW_SLOTS entries.
var crew_loadouts: Array[Dictionary] = _crew_from([])
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
	p.owned_mask_parts = _to_names(d.get("owned_mask_parts", []))
	p.custom_masks = []
	var cm: Variant = d.get("custom_masks", [])
	if cm is Array:
		for e: Variant in (cm as Array):
			p.custom_masks.append(_strings_dict(e))
	var ld: Variant = d.get("loadout", {})
	p.loadout = loadout_from_dict(ld as Dictionary if ld is Dictionary else {})
	p.loadout.mask_descriptor = LoadoutResolver.mask_descriptor_for(p.loadout, p)  # derived, never saved
	p.skill_sets = []
	var sets: Variant = d.get("skill_sets", [])
	if sets is Array:
		for e: Variant in (sets as Array):
			p.skill_sets.append(_skills_from(e))
	p.active_skill_set = maxi(int(d.get("active_skill_set", 0)), 0)
	while p.skill_sets.size() <= p.active_skill_set:
		p.skill_sets.append({})
	p.skill_sets[p.active_skill_set] = p.loadout.skills.duplicate()
	p.perk_cards = {}
	var pc: Variant = d.get("perk_cards", {})
	if pc is Dictionary:
		for k: Variant in (pc as Dictionary):
			p.perk_cards[StringName(String(k))] = int((pc as Dictionary)[k])
	p.unlocks = _to_names(d.get("unlocks", []))
	p.achievements = _achievements_from(d.get("achievements", {}))
	p.pro_job_locks = {}
	var locks: Variant = d.get("pro_job_locks", {})
	if locks is Dictionary:
		for k: Variant in (locks as Dictionary):
			p.pro_job_locks[String(k)] = float((locks as Dictionary)[k])
	p.notoriety = int(d.get("notoriety", 0))
	p.notoriety_xp = int(d.get("notoriety_xp", 0))
	p.notoriety_choices = {}
	var ch: Variant = d.get("notoriety_choices", {})
	if ch is Dictionary:
		for k: Variant in (ch as Dictionary):
			if String(k).is_valid_int():
				p.notoriety_choices[int(String(k))] = StringName(String((ch as Dictionary)[k]))
	p.held_skill_sets = []
	var held: Variant = d.get("held_skill_sets", [])
	if held is Array:
		for e: Variant in (held as Array):
			p.held_skill_sets.append(_skills_from(e))
	p.music_choice = StringName(String(d.get("music_choice", "")))
	p.career = _career_from(d.get("career", {}))
	p.freshness = _freshness_from(d.get("freshness", {}))
	p.crew_loadouts = _crew_from(d.get("crew_loadouts", []))
	p.weapon_finishes = {}
	var wf: Variant = d.get("weapon_finishes", {})
	if wf is Dictionary:
		for k: Variant in (wf as Dictionary):
			p.weapon_finishes[StringName(String(k))] = StringName(String((wf as Dictionary)[k]))
	p.stats = {}
	var st: Variant = d.get("stats", {})
	if st is Dictionary:
		for k: Variant in (st as Dictionary):
			p.stats[String(k)] = int((st as Dictionary)[k])
	var se: Variant = d.get("settings", {})
	p.settings = (se as Dictionary).duplicate(true) if se is Dictionary else {}
	return p


## PO-19: ProfileSchema.CREW_SLOTS entries with StringName ids (missing / malformed entries read as empty).
static func _crew_from(v: Variant) -> Array[Dictionary]:
	var src: Array = v as Array if v is Array else []
	var out: Array[Dictionary] = []
	for i: int in range(ProfileSchema.CREW_SLOTS):
		var e: Dictionary = src[i] as Dictionary if i < src.size() and src[i] is Dictionary else {}
		out.append({"weapon": StringName(String(e.get("weapon", ""))), "mods": _to_names(e.get("mods", [])),
			"armor": StringName(String(e.get("armor", ""))), "mask": StringName(String(e.get("mask", ""))),
			"outfit": StringName(String(e.get("outfit", ""))), "ability": StringName(String(e.get("ability", ""))),
			"boost": StringName(String(e.get("boost", "")))})
	return out


static func _crew_to(entries: Array[Dictionary]) -> Array:
	var out: Array = []
	for e: Dictionary in _crew_from(entries):
		out.append({"weapon": String(e["weapon"]), "mods": _to_strings(e["mods"] as Array[StringName]),
			"armor": String(e["armor"]), "mask": String(e["mask"]), "outfit": String(e["outfit"]),
			"ability": String(e["ability"]), "boost": String(e["boost"])})
	return out


## D-139: the saved freshness dict with ids as Strings and counters as ints (JSON floats come back as float).
static func _freshness_from(v: Variant) -> Dictionary:
	var out: Dictionary = HeistFreshness.empty()
	if not v is Dictionary:
		return out
	var d: Dictionary = v as Dictionary
	for id: Variant in d.get("recent", []) as Array if d.get("recent") is Array else []:
		(out["recent"] as Array).append(String(id))
	out["runs"] = int(d.get("runs", 0)) if (d.get("runs") is int or d.get("runs") is float) else 0
	if d.get("last_run") is Dictionary:
		for k: Variant in d["last_run"] as Dictionary:
			(out["last_run"] as Dictionary)[String(k)] = int((d["last_run"] as Dictionary)[k])
	for id2: Variant in d.get("completed", []) as Array if d.get("completed") is Array else []:
		(out["completed"] as Array).append(String(id2))
	return out


func to_dict() -> Dictionary:
	var st: Dictionary = {}
	for k: Variant in stats:
		st[String(k)] = int(stats[k])
	var pc: Dictionary = {}
	for k: Variant in perk_cards:
		pc[String(k)] = int(perk_cards[k])
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
		"owned_mask_parts": _to_strings(owned_mask_parts),
		"custom_masks": _custom_masks_to_list(),
		"loadout": loadout_to_dict(loadout),
		"skill_sets": _skill_sets_to_list(),
		"active_skill_set": active_skill_set,
		"perk_cards": pc,
		"unlocks": _to_strings(unlocks),
		"achievements": _achievements_to(achievements),
		"pro_job_locks": _locks_to(pro_job_locks),
		"notoriety": notoriety,
		"notoriety_xp": notoriety_xp,
		"notoriety_choices": _choices_to(notoriety_choices),
		"held_skill_sets": _held_to_list(),
		"music_choice": String(music_choice),
		"career": career.duplicate(true),
		"freshness": freshness.duplicate(true),
		"crew_loadouts": _crew_to(crew_loadouts),
		"weapon_finishes": _finishes_to(weapon_finishes),
		"stats": st,
		"settings": settings.duplicate(true),
	}


## Make skill set `index` active: the current loadout.skills is stored in its slot first, then the
## chosen set becomes loadout.skills. Grows skill_sets as needed. Negative index is ignored.
func switch_skill_set(index: int) -> void:
	if index < 0:
		return
	while skill_sets.size() <= maxi(index, active_skill_set):
		skill_sets.append({})
	skill_sets[active_skill_set] = loadout.skills.duplicate()
	active_skill_set = index
	loadout.skills = skill_sets[index].duplicate()


## Skill set `index` as stored (the active one is read from loadout.skills). Empty when unknown.
func skill_set(index: int) -> Dictionary:
	if index == active_skill_set:
		return loadout.skills
	if index < 0 or index >= skill_sets.size():
		return {}
	return skill_sets[index]


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
	out["skills"] = _skills_to(l.skills)
	out["perk_choices"] = choices_to(l.perk_choices)
	return out


static func loadout_from_dict(d: Dictionary) -> Loadout:
	var l: Loadout = Loadout.new()
	for f: String in LOADOUT_ID_FIELDS:
		l.set(f, StringName(String(d.get(f, ""))))
	for f: String in LOADOUT_LIST_FIELDS:
		l.set(f, _to_names(d.get(f, [])))
	l.perk_deck_cards = int(d.get("perk_deck_cards", 0))
	l.skills = _skills_from(d.get("skills", {}))
	l.perk_choices = choices_from(d.get("perk_choices", {}))
	return l


## D-164: Loadout.perk_choices (int card index -> int option) as a JSON-safe {"<index>": option} map, and back.
static func choices_to(c: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in c:
		out[str(int(k))] = int(c[k])
	return out


static func choices_from(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (v is Dictionary):
		return out
	for k: Variant in v as Dictionary:
		var key: String = str(k)
		if key.is_valid_int():
			out[int(key)] = maxi(int((v as Dictionary)[k]), 0)
	return out


func _skill_sets_to_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(maxi(skill_sets.size(), active_skill_set + 1)):
		out.append(_skills_to(skill_set(i)))
	return out


func _custom_masks_to_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in custom_masks:
		out.append(_strings_dict(c))
	return out


## String -> String copy of a JSON object (custom mask compositions); non-dicts become {}.
static func _strings_dict(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for k: Variant in (v as Dictionary):
			out[String(k)] = String((v as Dictionary)[k])
	return out


static func _achievements_from(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for k: Variant in (v as Dictionary):
			var e: Variant = (v as Dictionary)[k]
			if e is Dictionary:
				out[StringName(String(k))] = {
					"progress": int((e as Dictionary).get("progress", 0)),
					"unlocked": bool((e as Dictionary).get("unlocked", false)),
				}
	return out


static func _achievements_to(a: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in a:
		var e: Dictionary = a[k] as Dictionary
		out[String(k)] = {"progress": int(e.get("progress", 0)), "unlocked": bool(e.get("unlocked", false))}
	return out


static func _choices_to(c: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in c:
		out[str(k)] = String(c[k])
	return out


func _held_to_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h: Dictionary in held_skill_sets:
		out.append(_skills_to(h))
	return out


## Career dict with int counters (JSON numbers parse as float); sections missing -> empty.
static func _career_from(v: Variant) -> Dictionary:
	var out: Dictionary = Career.empty()
	if not v is Dictionary:
		return out
	for sec: String in Career.SECTIONS:
		var m: Variant = (v as Dictionary).get(sec)
		if not m is Dictionary:
			continue
		var dst: Dictionary = out[sec] as Dictionary
		for k: Variant in (m as Dictionary):
			var e: Variant = (m as Dictionary)[k]
			if e is Dictionary:
				var inner: Dictionary = {}
				for ik: Variant in (e as Dictionary):
					inner[String(ik)] = int((e as Dictionary)[ik])
				dst[String(k)] = inner
			else:
				dst[String(k)] = int(e)
	return out


static func _finishes_to(f: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in f:
		out[String(k)] = String(f[k])
	return out


static func _locks_to(locks: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in locks:
		out[String(k)] = float(locks[k])
	return out


static func _skills_to(skills: Dictionary) -> Dictionary:
	var sk: Dictionary = {}
	for k: Variant in skills:
		sk[String(k)] = int(skills[k])
	return sk


static func _skills_from(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for k: Variant in (v as Dictionary):
			out[StringName(String(k))] = int((v as Dictionary)[k])
	return out


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
