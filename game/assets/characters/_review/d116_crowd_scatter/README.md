# D-116 civilian panic: Gallery Night crowd before / after

* `before/scatter_sheet.png`: env/d-art with trunk's AnimDriver. `after/scatter_sheet.png`: a local scratch merge of
  env/d-art with env/a-core 2b97d701 (A's civ panic wiring). Both use `render_crowd_scatter.tscn`, Cataclysm, seed
  1002, the alarm raised at 0 s, shots at 0 / 0.3 / 0.6 / 1.0 / 1.6 s on the largest civilian cluster. At this distance
  the flee variants' upper bodies are too small to tell apart, so the sheets look alike; the counts below are the
  evidence.
* `cov_after/anim_coverage.json`: `loud_anim_coverage.tscn` on the same scratch build (GN, Cataclysm, 150 s), compared
  with `../d_loud_cov/gn_h/anim_coverage.json` (env/d-art, Lethal, 300 s). Civilian clip seconds, 19 bodies each:

| clip | before | after |
|---|---|---|
| cower / cower_b / cower_c | 3257 / 0 / 0 | 441 / 425 / 764 |
| flee / flee_b / flee_c | 50 / 0 / 0 | 7.6 / 24 / 26 |
| panic_start | - | 0 (never seen: ENV A to check) |
