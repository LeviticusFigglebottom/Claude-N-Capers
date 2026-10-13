## Ammo (mag / reserve of the equipped slot) and equipment counts (deployable, throwable, cable
## ties, body bags). Hidden in civilian mode (S1.3: no gear until the gear pickup, D-065).
class_name AmmoPanel
extends HudWidget

var ammo_label: Label
var equipment_label: Label


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(2)
	add_child(UiBuild.panel(v, UiBuild.HUD_PANEL))
	ammo_label = UiBuild.label(&"", UiBuild.HUD_BIG)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(ammo_label)
	equipment_label = UiBuild.label(&"", UiBuild.DIM)
	equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(equipment_label)


func watched_signals() -> Array[StringName]:
	return [&"ammo_changed", &"inventory_changed", &"player_mode_changed"]


func refresh() -> void:
	visible = player_mode() != &"civilian"
	var slots: Dictionary = prop(&"ammo", {}) as Dictionary
	var slot: int = int(prop(&"equipped_slot", Enums.WeaponSlot.SECONDARY))
	var a: Dictionary = slots.get(slot, {}) as Dictionary
	ammo_label.text = UiText.t(&"ui.hud.ammo", {"mag": int(a.get("mag", 0)), "reserve": int(a.get("reserve", 0))})
	var parts: Array[String] = []
	var dep: StringName = StringName(prop(&"deployable_id", &""))
	if dep != &"":
		parts.append(UiText.t(&"ui.hud.item_count", {"item": UiText.t(UiText.item_key(dep)),
				"count": int(prop(&"deployable_count", 0))}))
	var thr: StringName = StringName(prop(&"throwable_id", &""))
	if thr != &"":
		parts.append(UiText.t(&"ui.hud.item_count", {"item": UiText.t(UiText.item_key(thr)),
				"count": int(prop(&"throwable_count", 0))}))
	parts.append(UiText.t(&"ui.hud.cable_ties", {"count": int(prop(&"cable_ties", 0))}))
	parts.append(UiText.t(&"ui.hud.body_bags", {"count": int(prop(&"body_bags", 0))}))
	equipment_label.text = "\n".join(parts)
