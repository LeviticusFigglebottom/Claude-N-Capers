# RT phase 2: the clean-stop mixer move (r280, ENV C)

`game/world/tools/rt_mixer_capture.tscn`, opengl3, 960x540, seed 1 (route east, layout `east_clean`): signals rigged,
the convoy brought in, one frame per second from under the Skyway, south-west of the junction. `rt_mixer_log.txt` has
the mixer's position, the layout and the Tannery gate's state per frame: the convoy drives in and stops, 3 s later
A's `_mixer_move` swings `SiteTanneryGate` open and drives `Mixer` along `east_clean/MixerPath`, out of the gate,
along Tannery and onto its `MixerStop` (12.5, 0, -3.6) across the convoy's front (t = 12 s .. 21 s).
