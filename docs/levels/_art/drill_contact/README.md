# Drill contact close-ups (PO playtest 2026-10-16: the thermal lance stopped short of the DB strongroom door)

Cause: four DrillPoint markers stood 0.12-0.50 m off their target leaf (the device sits at the marker, tip at its
origin). Fix bd5f09dc: each marker 0.01 m off the leaf face. Re-probe (ray along -Z to the leaf): DB StrongroomDrill
0.010, ND VaultDrill 0.010, GN VaultDrill 0.010, GN ServerDoorDrill 0.010 (saws and the GH safe drill were flush).
The thermal device carries `Sparks` (world/vfx/drill_sparks.gd) and a hidden `Glow` light at the tip; ENV A toggles
them with the device state. These shots switch them on in place of that toggle.

Rendered by `res://world/tools/capture/drill_capture.tscn` (opengl3, xvfb, 1280x720), side view of the contact point:
`db_strongroom.jpg`, `nd_vault.jpg`, `gn_vault.jpg` (thermal lance), `gn_server.jpg` (drill on the server door).
