# RT phase 2: the mixer move, north route + crash stop (r284, ENV C)

`game/world/tools/rt_mixer_capture.tscn -- --seed=2 --crash --route=north --step=0.5`, opengl3, 960x540. The signals
are not rigged: the convoy runs the green, the crash stop fires the mixer move at once (t = 9 s), the Tannery gate
swings open, the mixer turns out of it on its 9 m arc (yaw 0 -> 18.9 -> 48.5 -> 78.2 -> 90 deg, pitch / roll 0) and
runs along Tannery onto `north_crash/MixerStop` (-7.9, 0, 2.8), against the lead car (t = 15.5 s). Log per frame in
`rt_mixer_log.txt`.
