## Casing/masked indicator (S1.1), carried bag, hostages, special warnings (Phantom/Stinger).
class_name StatusPanel
extends HudWidget

var mask_label: Label
var bag_label: Label
var hostages_label: Label
var warnings_label: Label


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_END
	add_child(v)
	mask_label = _add(v)
	bag_label = _add(v)
	hostages_label = _add(v)
	warnings_label = _add(v)
	warnings_label.add_theme_color_override(&"font_color", tweak.assault_color)


func _add(parent: Container) -> Label:
	var l: Label = UiBuild.label(&"", UiBuild.HUD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(l)
	return l


func watched_signals() -> Array[StringName]:
	return [&"masked_changed", &"carried_bag_changed", &"hostages_changed", &"warnings_changed"]


func refresh() -> void:
	var casing: bool = bool(prop(&"casing", false))
	var masked: bool = bool(prop(&"masked", false))
	mask_label.text = UiText.t(&"ui.hud.unmasked") if casing and not masked else (UiText.t(&"ui.hud.masked") if masked else "")
	mask_label.visible = mask_label.text != ""
	var bag: Dictionary = prop(&"carried_bag", {}) as Dictionary
	var loot: StringName = StringName(bag.get("loot_id", &""))
	bag_label.visible = loot != &""
	bag_label.text = UiText.t(&"ui.hud.carrying", {"loot": UiText.t(UiText.item_key(loot))}) if loot != &"" else ""
	var hostages: int = int(prop(&"hostages", 0))
	hostages_label.visible = hostages > 0
	hostages_label.text = UiText.t(&"ui.hud.hostages", {"count": hostages})
	var lines: Array[String] = []
	for w: StringName in prop(&"warnings", []) as Array:
		lines.append(UiText.t(StringName("ui.hud.%s_warning" % w)))
	warnings_label.text = "\n".join(lines)
	warnings_label.visible = not lines.is_empty()
