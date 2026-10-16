# Pistol hip hold levelled (PO 2026-10-16, PO6-11 follow-up)

Windowed (xvfb, 960x540) `ads_seq_capture`. Bore = AimPoint -> Muzzle in camera space (yaw + = muzzle left,
pitch + = up). At full ADS the sights are level by construction, and because the sight line sits above the bore
that line reads about -5..-7 deg pitch. So **level at the hip means the same pitch as the weapon's own ADS
reading**, not 0.

| weapon | hip before (yaw / pitch / roll) | hip after | full ADS |
|---|---|---|---|
| kestrel_p9 | 14.5 / +10.4 / -1.1 | 2.8 / -6.0 / 0.4 | 0.0 / -6.2 / 0 |
| marshal_357 (revolver) | 14.4 / +9.4 / -1.1 | 2.8 / -7.0 / 0.4 | 0.0 / -7.2 / 0 |
| sparrow_mp | 14.5 / +11.4 / -1.1 | 2.8 / -5.1 / 0.4 | 0.0 / -5.2 / 0 |
| warden_45 | 14.5 / +11.5 / -1.1 | 2.8 / -4.8 / 0.4 | 0.0 / -5.1 / 0 |
| wren_380 | 14.5 / +10.7 / -1.1 | 2.8 / -5.8 / 0.4 | 0.0 / -5.9 / 0 |
| akimbo_warden_45 (right gun) | 2.1 / -2.9 / 5.2 | 1.3 / -3.8 / 1.3 | 1.3 / -4.0 / 3.0 |

Tweak: `set_hip_rot_deg` pistol / revolver `(14, 3, -4)` -> `(-2.5, -8.5, -3.5)`; new akimbo entry `(-1, -1, -4)`.
The guard is `test_p_pistol_hold.gd:test_hip_bore_level`: hip pitch within 2.5 deg of ADS, and hip yaw in [-1, 6].
It fails on the old values.

The thumb wrap is D's grip pose and is still open with D.

## Round 2 (LEAD review of before_after_sheet.png)
- Hip framing: `set_hip_offset` for pistol and revolver went from (0.025, -0.015, 0.05) to (0.01, 0.02, 0.05), i.e.
  3.5 cm up and 1.5 cm in. The firing hand is now on screen, and the bore numbers are unchanged (table above).
- Akimbo ADS: the left gun was already upright, but it sat 16 cm left and only 31 cm from the eye, so it was
  28 deg off-axis and showed its side. Two fixes:
  - FpViewmodelOffhand.align turns the left gun toward the right gun's orientation by ads_weight.
  - `_late_align` centres the crosshair between the two sights (PD2), with `set_ads_offset_z` akimbo -0.08 and
    `set_ads_rot_deg` akimbo (0, -1.3, -3) for the clip's 3 deg roll.
- Full ADS result: both guns read yaw 0.2 / pitch -4.0 / roll 0.0, at +-8.2 cm and 38.5 cm out.
- Guard: test_p_akimbo_offhand.gd:test_ads_both_guns_upright_and_centred.
- round2_sheet.png columns: round 1 hip | round 2 hip | round 2 full ADS. The akimbo row shows the ADS before and after.
