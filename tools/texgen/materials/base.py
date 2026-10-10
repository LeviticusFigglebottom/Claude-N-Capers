"""Shared generator plumbing: context, map container, weathering and final encoding."""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from texgen import noise, ops, orm


@dataclass
class Ctx:
    """Everything a material generator may read. Colours/parameters come from the preset."""

    lib_id: str
    size: int
    tile_m: float
    seed: int
    params: dict
    rules: dict
    scales: dict
    u: np.ndarray = field(init=False, repr=False)
    v: np.ndarray = field(init=False, repr=False)

    def __post_init__(self) -> None:
        self.u, self.v = noise.coords(self.size)

    @property
    def shape(self) -> tuple[int, int]:
        return self.u.shape

    @property
    def pixel_m(self) -> float:
        return self.tile_m / self.size

    def s(self, name: str) -> int:
        """Child seed for a named feature of this material."""
        return noise.sub_seed(self.seed, name)

    def p(self, key: str, default=None):
        if key in self.params:
            return self.params[key]
        if default is None:
            raise KeyError(f"{self.lib_id}: preset is missing '{key}'")
        return default

    def col(self, key: str) -> np.ndarray:
        """A preset colour (sRGB hex) as linear RGB."""
        return ops.hex_to_linear(self.p(key))

    def per_m(self, cells_per_m: float) -> int:
        """Lattice period for a feature size given in cells per metre (integer, tile-safe)."""
        return max(1, int(round(cells_per_m * self.tile_m)))

    @property
    def wear(self) -> float:
        return float(self.params.get("wear", 0.0)) * float(self.scales.get("wear", 1.0))

    @property
    def grime(self) -> float:
        return float(self.params.get("grime", 0.0)) * float(self.scales.get("grime", 1.0))


@dataclass
class Maps:
    albedo: np.ndarray          # (H, W, 3) linear RGB
    roughness: np.ndarray       # (H, W)
    metallic: np.ndarray        # (H, W)
    height: np.ndarray          # (H, W) metres
    ao_mul: np.ndarray | None = None   # extra baked occlusion multiplier
    alpha: np.ndarray | None = None    # optional opacity (transparent materials)
    normal_strength: float = 1.0
    ao_radii_m: tuple = (0.004, 0.012, 0.04)
    ao_depth_m: float = 0.004
    ao_strength: float = 1.0


def weather(ctx: Ctx, m: Maps, *, edge_radius_m: float = 0.004, cavity_radius_m: float = 0.01,
            wear_color: np.ndarray | None = None, wear_lighten: float = 0.12,
            wear_rough: float | None = None, wear_metal: float | None = None,
            grime_color: np.ndarray | None = None, grime_rough: float = 0.92,
            breakup_per_m: float = 3.0) -> tuple[np.ndarray, np.ndarray]:
    """Edge wear on convex areas, grime in cavities. Intensities come from the preset
    (``wear`` / ``grime``) times the global preset scale. Returns (wear_mask, grime_mask)."""
    shape = ctx.shape
    zeros = np.zeros(shape)
    if ctx.wear <= 0 and ctx.grime <= 0:
        return zeros, zeros
    brk = ops.remap01(noise.fbm(ctx.u, ctx.v, ctx.per_m(breakup_per_m), ctx.s("wear_breakup"), octaves=5))
    wear_mask = zeros
    grime_mask = zeros
    if ctx.wear > 0:
        ref = float(ctx.params.get('relief_ref_mm', 1.0)) * 1e-3
        e = ops.edge_mask(m.height, ctx.pixel_m, edge_radius_m, ref_height_m=ref)
        wear_mask = ops.clamp01(e * ops.smoothstep(0.35, 0.75, brk + 0.25 * e) * ctx.wear * 1.6)
        if wear_color is None:
            target = m.albedo * (1.0 + wear_lighten)
        else:
            target = ops.fill(shape, wear_color)
        m.albedo = ops.blend(m.albedo, target, "normal", wear_mask)
        if wear_rough is not None:
            m.roughness = ops.lerp(m.roughness, wear_rough, wear_mask)
        if wear_metal is not None:
            m.metallic = ops.lerp(m.metallic, wear_metal, wear_mask)
    if ctx.grime > 0:
        ref = float(ctx.params.get('relief_ref_mm', 1.0)) * 1e-3
        c = ops.cavity_mask(m.height, ctx.pixel_m, cavity_radius_m, ref_height_m=ref)
        low = ops.remap01(noise.fbm(ctx.u, ctx.v, ctx.per_m(1.0), ctx.s("grime_low"), octaves=3))
        grime_mask = ops.clamp01(c * (0.4 + 0.6 * brk) * ctx.grime + float(ctx.params.get('grime_low', 0.06)) * ctx.grime * low * low)
        if grime_color is None:
            grime_color = ops.hex_to_linear(ctx.params.get("grime_color", "#5C5850"))
        tint = grime_color / max(1e-6, float(grime_color.max()))
        dark = 1.0 - float(ctx.params.get("grime_darken", 0.45))
        m.albedo = ops.blend(m.albedo, m.albedo * (tint * dark)[None, None, :], "normal", grime_mask * 0.8)
        m.roughness = ops.lerp(m.roughness, grime_rough, grime_mask)
    return wear_mask, grime_mask


