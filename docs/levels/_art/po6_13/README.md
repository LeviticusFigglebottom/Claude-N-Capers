# PO6-13 muzzle flash tone-down (ENV C, 2026-10-15, D-114 §8)

Changes (`game/world/vfx/muzzle_flash.gd`, `muzzle_fx.gd`):
- Size: `SIZE_K = 0.6` on every class shape (proportions kept). Long guns (rifle/lmg/sniper/shotgun) also get a
  brake: forward cone x0.75 plus two side-port jets (`PortL`/`PortR` quads), so the long-gun flash is ~0.45 of D-113.
- Duration: `FLASH_S` 0.05 -> 0.034 s (3 -> 2 frames at 60 fps). Sparks roughly halved (count and speed).
- Third-person light: energy 4.5 -> 2.2, life 0.06 -> 0.035 s, range 5 -> 3.5 m.
- API: `flash(size, suppressed, weapon_class, variant, brake = -1)`; -1 = by class, 0 = bare muzzle, 1 = brake.
  The root sits at the outermost `Muzzle` marker, i.e. the brake's front face once ENV B ships brake meshes.
- ENV P's FP light is P's own: it needs the same ~half energy/life cut on P's side.

Evidence (windowed, opengl3 under xvfb):
- `tp_before_flash_sheet.jpg` / `tp_after_flash_sheet.jpg`: VfxGoreCapture `--d113=flash` (glasshouse lighting).
- `tp_before_after_crop.png`: the same shot frame side by side (left before, right after).
- `fp_before_fx_sheet.jpg` / `fp_after_fx_sheet.jpg` and `fp_before_after_sheet.jpg`: ENV P's
  `tests/p/_review/fx_capture.tscn` (corsair_ar, kestrel_p9, mule_12), top row before, bottom row after.
