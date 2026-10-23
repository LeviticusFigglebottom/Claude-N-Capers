## Local human input -> CrewIntent (crew_intent.md). Owner: ENV A.
## The ONLY place raw `Input` is read for gameplay. Added by HeistRuntime under the local
## player's CrewController on every peer. Integration-test bot intents (HeistRuntime) take
## precedence over this node while held. Actions are defined in project.godot (D-025, QA-4).
##
## Contextual keys (PD2 style):
##   F (`interact` / `shout`): hold to interact when an interactable is aimed at, otherwise a
##     press is a shout (intimidate / mark).
##   G (`mask_up` / `throw_item` / `drop_bag`): hold to mask up while unmasked; while masked and
##     carrying a bag a press throws the bag; otherwise a press throws the throwable.
##   T (`order_menu`, A3-05): tap = contextual AI teammate order (CrewOrders.contextual_order):
##     aimed AI carrying a bag -> drop_bag; aimed downed crew -> revive; aimed AI -> hold here /
##     follow toggle; aimed bag -> carry_bag; aimed point -> hold there; nothing -> follow. The order
##     stays on the intent for CrewAiTweak.order_latch_s (the server routes it once).
class_name PlayerInput
extends Node

## Actions held when a UI released the input (payday LB/RB, menus): ignored until released once, so the
## press that closed or navigated the UI does not also melee / throw / fire in the game.
const RESUME_GATED: Array[StringName] = [&"fire", &"melee", &"throw_item", &"mask_up", &"drop_bag", &"deploy",
	&"interact", &"shout", &"reload", &"jump", &"aim", &"slot_primary", &"slot_secondary",
	&"swap_weapon", &"gadget_toggle"]

## Tests only (PInputDriver): headless cannot capture the mouse; treat motion as captured.
## Never set by game code: the real capture is MouseCapture's (D-087).
static var test_assume_captured: bool = false

## Radians of look per mouse count at GameSettings sensitivity 1.0. Feel pass (PO-4): 0.0025 (0.143 deg/count,
## 360 deg in ~3 in at 800 DPI) was twitchy; 0.0016 = 0.092 deg/count, 360 deg in ~4.9 in, close to PD2's default.
@export var mouse_sensitivity: float = 0.0016
## PD2 zoom sensitivity: while ADS / scoped, mouse and stick look slow down by the camera zoom (CrewView.zoom_factor,
## D-084), so a 4x scope does not turn 4x faster on screen.
@export var scale_look_by_zoom: bool = true
## Gamepad look: radians per second at full stick deflection (yaw; pitch uses the same rate).
@export var gamepad_look_speed: float = 3.0
## Radial deadzone of the right stick (0..1).
@export var gamepad_deadzone: float = 0.2
## Response curve exponent (1 = linear; 2 = finer aim near the centre).
@export var gamepad_curve: float = 1.5
@export var gamepad_invert_y: bool = false
## L4 (PD2 pad feel): turn acceleration. After the stick has been past gamepad_ramp_threshold (raw |stick|) for
## gamepad_ramp_delay_s, yaw speed ramps from 1x up to gamepad_ramp_max_mult over gamepad_ramp_time_s; dropping below
## the threshold resets it. Pitch is never ramped. Fine aim stays on the curve; only held full turns speed up.
@export var gamepad_ramp_enabled: bool = true
@export var gamepad_ramp_threshold: float = 0.9
@export var gamepad_ramp_delay_s: float = 0.25
@export var gamepad_ramp_time_s: float = 0.35
@export var gamepad_ramp_max_mult: float = 1.8
## PO-4 (PD2, playerstandard / fpcameraplayerbase): a shot's camera kick (CrewWeapons -> add_recoil) is applied over
## this many seconds (ease-out) instead of a one-frame snap. 0 = instant.
@export var recoil_apply_s: float = 0.06
## PD2 recovery (D-097): once shooting stops the camera puts back the WHOLE kick accumulated since shooting started
## (whatever the player pulled down meanwhile), easing out at these rates (1/s; PD2 lerp 9*dt vertical, 5*dt
## horizontal). "Stopped" = no shot for one fire interval for auto-default guns (WeaponDef.fire_modes[0] == auto),
## at once for semi-default ones (PD2 recoil_wait). Vertical accumulation caps at recoil_max_accum_deg.
@export var recoil_recover_rate_v: float = 9.0
@export var recoil_recover_rate_h: float = 5.0
@export var recoil_max_accum_deg: float = 20.0
@export var gamepad_requires_capture: bool = false

