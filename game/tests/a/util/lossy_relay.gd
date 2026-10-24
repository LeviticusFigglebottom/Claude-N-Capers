## P6 lossy network relay (test only, never shipped): a UDP proxy between loopback clients and the host's ENet port
## that adds one-way latency, jitter and packet loss in both directions, so the co-op soaks run under a bad link.
## Clients join the relay's port; it opens one upstream socket per client address (ENet keys peers by address) and
## forwards both ways after `delay_ms` +- `jitter_ms`, dropping `loss` of the packets. Polled every frame by the host.
class_name LossyRelay
extends Node

var listen_port: int = 0
var host_port: int = 0
var delay_ms: float = 60.0
var jitter_ms: float = 10.0
var loss: float = 0.05
var forwarded: int = 0
var dropped: int = 0

var _down: PacketPeerUDP = null
## "ip:port" of a client -> {"up": PacketPeerUDP, "ip": String, "port": int}
var _clients: Dictionary[String, Dictionary] = {}
## [due_ms, packet, to_client_key ("" = upstream of `from_key`), from_key]
var _queue: Array[Array] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Bind on `p_listen` (0 = pick a free port), forward to 127.0.0.1:`p_host`. Returns the listen port, -1 on failure.
func start(p_listen: int, p_host: int, p_delay_ms: float, p_jitter_ms: float, p_loss: float, seed_value: int = 1) -> int:
	host_port = p_host
	delay_ms = p_delay_ms
	jitter_ms = p_jitter_ms
	loss = p_loss
	_rng.seed = seed_value
	_down = PacketPeerUDP.new()
	for i: int in 12:
		var port: int = p_listen if p_listen > 0 else 50000 + _rng.randi_range(0, 14000)
		if _down.bind(port, "127.0.0.1") == OK:
			listen_port = port
			return port
	return -1


func _process(_delta: float) -> void:
	if _down == null:
		return
	var now: int = Time.get_ticks_msec()
	while _down.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _down.get_packet()
		var key: String = "%s:%d" % [_down.get_packet_ip(), _down.get_packet_port()]
		if not _clients.has(key):
			var up: PacketPeerUDP = PacketPeerUDP.new()
			up.bind(0, "127.0.0.1")
			up.set_dest_address("127.0.0.1", host_port)
			_clients[key] = {"up": up, "ip": _down.get_packet_ip(), "port": _down.get_packet_port()}
		_enqueue(now, pkt, "", key)
	for key: String in _clients:
		var up: PacketPeerUDP = _clients[key]["up"]
		while up.get_available_packet_count() > 0:
			_enqueue(now, up.get_packet(), key, key)
	var keep: Array[Array] = []
	for e: Array in _queue:
		if int(e[0]) > now:
			keep.append(e)
			continue
		var c: Dictionary = _clients.get(String(e[3]), {})
		if c.is_empty():
			continue
		if String(e[2]) == "":
			(c["up"] as PacketPeerUDP).put_packet(e[1] as PackedByteArray)
		else:
			_down.set_dest_address(String(c["ip"]), int(c["port"]))
			_down.put_packet(e[1] as PackedByteArray)
		forwarded += 1
	_queue = keep


func _enqueue(now: int, pkt: PackedByteArray, to_client: String, from_key: String) -> void:
	if _rng.randf() < loss:
		dropped += 1
		return
	var d: float = maxf(delay_ms + _rng.randf_range(-jitter_ms, jitter_ms), 0.0)
	_queue.append([now + int(d), pkt, to_client, from_key])


func stop() -> void:
	for key: String in _clients:
		(_clients[key]["up"] as PacketPeerUDP).close()
	_clients.clear()
	if _down != null:
		_down.close()
	_down = null
