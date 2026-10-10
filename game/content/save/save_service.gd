## Versioned JSON persistence for PlayerProfile. Owner: ENV B. Static API (architecture.md §11).
##
## Files: `<root_dir>/profile_<slot>.json` (+ `.bak` = previous good save, `.tmp` while writing).
## save_profile is atomic: write `.tmp`, move the current file to `.bak`, rename `.tmp` into place.
## load_profile: missing -> default profile; unreadable/corrupt -> `.bak`; else default + Log.error.
## A file whose version is newer than CURRENT_VERSION is refused (default returned, file untouched).
## Migrations: add `_migrate_<n>_to_<n+1>(d: Dictionary) -> Dictionary` and register it in
## migrate(); a dict without "version" is v0.
## Versions: 1 = first shipped shape; 2 = adds `banked_stealth_mult` (D-022 QB-13);
## 3 = adds `skill_sets` + `active_skill_set` (multiple skill sets) and `perk_cards` (per-deck progress).
class_name SaveService
extends RefCounted

const CURRENT_VERSION: int = 3
const DEFAULT_ROOT_DIR: String = "user://profiles"

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
	return PlayerProfile.from_dict(migrate(d))


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
## `level_for_xp` (e.g. XpCurve.level_for_xp) recomputes level; without it only xp is stored.
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
		p.level = int(level_for_xp.call(p.xp))


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


static func _version_of(d: Dictionary) -> int:
	return int(d.get("version", 0))


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
