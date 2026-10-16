## PO-4 (lead note 3): a loadout slot card. Looks like a card (slot caption over the equipped item's
## name, a category glyph on the left); pressing it opens an ItemPicker grid instead of a dropdown.
## Speaks the OptionButton subset LoadoutScreen and its tests use (add_item, clear, select, selected,
## item_count, get/set_item_text / _metadata / _disabled / _icon, item_selected), so the screen's
## data flow is unchanged. select() does not emit item_selected (like OptionButton); a pick in the
## grid does. Owner: ENV B.
class_name ItemSlot
extends Button

signal item_selected(index: int)
## Focus / hover moved to `index` in the open picker (stat preview); -1 when the picker closed.
signal item_previewed(index: int)

## Slot caption (strings key) shown on the card and as the picker title.
var caption_key: StringName = &""
## Glyph kind drawn on the card (HubStationIcon kinds: armory, mask, range, crew ...).
var glyph: StringName = &"armory"
var selected: int = -1
var item_count: int:
	get:
		return _items.size()
var picker: ItemPicker = null
var _items: Array[Dictionary] = []
var _caption: Label
var _value: Label
var _icon: HubStationIcon


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	focus_mode = Control.FOCUS_ALL
	theme_type_variation = &"StationButton"
	custom_minimum_size = Vector2(0, 74)
	clip_contents = true
	pressed.connect(open_picker)


func _ready() -> void:
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UiTokens.S3
	row.offset_right = -UiTokens.S3
	add_child(row)
	_icon = HubStationIcon.new()
	_icon.kind = glyph
	_icon.color = UiTokens.PAPER_DIM
	_icon.tile_color = UiTokens.INK_0
	_icon.custom_minimum_size = Vector2(52, 52)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	var v: VBoxContainer = UiBuild.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	_caption = UiBuild.caption(caption_key)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_caption)
	_value = UiBuild.label(&"")
	_value.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
	_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_value)
	_sync()


# --- OptionButton-compatible API ------------------------------------------------------------------

func add_item(label: String, _id: int = -1) -> void:
	_items.append({"text": label, "meta": null, "disabled": false, "icon": null, "glyph": &""})
	if selected < 0:
		selected = 0
	_sync()


func clear() -> void:
	_items.clear()
	selected = -1
	_sync()


func select(index: int) -> void:
	selected = clampi(index, -1, _items.size() - 1)
	_sync()


func get_item_text(i: int) -> String:
	return String(_items[i]["text"])


func set_item_text(i: int, label: String) -> void:
	_items[i]["text"] = label
	_sync()


func get_item_metadata(i: int) -> Variant:
	return _items[i]["meta"]


func set_item_metadata(i: int, v: Variant) -> void:
	_items[i]["meta"] = v


func is_item_disabled(i: int) -> bool:
	return bool(_items[i]["disabled"])


func set_item_disabled(i: int, on: bool) -> void:
	_items[i]["disabled"] = on


## D-126: an item's own category glyph (HubStationIcon kind) for its picker tile; &"" = the slot's `glyph`.
func get_item_glyph(i: int) -> StringName:
	var g: StringName = StringName(_items[i].get("glyph", &""))
	return g if g != &"" else glyph


func set_item_glyph(i: int, kind: StringName) -> void:
	_items[i]["glyph"] = kind
	_sync()


func get_item_icon(i: int) -> Texture2D:
	return _items[i]["icon"] as Texture2D


func set_item_icon(i: int, tex: Texture2D) -> void:
	_items[i]["icon"] = tex


## Lead queue (heister picker): an accent strip on this item's picker tile (alpha 0 = none).
func get_item_accent(i: int) -> Color:
	return _items[i].get("accent", Color(0, 0, 0, 0)) as Color


func set_item_accent(i: int, c: Color) -> void:
	_items[i]["accent"] = c


# --- Picker -----------------------------------------------------------------------------------------

## Opens the item grid over the screen (the nearest UiScreen, else the viewport root).
func open_picker() -> ItemPicker:
	if picker != null and is_instance_valid(picker):
		return picker
	var host: Node = self
	while host != null and not host is UiScreen:
		host = host.get_parent()
	if host == null:
		host = get_tree().root
	picker = ItemPicker.new()
	picker.setup(self)
	picker.picked.connect(_on_picked)
	picker.previewed.connect(item_previewed.emit)
	picker.closed.connect(_on_picker_closed)
	host.add_child(picker)
	return picker


## A pick from the grid (or a test): select + item_selected, like choosing in a dropdown.
func pick(index: int) -> void:
	if index < 0 or index >= _items.size() or is_item_disabled(index):
		return
	select(index)
	item_selected.emit(index)


func _on_picked(index: int) -> void:
	pick(index)


func _on_picker_closed() -> void:
	picker = null
	item_previewed.emit(-1)
	if is_inside_tree():
		grab_focus.call_deferred()


func _sync() -> void:
	if _value == null:
		return
	_value.text = get_item_text(selected) if selected >= 0 and selected < _items.size() else ""
	if _icon != null:
		var g: StringName = get_item_glyph(selected) if selected >= 0 and selected < _items.size() else glyph
		if _icon.kind != g:
			_icon.kind = g
			_icon.queue_redraw()
	text = ""  # the card draws its own labels
