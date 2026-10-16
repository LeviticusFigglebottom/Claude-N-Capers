# D-116: the carried loot bag at Back/Socket (third person, windowed, Glasshouse)
carry_bag_walk at 0.55 s. crew_rook carries the light bag, crew_sable the medium and crew_dutch the heavy
(world/props/loot_bag/prop_loot_bag_<size>.tscn under Back/Socket, at character_spec.gd BACK_BAG_OFFSETS[size]).
The capture tool's `--bags=light,medium,heavy` option does what A's AnimDriver._update_bag_visual does.
- `carry_bag_walk_front.png`: 3/4 front. The bag shows over the left shoulder, behind the left hand on the strap.
- `carry_bag_walk_back.png`: from behind (`--turn=180`). Diagonal, from the left shoulder blade down to the right hip.
- `carry_bag_walk_side.png`: profile (`--turn=90`). The bag's top (straps) lies against the back.
Back/Socket = the bag's bottom-centre pivot for the medium bag. Light +0.05 m and heavy -0.05 m along socket Y keep
their tops on the back as well.