var enabled: bool = true
var _suppressed: Dictionary[StringName, bool] = {}
var _ui_focused: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _crew: CrewController = null
var _toggled: Dictionary[StringName, bool] = {}
var _held_prev: Dictionary[StringName, bool] = {}
## Slot to restore when `swap_weapon` toggles.
var _last_slot: int = Enums.WeaponSlot.SECONDARY
## A3-05: the order being sent (latched for a few ticks) and the last follow/hold given per AI net id.
var _order: Dictionary = {}
var _order_ticks: int = 0
var _ai_stances: Dictionary = {}
## PO-4: recoil impulses being applied: [{"total": Vector2(yaw, pitch), "done": applied share 0..1, "t": s in}].
var _recoil: Array[Dictionary] = []
## PD2 recovery: kick accumulated since shooting started (yaw, pitch; radians) and seconds since the last shot.
var _recoil_acc: Vector2 = Vector2.ZERO
## PO-4: seconds left of the sprint -> fire exit (CrewTweak.sprint_exit_fire_s); sprint cancelled until re-pressed.
var _sprint_exit_left: float = 0.0
var _sprint_cancelled: bool = false
var _since_shot: float = 0.0
## Seconds the right stick has been past gamepad_ramp_threshold (L4 turn ramp).
var _pad_ramp_s: float = 0.0


func _ready() -> void:
	_crew = get_parent() as CrewController
	if _crew != null:
		_yaw = _crew.look_yaw
		_pitch = _crew.look_pitch
		_crew.teleported.connect(_on_teleported)
	var n: Object = MouseCapture.notifier()
	if n != null:
		n.connect(&"changed", _on_capture_changed)
	_sync_capture()


func _exit_tree() -> void:
	MouseCapture.set_gameplay_active(self, false)


func _process(_delta: float) -> void:
	_sync_capture()


## D-087: the live local human's input owns the gameplay mouse capture (a paused / disabled input does not).
func _sync_capture() -> void:
	MouseCapture.set_gameplay_active(self, enabled and is_inside_tree() and _crew != null)


## The click that (re)captured the mouse, or a button held through a capture, must not also fire / act.
func _on_capture_changed(captured: bool) -> void:
	if captured:
		_latch_held()


## PI-06: spawns, custody release and server teleports set the facing; keep it instead of snapping back.
func _on_teleported() -> void:
	_yaw = _crew.look_yaw
	_pitch = _crew.look_pitch
	_recoil.clear()
	_recoil_acc = Vector2.ZERO


## D-087: mouse look reads _input, not _unhandled_input: with the mouse captured no Control under the screen
## centre (HUD panel, a MenuFlow left with MOUSE_FILTER_STOP) may swallow the motion.
func _input(event: InputEvent) -> void:
	if not enabled:
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and (MouseCapture.is_captured() or test_assume_captured):
		var gs: GameSettings = GameSettings.current()  # B5-01 options
		var ms: Vector2 = gs.mouse_sensitivity() if gs != null else Vector2.ONE
		var inv: float = -1.0 if gs != null and gs.invert_y() else 1.0
		# P1-01 (mouse gain): screen_relative = raw device counts. `relative` is scaled by the canvas_items stretch
		# (base 1920x1080 / window size), which made sensitivity depend on resolution (x0.75 at 1440p, x0.5 at 4K,
		# x1.5 at 720p, x30 headless).
		var d: Vector2 = mm.screen_relative * mouse_sensitivity / _zoom() * _ads_mult()
		add_look(-d.x * ms.x, -d.y * ms.y * inv)


## QB-46: paused input stops building intents; resuming re-reads the crew's look direction.
func set_paused(paused: bool) -> void:
	enabled = not paused
	_pad_ramp_s = 0.0
	if not paused and _crew != null:
		_yaw = _crew.look_yaw
		_pitch = _crew.look_pitch
	if not paused:
		_latch_held()
	_sync_capture()


## Every gameplay read here polls Input (is_action_pressed / just_pressed), so a UI consuming the event (payday
## LB/RB, menus) does not stop it: actions held when the UI lets go stay ignored until released once.
func _latch_held() -> void:
	_suppressed.clear()
	for a: StringName in RESUME_GATED:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			_suppressed[a] = true


## A visible Control holds keyboard/gamepad focus (payday cards, menus, pause, chat): gameplay input is off.
func ui_has_focus() -> bool:
	if not is_inside_tree():
		return false
	var f: Control = get_viewport().gui_get_focus_owner()
	return f != null and f.is_visible_in_tree()


## Look divisor while zoomed (1.0 at hip fire or with scale_look_by_zoom off).
func _zoom() -> float:
	return maxf(CrewView.local_zoom_factor(), 1.0) if scale_look_by_zoom else 1.0


