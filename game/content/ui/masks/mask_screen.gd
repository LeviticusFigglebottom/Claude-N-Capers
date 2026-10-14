## Mask screen (B2-03, pd2_fidelity P8 / C9 mask bench). Owner: ENV B. Opened by MenuFlow from the
## loadout screen: `setup(profile)`, then listen to `back_requested` and `mask_changed(mask_id)`.
## Left: owned presets and the custom slots. Centre: 3D preview (MaskPreview). Right: base /
## material / colours / pattern pickers (locked parts listed but disabled), "Save into" slot picker,
## Save and Equip. Editing a mask makes an unsaved draft; Save stores it in a custom slot
## (`mask.custom.<n>`), Equip writes Loadout.mask. Every change is saved via SaveService.
class_name MaskScreen
extends UiScreen

## After Equip wrote Loadout.mask (preset id or `mask.custom.<n>`).
signal mask_changed(mask_id: StringName)

const LIST_WIDTH: float = 380.0
const EDITOR_WIDTH: float = 470.0
const SWATCH_SIZE: Vector2 = Vector2(64, 28)

@export var profile_slot: int = 0

var profile: PlayerProfile
var tweak: MaskTweak
## The saved mask being shown (preset or custom id); "" while an empty slot is selected.
var selected_id: StringName = &""
## Composition in the editor (MaskComposer.normalized shape).
var draft: Dictionary = {}
## The draft differs from the selected saved mask.
var dirty: bool = false
## Custom slot that Save writes to.
var target_slot: int = 0
## mask id (presets + every custom slot id) -> Button
var list_buttons: Dictionary = {}
## kind (MaskCatalog.BASE ...) -> OptionButton
var part_options: Dictionary = {}
var slot_option: OptionButton
var save_button: Button
var equip_button: Button
var back_button: Button
var name_label: Label
var equipped_label: Label
var status_label: Label
var swatch_a: ColorRect
var swatch_b: ColorRect
var preview: MaskPreview


## Optional: inject a profile before the screen enters the tree (tests, MenuFlow).
## Full focus order; focus_chain is its visible subset (hidden empty mask slots drop out, D-111).
var _all_focus: Array[Control] = []

func setup(p: PlayerProfile) -> void:
	profile = p


