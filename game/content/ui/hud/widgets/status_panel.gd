## Civilian/casing/masked indicator (S1.1, S1.3 civilian badge D-065), carried bag, hostages, special warnings (Phantom/Stinger).
class_name StatusPanel
extends HudWidget

## player_mode -> ui.hud.<key>.
const MODE_KEYS: Dictionary = {&"civilian": "civilian", &"casing": "unmasked", &"masked": "masked"}

var mask_label: Label
var bag_label: Label
var hostages_label: Label
var warnings_label: Label


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_END
	add_child(v)
	mask_label = _add(v)
	# PO-4: the mode reads as a tracked-caps chip (CASING / CIVILIAN); MASKED is the normal state and
	# is not shown (its text is kept for tests and screen readers).
	mask_label.uppercase = true
	mask_label.add_theme_font_override(&"font", UiTokens.font_caps())
	mask_label.add_theme_font_size_override(&"font_size", UiTokens.FONT_LEAD)
	mask_label.add_theme_color_override(&"font_color", UiTokens.BRASS_HI)
	bag_label = _add(v)
	hostages_label = _add(v)
	warnings_label = _add(v)
	bag_label.add_theme_color_override(&"font_color", tweak.loot_color)
	warnings_label.add_theme_color_override(&"font_color", tweak.assault_color)


func _add(parent: Container) -> Label:
	var l: Label = UiBuild.float_text(UiBuild.label(&"", UiBuild.HUD))  # floats over the world (PQ-B-23)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(l)
	return l


func watched_signals() -> Array[StringName]:
	return [&"masked_changed", &"carried_bag_changed", &"hostages_changed", &"warnings_changed", &"player_mode_changed"]


func refresh() -> void:
	var mode: StringName = player_mode()
	mask_label.text = UiText.t(StringName("ui.hud.%s" % MODE_KEYS[mode])) if MODE_KEYS.has(mode) else ""
	mask_label.visible = mask_label.text != "" and mode != &"masked"
	var bag: Dictionary = prop(&"carried_bag", {}) as Dictionary
	var loot: StringName = StringName(bag.get("loot_id", &""))
	bag_label.visible = loot != &""
	bag_label.text = UiText.t(&"ui.hud.carrying", {"loot": UiText.t(UiText.item_key(loot))}) if loot != &"" else ""
	var hostages: int = int(prop(&"hostages", 0))
	hostages_label.visible = hostages > 0
	hostages_label.text = UiText.t(&"ui.hud.hostages", {"count": hostages})
	var lines: Array[String] = []
	var captain_widget: bool = prop(&"captain_present") != null  # v1.3: CaptainPanel shows Brandt
	for w: StringName in prop(&"warnings", []) as Array:
		if w == &"captain" and captain_widget:
			continue
		lines.append(UiText.t(StringName("ui.hud.%s_warning" % w)))
	warnings_label.text = "\n".join(lines)
	warnings_label.visible = not lines.is_empty()