## Options "aiming sensitivity" (B, options.md: GameSettings.ads_sensitivity, 0.1..2, default 1) while aimed /
## scoped, on top of the zoom divisor; 1.0 at hip fire, or when the settings build has no such option.
func _ads_mult() -> float:
	var gs: GameSettings = GameSettings.current()
	if gs == null or not gs.has_method(&"ads_sensitivity"):
		return 1.0
	var aimed: bool = _zoom() > 1.001 or (_crew != null and CrewView.is_aiming(_crew))
	return float(gs.call(&"ads_sensitivity")) if aimed else 1.0


## Recoil kick of one shot (radians; CrewWeapons._apply_recoil): pitch up `kick`, yaw `side`, spread over
## recoil_apply_s with an ease-out so the camera punches up instead of teleporting.
func add_recoil(kick: float, side: float) -> void:
	var cap: float = deg_to_rad(recoil_max_accum_deg)
	kick = clampf(kick, -cap - _recoil_acc.y, cap - _recoil_acc.y) if recoil_max_accum_deg > 0.0 else kick
	_recoil_acc += Vector2(side, kick)
	_since_shot = 0.0
	if recoil_apply_s <= 0.0:
		add_look(side, kick)
		return
	_recoil.append({"total": Vector2(side, kick), "done": 0.0, "t": 0.0})


## PD2 recoil_wait: one fire interval for auto-default weapons, none for semi-default ones.
func _recover_wait_s() -> float:
	var w: CrewWeapons = _crew.weapons if _crew != null else null
	if w == null:
		return 0.0
	var def: WeaponDef = ContentDB.weapon(w.weapon_id(w.equipped_slot))
	var st: WeaponStats = w.stats(w.equipped_slot)
	if def == null or st == null or def.fire_modes.is_empty() or def.fire_modes[0] != &"auto":
		return 0.0
	return 60.0 / maxf(st.fire_rate_rpm, 1.0)


## Advance the pending recoil impulses by `delta` (applies exactly their total in the end).
func _tick_recoil(delta: float) -> void:
	_since_shot += delta
	if _recoil.is_empty() and _recoil_acc != Vector2.ZERO and _since_shot >= _recover_wait_s():
		var back: Vector2 = Vector2(_recoil_acc.x * minf(recoil_recover_rate_h * delta, 1.0),
			_recoil_acc.y * minf(recoil_recover_rate_v * delta, 1.0))
		if _recoil_acc.length() < 1e-5:
			back = _recoil_acc
		add_look(-back.x, -back.y)
		_recoil_acc -= back
	if _recoil.is_empty():
		return
	var keep: Array[Dictionary] = []
	for r: Dictionary in _recoil:
		var t: float = minf(float(r["t"]) + delta, recoil_apply_s)
		var x: float = clampf(t / recoil_apply_s, 0.0, 1.0)
		var frac: float = 1.0 - (1.0 - x) * (1.0 - x)  # ease-out
		var d: float = frac - float(r["done"])
		var total: Vector2 = r["total"]
		add_look(total.x * d, total.y * d)
		r["t"] = t
		r["done"] = frac
		if x < 1.0:
			keep.append(r)
	_recoil = keep


## Add yaw/pitch (radians); pitch clamped to +-89 degrees.
func add_look(d_yaw: float, d_pitch: float) -> void:
	_yaw += d_yaw
	_pitch = clampf(_pitch + d_pitch, -deg_to_rad(89.0), deg_to_rad(89.0))


## QB-49: right-stick look delta (radians) for `delta` seconds from a stick vector (x right, y down,
## as Input.get_vector(look_left, look_right, look_up, look_down) returns it).
## B5-01: GameSettings pad_sensitivity (x look speed), pad_deadzone and invert_y override the exports.
func gamepad_look_delta(stick: Vector2, delta: float) -> Vector2:
	var gs: GameSettings = GameSettings.current()
	var dz: float = gs.pad_deadzone() if gs != null else gamepad_deadzone
	var speed: float = gamepad_look_speed * (gs.pad_sensitivity() if gs != null else 1.0)
	var invert: bool = gamepad_invert_y or (gs != null and gs.invert_y())
	var mag: float = stick.length()
	if mag <= dz or mag <= 0.0:
		return Vector2.ZERO
	var scaled: float = pow(clampf((mag - dz) / maxf(1.0 - dz, 0.001), 0.0, 1.0), gamepad_curve)
	var v: Vector2 = stick / mag * scaled * speed * delta
	return Vector2(-v.x, v.y if invert else -v.y)


