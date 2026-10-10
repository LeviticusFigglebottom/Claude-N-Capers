"""Olive polymer (furniture, magazines, grips): same moulded grain as polymer_black, preset colour."""

from texgen.materials.base import Ctx, Maps
from texgen.materials.polymer_black import generate as _polymer


def generate(ctx: Ctx) -> Maps:
    return _polymer(ctx)
