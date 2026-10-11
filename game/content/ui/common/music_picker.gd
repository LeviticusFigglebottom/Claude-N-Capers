## "Music" option row (B5-03, D-062). Owner: ENV B. Used by the pre-planning screen (solo / host) and
## the lobby (host picks, clients see the host's pick read-only).
## Items: "Heist default" (&"", HeistDef.music_track) + every MusicCatalog track; locked tracks stay
## listed but disabled, with the Notoriety rank that unlocks them when known. Picking writes
## PlayerProfile.music_choice and (save_on_change) saves the profile to profile_slot.
## API: setup(profile, heist_id) before or after entering the tree; choose(id) -> bool; selected_id();
## set_read_only(track_id) shows a fixed pick (no list); set_editable() goes back to the list.
class_name MusicPicker
extends HBoxContainer

signal music_changed(track_id: StringName)

@export var profile_slot: int = 0
@export var save_on_change: bool = true

var profile: PlayerProfile = null
## Heist the pick is for (names the "Heist default" item); &"" = generic.
var heist_id: StringName = &""
## False while showing someone else's pick (set_read_only).
var editable: bool = true
## The pick shown while read-only.
var read_only_id: StringName = &""
var title_label: Label
var option: OptionButton
## Read-only value (set_read_only).
var value_label: Label
## Track id per option index (index 0 = &"", the heist default).
var item_ids: Array[StringName] = []


func setup(p: PlayerProfile, p_heist_id: StringName = &"") -> void:
	profile = p
	heist_id = p_heist_id
	refresh()


func _init() -> void:
	add_theme_constant_override(&"separation", 16)
	title_label = UiBuild.label(&"ui.music.title")
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title_label)
	option = UiBuild.option_button()
	option.name = "MusicOption"
	option.item_selected.connect(_on_item_selected)
	add_child(option)
	value_label = UiBuild.label(&"", UiBuild.DIM)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.visible = false
	add_child(value_label)


func _ready() -> void:
	refresh()


## Rebuilds the item list from MusicCatalog and selects the profile's (resolved) pick.
func refresh() -> void:
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	option.clear()
	item_ids.clear()
	option.add_item(default_text(heist_id))
	item_ids.append(&"")
	for t: Dictionary in MusicCatalog.tracks():
		var id: StringName = t["id"]
		var unlocked: bool = MusicCatalog.is_unlocked(profile, id)
		option.add_item(entry_text(id, unlocked))
		option.set_item_disabled(item_ids.size(), not unlocked)
		item_ids.append(id)
	option.select(maxi(item_ids.find(MusicCatalog.resolve_choice(profile)), 0))
	option.visible = editable
	value_label.visible = not editable
	value_label.text = default_text(heist_id) if read_only_id == &"" else UiText.t(MusicCatalog.display_key(read_only_id))


## Picks `track_id` (&"" = heist default): writes profile.music_choice, saves (save_on_change) and emits
## music_changed. False (nothing changes) for an unknown or locked track, or while read-only.
func choose(track_id: StringName) -> bool:
	if not editable or profile == null:
		return false
	if track_id != &"" and not MusicCatalog.is_unlocked(profile, track_id):
		return false
	profile.music_choice = track_id
	if save_on_change:
		SaveService.save_profile(profile, profile_slot)
	option.select(maxi(item_ids.find(track_id), 0))
	music_changed.emit(track_id)
	return true


## The pick the list shows (&"" = heist default).
func selected_id() -> StringName:
	if option.selected < 0 or option.selected >= item_ids.size():
		return &""
	return item_ids[option.selected]


## Shows `track_id` (another player's pick, e.g. the host's) as text instead of the list.
func set_read_only(track_id: StringName) -> void:
	editable = false
	read_only_id = track_id
	refresh()


func set_editable() -> void:
	editable = true
	refresh()


## "Heist default", naming the heist's track when the catalog knows it.
static func default_text(p_heist_id: StringName) -> String:
	var def_id: StringName = MusicCatalog.default_for(p_heist_id) if p_heist_id != &"" else &""
	if def_id == &"":
		return UiText.t(MusicCatalog.DEFAULT_KEY)
	return UiText.t(&"ui.music.heist_default_named", {"name": UiText.t(MusicCatalog.display_key(def_id))})


## A track's list text: its name, or "name (locked: Notoriety VII)" when locked.
static func entry_text(track_id: StringName, unlocked: bool) -> String:
	var n: String = UiText.t(MusicCatalog.display_key(track_id))
	if unlocked:
		return n
	var rank: int = MusicCatalog.unlock_rank(track_id)
	if rank <= 0:
		return UiText.t(&"ui.music.locked", {"name": n})
	return UiText.t(&"ui.music.locked_rank", {"name": n, "rank": Notoriety.roman(rank)})


func _on_item_selected(index: int) -> void:
	if index >= 0 and index < item_ids.size() and not choose(item_ids[index]):
		option.select(maxi(item_ids.find(MusicCatalog.resolve_choice(profile)), 0))