## Current yaw multiplier of the L4 turn ramp (1.0 when off, before the delay or below the threshold).
func gamepad_ramp_multiplier() -> float:
	if not gamepad_ramp_enabled:
		return 1.0
	var t: float = _pad_ramp_s - gamepad_ramp_delay_s
	if t < 0.0:
		return 1.0
	var k: float = 1.0 if gamepad_ramp_time_s <= 0.0 else clampf(t / gamepad_ramp_time_s, 0.0, 1.0)
	return lerpf(1.0, maxf(gamepad_ramp_max_mult, 1.0), k)


## One tick of stick look: gamepad_look_delta with the turn ramp on yaw (advances the ramp timer by `delta`).
func gamepad_look_step(stick: Vector2, delta: float) -> Vector2:
	if gamepad_ramp_enabled and stick.length() > gamepad_ramp_threshold:
		_pad_ramp_s += delta
	else:
		_pad_ramp_s = 0.0
	var d: Vector2 = gamepad_look_delta(stick, delta)
	d.x *= gamepad_ramp_multiplier()
	return d


func _physics_process(delta: float) -> void:
	if not enabled or _crew == null:
		return
	_tick_recoil(delta)
	if not gamepad_requires_capture or MouseCapture.is_captured():
		var stick: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", 0.0)
		var d: Vector2 = gamepad_look_step(stick, delta) / _zoom() * _ads_mult()
		if d != Vector2.ZERO:
			add_look(d.x, d.y)
	else:
		_pad_ramp_s = 0.0
	var rt: HeistRuntime = HeistRuntime.of(_crew)
	if rt != null and rt.has_bot_intent(_crew.slot):
		return
	if ui_has_focus():  # same as paused: idle intent, nothing polled reaches gameplay
		_ui_focused = true
		var idle: CrewIntent = CrewIntent.new()
		idle.look_yaw = _yaw
		idle.look_pitch = _pitch
		_crew.apply_intent(idle)
		return
	if _ui_focused:
		_ui_focused = false
		_latch_held()
	_crew.apply_intent(build_intent(rt))


func build_intent(rt: HeistRuntime) -> CrewIntent:
	for a: StringName in _suppressed.keys():
		if not Input.is_action_pressed(a):
			_suppressed.erase(a)
	var i: CrewIntent = CrewIntent.new()
	i.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	i.look_yaw = _yaw
	i.look_pitch = _pitch
	i.sprint = _held_or_toggled(&"sprint")
	if _sprint_cancelled:
		if Input.is_action_pressed(&"sprint"):
			i.sprint = false
		else:
			_sprint_cancelled = false
	i.crouch = _held_or_toggled(&"crouch")
	i.jump = Input.is_action_pressed(&"jump")
	i.fire = Input.is_action_pressed(&"fire")
	_sprint_to_fire(i)
	i.aim = _held_or_toggled(&"aim")
	var any_dir: bool = _crew != null and Modifiers.flag(_crew.slot, &"movement.sprint_any_direction")
	if i.move.y <= 0.1 and not (any_dir and i.move.length() > 0.1):
		_toggled.erase(&"sprint")  # a toggled sprint ends when the player stops running (forward, unless any_dir)
	i.reload = Input.is_action_pressed(&"reload")
	i.melee = Input.is_action_pressed(&"melee")
	i.deploy = Input.is_action_pressed(&"deploy")
	# F: interact when aiming at something usable, else shout.
	var isys: InteractionSystem = rt.interaction if rt != null else null
	var aimed: bool = isys != null and (isys.aimed_component(_crew) != null or not isys.session(_crew.slot).is_empty())
	var f_held: bool = Input.is_action_pressed(&"interact") or Input.is_action_pressed(&"shout")
	i.interact = f_held and aimed
	i.shout = not i.interact and (Input.is_action_just_pressed(&"shout") or Input.is_action_just_pressed(&"interact"))
	# G: mask up (hold) / throw bag / throwable.
	var g_held: bool = Input.is_action_pressed(&"mask_up")
	var g_pressed: bool = Input.is_action_just_pressed(&"mask_up") or Input.is_action_just_pressed(&"throw_item") \
		or Input.is_action_just_pressed(&"drop_bag")
	if not _crew.masked:
		i.mask_up = g_held
	elif _crew.is_carrying_bag():
		i.throw_bag = g_pressed
	else:
		i.throw_item = g_pressed
	if Input.is_action_just_pressed(&"slot_primary"):
		i.weapon_slot = Enums.WeaponSlot.PRIMARY
	elif Input.is_action_just_pressed(&"slot_secondary"):
		i.weapon_slot = Enums.WeaponSlot.SECONDARY
	elif Input.is_action_just_pressed(&"swap_weapon"):
		# PT-03: swap from what is actually held (1/2 keys or a failed equip used to desync a local toggle,
		# so a swap press could pick the slot already in hand and do nothing).
		var held: int = _crew.weapons.equipped_slot if _crew.weapons != null else _last_slot
		_last_slot = Enums.WeaponSlot.PRIMARY if held == Enums.WeaponSlot.SECONDARY else Enums.WeaponSlot.SECONDARY
		i.weapon_slot = _last_slot
	i.gadget = Input.is_action_just_pressed(&"gadget_toggle")  # D-118 edge (crew_intent v1.1)
	_order_input(rt, i)
	if not _suppressed.is_empty():
		i.gadget = i.gadget and not _suppressed.has(&"gadget_toggle")
		i.fire = i.fire and not _suppressed.has(&"fire")
		i.melee = i.melee and not _suppressed.has(&"melee")
		i.reload = i.reload and not _suppressed.has(&"reload")
		i.deploy = i.deploy and not _suppressed.has(&"deploy")
		i.jump = i.jump and not _suppressed.has(&"jump")
		i.mask_up = i.mask_up and not _suppressed.has(&"mask_up")
		i.throw_item = i.throw_item and not _suppressed.has(&"throw_item") and not _suppressed.has(&"mask_up")
		i.throw_bag = i.throw_bag and not _suppressed.has(&"throw_item") and not _suppressed.has(&"drop_bag") \
			and not _suppressed.has(&"mask_up")
		i.aim = i.aim and not _suppressed.has(&"aim")
		if _suppressed.has(&"slot_primary") or _suppressed.has(&"slot_secondary") or _suppressed.has(&"swap_weapon"):
			i.weapon_slot = -1
		if _suppressed.has(&"interact") or _suppressed.has(&"shout"):
			i.interact = false
			i.shout = false
	return i


