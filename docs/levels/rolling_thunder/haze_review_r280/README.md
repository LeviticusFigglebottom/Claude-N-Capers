# RT haze fix: opengl3 review shots (r280, ENV C)

Rendered with the Compatibility renderer (`--rendering-driver opengl3`, 1280x720) by
`game/world/tools/rt_haze_review.tscn` from the live map in a HeistRuntime (seed 1, Routine).

| File | What |
|---|---|
| `before_rc_ext_junction.jpg` | r277 environment (height fog): the beige wash |
| `rc_ext_junction.jpg` | after: depth fog from 35 m, LUT blacks held, ambient 0.7, concrete Skyway deck |
| `street_3m.jpg`, `street_10m.jpg` | a street NPC (patrol officer) at 3 m and 10 m |
| `diner_3m.jpg`, `rc_diner_dining.jpg` | the diner interior (no haze) with customers |
| `rc_carpark_booth.jpg` | the attendant booth interior (no haze) |

The diner and booth shots are from the run before the Skyway deck's finish changed (metal to concrete), which does
not show in them.