@dataclass
class Encoded:
    albedo: np.ndarray   # uint8 (H, W, 3|4) sRGB
    orm: np.ndarray      # uint8 (H, W, 3) linear
    normal: np.ndarray   # uint8 (H, W, 3) OpenGL Y+
    stats: dict


def finalize(ctx: Ctx, m: Maps) -> Encoded:
    rules = ctx.rules
    lum_min = float(ctx.params.get("lum_min", rules["lum_min"]))
    if lum_min < float(rules["lum_min_black"]):
        raise ValueError(f"{ctx.lib_id}: lum_min {lum_min} below the black-material floor {rules['lum_min_black']}")
    albedo = ops.enforce_albedo_rules(m.albedo, lum_min, rules["lum_max"], rules["sat_max"])
    rough = ops.clamp01(m.roughness)
    metal = ops.clamp01(m.metallic)
    rough = np.where(metal > 0.5, np.maximum(rough, rules["metal_rough_min"]), rough)
    ao = ops.ao_from_height(m.height, ctx.pixel_m, m.ao_radii_m, m.ao_strength, m.ao_depth_m)
    if m.ao_mul is not None:
        ao = ao * m.ao_mul
    ao = np.clip(ao, 0.2, 1.0)
    n = ops.normal_from_height(m.height, ctx.pixel_m, m.normal_strength)

    srgb = ops.linear_to_srgb(albedo)
    alb8 = orm.to_u8(srgb)
    if m.alpha is not None:
        alb8 = np.concatenate([alb8, orm.to_u8(m.alpha)[..., None]], axis=-1)
    check_forbidden(ctx, alb8[..., :3])
    nrm8 = orm.to_u8(n * 0.5 + 0.5)
    lum = ops.luminance(albedo)
    stats = {
        "lum_floor_linear": lum_min,
        "albedo_lum_mean_linear": round(float(lum.mean()), 4),
        "albedo_lum_min_linear": round(float(lum.min()), 4),
        "albedo_lum_max_linear": round(float(lum.max()), 4),
        "roughness_mean": round(float(rough.mean()), 3),
        "metallic_mean": round(float(metal.mean()), 3),
        "ao_mean": round(float(ao.mean()), 3),
    }
    return Encoded(alb8, orm.pack(ao, rough, metal), nrm8, stats)


def check_forbidden(ctx: Ctx, srgb8: np.ndarray) -> None:
    """World surfaces must never show the interactable accent colour."""
    dist = float(ctx.rules.get("forbidden_dist", 40.0))
    flat = srgb8.reshape(-1, 3).astype(np.float64)
    for hx in ctx.rules.get("forbidden", []):
        h = hx.lstrip("#")
        ref = np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)
        d = np.sqrt(((flat - ref) ** 2).sum(axis=1)).min()
        if d < dist:
            raise ValueError(f"{ctx.lib_id}: albedo contains a colour within {d:.1f} of forbidden {hx}")
