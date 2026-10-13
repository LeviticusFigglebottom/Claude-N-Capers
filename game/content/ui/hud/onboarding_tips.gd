## PO-4 lane 11 (lead ruling): which first-time onboarding cards the player has already seen. Stored in
## the profile's free-form `settings` dict under SETTINGS_KEY (an Array of tip ids), so the save shape
## and version do not change. Loaded lazily from SaveService (slot 0); `persist = false` keeps tests and
## captures off the player's save. Owner: ENV B.
class_name OnboardingTips
extends RefCounted

const SETTINGS_KEY: String = "onboarding_seen"
## Every tip, in the order a heist reaches them (OnboardingCard).
const ALL: Array[StringName] = [&"casing", &"stealth", &"loud", &"escape"]

static var persist: bool = true
static var profile_slot: int = 0
static var _seen: Dictionary = {}
static var _loaded: bool = false


static func is_seen(id: StringName) -> bool:
	_load()
	return _seen.has(String(id))


## Marks `id` seen and writes it to the profile (fresh load, so nothing else in the save is clobbered).
static func mark_seen(id: StringName) -> void:
	_load()
	if _seen.has(String(id)):
		return
	_seen[String(id)] = true
	if not _writes():
		return
	var p: PlayerProfile = SaveService.load_profile(profile_slot)
	p.settings[SETTINGS_KEY] = seen_ids()
	SaveService.save_profile(p, profile_slot)


static func seen_ids() -> Array:
	_load()
	var out: Array = []
	for id: StringName in ALL:
		if _seen.has(String(id)):
			out.append(String(id))
	return out


## Forget every tip (Options "show tips again"; tests). Writes the profile when persisting.
static func reset() -> void:
	_seen.clear()
	_loaded = true
	if not _writes():
		return
	var p: PlayerProfile = SaveService.load_profile(profile_slot)
	p.settings.erase(SETTINGS_KEY)
	SaveService.save_profile(p, profile_slot)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_seen.clear()
	if not _writes():
		return
	var v: Variant = SaveService.load_profile(profile_slot).settings.get(SETTINGS_KEY, [])
	if v is Array:
		for id: Variant in v as Array:
			_seen[String(id)] = true


## Persisting, and not inside the test runner (a HUD built by a test must never touch the real save).
static func _writes() -> bool:
	if not persist:
		return false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree == null or tree.current_scene == null or not tree.current_scene.scene_file_path.begins_with("res://tests/")
