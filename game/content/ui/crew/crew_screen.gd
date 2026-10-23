## Crew screen (D-145.4 / PO-19). Owner: ENV B. Opened from the hub (HubMenu.crew_requested / the safehouse pause
## menu -> MenuFlow._open_crew); Back returns. Gears the three crew bots from the player's armory (CrewLoadouts):
## tabs Bot 1-3 pick the bot; the editor rows are its Primary (owned primaries; "Standard issue" = A's default bot
## gun), one row per mod slot the gun has an owned mod for ("Stock" = no mod), Armor (unlocked armors), Mask (wearable
## masks) and Outfit (any free heister, an unlocked heister, a heist suit), plus Reset. Every change is validated and
## saved at once (SaveService.save_profile); the summary column lists all three bots. Nothing is bought here: the
## hint points at the Workshop. Keyboard / pad: the tabs along the top (left / right), down into the editor rows,
## right from a row to the summary cards' Back.
## API: setup(profile, slot) before or after entering the tree; select_bot(i); pick(row, id) (tests).
class_name CrewScreen
extends UiScreen

## The profile slot changes are saved to.
var profile_slot: int = 0
var profile: PlayerProfile = null
## Bot slot being edited (0..CrewLoadouts.SLOTS-1).
var bot: int = 0
var bot_tabs: Array[Button] = []
## Editor rows: "weapon", "armor", "mask", "outfit" and "mod.<ModType>" -> ItemSlot.
var rows: Dictionary = {}
var reset_button: Button
var back_button: Button
## Summary cards, one Label per bot ("Bot 1 / Corsair AR / Heavy vest / ...").
var summary_labels: Array[Label] = []
var _editor: VBoxContainer
var _summary: VBoxContainer


func setup(p: PlayerProfile, slot: int = 0) -> void:
	profile = p
	profile_slot = slot
	if is_node_ready():
		refresh()


