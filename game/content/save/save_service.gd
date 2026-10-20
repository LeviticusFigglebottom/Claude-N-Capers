## Versioned JSON persistence for PlayerProfile. Owner: ENV B. Static API (architecture.md §11).
##
## Files: `<root_dir>/profile_<slot>.json` (+ `.bak` = previous good save, `.tmp` while writing).
## save_profile is atomic: write `.tmp`, move the current file to `.bak`, rename `.tmp` into place.
## load_profile: missing -> default profile; unreadable/corrupt -> `.bak`; else default + Log.error.
## A file whose version is newer than CURRENT_VERSION is refused (default returned, file untouched).
## Migrations: add `_migrate_<n>_to_<n+1>(d: Dictionary) -> Dictionary` and register it in
## migrate(); a dict without "version" is v0.
## Versions: 1 = first shipped shape; 2 = adds `banked_stealth_mult` (D-022 QB-13);
## 3 = adds `skill_sets` + `active_skill_set` (multiple skill sets) and `perk_cards` (per-deck progress);
## 4 = adds `owned_mask_parts` and `custom_masks` (mask customisation, B2-03; content/docs/masks.md);
## 5 = adds `unlocks`, `achievements` (B4-20) and `pro_job_locks` (persisted pro-job locks, QB-BRD1);
## 6 = adds `notoriety`, `notoriety_xp`, `notoriety_choices`, `held_skill_sets` (Notoriety ranks, B5-02)
## and `music_choice` (B5-03); 7 = adds `career` (lifetime career stats, B7-01) and `weapon_finishes`
## (weapon id -> finish id, reserved for B7-04); 8 = no new field: every profile owns the starter AR
## (STARTER_PRIMARY, new profiles since round 38) and an empty primary slot gets it equipped.
## Field reference: content/docs/save_format.md. Golden migration fixtures: tests/b/fixtures/save/.
## Load pipeline (profile_from_save): migrate -> ProfileSchema.sanitize (types; wrong type -> default +
## Log.warn) -> PlayerProfile.from_dict -> ProfileValidator.validate (unknown ids pruned, illegal skill
## sets reset, each with a Log.warn). A damaged field never crashes a load.
class_name SaveService
extends RefCounted

const CURRENT_VERSION: int = 10
const DEFAULT_ROOT_DIR: String = "user://profiles"
## v8: the starter primary granted to (and, into an empty primary slot, equipped on) older profiles.
const STARTER_PRIMARY: String = "weapon.corsair_ar"

## Tests point this at e.g. `user://test_profiles`.
static var root_dir: String = DEFAULT_ROOT_DIR


static func profile_path(slot: int = 0) -> String:
	return root_dir.path_join("profile_%d.json" % slot)


static func save_profile(p: PlayerProfile, slot: int = 0) -> Error:
	if p == null:
		return ERR_INVALID_PARAMETER
	var err: Error = DirAccess.make_dir_recursive_absolute(root_dir)
	if err != OK:
		Log.error(&"save", "cannot create %s (%s)" % [root_dir, error_string(err)])
		return err
	p.version = CURRENT_VERSION
	var path: String = profile_path(slot)
	var tmp: String = path + ".tmp"
	var bak: String = path + ".bak"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		err = FileAccess.get_open_error()
		Log.error(&"save", "cannot write %s (%s)" % [tmp, error_string(err)])
		return err
	f.store_string(JSON.stringify(p.to_dict(), "\t"))
	f.flush()
	err = f.get_error()
	f.close()
	if err != OK:
		Log.error(&"save", "write failed %s (%s)" % [tmp, error_string(err)])
		DirAccess.remove_absolute(tmp)
		return err
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		err = DirAccess.rename_absolute(path, bak)
		if err != OK:
			Log.error(&"save", "cannot rotate backup %s (%s)" % [bak, error_string(err)])
			return err
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		Log.error(&"save", "cannot finalize %s (%s)" % [path, error_string(err)])
	return err


static func load_profile(slot: int = 0) -> PlayerProfile:
	var path: String = profile_path(slot)
	var bak: String = path + ".bak"
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(bak):
		return PlayerProfile.new_default()
	var data: Variant = _read_dict(path)
	if data == null:
		Log.error(&"save", "profile %s missing or corrupt; trying backup" % path)
		data = _read_dict(bak)
		if data == null:
			Log.error(&"save", "backup %s unusable; using default profile" % bak)
			return PlayerProfile.new_default()
	var d: Dictionary = data as Dictionary
	if _version_of(d) > CURRENT_VERSION:
		Log.error(&"save", "profile %s has version %d > %d; refusing to load" % [path, _version_of(d), CURRENT_VERSION])
		return PlayerProfile.new_default()
	return profile_from_save(d)


