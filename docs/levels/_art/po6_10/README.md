# PO6-10 FP "black gun" (ENV C, 2026-10-15)

Change (`tools/texgen/presets/gsr.py`, `materials/{alu_anodized_black,steel_blued,metal_matte}.py`): coated finishes are
dielectrics. Preset param `coat_metal` (anodized 0.10, blued 0.12, matte 0.15), roughness 0.45-0.55; worn/holster-wear
spots stay bare metal (metal 1). Albedo keeps the D-038 lift. Bare steel, brass and chrome stay metallic. Rebuilt with
`--check-determinism` (12/12 byte-identical); `c texgen` 10/10.

ENV P's `tests/p/_review/vm_light_probe.tscn` (Glasshouse spawn, opengl3/xvfb), mean luminance 0-255 of the viewmodel
render with alpha coverage (same formula as the probe, computed from its saved frames):

| variant | before (gun / arms) | after (gun / arms) |
|---|---|---|
| base (as shipped) | 8.0 / 89.5 | **36.4** / 89.5 |
| metal0 (diagnostic) | 7.8 / 92.2 | 35.4 / 92.2 |
| unshaded (albedo only) | 87.1 / 92.5 | 87.1 / 92.5 |
| arms_mat (gun with the skin material) | 83.0 / 91.0 | 83.0 / 90.9 |

Reading: metal is no longer a factor (base ~ metal0). With the same lighting, the arms' material on the gun gives 83,
and the skin material fed the gun's albedo gave 39 before; so what is left between 36 and the arms' ~90 is the black
albedo itself (dark values are compressed by the tonemapper), not the shading. Reaching ~80 needs a lighting answer on the
viewmodel (P: fill light / exposure for the viewmodel layer, the probe's `omni` / `env_color` variants) or a lighter, no
longer black, albedo.

Lit close-up: `vm_before_after_closeup.jpg` (left before, right after).
