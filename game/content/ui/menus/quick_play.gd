## Quick Play / Continue (lead: repeated play in 1-2 clicks). MenuFlow.launch() remembers the last
## regular job (not a pro / Board contract) as {heist, difficulty} in the profile's free-form `settings`
## (SETTINGS_KEY; the save shape and version do not change); the main menu and the hub offer "Continue"
## while that job is still offered (HeistCatalog.ids()) at an unlocked difficulty, and relaunch it with
## the profile's current loadout. Owner: ENV B.
class_name QuickPlay
extends RefCounted

const SETTINGS_KEY: String = "last_job"


## Stores `heist_id` / `difficulty` as the profile's last job (fresh load, so nothing else is clobbered).
static func remember(profile_slot: int, heist_id: StringName, difficulty: int) -> void:
	var p: PlayerProfile = SaveService.load_profile(profile_slot)
	p.settings[SETTINGS_KEY] = {"heist": String(heist_id), "difficulty": difficulty}
	SaveService.save_profile(p, profile_slot)


## The job Continue would launch: {heist_id: StringName, difficulty: int}, or {} when there is none or
## it is no longer playable.
static func last(p: PlayerProfile) -> Dictionary:
	if p == null or not p.settings.get(SETTINGS_KEY) is Dictionary:
		return {}
	var d: Dictionary = p.settings[SETTINGS_KEY] as Dictionary
	var id: StringName = StringName(String(d.get("heist", "")))
	var diff: int = int(d.get("difficulty", 0))
	if id == &"" or not HeistCatalog.ids().has(id) or not HeistCatalog.is_difficulty_unlocked(diff):
		return {}
	return {"heist_id": id, "difficulty": diff}


## Button text: "Continue · Golden Hour · Routine".
static func label(job: Dictionary) -> String:
	return UiText.t(&"ui.menu.continue_job", {
		"heist": UiText.t(StringName("heist.%s.name" % job["heist_id"])),
		"difficulty": UiText.t(UiText.difficulty_key(int(job["difficulty"])))})