## A save dict (any version <= CURRENT_VERSION) -> a valid current profile (see the header's load
## pipeline). Future versions are the caller's to refuse (load_profile does).
static func profile_from_save(d: Dictionary) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.from_dict(ProfileSchema.sanitize(migrate(d)))
	ProfileValidator.validate(p)
	return p


static func delete_profile(slot: int = 0) -> void:
	var path: String = profile_path(slot)
	for f: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


## Runs every migration from the dict's version up to CURRENT_VERSION, in order.
## Returns a new dict; versions > CURRENT_VERSION are returned unchanged (callers refuse them).
static func migrate(data: Dictionary) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var v: int = _version_of(d)
	if v > CURRENT_VERSION:
		Log.error(&"save", "cannot migrate version %d (current %d)" % [v, CURRENT_VERSION])
		return d
	while v < CURRENT_VERSION:
		match v:
			0:
				d = _migrate_0_to_1(d)
			1:
				d = _migrate_1_to_2(d)
			2:
				d = _migrate_2_to_3(d)
			3:
				d = _migrate_3_to_4(d)
			4:
				d = _migrate_4_to_5(d)
			5:
				d = _migrate_5_to_6(d)
			6:
				d = _migrate_6_to_7(d)
			7:
				d = _migrate_7_to_8(d)
			8:
				d = _migrate_8_to_9(d)
			9:
				d = _migrate_9_to_10(d)
			_:
				Log.error(&"save", "no migration from version %d" % v)
				return d
		v += 1
		d["version"] = v
	return d


## Adds a heist payout (PayoutCalculator.compute() output: "stash", "spending", "xp_total",
## "stealth_bonus_consumed", "stealth_bonus_banked"). Stealth bank (D-022 QB-13): a consumed bank
## resets to 1.0, then a newly banked bonus (> 1.0) replaces it. Pass the profile's
## banked_stealth_mult to PayoutCalculator.compute() for the same payday.
## `level_for_xp` (e.g. XpCurve.level_for_xp) recomputes level; without it only xp is stored. A level
## gain re-buys skills held by a Notoriety rank-up (NotorietySkills.restore).
static func apply_heist_payout(p: PlayerProfile, payout: Dictionary, level_for_xp: Callable = Callable()) -> void:
	if p == null:
		return
	p.stash += int(payout.get("stash", 0))
	p.cash += int(payout.get("spending", 0))
	p.xp += int(payout.get("xp_total", 0))
	if bool(payout.get("stealth_bonus_consumed", false)):
		p.banked_stealth_mult = 1.0
	var banked: float = float(payout.get("stealth_bonus_banked", 1.0))
	if banked > 1.0:
		p.banked_stealth_mult = banked
	if level_for_xp.is_valid():
		var before: int = p.level
		p.level = int(level_for_xp.call(p.xp))
		if p.level > before:
			NotorietySkills.restore(p)


## v0 = pre-versioned profile. Fills fields missing in early dev saves; old "money" -> cash.
static func _migrate_0_to_1(d: Dictionary) -> Dictionary:
	if d.has("money") and not d.has("cash"):
		d["cash"] = d["money"]
	d.erase("money")
	for k: String in ["owned_weapons", "owned_mods", "owned_masks"]:
		if not d.get(k) is Array:
			d[k] = []
	for k: String in ["stats", "settings", "loadout"]:
		if not d.get(k) is Dictionary:
			d[k] = {}
	return d


## v1 -> v2: stealth bonus bank (D-022 QB-13); nothing banked.
static func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	if not (d.get("banked_stealth_mult") is float or d.get("banked_stealth_mult") is int):
		d["banked_stealth_mult"] = 1.0
	return d


## v2 -> v3: the loadout's skills become skill set 0 (active); the equipped deck's card count becomes
## that deck's progress, so nothing already unlocked is lost.
static func _migrate_2_to_3(d: Dictionary) -> Dictionary:
	var ld: Dictionary = d.get("loadout", {}) as Dictionary if d.get("loadout") is Dictionary else {}
	if not d.get("skill_sets") is Array:
		var sk: Variant = ld.get("skills", {})
		d["skill_sets"] = [(sk as Dictionary).duplicate() if sk is Dictionary else {}]
		d["active_skill_set"] = 0
	if not d.get("perk_cards") is Dictionary:
		var pc: Dictionary = {}
		var deck: String = String(ld.get("perk_deck", ""))
		if deck != "" and int(ld.get("perk_deck_cards", 0)) > 0:
			pc[deck] = int(ld.get("perk_deck_cards", 0))
		d["perk_cards"] = pc
	return d


