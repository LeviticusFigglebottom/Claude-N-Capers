## PO6-05 (lead r213): loot stowed in a safe has art that fits inside the safe body, on every heist map.
extends TestCase

const MAPS: Array[String] = [
	"res://world/heists/glasshouse/glasshouse.tscn", "res://world/heists/night_deposit/night_deposit.tscn",
	"res://world/heists/shadow_ledger/shadow_ledger.tscn", "res://world/heists/dockside_burn/dockside_burn.tscn",
	"res://world/heists/gallery_night/gallery_night.tscn",
]
const TOL_M: float = 0.005


func test_stowed_loot_art_fits_its_safe() -> void:
	var checked: int = 0
	for path: String in MAPS:
		if not ResourceLoader.exists(path):
			continue
		var map: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		add_child(map)
		for n: Node in map.find_children("*", "", true, false):
			if not (n is Safe):
				continue
			var safe: Node3D = n as Node3D
			var inv: Transform3D = safe.global_transform.affine_inverse()
			var body: AABB = _merged(safe.get_node_or_null("Visual"), inv)
			for c: Node in safe.get_children():
				if not LcTargets.is_loot_spawn(c):
					continue
				var art: AABB = _merged(c.get_node_or_null("Visual"), inv)
				if art.size == Vector3.ZERO or body.size == Vector3.ZERO:
					continue
				checked += 1
				var grown: AABB = body.grow(TOL_M)
				assert_true(grown.encloses(art), "%s: %s art %s does not fit the safe body %s" % [
					path.get_file(), map.get_path_to(c), art, body])
		map.queue_free()
		await wait_frames(1)
	assert_true(checked >= 2, "checked the stowed loot (%d)" % checked)


func _merged(root: Node, inv: Transform3D) -> AABB:
	var out: AABB = AABB()
	if root == null:
		return out
	var first: bool = true
	for m: Node in root.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = m as VisualInstance3D
		var a: AABB = (inv * vi.global_transform) * vi.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out