func build_ui() -> void:
	tweak = MaskCatalog.tweak()
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	draft = MaskComposer.normalized(tweak.default_composition)
	var root: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	UiBuild.screen_margin(self, root, UiTokens.S6)
	var top: HBoxContainer = UiBuild.hbox(UiTokens.S5)
	var titles: VBoxContainer = UiBuild.header(&"ui.masks.crumb", &"ui.masks.title")
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	equipped_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	var worn: VBoxContainer = UiBuild.field(&"ui.masks.equipped_caption", equipped_label)
	worn.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(worn)
	root.add_child(top)
	var body: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_build_list())
	body.add_child(_build_preview())
	body.add_child(_build_editor())
	# PO-4 footer: Back (ghost) left, a one-line how-to, Equip (the screen's primary) right.
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.pressed.connect(back_requested.emit)
	var hint: Label = UiBuild.label(&"ui.masks.hint", UiBuild.DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(UiBuild.footer(back_button, equip_button, [hint] as Array[Control]))
	UiNav.chain_horizontal([back_button, equip_button] as Array[Control], false)
	for id: StringName in _list_ids():
		focus_chain.append(list_buttons[id] as Control)
	focus_chain.append(preview)
	for k: String in MaskCatalog.KINDS:
		focus_chain.append(part_options[k] as Control)
	for c: Control in [slot_option, save_button, equip_button, back_button]:
		focus_chain.append(c)
	_all_focus = focus_chain.duplicate()
	var start: StringName = profile.loadout.mask
	if not MaskLocker.is_equippable(profile, start) or start == &"":
		var avail: Array[StringName] = MaskLocker.available_ids(profile)
		start = avail[0] if not avail.is_empty() else MaskCatalog.custom_id(0)
	select_mask(start)


## Show a saved mask (preset or filled custom slot) or an empty custom slot (keeps the draft and
## targets that slot). Returns false for ids that are not in the list.
func select_mask(mask_id: StringName) -> bool:
	if not list_buttons.has(mask_id):
		return false
	if MaskCatalog.is_custom_id(mask_id):
		target_slot = MaskCatalog.custom_index(mask_id)
		var comp: Dictionary = MaskLocker.custom_composition(profile, target_slot)
		if comp.is_empty():
			selected_id = &""
			dirty = true
		else:
			selected_id = mask_id
			draft = comp
			dirty = false
	else:
		selected_id = mask_id
		var from_preset: Dictionary = MaskComposer.composition_of(MaskCatalog.resolve(mask_id, profile))
		for k: String in MaskCatalog.KINDS:
			if String(from_preset[k]) != "":
				draft[k] = from_preset[k]
		dirty = false
		target_slot = _first_empty_slot()
	_sync_options()
	_refresh()
	return true


## Change one part of the draft (as if picked in the UI). False for unknown parts / wrong kind.
func set_part(kind: String, part_id: StringName) -> bool:
	if not MaskCatalog.KINDS.has(kind) or MaskCatalog.kind_of(part_id) != kind or not MaskCatalog.has_part(part_id):
		return false
	if String(draft.get(kind, "")) == String(part_id):
		return true
	draft[kind] = String(part_id)
	dirty = true
	_sync_options()
	_refresh()
	return true


## Save the draft into custom slot `index` (-1 = target_slot) and the profile. Returns the new mask
## id or "" when refused (locked parts, bad slot).
func save_to_slot(index: int = -1) -> StringName:
	var slot: int = target_slot if index < 0 else index
	var id: StringName = MaskLocker.save_custom(profile, slot, draft)
	if id == &"":
		_refresh()
		return &""
	target_slot = slot
	selected_id = id
	dirty = false
	SaveService.save_profile(profile, profile_slot)
	_refresh()
	_set_status(&"ui.masks.status.saved", {"name": MaskCatalog.display_name(id)})
	return id


## Equip the selected saved mask (writes Loadout.mask, saves, emits mask_changed).
func equip_selected() -> bool:
	if dirty or selected_id == &"" or not MaskLocker.equip(profile, selected_id):
		return false
	SaveService.save_profile(profile, profile_slot)
	_refresh()
	mask_changed.emit(selected_id)
	return true


## The MaskDef currently previewed (draft when dirty, else the selected saved mask).
func current_def() -> MaskDef:
	if not dirty and selected_id != &"":
		return MaskCatalog.resolve(selected_id, profile)
	if not MaskComposer.validate(draft).is_empty():
		return null
	return MaskComposer.compose(draft, MaskCatalog.custom_id(target_slot))


func _build_list() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	var list: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	list.add_child(UiBuild.caption(&"ui.masks.your_masks"))
	for id: StringName in _list_ids():
		var b: Button = UiBuild.button(&"ui.masks.none")
		b.custom_minimum_size = Vector2(LIST_WIDTH - 20.0, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true  # PO-4: the shown mask uses the pressed style (ink + cyan edge)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(_on_list_pressed.bind(id))
		list.add_child(b)
		list_buttons[id] = b
	return scroll


func _build_preview() -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	preview = MaskPreview.new()
	v.add_child(preview)
	var hint: Label = UiBuild.caption(&"ui.masks.preview_hint")
	hint.uppercase = false
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var p: PanelContainer = UiBuild.panel(v)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return p


func _build_editor() -> VBoxContainer:
	var v: VBoxContainer = UiBuild.vbox(UiTokens.S2)
	v.custom_minimum_size = Vector2(EDITOR_WIDTH, 0)
	name_label = UiBuild.label(&"", UiBuild.SUBHEADER)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_label)
	var keys: Dictionary = {
		MaskCatalog.BASE: &"ui.masks.base", MaskCatalog.MATERIAL: &"ui.masks.material",
		MaskCatalog.COLORS: &"ui.masks.colors", MaskCatalog.PATTERN: &"ui.masks.pattern",
	}
	for k: String in MaskCatalog.KINDS:
		v.add_child(UiBuild.caption(keys[k] as StringName))
		var o: OptionButton = UiBuild.option_button()
		o.custom_minimum_size = Vector2(EDITOR_WIDTH, 0)
		o.item_selected.connect(_on_part_selected.bind(k))
		v.add_child(o)
		part_options[k] = o
		if k == MaskCatalog.COLORS:
			v.add_child(_build_swatches())
	_fill_part_options()
	v.add_child(UiBuild.caption(&"ui.masks.save_slot"))
	slot_option = UiBuild.option_button()
	slot_option.custom_minimum_size = Vector2(EDITOR_WIDTH, 0)
	slot_option.item_selected.connect(_on_slot_selected)
	v.add_child(slot_option)
	save_button = UiBuild.button(&"ui.masks.save")
	save_button.custom_minimum_size = Vector2(EDITOR_WIDTH, 0)
	save_button.pressed.connect(save_to_slot.bind(-1))
	v.add_child(save_button)
	equip_button = UiBuild.button(&"ui.masks.equip")  # placed in the footer by build_ui
	equip_button.pressed.connect(equip_selected)
	status_label = UiBuild.label()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(EDITOR_WIDTH, 0)
	v.add_child(status_label)
	return v


func _build_swatches() -> HBoxContainer:
	var h: HBoxContainer = UiBuild.hbox(8)
	swatch_a = ColorRect.new()
	swatch_b = ColorRect.new()
	for r: ColorRect in [swatch_a, swatch_b]:
		r.custom_minimum_size = SWATCH_SIZE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(r)
	return h


func _fill_part_options() -> void:
	for k: String in MaskCatalog.KINDS:
		var o: OptionButton = part_options[k] as OptionButton
		o.clear()
		for p: MaskPartDef in MaskCatalog.parts(k):
			var nm: String = MaskCatalog.part_name(p.id)
			var owned: bool = MaskLocker.is_part_owned(profile, p.id)
			o.add_item(nm if owned else UiText.t(&"ui.masks.locked", {"name": nm}))
			var idx: int = o.item_count - 1
			o.set_item_metadata(idx, p.id)
			o.set_item_disabled(idx, not owned)


func _sync_options() -> void:
	for k: String in MaskCatalog.KINDS:
		var o: OptionButton = part_options[k] as OptionButton
		for i: int in range(o.item_count):
			if String(o.get_item_metadata(i)) == String(draft.get(k, "")):
				if o.selected != i:
					o.select(i)
				break


func _refresh() -> void:
	var worn: StringName = profile.loadout.mask
	equipped_label.text = MaskCatalog.display_name(worn) if worn != &"" else UiText.t(&"ui.masks.none")
	var first_empty: int = _first_empty_slot()
	for id: StringName in list_buttons:
		var b: Button = list_buttons[id] as Button
		var label: String = MaskCatalog.display_name(id)
		b.visible = true
		if MaskCatalog.is_custom_id(id) and MaskLocker.custom_composition(profile, MaskCatalog.custom_index(id)).is_empty():
			# D-111 (style.md §11): one "New mask" row instead of every empty slot; the rest stay hidden.
			label = UiText.t(&"ui.masks.new_mask")
			b.visible = MaskCatalog.custom_index(id) == first_empty
		elif id == worn:
			label = UiText.t(&"ui.masks.equipped_tag", {"name": label})
		b.text = label
		b.set_pressed_no_signal(id == (selected_id if selected_id != &"" else MaskCatalog.custom_id(target_slot)))
	_rechain_visible()
	_refresh_slots()
	if dirty:
		name_label.text = MaskCatalog.display_name(MaskCatalog.custom_id(target_slot)) + " *"
	elif selected_id != &"":
		name_label.text = MaskCatalog.display_name(selected_id)
	else:
		name_label.text = UiText.t(&"ui.masks.empty_slot", {"n": target_slot + 1})
	var colors: MaskColorDef = null
	var cid: StringName = StringName(String(draft.get(MaskCatalog.COLORS, "")))
	if MaskCatalog.has_part(cid):
		colors = MaskCatalog.part(cid) as MaskColorDef
	swatch_a.color = colors.color_a if colors != null else Color.TRANSPARENT
	swatch_b.color = colors.color_b if colors != null else Color.TRANSPARENT
	var locked: bool = not MaskLocker.check_composition(profile, draft).is_empty()
	save_button.disabled = not dirty or locked
	equip_button.disabled = dirty or selected_id == &"" or selected_id == worn
	if dirty:
		_set_status(&"ui.masks.status.locked_parts" if locked else &"ui.masks.status.unsaved")
	elif selected_id == &"":
		_set_status(&"ui.masks.status.empty_slot")
	elif selected_id == worn:
		_set_status(&"ui.masks.status.equipped", {"name": MaskCatalog.display_name(selected_id)})
	else:
		_set_status(&"ui.masks.status.ready", {"name": MaskCatalog.display_name(selected_id)})
	preview.show_def(current_def())


func _refresh_slots() -> void:
	slot_option.clear()
	for i: int in range(tweak.custom_slot_count):
		var filled: bool = not MaskLocker.custom_composition(profile, i).is_empty()
		slot_option.add_item(MaskCatalog.display_name(MaskCatalog.custom_id(i)) if filled
			else UiText.t(&"ui.masks.empty_slot", {"n": i + 1}))
	slot_option.select(clampi(target_slot, 0, maxi(tweak.custom_slot_count - 1, 0)))


func _set_status(key: StringName, args: Dictionary = {}) -> void:
	status_label.text = UiText.t(key, args)


## Owned presets first (sorted ids), then every custom slot.
func _list_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for md: MaskDef in MaskCatalog.presets():
		if MaskLocker.is_equippable(profile, md.id):
			out.append(md.id)
	for i: int in range(tweak.custom_slot_count):
		out.append(MaskCatalog.custom_id(i))
	return out


func _first_empty_slot() -> int:
	for i: int in range(tweak.custom_slot_count):
		if MaskLocker.custom_composition(profile, i).is_empty():
			return i
	return clampi(target_slot, 0, maxi(tweak.custom_slot_count - 1, 0))


func _on_list_pressed(mask_id: StringName) -> void:
	select_mask(mask_id)


func _on_part_selected(index: int, kind: String) -> void:
	var o: OptionButton = part_options[kind] as OptionButton
	set_part(kind, StringName(String(o.get_item_metadata(index))))


func _on_slot_selected(index: int) -> void:
	target_slot = index
	_refresh()


func _rechain_visible() -> void:
	if _all_focus.is_empty():
		return
	focus_chain.clear()
	for c: Control in _all_focus:
		if c.visible:
			focus_chain.append(c)
	if is_inside_tree():
		UiNav.chain_vertical(focus_chain)
