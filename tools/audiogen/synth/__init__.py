"""CAPERWORKS procedural audio synth core (numpy + scipy). No samples, ever.

Modules: core (rate/time/rng), osc (band-limited oscillators, FM), noise, env (ADSR, curves),
filters (RBJ biquads, time-varying biquad, TPT state-variable), fx (waveshaping, delay,
generated-IR convolution reverb, pan, doppler, limiter, ducking), granular, loudness
(ITU-R BS.1770 LUFS + true peak), wavio (WAV 48k/24 and OGG export), seq (music sequencer + drums).
"""