## v3 -> v4: mask customisation; no extra parts owned, every custom slot empty. A preset
## loadout.mask stays valid.
static func _migrate_3_to_4(d: Dictionary) -> Dictionary:
	if not d.get("owned_mask_parts") is Array:
		d["owned_mask_parts"] = []
	if not d.get("custom_masks") is Array:
		d["custom_masks"] = []
	return d


## v4 -> v5: nothing unlocked by achievements yet, no achievement progress, no pro-job locks (they
## were session-only before). Everything else is unchanged.
static func _migrate_4_to_5(d: Dictionary) -> Dictionary:
	if not d.get("unlocks") is Array:
		d["unlocks"] = []
	if not d.get("achievements") is Dictionary:
		d["achievements"] = {}
	if not d.get("pro_job_locks") is Dictionary:
		d["pro_job_locks"] = {}
	return d


## v5 -> v6: Notoriety rank 0 (nothing retired, no choices, no held skill builds) and the heist's default
## music. Everything else is unchanged.
static func _migrate_5_to_6(d: Dictionary) -> Dictionary:
	for k: String in ["notoriety", "notoriety_xp"]:
		if not (d.get(k) is int or d.get(k) is float):
			d[k] = 0
	if not d.get("notoriety_choices") is Dictionary:
		d["notoriety_choices"] = {}
	if not d.get("held_skill_sets") is Array:
		d["held_skill_sets"] = []
	if not d.get("music_choice") is String:
		d["music_choice"] = ""
	return d


## v6 -> v7: an empty career (nothing counted before v7) and no weapon finishes (every weapon on its
## default finish). Everything else is unchanged.
## v8 (lead): saves from before round 38 own no primary ("None yet" in the loadout). Grant the starter AR
## and equip it when the primary slot is empty; an owned / equipped primary is left as it is.
static func _migrate_7_to_8(d: Dictionary) -> Dictionary:
	var owned: Array = d.get("owned_weapons", []) as Array if d.get("owned_weapons") is Array else []
	if not owned.has(STARTER_PRIMARY):
		owned.append(STARTER_PRIMARY)
	d["owned_weapons"] = owned
	if d.get("loadout") is Dictionary:
		var l: Dictionary = d["loadout"] as Dictionary
		if String(l.get("primary", "")) == "":
			l["primary"] = STARTER_PRIMARY
			l["primary_mods"] = []
	return d


## v8 -> v9 (D-139 heist freshness): an empty run memory; every heist the career shows a win for is marked completed,
## with its last run at 0, so its rotation bonus ramps up from here (no instant +10 %).
static func _migrate_8_to_9(d: Dictionary) -> Dictionary:
	if d.get("freshness") is Dictionary:
		return d
	var f: Dictionary = {"recent": [], "runs": 0, "last_run": {}, "completed": []}
	var heists: Variant = (d.get("career", {}) as Dictionary).get("heists", {}) if d.get("career") is Dictionary else {}
	if heists is Dictionary:
		var ids: Array = (heists as Dictionary).keys()
		ids.sort()
		for id: Variant in ids:
			var row: Variant = (heists as Dictionary)[id]
			if row is Dictionary and int((row as Dictionary).get(Career.WON, 0)) > 0:
				(f["completed"] as Array).append(String(id))
				(f["last_run"] as Dictionary)[String(id)] = 0
	d["freshness"] = f
	return d


## v10 (D-145.4 / PO-19): the crew bots' loadouts, every bot slot empty (the bots' defaults). A save that already
## has `crew_loadouts` keeps it.
static func _migrate_9_to_10(d: Dictionary) -> Dictionary:
	if not d.get("crew_loadouts") is Array:
		d["crew_loadouts"] = ProfileSchema.empty_crew_loadouts()
	return d


static func _migrate_6_to_7(d: Dictionary) -> Dictionary:
	if not d.get("career") is Dictionary:
		d["career"] = Career.empty()
	if not d.get("weapon_finishes") is Dictionary:
		d["weapon_finishes"] = {}
	return d


## A non-numeric version reads as 0 (the oldest shape; every migration is additive).
static func _version_of(d: Dictionary) -> int:
	var v: Variant = d.get("version", 0)
	return int(v) if (v is int or v is float) else 0


static func _read_dict(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		return null
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	return json.data