## PO-4 (PD2): fire pressed while sprinting ends the sprint (until sprint is pressed again) and holds the shot for
## CrewTweak.sprint_exit_fire_s while the gun comes up. Ticks on intent builds (physics rate).
func _sprint_to_fire(i: CrewIntent) -> void:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	if _sprint_exit_left > 0.0:
		_sprint_exit_left = maxf(_sprint_exit_left - dt, 0.0)
		i.fire = false
		i.sprint = false
		return
	# A4-04 movement.shoot_while_sprinting (Hip Fire .shotgun, Run and Gun .all): fire without leaving the sprint.
	if i.fire and _crew != null and _crew.sprinting \
			and Modifiers.flag(_crew.slot, &"movement.shoot_while_sprinting", CrewView.weapon_qualifiers(_crew)):
		return
	if i.fire and _crew != null and _crew.sprinting:
		_sprint_exit_left = Tweak.crew().sprint_exit_fire_s
		_sprint_cancelled = true
		_toggled.erase(&"sprint")
		i.fire = false
		i.sprint = false


## A3-05 `order_menu` tap -> CrewIntent order fields (see the header).
func _order_input(rt: HeistRuntime, i: CrewIntent) -> void:
	if rt != null and Input.is_action_just_pressed(&"order_menu"):
		var tw: CrewAiTweak = load(CrewAiBrain.TWEAK_PATH) as CrewAiTweak
		_order = CrewOrders.contextual_order(rt, _crew, _ai_stances, tw)
		_order_ticks = maxi(1, int(ceil(tw.order_latch_s * float(Engine.physics_ticks_per_second))))
		var o: StringName = _order["order"]
		if (o == &"follow" or o == &"hold") and int(_order["target"]) != 0:
			_ai_stances[int(_order["target"])] = o
	if _order_ticks <= 0:
		return
	_order_ticks -= 1
	i.order = _order["order"]
	i.order_target_net_id = int(_order["target"])
	i.order_position = _order["position"]


## B5-01: hold (default) or toggle (GameSettings.is_toggle) for aim / crouch / sprint.
func _held_or_toggled(action: StringName) -> bool:
	var gs: GameSettings = GameSettings.current()
	var held: bool = Input.is_action_pressed(action)
	var pressed: bool = held and not bool(_held_prev.get(action, false))  # own edge: intents build on physics ticks
	_held_prev[action] = held
	if gs == null or not gs.is_toggle(action):
		_toggled.erase(action)
		return held
	if pressed:
		_toggled[action] = not bool(_toggled.get(action, false))
	return bool(_toggled.get(action, false))

