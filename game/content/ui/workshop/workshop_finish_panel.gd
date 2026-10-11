## Finish picker of the weapon workshop (B7-04). Owner: ENV B.
## A list of every finish for the previewed weapon: Stock first, then WeaponFinishes.all() in order; owned
## ones show "owned" / "applied", locked ones are dimmed and show how they are earned (an achievement's name or
## a Notoriety rank, WeaponFinishes.source_of). Picking a row previews it live (`preview_changed`: the screen
## puts it on the turntable model); "Apply Finish" equips the previewed finish on this weapon
## (WeaponFinishes.equip) and emits `finish_equipped` (the screen saves). Locked finishes, unowned weapons and
## the already-applied finish cannot be equipped.
class_name WorkshopFinishPanel
extends VBoxContainer

signal preview_changed(finish_id: StringName)
signal finish_equipped(finish_id: StringName)

var profile: PlayerProfile
var weapon_id: StringName = &""
## The weapon is owned (finishes go on owned weapons only).
var weapon_owned: bool = false
## Finish shown on the turntable (&"" = stock).
var preview_id: StringName = &""
var list: ItemList
var status_label: Label
var equip_button: Button

## Row index -> finish id (&"" = stock).
var _rows: Array[StringName] = []


## Build the panel around `item_list` (styled by the screen).
func build(p: PlayerProfile, item_list: ItemList) -> void:
	profile = p
	add_theme_constant_override(&"separation", 8)
	add_child(UiBuild.label(&"ui.workshop.finish.title", UiBuild.DIM))
	list = item_list
	list.name = "FinishList"
	list.custom_minimum_size = Vector2(0, 200)
	list.item_selected.connect(_on_row)
	add_child(list)
	status_label = UiBuild.label(&"", UiBuild.DIM)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	equip_button = UiBuild.button(&"ui.workshop.finish.equip")
	equip_button.pressed.connect(equip_preview)
	add_child(equip_button)


## Show `id`'s finishes; the preview starts on its applied finish.
func set_weapon(id: StringName, owned: bool) -> void:
	weapon_id = id
	weapon_owned = owned
	preview_id = WeaponFinishes.equipped(profile, id)
	refresh()
	preview_changed.emit(preview_id)


## Preview finish `id` (&"" = stock) without equipping it. False for an unknown id.
func preview(id: StringName) -> bool:
	if id != &"" and not WeaponFinishes.is_known(id):
		return false
	preview_id = id
	refresh()
	preview_changed.emit(preview_id)
	return true


## Equip the previewed finish on the weapon. False when blocked (see block_key()).
func equip_preview() -> bool:
	if block_key() != &"":
		return false
	if not WeaponFinishes.equip(profile, weapon_id, preview_id):
		return false
	refresh()
	finish_equipped.emit(preview_id)
	return true


## Why equipping the preview is blocked (&"" = allowed).
func block_key() -> StringName:
	if not weapon_owned:
		return &"ui.workshop.finish.weapon_locked"
	if not WeaponFinishes.is_owned(profile, preview_id):
		return &"ui.workshop.finish.tag.locked"
	if WeaponFinishes.equipped(profile, weapon_id) == preview_id:
		return &"ui.workshop.finish.equipped"
	return &""


## Rebuild rows, status and the button from the profile.
func refresh() -> void:
	list.clear()
	_rows.clear()
	var applied: StringName = WeaponFinishes.equipped(profile, weapon_id)
	_add_row(&"", UiText.t(&"ui.workshop.finish.stock"), true)
	for d: FinishDef in WeaponFinishes.all():
		var owned: bool = WeaponFinishes.is_owned(profile, d.id)
		var tag: StringName = &"ui.workshop.finish.tag.owned"
		if d.id == applied:
			tag = &"ui.workshop.finish.tag.equipped"
		elif not owned:
			tag = &"ui.workshop.finish.tag.locked"
		var text: String = UiText.t(&"ui.workshop.finish.entry", {"name": UiText.t(UiText.item_key(d.id)), "status": UiText.t(tag)})
		_add_row(d.id, text, owned)
	var row: int = _rows.find(preview_id)
	if row >= 0:
		list.select(row)
	status_label.text = status_text(profile, weapon_id, preview_id)
	var block: StringName = block_key()
	equip_button.disabled = block != &""
	equip_button.text = UiText.t(&"ui.workshop.finish.equipped" if block == &"ui.workshop.finish.equipped"
			else &"ui.workshop.finish.equip")


## Status line for finish `id` on `weapon`: applied / owned / how a locked one is earned.
static func status_text(p: PlayerProfile, weapon: StringName, id: StringName) -> String:
	if id == &"":
		return UiText.t(&"ui.workshop.finish.status.stock")
	if WeaponFinishes.is_owned(p, id):
		var applied: bool = WeaponFinishes.equipped(p, weapon) == id
		return UiText.t(&"ui.workshop.finish.status.equipped" if applied else &"ui.workshop.finish.status.owned")
	return source_text(id)


## How a locked finish is earned, as text.
static func source_text(id: StringName) -> String:
	var src: Dictionary = WeaponFinishes.source_of(id)
	match StringName(src.get("kind", &"")):
		WeaponFinishes.SOURCE_ACHIEVEMENT:
			var a: AchievementDef = ContentDB.by_id(ContentDB.ACHIEVEMENTS, src["achievement"]) as AchievementDef
			var a_name: String = UiText.t(a.name_key) if a != null else String(src["achievement"])
			return UiText.t(&"ui.workshop.finish.source.achievement", {"name": a_name})
		WeaponFinishes.SOURCE_NOTORIETY:
			return UiText.t(&"ui.workshop.finish.source.notoriety", {"rank": Notoriety.roman(int(src["rank"]))})
	return UiText.t(&"ui.workshop.finish.source.unknown")


func _add_row(id: StringName, text: String, owned: bool) -> void:
	var row: int = list.add_item(text)
	list.set_item_metadata(row, id)
	list.set_item_tooltip(row, UiText.t(StringName("item.%s.desc" % id)) if id != &"" else text)
	if not owned:
		list.set_item_custom_fg_color(row, UiBuild.theme().get_color(&"font_color", &"DimLabel"))
	_rows.append(id)


func _on_row(row: int) -> void:
	if row >= 0 and row < _rows.size() and _rows[row] != preview_id:
		preview(_rows[row])
