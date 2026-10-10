"""Procedural human head, sculpted as a signed distance field (sdf.py) from anatomical landmarks.

Local frame (metres): +X = character's left, -Y = forward (face), +Z = up; origin between the eyes'
centres at eye height on the mid-sagittal plane, roughly. Style parameters:
  exaggeration  >1 squares the jaw, deepens the brow, enlarges chin/cheekbones (graphic styles)
  asymmetry     0..1 applies seeded millimetre-scale left/right differences (photoreal)
"""

from __future__ import annotations

import math

import numpy as np

import sdf as S

EYE_R = 0.0120          # eyeball radius
EYE_X = 0.0318          # half inter-pupillary distance
EYE_Y = -0.0705         # eyeball centre depth
EYE_Z = 0.0


def superellipsoid(c, r, n=2.6, rot=None):
    """Ellipsoid whose horizontal (x-y) cross-section is a superellipse |x|^n + |y|^n = 1 (n > 2: broad,
    rounded front instead of a pointed prow). First-order distance (value / |gradient|)."""
    r = np.asarray(r, np.float32)

    def fn(p):
        q = S._local(p, c, rot) / r
        ax, ay, az = np.abs(q[..., 0]) + 1e-9, np.abs(q[..., 1]) + 1e-9, q[..., 2]
        rho = (ax ** n + ay ** n) ** (1.0 / n)
        k = np.sqrt(rho * rho + az * az) + 1e-9
        g = rho ** (1.0 - n)
        gx = (rho / k) * g * ax ** (n - 1) / r[0]
        gy = (rho / k) * g * ay ** (n - 1) / r[1]
        gz = az / (k * r[2])
        return ((k - 1.0) / np.maximum(np.sqrt(gx * gx + gy * gy + gz * gz), 1e-6)).astype(np.float32)
    ext = np.full(3, r.max()) if rot is not None else r
    return S.custom(fn, *S._bbox(c, ext))


