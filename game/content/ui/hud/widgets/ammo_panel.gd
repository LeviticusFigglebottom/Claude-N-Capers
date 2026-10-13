## Ammo (mag / reserve of the equipped slot) and equipment counts (deployable, throwable, cable
## ties, body bags). Hidden until masked (civilian: no gear, S1.3 / D-065; casing: no weapon out).
class_name AmmoPanel
extends HudWidget

var ammo_label: Label
var equipment_label: Label


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(2)
	var p: PanelContainer = UiBuild.panel(v, UiBuild.HUD_PANEL)
	add_child(p)
	# PO-4: hug the bottom-right corner (the frameless text must line up with the screen margin).
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ammo_label = UiBuild.label(&"", UiBuild.HUD_BIG)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(ammo_label)
	equipment_label = UiBuild.float_text(UiBuild.label(&"", UiBuild.DIM))
	equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(equipment_label)


func watched_signals() -> Array[StringName]:
	return [&"ammo_changed", &"inventory_changed", &"player_mode_changed"]


func refresh() -> void:
	# PO-1 (P): no weapon is drawn until you mask up, so the weapon HUD shows only when masked (PD2);
	# models without a mode (pre-v1.6, loading) keep it visible.
	var mode: StringName = player_mode()
	visible = mode == &"masked" or mode == &""
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
