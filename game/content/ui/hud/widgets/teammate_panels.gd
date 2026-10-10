## Teammate panels: name, health/armor bars, state, downs, carried bag. One per model.crew entry.
class_name TeammatePanels
extends HudWidget

var list_box: VBoxContainer
## slot -> name Label (tests).
var name_labels: Dictionary = {}


func build() -> void:
	list_box = UiBuild.vbox(6)
	add_child(list_box)


func watched_signals() -> Array[StringName]:
	return [&"crew_changed"]


func refresh() -> void:
	for c: Node in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	name_labels.clear()
	for m: Dictionary in prop(&"crew", []) as Array:
		list_box.add_child(_panel(m))


func _panel(m: Dictionary) -> PanelContainer:
	var v: VBoxContainer = UiBuild.vbox(2)
	var name_label: Label = UiBuild.label(&"", UiBuild.HUD)
	name_label.text = String(m.get("name", ""))
	v.add_child(name_label)
	name_labels[int(m.get("slot", -1))] = name_label
	var armor_bar: ProgressBar = UiBuild.bar(tweak.armor_color, Vector2(200, 6))
	armor_bar.value = float(m.get("armor_frac", 0.0))
	v.add_child(armor_bar)
	var health_bar: ProgressBar = UiBuild.bar(tweak.health_color, Vector2(200, 8))
	health_bar.value = float(m.get("health_frac", 0.0))
	v.add_child(health_bar)
	var info: Array[String] = [UiText.t(&"ui.hud.downs_left", {"count": int(m.get("downs_left", 0))})]
	var st: int = int(m.get("state", Enums.CrewState.NORMAL))
	if st == Enums.CrewState.CUSTODY:
		info.append(UiText.t(&"ui.hud.custody"))
	elif st != Enums.CrewState.NORMAL:
		info.append(UiText.t(&"ui.hud.downed"))
	var loot: StringName = StringName(m.get("carried_loot_id", &""))
	if loot != &"":
		info.append(UiText.t(&"ui.hud.carrying", {"loot": UiText.t(UiText.item_key(loot))}))
	var info_label: Label = UiBuild.label(&"", UiBuild.HUD)
	info_label.text = "  ".join(info)
	info_label.add_theme_font_size_override(&"font_size", 18)
	v.add_child(info_label)
	return UiBuild.panel(v, UiBuild.HUD_PANEL)