class Head:
    def __init__(self, exaggeration: float = 1.0, asymmetry: float = 0.0, seed: int = 0, neck_r: float = 0.057):
        self.E = exaggeration
        self.neck_r = neck_r      # head-local neck radius (the caller compensates for the head's scale)
        self.rng = np.random.Generator(np.random.PCG64(seed))
        self.asym = asymmetry
        self.field = S.SDF()
        self.eyes: list[tuple[float, float, float]] = []
        self._build()

    # small seeded jitter (photoreal asymmetry), metres
    def j(self, amt: float = 0.0012) -> float:
        return float(self.rng.uniform(-amt, amt)) * self.asym

    def _build(self) -> None:
        E = self.E
        f = self.field
        e1 = E - 1.0
        # ---- cranium & forehead
        f.add(S.ellipsoid((0, 0.008, 0.030), (0.0735, 0.102, 0.089)))
        f.add(S.ellipsoid((0, -0.030, 0.045), (0.064, 0.064, 0.052)), k=0.02)   # frontal bossing
        # ---- brow ridge (glabella + arches): a real shelf over the orbits so the eyes sit in shadow-catching
        # sockets; the temporal line carries it round the side of the forehead
        bz = 0.017
        for s in (-1, 1):
            f.add(S.capsule((0, -0.0905 - 0.004 * e1, bz), (s * (0.047 + 0.004 * e1), -0.079 - 0.003 * e1, bz + 0.004),
                            0.0090 * (1 + 0.35 * e1)), k=0.014)
            f.add(S.capsule((s * 0.047, -0.079, bz + 0.004), (s * 0.058, -0.060, bz + 0.009), 0.0050), k=0.016)
        # ---- mid face (maxilla) and cheekbones. Superellipse cross-sections keep the front of the face broad
        # and rounded (no centreline prow); the malar fat pads fill the cheeks at three-quarter view.
        f.add(superellipsoid((0, -0.033, -0.036), (0.053, 0.061, 0.050), 2.35), k=0.02)
        for s in (-1, 1):
            # zygoma body: the corner where the front plane of the face turns into the side plane
            f.add(S.ellipsoid((s * (0.045 + self.j()), -0.060 + self.j(), -0.017),
                              (0.0150 * (1 + 0.3 * e1), 0.019, 0.0115 * (1 + 0.2 * e1)),
                              S.rot_xyz(0.0, 0.0, -s * 0.45)), k=0.02)
            # zygomatic arch running back to the ear
            f.add(S.capsule((s * 0.053, -0.046, -0.017), (s * 0.063, -0.010, -0.019), 0.0050 * (1 + 0.2 * e1)), k=0.018)
            f.add(S.ellipsoid((s * 0.034, -0.068, -0.030), (0.017, 0.015, 0.016)), k=0.02)    # malar fat (soft)
            # lateral orbital rim (frontal process of the zygoma): closes the temple-to-cheek hollow
            f.add(S.capsule((s * 0.0545, -0.064, 0.020), (s * 0.0525, -0.060, -0.012), 0.0065), k=0.018)
        # ---- mandible: ramus down from the ear to a defined jaw angle (gonion), body forward to the chin
        jw = 1.0 + 0.16 * e1
        f.add(superellipsoid((0, -0.026, -0.071), (0.054 * jw, 0.062, 0.043), 2.6), k=0.02)
        for s in (-1, 1):
            go = (s * 0.0545 * jw, 0.004, -0.084 - 0.003 * e1)                                   # jaw angle
            jr = 0.0092 * (1 + 0.25 * e1)
            f.add(S.capsule((s * 0.057 * jw, 0.012, -0.030), go, jr * 0.95), k=0.022)            # ramus
            f.add(S.capsule(go, (s * (0.028 * jw + self.j()), -0.072, -0.107 - 0.004 * e1), jr), k=0.024)   # body
        for s in (-1, 1):   # masseter / buccal fill so the lower face is not gaunt (broad, soft)
            f.add(S.ellipsoid((s * 0.043 * jw, -0.018, -0.050), (0.019, 0.032, 0.033)), k=0.024)
            # side of the face in front of the ear (temporal fossa / TMJ): bridges cranium, arch and ramus so the
            # side plane is continuous instead of a pit behind the cheekbone
            f.add(S.ellipsoid((s * 0.052 * jw, -0.004, -0.026), (0.014, 0.028, 0.030)), k=0.025)
        # chin: a broad rounded block (superellipse), not a wedge
        f.add(superellipsoid((0, -0.0855 - 0.006 * e1, -0.106 - 0.004 * e1),
                             (0.025 * (1 + 0.4 * e1), 0.017, 0.0175 * (1 + 0.25 * e1)), 2.8), k=0.018)
        # ---- muzzle and lips
        f.add(S.ellipsoid((0, -0.066, -0.0705), (0.041, 0.034, 0.028)), k=0.018)   # muzzle barrel
        f.add(S.ellipsoid((0, -0.0962, -0.0690), (0.0235, 0.0108, 0.0068), S.rot_xyz(-0.25, 0, 0)), k=0.005)    # upper lip
        f.add(S.ellipsoid((0, -0.0940, -0.0818), (0.0205, 0.0112, 0.0084), S.rot_xyz(0.3, 0, 0)), k=0.005)     # lower lip
        f.sub(S.ellipsoid((0, -0.106, -0.0752), (0.0205, 0.016, 0.0010)), k=0.0016)
        for s in (-1, 1):
            f.sub(S.sphere((s * 0.0212, -0.0925, -0.0752), 0.0008), k=0.008)     # mouth corners (soft)
        # philtrum groove + mentolabial sulcus
        for s in (-1, 1):
            f.add(S.capsule((s * 0.0042, -0.1040, -0.0585), (s * 0.0056, -0.1030, -0.0662), 0.0017), k=0.003)
        f.sub(S.capsule((0, -0.1060, -0.0595), (0, -0.1062, -0.065), 0.0016), k=0.003)
        f.sub(S.ellipsoid((0, -0.0985, -0.0935), (0.016, 0.004, 0.0035)), k=0.006)
        # ---- nose
        nl = 1.0 + 0.12 * e1
        tip = (0 + self.j(0.0008), -0.1165 * nl + 0.0005, -0.0425 * nl)
        f.add(S.ellipsoid((0, -0.088, -0.026), (0.0135, 0.017, 0.026)), k=0.012)            # nose body
        f.add(S.round_cone((0, -0.0925, 0.003), tip, 0.0058, 0.0075), k=0.008)              # dorsum
        f.add(S.sphere((tip[0], tip[1] + 0.0024, tip[2] - 0.0012), 0.0080), k=0.007)          # tip
        for s in (-1, 1):
            f.add(S.ellipsoid((s * 0.0128, -0.0995, -0.0478), (0.0064, 0.0082, 0.0060),
                              S.rot_xyz(0, 0, s * 0.35)), k=0.006)                           # alae
        f.add(S.capsule((tip[0], tip[1] + 0.003, tip[2] - 0.0085), (0, -0.1025, -0.0565), 0.0040), k=0.004)  # columella
        for s in (-1, 1):
            f.sub(S.ellipsoid((s * 0.0078, -0.1075, -0.0548), (0.0040, 0.0068, 0.0026), S.rot_xyz(0.2, 0, s * 0.35)),
                  k=0.0018)                                                                  # nostrils
            # alar crease
            f.sub(S.capsule((s * 0.0212, -0.0955, -0.042), (s * 0.0212, -0.0965, -0.052), 0.0007), k=0.004)
        # ---- neck: a plain cylinder whose (world) radius is fixed by the caller so it fits the shirt collar,
        # soft sternocleidomastoids that stay inside that radius where the collar is, a subtle Adam's apple
        nr = self.neck_r
        ay = 0.016                               # neck axis depth
        f.add(S.capsule((0, 0.016, -0.065), (0, 0.016, -0.30), nr), k=0.02)
        for s in (-1, 1):
            x1 = 0.020
            y1 = ay - math.sqrt(max((nr - 0.0105) ** 2 - x1 * x1, 1e-6))
            f.add(S.capsule((s * 0.056, 0.026, -0.050), (s * x1, y1, -0.215), 0.0085), k=0.018)
        f.add(S.ellipsoid((0, ay - nr - 0.0005, -0.132), (0.0105, 0.0075, 0.014)), k=0.016)   # Adam's apple
        # ---- ears
        for s in (-1, 1):
            R = S.rot_xyz(-0.22, 0.0, -s * 0.30)
            c = np.array((s * 0.0715, 0.013 + self.j(), -0.0125 + self.j()), np.float32)
            ear = S.ellipsoid(c, (0.0075, 0.0185, 0.0305), R)
            out_ax = R[:, 0] * s       # outward axis
            fwd = R[:, 1]
            up = R[:, 2]
            ear = S.subtract_prim(ear, S.ellipsoid(c + out_ax * 0.0068 - fwd * 0.0015 - up * 0.004,
                                                   (0.0058, 0.0108, 0.0150), R), k=0.0022)   # concha
            ear = S.subtract_prim(ear, S.ellipsoid(c + out_ax * 0.0075 + fwd * 0.004 + up * 0.009,
                                                   (0.0035, 0.0125, 0.017), R), k=0.0015)    # scapha
            f.add(ear, k=0.0045)
        # ---- eyes: sockets, lids with almond aperture
        for s in (-1, 1):
            ec = np.array((s * EYE_X + self.j(0.0006), EYE_Y, EYE_Z + self.j(0.0006)), np.float32)
            self.eyes.append(tuple(float(v) for v in ec))
            # orbit hollow above the lid (upper lid crease) and socket
            f.sub(S.ellipsoid(ec + np.array((s * 0.002, -0.0145, 0.0095), np.float32), (0.0155, 0.0065, 0.0055)), k=0.007)
            # orbital depth: recess the whole eye region under the brow shelf
            f.sub(S.ellipsoid(ec + np.array((s * 0.002, -0.0155, 0.004), np.float32), (0.0190, 0.0070, 0.0105)), k=0.010)
            f.sub(S.sphere(ec, EYE_R + 0.0016), k=0.004)
            # lid shell, front hemisphere only
            shell = S.shell(S.sphere(ec, EYE_R + 0.0019), 0.0015)
            front = S.custom(lambda p, y0=float(ec[1]) + 0.004: (p[..., 1] - y0).astype(np.float32),
                             ec - 0.03, ec + 0.03)
            lid = S.intersect(shell, front, 0.002)
            lid = S.intersect(lid, S.ellipsoid(ec + np.array((0, -0.004, 0), np.float32), (0.0185, 0.02, 0.0145)), 0.003)
            f.add(lid, k=0.0035)
            # almond aperture prism (upper arc higher; outer corner a little higher: canthal tilt)
            tilt = s * math.radians(5.0 + 3.0 * (self.E - 1.0))
            Rt = S.rot_xyz(0.0, tilt, 0.0)
            open_u = 0.0050 / (1 + 0.5 * (self.E - 1.0))   # graphic styles narrow the eye
            open_l = 0.0038
            hw = 0.0150

            def aperture(p, ec=ec, Rt=Rt, open_u=open_u, open_l=open_l, hw=hw):
                q = (p - ec) @ Rt
                x, y, z = q[..., 0], q[..., 1], q[..., 2]
                ru = 0.0168
                up = np.sqrt((x / hw) ** 2 + ((z + ru - open_u) / ru) ** 2) - 1.0   # upper arc region
                rl = 0.0135
                lo = np.sqrt((x / hw) ** 2 + ((z - rl + open_l) / rl) ** 2) - 1.0   # lower arc region
                d2 = np.maximum(up, lo) * 0.012
                dy = y + 0.002                    # only in front of the eye centre
                return np.maximum(d2, dy).astype(np.float32)
            f.sub(S.custom(aperture, ec - 0.03, ec + 0.03), k=0.0012)

    def mesh(self, voxel: float, smooth_iters: int):
        lo = (-0.098, -0.135, -0.30)
        hi = (0.098, 0.125, 0.128)
        return self.field.mesh(lo, hi, voxel, smooth_iters)

    def hair_field(self) -> S.SDF:
        """Short hair shell (2.5 mm proud of the scalp) below the cap: sides, back and sideburns."""
        head = self.field
        h = S.SDF()

        def fn(p):
            d = head.eval(p) - 0.0019
            x, y, z = p[..., 0], p[..., 1], p[..., 2]
            ax = np.abs(x)
            # region: above the nape line, behind the temples, sideburn in front of the ear
            zb = np.interp(y, [0.0, 0.05], [-0.026, -0.062])            # sideburn bottom -> nape line
            bottom = zb - z
            yf = -0.036 + 0.014 * np.clip((0.04 - z) / 0.03, 0, 1)      # temple hairline -> sideburn front
            side = 0.040 - ax
            region = np.maximum(np.maximum(bottom, -(y - yf)), np.minimum(side, -(y - 0.02)))
            # keep the ears bare
            ear = np.sqrt(((ax - 0.072) / 0.016) ** 2 + ((y - 0.013) / 0.026) ** 2 + ((z + 0.013) / 0.036) ** 2) - 1
            region = np.maximum(region, -ear * 0.01)
            return np.maximum(d, region).astype(np.float32)
        h.add(S.custom(fn, (-0.1, -0.08, -0.07), (0.1, 0.13, 0.12)))
        return h
