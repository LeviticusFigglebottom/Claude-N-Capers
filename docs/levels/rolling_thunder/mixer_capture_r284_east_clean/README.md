# RT phase 2: the mixer move, east route + clean stop, after the path fix (r284, ENV C)

The same capture as `mixer_capture_r280/` (seed 1, `--step=0.5`) after c0fa5875's 9 m arcs: the turn out of the gate
now runs yaw 0 -> 14.8 -> 44.4 -> 74 -> 90 deg over ~1.5 s (before: 28.7 -> 90 in 0.5 s, the truck pivoting almost on
the spot); pitch / roll 0 throughout. Log per frame in `rt_mixer_log.txt`.
