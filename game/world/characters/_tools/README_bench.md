# Character bench on a real GPU (D-132: is D1 worth landing?)

`bench_crowd.tscn` draws N animating characters in front of a camera and prints one `[BENCH]` line per case, with
draw calls per frame, primitives, mean / p95 frame time and texture / video memory. Two preset cases come from the
D-130 performance audit (`docs/art/d130_character_perf_audit.md`):

- `gn34`: Gallery Night stealth at Cataclysm, 30 NPCs and 4 crew.
- `loud50`: a loud Cataclysm fight, 50 police, specials, civilians and crew.

Both play the upper-body layer, between 4 and 45 m from the camera, with one shadowed sun.

D1 (the per-node material merge) is parked on the branch `wip/d-d1-merge`, so "D1 off" and "D1 on" are two runs on
two checkouts. Use the same machine, window size and power settings for both.

## Steps

From the repository root, with Godot 4.7.2 (`godot` below), and the Forward+ or Compatibility renderer you want to
measure:

```sh
# 1. D1 OFF: the current branch (env/d-art or trunk)
git checkout env/d-art
godot --path game --import                     # once, after a checkout
godot --path game --resolution 1920x1080 res://world/characters/_tools/bench_crowd.tscn -- --preset=both --frames=600

# 2. D1 ON: the parked branch (its scenes are already assembled with merged meshes)
git checkout wip/d-d1-merge
godot --path game --import
godot --path game --resolution 1920x1080 res://world/characters/_tools/bench_crowd.tscn -- --preset=both --frames=600
```

Add `--rendering-driver opengl3` to measure the Compatibility renderer (what we ship). Leave it out for Forward+.
Each run takes about a minute and prints two lines, for example:

```
[BENCH] preset=gn34 n=34 lod=on layer=true near=4 far=45 frame_ms mean=… p95=… process_ms=… draws=… prims=… objects=… tex_mem_mb=… video_mem_mb=…
[BENCH] preset=loud50 n=50 …
```

Send all four lines (2 cases × off / on) with the GPU model and the renderer. The bench disables vsync and the FPS
cap itself.

## What it measured here (llvmpipe, CPU rendering, 1280x720)

| Case | D1 off | D1 on |
|---|---|---|
| gn34 | 738 draws, 829 ms | 499 draws (-32 %), 814 ms |
| loud50 | 2524 draws | 2224 draws (-12 %) |
| VRAM, gn34 | 118 MB textures / 187 MB video | 147 / 233 MB |

On llvmpipe, frame time barely moves with the draw count, so draw calls aren't the bottleneck there. D1 lands
only if a real GPU shows that they are (D-132 addendum 2).

Other modes: `-- --stats --ids=a,b` prints per-character surfaces, triangles per LOD and bones. `-- --ids=… --n=…`
with `--lod=off` / `--switch=m` runs custom cases. The full flag list is in `bench_crowd.gd`'s header.
