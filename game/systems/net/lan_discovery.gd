## B6-05 LAN host list (LEAD r286; PD2 has no LAN browser, this is ours ◇). Owner: ENV A. A host with an open lobby
## sends a small UDP beacon every BEACON_S to the broadcast address; a browsing player listens on the same port and
## keeps a list of hosts, dropping one EXPIRY_S after its last beacon. No service, no NAT traversal: LAN only.
## Use (ENV B's lobby UI):
##   var lan: LanDiscovery = LanDiscovery.ensure(get_tree())
##   host:    lan.start_beacon({"name": "Dallas's lobby", "port": game_port, "players": 1, "max_players": 4,
##            "heist": &"dockside_burn"})  # update_beacon(...) when players / heist change; stop_beacon() on close
##   browser: lan.start_listening(); lan.hosts_changed.connect(func(hosts: Array) -> void: ...); stop_listening()
## A host row: {"address": String (sender IP), "port": int, "name": String, "players": int, "max_players": int,
##   "heist": StringName, "version": int, "age_s": float}. Rows with another protocol `version` are dropped.
## `beacon_address` / `discovery_port` are fields so tests (and a VPN LAN) can point it elsewhere.
class_name LanDiscovery
extends Node

signal hosts_changed(hosts: Array)

const NODE_NAME: String = "LanDiscovery"
const DEFAULT_PORT: int = 47431
const BEACON_S: float = 1.0
const EXPIRY_S: float = 3.0
const MAGIC: String = "CAPERWORKS-LAN"
## Bumped with the bring-up protocol: an older / newer build cannot join anyway.
const VERSION: int = HeistLauncher.BRING_UP_VERSION

var discovery_port: int = DEFAULT_PORT
var beacon_address: String = "255.255.255.255"
## The beacon payload (start_beacon / update_beacon); {} = not beaconing.
var beacon: Dictionary = {}
var listening: bool = false

var _send: PacketPeerUDP = null
var _recv: PacketPeerUDP = null
var _beacon_left: float = 0.0
## "address:port" -> row
var _hosts: Dictionary = {}


## The tree's LanDiscovery (created under the root on first use).
static func ensure(tree: SceneTree) -> LanDiscovery:
	var n: LanDiscovery = tree.root.get_node_or_null(NODE_NAME) as LanDiscovery
	if n == null:
		n = LanDiscovery.new()
		n.name = NODE_NAME
		tree.root.add_child(n)
	return n


## Host: beacon `info` ({"name", "port", "players", "max_players", "heist"}) every BEACON_S. False on a socket error.
func start_beacon(info: Dictionary) -> bool:
	stop_beacon()
	_send = PacketPeerUDP.new()
	_send.set_broadcast_enabled(true)
	if _send.set_dest_address(beacon_address, discovery_port) != OK:
		Log.warn(&"net", "LAN beacon: cannot target %s:%d" % [beacon_address, discovery_port])
		_send = null
		return false
	beacon = info.duplicate()
	_beacon_left = 0.0  # the first beacon goes out on the next frame
	return true


func update_beacon(info: Dictionary) -> void:
	beacon.merge(info, true)
	_beacon_left = 0.0


func stop_beacon() -> void:
	if _send != null:
		_send.close()
	_send = null
	beacon = {}


## Browser: listen for beacons. False when the port cannot be bound (another browser on this machine).
func start_listening() -> bool:
	stop_listening()
	_recv = PacketPeerUDP.new()
	if _recv.bind(discovery_port) != OK:
		Log.warn(&"net", "LAN browser: port %d busy" % discovery_port)
		_recv = null
		return false
	listening = true
	return true


func stop_listening() -> void:
	if _recv != null:
		_recv.close()
	_recv = null
	listening = false
	if not _hosts.is_empty():
		_hosts.clear()
		hosts_changed.emit(hosts())


## The hosts heard within EXPIRY_S, sorted by name.
func hosts() -> Array:
	var out: Array = _hosts.values().map(func(r: Dictionary) -> Dictionary: return r.duplicate())
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]) < String(b["name"]))
	return out


func _process(delta: float) -> void:
	_tick_beacon(delta)
	_tick_listen(delta)


func _tick_beacon(delta: float) -> void:
	if _send == null:
		return
	_beacon_left -= delta
	if _beacon_left > 0.0:
		return
	_beacon_left = BEACON_S
	var msg: Dictionary = {"magic": MAGIC, "version": VERSION, "name": str(beacon.get("name", "Crew")),
		"port": int(beacon.get("port", 0)), "players": int(beacon.get("players", 1)),
		"max_players": int(beacon.get("max_players", 4)), "heist": StringName(beacon.get("heist", &""))}
	_send.put_packet(var_to_bytes(msg))


func _tick_listen(delta: float) -> void:
	if _recv == null:
		return
	var changed: bool = false
	while _recv.get_available_packet_count() > 0:
		var bytes: PackedByteArray = _recv.get_packet()
		var ip: String = _recv.get_packet_ip()
		changed = _accept(bytes_to_var(bytes), ip) or changed
	for k: Variant in _hosts.keys():
		var r: Dictionary = _hosts[k]
		r["age_s"] = float(r["age_s"]) + delta
		if float(r["age_s"]) > EXPIRY_S:
			_hosts.erase(k)
			changed = true
	if changed:
		hosts_changed.emit(hosts())


## One beacon: true when it added a host or changed a listed one.
func _accept(v: Variant, ip: String) -> bool:
	if not v is Dictionary:
		return false
	var d: Dictionary = v
	if str(d.get("magic", "")) != MAGIC or int(d.get("version", -1)) != VERSION or int(d.get("port", 0)) <= 0:
		return false
	var key: String = "%s:%d" % [ip, int(d["port"])]
	var row: Dictionary = {"address": ip, "port": int(d["port"]), "name": str(d.get("name", "")),
		"players": int(d.get("players", 1)), "max_players": int(d.get("max_players", 4)),
		"heist": StringName(d.get("heist", &"")), "version": int(d["version"]), "age_s": 0.0}
	var old: Dictionary = _hosts.get(key, {})
	_hosts[key] = row
	if old.is_empty():
		return true
	for f: String in ["name", "players", "max_players", "heist"]:
		if str(old[f]) != str(row[f]):
			return true
	return false


func _exit_tree() -> void:
	stop_beacon()
	stop_listening()
