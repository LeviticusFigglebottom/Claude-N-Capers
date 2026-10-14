## Custody state (ui_hud.md v1.2, D-043 QA-22; pd2_fidelity L2.5/L5.x): while the local player is in custody,
## the negotiation timer (a trade is possible once it reaches 0) and the auto-release timer (< 0 = none);
## while free with a teammate in custody, a hint to trade the highlighted hostage. Binds `custody_changed`
## / `custody` = {} or {in_custody, negotiation_left_s, auto_release_left_s, highlighted_hostage_net_id}.
class_name CustodyPanel
extends HudWidget

var title_label: Label
var negotiation_label: Label
var release_label: Label
var hostage_label: Label


func build() -> void:
	var v: VBoxContainer = UiBuild.vbox(4)
	add_child(v)
	# HUD readability pass: unanchored, the box sat at its natural width in the widget's top-left corner, so
	# the centred lines read left of the screen centre. It spans the widget now.
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_label = UiBuild.label(&"ui.hud.custody", UiBuild.HUD_BIG)
	negotiation_label = UiBuild.label(&"", UiBuild.HUD)
	release_label = UiBuild.label(&"", UiBuild.HUD)
	hostage_label = UiBuild.label(&"", UiBuild.HUD)
	for l: Label in [title_label, negotiation_label, release_label, hostage_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)


func watched_signals() -> Array[StringName]:
	return [&"custody_changed"]


func refresh() -> void:
	var c: Dictionary = prop(&"custody", {}) as Dictionary
	var in_custody: bool = bool(c.get("in_custody", false))
	var hostage: int = int(c.get("highlighted_hostage_net_id", 0))
	title_label.visible = in_custody
	var nego: float = float(c.get("negotiation_left_s", 0.0))
	negotiation_label.visible = in_custody
	negotiation_label.text = UiText.t(&"ui.hud.custody_negotiation", {"seconds": UiText.clock(nego)}) if nego > 0.0 \
			else UiText.t(&"ui.hud.custody_trade")
	var release: float = float(c.get("auto_release_left_s", -1.0))
	release_label.visible = in_custody and release >= 0.0
	release_label.text = UiText.t(&"ui.hud.custody_release", {"seconds": UiText.clock(maxf(release, 0.0))})
	hostage_label.visible = not in_custody and hostage > 0
	hostage_label.text = UiText.t(&"ui.hud.custody_trade_hint")
	visible = in_custody or hostage > 0
