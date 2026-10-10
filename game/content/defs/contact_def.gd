## A contact (contractor or handler) shown on the briefing screen and the Board (pd2_fidelity C1, C2).
## Owner: ENV B. Data: res://content/data/contacts/<name>.tres with id `contact.<name>`
## (HeistDef.contact refers to it, e.g. &"contact.vance").
##
## Portrait slot: ENV D/C fill `portrait_scene` (a Control or Node3D scene) or `portrait_texture`
## later. While both are empty the briefing draws an original procedural silhouette
## (ContactPortrait) from `silhouette` + `accent_color`. No third-party art.
class_name ContactDef
extends Resource

const DIR: String = "res://content/data/contacts"
const LOG_CHANNEL: StringName = &"content"

static var _cache: Dictionary = {}

@export var id: StringName = &""
## strings.csv key of the display name (e.g. `contact.odile_vance`).
@export var display_name_key: StringName = &""
## strings.csv key of the faction/role line (e.g. `contact.role.fence`).
@export var role_key: StringName = &""
## Final portrait art (ENV D/C). A Control root fills the slot; a Node3D root renders in a SubViewport.
@export var portrait_scene: PackedScene = null
## Alternative final portrait art (a still). Used when portrait_scene is null.
@export var portrait_texture: Texture2D = null
## Placeholder silhouette variant drawn by ContactPortrait: &"bun", &"cap", &"veiled", &"headset".
@export var silhouette: StringName = &"bun"
@export var accent_color: Color = Color(1.0, 0.8, 0.4)
## VoiceLineTable speaker id (lines.tres `speaker`), e.g. &"vance".
@export var voice_speaker: StringName = &""
## True for the handler on comms (Mercer); false for contractors who offer contracts.
@export var is_handler: bool = false


## The contact with `contact_id` (`contact.<name>`), or null (logs an error) when it does not exist.
static func find(contact_id: StringName) -> ContactDef:
	if _cache.has(contact_id):
		return _cache[contact_id] as ContactDef
	var path: String = path_for(contact_id)
	var c: ContactDef = null
	if path != "" and ResourceLoader.exists(path):
		c = load(path) as ContactDef
	if c == null or c.id != contact_id:
		Log.error(LOG_CHANNEL, "unknown contact '%s'" % contact_id)
		return null
	_cache[contact_id] = c
	return c


## res://content/data/contacts/<name>.tres for `contact.<name>` ("" for a malformed id).
static func path_for(contact_id: StringName) -> String:
	var s: String = String(contact_id)
	if not s.begins_with("contact.") or s.length() <= "contact.".length():
		return ""
	return "%s/%s.tres" % [DIR, s.trim_prefix("contact.")]


## Every contact in the data folder, sorted by id (ContentDB.sort_ids).
static func all() -> Array[ContactDef]:
	var ids: Array = []
	var by_id: Dictionary = {}
	if DirAccess.dir_exists_absolute(DIR):
		for entry: String in ResourceLoader.list_directory(DIR):
			if not entry.ends_with(".tres"):
				continue
			var c: ContactDef = load(DIR.path_join(entry)) as ContactDef
			if c != null and c.id != &"":
				ids.append(c.id)
				by_id[c.id] = c
	ContentDB.sort_ids(ids)
	var out: Array[ContactDef] = []
	for cid: Variant in ids:
		out.append(by_id[cid] as ContactDef)
	return out
