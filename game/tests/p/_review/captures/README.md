# ENV P review captures (PO lane 3, 2026-10-13)

Windowed, real X input (xdotool), `--fixed-fps 60`. GL compatibility renderer unless noted (Vulkan/Forward+ is the
shipping look; lighting differs slightly).

- `nd_real_menu_sheet_1280x720.png`: night_deposit entered the way a player does. Main menu, hub, planning, heist
  select, briefing, pre-planning and loadout lead to Start Heist. Then mask-up by holding G, walk, sprint,
  sprint→fire (sprint ends, shot after 0.4 s), ADS and fire, reload and crouch.
  `res://tests/p/_review/po_playthrough.tscn -- --out=DIR --po_heist=night_deposit --no_kerb`.
  The reload step failed in this run only because the harness tapped R inside one ~0.1 fps frame; it now holds R.
- `nd_10_masked.png`, `nd_13_ads.png`, `nd_14_ads_fire.png`: full-size frames from that run.
- `knife_melee_unitmap.png`: B's folding-knife model on the `melee_knife` set with its framing offset: quick swing
  (top row), charge and charged swing (bottom). `vm_probe.tscn -- --melee --melee_id=melee.folding_knife`.
- `ar_hip_glasshouse_vulkan.png`: corsair_ar hip in live Glasshouse (Vulkan) after the viewmodel lighting and
  framing fixes.
- `db_real_menu_sheet_1280x720.png`: the same run on dockside_burn (loud start, so already masked). Every step passed,
  reload included. The sprint frames show ~2.6 m/s because the player is pressed against a wall; open-field sprint
  reaches 5.75 m/s in ~0.3 s (headless check).
