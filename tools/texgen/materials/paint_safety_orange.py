"""High-vis safety-orange enamel on steel (saw housings): orange peel, edge chips to bare steel.
Same paint model as metal_painted, preset colour."""

from texgen.materials.base import Ctx, Maps
from texgen.materials.metal_painted import generate as _painted


def generate(ctx: Ctx) -> Maps:
    return _painted(ctx)
