## Hit marker (lead round 62, PD2): an X around the crosshair when the LOCAL player's damage lands on
## an NPC (EventBus.damage_applied, attacker = local_net_id()), with a cue per kind:
##   hit       paper-white X, T_HIT                     cue.hud_hit
##   headshot  brass X, a little larger, T_HIT          cue.hud_headshot  (zone HEAD, or a crit)
##   kill      red X that pops out, T_KILL              cue.hud_kill      (info.killed / npc_killed)
## Zero-damage hits (shield, plate) show nothing. damage_applied replicates to clients
## (Net.replicate_event), so every peer gets its own markers. Owner: ENV B.
class_name HitFeedback
extends HudWidget

const T_HIT: float = 0.22
const T_KILL: float = 0.45
## Inner gap and arm length of the X (canvas units, 1080p canvas).
const GAP: float = 9.0
const ARM: float = 11.0

## Last marker: &"" / &"hit" / &"headshot" / &"kill" (tests) and its remaining time.
var kind: StringName = &""
var left_s: float = 0.0


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func _enter_tree() -> void:
	if not EventBus.damage_applied.is_connected(_on_damage):
		EventBus.damage_applied.connect(_on_damage)
		EventBus.npc_killed.connect(_on_killed)


func _exit_tree() -> void:
	if EventBus.damage_applied.is_connected(_on_damage):
		EventBus.damage_applied.disconnect(_on_damage)
		EventBus.npc_killed.disconnect(_on_killed)


func _on_damage(victim_net_id: int, attacker_net_id: int, info: Dictionary) -> void:
	var me: int = local_net_id()
	if me == 0 or attacker_net_id != me or victim_net_id == me or float(info.get("amount", 0.0)) <= 0.0:
		return
	if bool(info.get("killed", false)):
		show_marker(&"kill")
	elif int(info.get("zone", Enums.HitZone.BODY)) == Enums.HitZone.HEAD or bool(info.get("crit", false)):
		show_marker(&"headshot")
	else:
		show_marker(&"hit")


## A kill that arrives without a lethal damage_applied (e.g. a melee finisher) still confirms.
func _on_killed(_npc_net_id: int, killer_net_id: int, _info: Dictionary) -> void:
	var me: int = local_net_id()
	if me != 0 and killer_net_id == me and not (kind == &"kill" and left_s > T_KILL - 0.05):
		show_marker(&"kill")


func show_marker(k: StringName) -> void:
	if kind == &"kill" and left_s > 0.0 and k != &"kill":
		return  # the kill confirm is not overwritten by the rest of the burst
	kind = k
	left_s = T_KILL if k == &"kill" else T_HIT
	UiSfx.play({&"hit": UiSfx.HIT, &"headshot": UiSfx.HEADSHOT, &"kill": UiSfx.KILL}[k] as StringName)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	left_s -= delta
	if left_s <= 0.0:
		left_s = 0.0
		kind = &""
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if kind == &"" or left_s <= 0.0:
		return
	var total: float = T_KILL if kind == &"kill" else T_HIT
	var t: float = 1.0 - left_s / total  # 0 -> 1 over the marker's life
	var col: Color = UiTokens.PAPER
	var gap: float = GAP
	var arm: float = ARM
	var width: float = 2.0
	match kind:
		&"headshot":
			col = UiTokens.BRASS_HI
			arm += 3.0
			width = 2.5
		&"kill":
			col = UiTokens.ALERT
			arm += 5.0
			width = 3.0
			if UiTokens.motion_ok():
				gap += 6.0 * t  # pops outward
	col.a = clampf(1.0 - t * t, 0.0, 1.0)
	var c: Vector2 = size * 0.5
	for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var n: Vector2 = d.normalized()
		var a: Vector2 = c + n * gap
		var b: Vector2 = c + n * (gap + arm)
		draw_line(a, b, Color(0, 0, 0, col.a * 0.7), width + 2.0, true)  # outline for bright scenes
		draw_line(a, b, col, width, true)
