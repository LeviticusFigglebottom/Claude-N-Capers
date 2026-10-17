## D-116 `npc_oneshot` (net.md): NPC presentation one-shots the host's AnimDriver starts on its own (door breach
## door_kick_<fam> / shield_bang, civilian panic_start) reach the clients, which play the same clip with the same
## timing. Owner: ENV A. Presentation only. The fire / hit / melee / reload one-shots already come from [R] EventBus
## facts on every peer and the turns from each peer's own body yaw: they are not sent.
## Host: NetOneshot.play / relay -> HeistNetSync.relay_npc_oneshot(net_id, clip, start_s, speed) (reliable, ordered
## with the entity state) -> client HeistNetSync._rpc_npc_oneshot -> NetOneshot.apply on that NPC's AnimDriver.
class_name NetOneshot
extends RefCounted


## Host: play one-shot `p_clip` on driver `d` (AnimDriver.play_oneshot, not while moving) and send it to the clients.
static func play(d: AnimDriver, p_clip: StringName, duration: float, speed: float, start: float) -> void:
	d.play_oneshot(p_clip, duration, false, speed, start)
	relay(d, p_clip, start, speed)


## Host: tell the clients NPC `d` started `p_clip` at clip time `start` (s) with speed_scale `speed`. No-op on a
## client, for crew bodies, or outside a live heist session (solo, tests without a session: only recorded).
static func relay(d: AnimDriver, p_clip: StringName, start: float, speed: float) -> void:
	if d._npc == null or not Net.is_authority():
		return
	d.last_net_oneshot = [p_clip, start, speed]
	var rt: HeistRuntime = HeistRuntime.of(d._npc)
	if rt != null and rt.net_sync != null:
		rt.net_sync.relay_npc_oneshot(d._npc.net_id, p_clip, start, speed)


## Client: the host's `npc_oneshot` for this driver's NPC. panic_start goes through CivPanic (its chain into cower);
## anything else plays as a one-shot from `start` at `speed` for the rest of the clip, and no turn clip cuts it
## (AnimDriver.net_oneshot_left). A clip the rig lacks plays nothing.
static func apply(d: AnimDriver, p_clip: StringName, start: float, speed: float) -> void:
	if d.player == null or d._npc == null or not d._npc.alive:
		return
	d.last_net_oneshot = [p_clip, start, speed]
	if p_clip == CivPanic.PANIC_START:
		d.civ_panic.start_net(start)
		return
	if not d._has_clip(p_clip):
		return
	var sp: float = maxf(speed, 0.01)
	var length: float = d.player.get_animation("%s/%s" % [AnimDriver.LIBRARY, p_clip]).length
	var dur: float = (length - start) / sp
	if dur <= 0.0:
		return
	d.play_oneshot(p_clip, dur, false, sp, maxf(start, 0.0))
	d.net_oneshot_left = dur
