## PO-4 (lead note 3): the item grid an ItemSlot opens. A scrim over the screen with the slot caption,
## a grid of item tiles (name, EQUIPPED tag on the current one, locked tiles muted with their reason),
## focus on the equipped tile. Focus / hover emits `previewed(index)` (the loadout previews stat
## diffs); A / Enter / click emits `picked(index)` and closes; Esc / B closes without a change.
## Owner: ENV B.
class_name ItemPicker
extends Control

signal picked(index: int)
signal previewed(index: int)
signal closed()

const COLUMNS: int = 3
const TILE_SIZE: Vector2 = Vector2(360, 92)
## The sheet covers this fraction of the screen width from the left.
const SHEET_WIDTH_FRAC: float = 0.665

## Tile Button per item index (tests).
var tiles: Array[Button] = []
var _slot: ItemSlot = null


func setup(slot: ItemSlot) -> void:
	_slot = slot


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# A solid sheet over the left two thirds; the screen's right column (stats) stays visible so the
	# focused tile's preview reads beside it.
	var sheet: PanelContainer = PanelContainer.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.anchor_right = SHEET_WIDTH_FRAC
	sheet.anchor_bottom = 1.0
	sheet.offset_left = UiTokens.MARGIN - UiTokens.S3
	# Lane 2 audit: the sheet started inside the screen title ("Lo..dout" peeked over it); it starts where
	# the screen's content does, under the header.
	sheet.offset_top = UiTokens.MARGIN + UiTokens.S7 + UiTokens.S6
	sheet.offset_bottom = -(UiTokens.MARGIN + UiTokens.S6)
	var sb: StyleBoxFlat = UiThemeFactory.box(UiTokens.INK_1, UiTokens.LINE_STRONG, 1, UiTokens.CUT,
			Vector2(UiTokens.S4, UiTokens.S4))
	sheet.add_theme_stylebox_override(&"panel", sb)
	add_child(sheet)
	var col: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	sheet.add_child(col)
	var title: Label = UiBuild.caption(_slot.caption_key if _slot != null else &"")
	title.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	col.add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override(&"h_separation", UiTokens.S3)
	grid.add_theme_constant_override(&"v_separation", UiTokens.S3)
	scroll.add_child(grid)
	var focus_tile: Button = null
	for i: int in range(_slot.item_count if _slot != null else 0):
		var t: Button = _tile(i)
		grid.add_child(t)
		tiles.append(t)
		if not t.disabled and (i == _slot.selected or focus_tile == null):
			focus_tile = t
	_link_grid()
	if focus_tile != null:
		focus_tile.grab_focus.call_deferred()


func _tile(i: int) -> Button:
	var b: Button = Button.new()
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.theme_type_variation = &"StationButton"
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = TILE_SIZE
	b.clip_contents = true
	var row: HBoxContainer = UiBuild.hbox(UiTokens.S3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = UiTokens.S3
	row.offset_right = -UiTokens.S3
	b.add_child(row)
	var accent: Color = _slot.get_item_accent(i)
	if accent.a > 0.0:
		var strip: ColorRect = ColorRect.new()
		strip.name = "Accent"
		strip.color = accent
		strip.custom_minimum_size = Vector2(4, 56)
		strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(strip)
	var tex: Texture2D = _slot.get_item_icon(i)
	if tex != null:
		# Lead queue: an item's own picture (heister portrait) instead of the slot glyph.
		var pic: TextureRect = TextureRect.new()
		pic.name = "Picture"
		pic.texture = tex
		pic.custom_minimum_size = Vector2(56, 56)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pic)
	else:
		var icon: HubStationIcon = HubStationIcon.new()
		icon.kind = _slot.get_item_glyph(i)
		icon.color = UiTokens.PAPER_DIM
		icon.tile_color = UiTokens.INK_0
		icon.custom_minimum_size = Vector2(56, 56)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var name_label: Label = UiBuild.label(&"")
	# D-126: a lock suffix ("Marshal .357\n(level 10)") goes on its own line instead of being cut off.
	var parts: PackedStringArray = _slot.get_item_text(i).split(" (", false, 1)
	name_label.text = parts[0]
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_label)
	if parts.size() > 1:
		var lock: Label = UiBuild.caption()
		lock.name = "Lock"
		lock.text = "(" + parts[1]
		lock.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lock.add_theme_color_override(&"font_color", UiTokens.PAPER_MUTE)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(lock)
	if i == _slot.selected:
		var tag: Label = UiBuild.caption(&"ui.loadout.equipped")
		tag.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tag)
	if _slot.is_item_disabled(i):
		b.disabled = true
		# LEAD r229 reach pass: a locked tile still takes d-pad focus (the grid neighbours point at it, and the pad
		# previews its stats like the mouse does); being disabled, it cannot be picked.
		b.focus_mode = Control.FOCUS_ALL
		name_label.add_theme_color_override(&"font_color", UiTokens.PAPER_MUTE)
	b.pressed.connect(_on_tile.bind(i))
	b.focus_entered.connect(previewed.emit.bind(i))
	b.mouse_entered.connect(previewed.emit.bind(i))
	return b


## Arrow / d-pad neighbours that follow the grid (wrap off). D-115: the picker is modal, so focus never
## leaves the grid for the screen under the scrim: an edge points at the tile itself, down from a row
## above a short last row lands on the last tile, and Tab / Shift+Tab cycle the tiles (locked ones too).
func _link_grid() -> void:
	var n: int = tiles.size()
	var last_row: int = floori((n - 1) / float(COLUMNS))
	for i: int in range(n):
		var t: Button = tiles[i]
		var col: int = i % COLUMNS
		t.focus_neighbor_left = t.get_path_to(tiles[i - 1] if col > 0 else t)
		t.focus_neighbor_right = t.get_path_to(tiles[i + 1] if col < COLUMNS - 1 and i + 1 < n else t)
		t.focus_neighbor_top = t.get_path_to(tiles[i - COLUMNS] if i >= COLUMNS else t)
		var below: Button = t
		if i + COLUMNS < n:
			below = tiles[i + COLUMNS]
		elif floori(i / float(COLUMNS)) < last_row:
			below = tiles[n - 1]
		t.focus_neighbor_bottom = t.get_path_to(below)
	# Tab / Shift+Tab cycle every tile: locked ones take focus too (they preview), so the cycle must hold them or
	# Tab from a locked tile would leave the modal picker.
	for k: int in range(n):
		var t: Button = tiles[k]
		t.focus_next = t.get_path_to(tiles[(k + 1) % n])
		t.focus_previous = t.get_path_to(tiles[(k - 1 + n) % n])


func _on_tile(i: int) -> void:
	picked.emit(i)
	close()


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