func build_ui() -> void:
	var root: VBoxContainer = UiBuild.vbox(UiTokens.S3)
	UiBuild.screen_margin(self, root)
	var titles: VBoxContainer = UiBuild.header(&"ui.crew.crumb", &"ui.crew.title")
	var sub: Label = UiBuild.label(&"ui.crew.subtitle", UiBuild.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(sub)
	root.add_child(titles)
	var tabs: HBoxContainer = UiBuild.hbox(UiTokens.S2)
	root.add_child(tabs)
	for i: int in range(CrewLoadouts.SLOTS):
		var t: Button = UiBuild.tab(UiBuild.button(&"ui.crew.bot", {"n": i + 1}))
		t.pressed.connect(select_bot.bind(i))
		tabs.add_child(t)
		bot_tabs.append(t)
	var body: HBoxContainer = UiBuild.hbox(UiTokens.S4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	_editor = UiBuild.vbox(UiTokens.S2)
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_editor)
	_summary = UiBuild.vbox(UiTokens.S2)
	_summary.custom_minimum_size = Vector2(560, 0)
	body.add_child(_summary)
	_summary.add_child(UiBuild.caption(&"ui.crew.summary"))
	for i: int in range(CrewLoadouts.SLOTS):
		var l: Label = UiBuild.label(&"")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_summary.add_child(UiBuild.panel(l))
		summary_labels.append(l)
	var hint: Label = UiBuild.label(&"ui.crew.workshop_hint", UiBuild.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_child(hint)
	reset_button = UiBuild.ghost(UiBuild.button(&"ui.crew.reset"))
	reset_button.pressed.connect(reset_bot)
	back_button = UiBuild.button(&"ui.menu.back")
	back_button.pressed.connect(back_requested.emit)
	root.add_child(UiBuild.footer(back_button, null, [reset_button] as Array[Control]))
	refresh()


func _ready() -> void:
	super()
	_wire_focus()


## Edit bot slot `i`.
func select_bot(i: int) -> void:
	bot = clampi(i, 0, CrewLoadouts.SLOTS - 1)
	refresh()
	if is_inside_tree() and not rows.is_empty():
		(rows["weapon"] as Control).grab_focus.call_deferred()


## Rebuild the editor for `bot` and every summary card from the profile.
func refresh() -> void:
	if profile == null:
		profile = SaveService.load_profile(profile_slot)
	if _editor == null:
		return
	for i: int in range(bot_tabs.size()):
		bot_tabs[i].set_pressed_no_signal(i == bot)
	_rebuild_editor()
	for i: int in range(summary_labels.size()):
		var n: Dictionary = CrewLoadouts.names(CrewLoadouts.validate(profile, CrewLoadouts.entry(profile, i)))
		summary_labels[i].text = UiText.t(&"ui.crew.card", {"n": i + 1, "weapon": n["weapon"], "armor": n["armor"],
			"mask": n["mask"], "outfit": n["outfit"], "ability": n["ability"], "boost": n["boost"]})
	if is_node_ready():
		_wire_focus()


## Choose `id` on editor row `row` ("weapon", "armor", "mask", "outfit", "ability", "boost", "mod.<ModType>"; &"" =
## default / stock / none) and save. False when the row or id is not on offer.
func pick(row: String, id: StringName) -> bool:
	var o: ItemSlot = rows.get(row) as ItemSlot
	if o == null or not LoadoutScreen._select_id(o, id):
		return false
	_on_row_changed(0, row)
	return true


## Bot `bot` back to its defaults (saved).
func reset_bot() -> void:
	CrewLoadouts.set_entry(profile, bot, CrewLoadouts.empty_entry())
	_save()
	refresh()


func _rebuild_editor() -> void:
	for c: Node in _editor.get_children():
		_editor.remove_child(c)
		c.queue_free()
	rows.clear()
	var e: Dictionary = CrewLoadouts.validate(profile, CrewLoadouts.entry(profile, bot))
	var w: ItemSlot = _row("weapon", &"ui.crew.row.weapon", &"armory")
	LoadoutScreen._add_item(w, CrewLoadouts.default_weapon_name(), &"")
	for id: StringName in CrewLoadouts.weapons(profile):
		LoadoutScreen._add_item(w, UiText.t(UiText.item_key(id)), id)
	_finish_row(w, e["weapon"])
	var mods: Dictionary = CrewLoadouts.mods(profile, e["weapon"]) if e["weapon"] != &"" else {}
	var types: Array = mods.keys()
	types.sort()
	for t: Variant in types:
		var key: String = "mod.%d" % int(t)
		var m: ItemSlot = _row(key, LoadoutScreen._mod_type_key(int(t)), &"range")
		LoadoutScreen._add_item(m, UiText.t(&"ui.loadout.stock"), &"")
		for id: StringName in mods[t] as Array[StringName]:
			LoadoutScreen._add_item(m, UiText.t(UiText.item_key(id)), id)
		var on: StringName = &""
		for id: StringName in e["mods"] as Array[StringName]:
			if (mods[t] as Array).has(id):
				on = id
		_finish_row(m, on)
	var a: ItemSlot = _row("armor", &"ui.crew.row.armor", &"vest")
	LoadoutScreen._add_item(a, CrewLoadouts.default_armor_name(), &"")
	for id: StringName in CrewLoadouts.armors(profile):
		LoadoutScreen._add_item(a, UiText.t(UiText.item_key(id)), id)
	_finish_row(a, e["armor"])
	var mk: ItemSlot = _row("mask", &"ui.crew.row.mask", &"masks")
	LoadoutScreen._add_item(mk, UiText.t(&"ui.crew.no_mask"), &"")
	for id: StringName in CrewLoadouts.masks(profile):
		LoadoutScreen._add_item(mk, MaskCatalog.display_name(id), id)
	_finish_row(mk, e["mask"])
	var of: ItemSlot = _row("outfit", &"ui.crew.row.outfit", &"crew")
	LoadoutScreen._add_item(of, CrewLoadouts.outfit_name(&""), &"")
	for id: StringName in CrewLoadouts.outfits(profile):
		LoadoutScreen._add_item(of, CrewLoadouts.outfit_name(id), id)
		if not CrewLoadouts.is_suit(id):
			of.set_item_accent(of.item_count - 1, Heisters.accent(id))
	_finish_row(of, e["outfit"])
	# L6.2: one ability (the bot itself) and one boost (the whole crew while the bot is in play).
	var ab: ItemSlot = _row("ability", &"ui.crew.row.ability", &"crew")
	LoadoutScreen._add_item(ab, UiText.t(&"ui.crew.none"), &"")
	for id: StringName in CrewLoadouts.abilities():
		LoadoutScreen._add_item(ab, UiText.t(UiText.item_key(id)), id)
	_finish_row(ab, e["ability"])
	var bo: ItemSlot = _row("boost", &"ui.crew.row.boost", &"crew")
	LoadoutScreen._add_item(bo, UiText.t(&"ui.crew.none"), &"")
	for id: StringName in CrewLoadouts.boosts():
		LoadoutScreen._add_item(bo, UiText.t(UiText.item_key(id)), id)
	_finish_row(bo, e["boost"])


func _row(key: String, caption: StringName, glyph: StringName) -> ItemSlot:
	var o: ItemSlot = ItemSlot.new()
	o.caption_key = caption
	o.glyph = glyph
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.add_child(o)
	rows[key] = o
	return o


func _finish_row(o: ItemSlot, selected: StringName) -> void:
	if not LoadoutScreen._select_id(o, selected):
		o.select(0)
	var key: String = ""
	for k: Variant in rows:
		if rows[k] == o:
			key = String(k)
	o.item_selected.connect(_on_row_changed.bind(key))


func _on_row_changed(_index: int, row: String) -> void:
	var e: Dictionary = CrewLoadouts.entry(profile, bot)
	var id: StringName = LoadoutScreen._selected_id(rows[row] as ItemSlot)
	if row == "weapon":
		if id != e["weapon"]:
			e["mods"] = [] as Array[StringName]  # another gun: its own mods (stock until picked)
		e["weapon"] = id
	elif row.begins_with("mod."):
		var t: int = int(row.trim_prefix("mod."))
		var keep: Array[StringName] = []
		for m: StringName in e["mods"] as Array[StringName]:
			if not (CrewLoadouts.mods(profile, e["weapon"]).get(t, []) as Array).has(m):
				keep.append(m)
		if id != &"":
			keep.append(id)
		e["mods"] = keep
	else:
		e[row] = id
	CrewLoadouts.set_entry(profile, bot, e)
	_save()
	var focus_row: String = row
	refresh()
	if is_inside_tree() and rows.has(focus_row):
		(rows[focus_row] as Control).grab_focus.call_deferred()


func _save() -> void:
	SaveService.save_profile(profile, profile_slot)


## Tabs left / right along the top, down into the editor rows (top to bottom), Reset and Back in the footer.
func _wire_focus() -> void:
	focus_chain.clear()
	focus_chain.append_array(bot_tabs)
	for k: Variant in rows:
		focus_chain.append(rows[k] as Control)
	focus_chain.append(reset_button)
	focus_chain.append(back_button)
	UiNav.chain_vertical(focus_chain)
	var tabs: Array[Control] = []
	tabs.append_array(bot_tabs)
	UiNav.chain_horizontal(tabs, false)
	var first: Control = rows.get("weapon") as Control
	for t: Button in bot_tabs:
		if first != null:
			t.set_focus_neighbor(SIDE_BOTTOM, t.get_path_to(first))
	if first != null:
		first.set_focus_neighbor(SIDE_TOP, first.get_path_to(bot_tabs[bot]))
	reset_button.set_focus_neighbor(SIDE_RIGHT, reset_button.get_path_to(back_button))
	back_button.set_focus_neighbor(SIDE_LEFT, back_button.get_path_to(reset_button))
