# Shared helpers for the Rolling Thunder plan scripts (rolling_thunder_*.py): rectangles on the 1 m plan grid, cell
# tiling, which room lies on each side of an opening, a reachability graph, and the PASS / WARN / FAIL report every
# `--check` prints. Owner: ENV C (RT-C1, paper stage: D-148.2, D-149.10). No game/ output: these scripts only read the
# design doc's numbers (docs/design/heists/rolling_thunder.md) and check them.
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

Rect = Tuple[float, float, float, float]          # (x0, z0, x1, z1), metres, x0 < x1, z0 < z1
Cell = Tuple[int, int]
OUT = "OUT"                                       # outside a building footprint


@dataclass
class Report:
    """Collects check lines. FAIL makes the script exit 1; WARN is an early warning only (D-149.5)."""

    title: str
    fails: List[str] = field(default_factory=list)
    warns: List[str] = field(default_factory=list)
    lines: List[str] = field(default_factory=list)

    def section(self, name: str) -> None:
        self.lines.append(name + ":")

    def ok(self, msg: str) -> None:
        self.lines.append("  ok   " + msg)

    def info(self, msg: str) -> None:
        self.lines.append("  info " + msg)

    def warn(self, msg: str) -> None:
        self.warns.append(msg)
        self.lines.append("  WARN " + msg)

    def fail(self, msg: str) -> None:
        self.fails.append(msg)
        self.lines.append("  FAIL " + msg)

    def expect(self, cond: bool, msg: str) -> bool:
        (self.ok if cond else self.fail)(msg)
        return cond

    @property
    def passed(self) -> bool:
        return not self.fails

    def render(self) -> str:
        head = "== %s" % self.title
        tail = "RESULT: %s (%d fail, %d warn)" % ("PASS" if self.passed else "FAIL", len(self.fails), len(self.warns))
        return "\n".join([head] + self.lines + [tail])


def area(r: Rect) -> float:
    return (r[2] - r[0]) * (r[3] - r[1])


def size(r: Rect) -> Tuple[float, float]:
    return (r[2] - r[0], r[3] - r[1])


def inside(p: Tuple[float, float], r: Rect, margin: float = 0.0) -> bool:
    return r[0] - margin <= p[0] <= r[2] + margin and r[1] - margin <= p[1] <= r[3] + margin


def rect_inside(a: Rect, b: Rect) -> bool:
    return b[0] <= a[0] and b[1] <= a[1] and a[2] <= b[2] and a[3] <= b[3]


def overlap(a: Rect, b: Rect) -> bool:
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def gap(a: Rect, b: Rect) -> float:
    """Clear distance between two axis-aligned rectangles (0 when they touch or overlap)."""
    dx = max(b[0] - a[2], a[0] - b[2], 0.0)
    dz = max(b[1] - a[3], a[1] - b[3], 0.0)
    return math.hypot(dx, dz)


def dist(a: Tuple[float, float], b: Tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def path_len(points: Sequence[Tuple[float, float]]) -> float:
    return sum(dist(p, q) for p, q in zip(points, points[1:]))


def rect_cells(r: Rect) -> Iterable[Cell]:
    for i in range(int(math.floor(r[0])), int(math.ceil(r[2]))):
        for j in range(int(math.floor(r[1])), int(math.ceil(r[3]))):
            yield (i, j)


@dataclass(frozen=True)
class Room:
    rid: str
    purpose: str          # RoomVolume.purpose (lc_check_scale.gd); "deck" / "void" / "ramp" are plan-only
    rect: Rect
    ceiling: Optional[float] = None


@dataclass(frozen=True)
class Opening:
    """A door, gate or lift door on a wall line. (x, z) is the drawn grid point; `along` is the wall's direction:
    "x" = a wall at constant z (the opening spans x), "z" = a wall at constant x (it spans z). `width` is the clear
    width the doc gives (legend: personnel 0.9, service 1.0-1.2, diner front 1.8; None = not stated)."""

    level: str
    name: str
    x: float
    z: float
    along: str
    width: Optional[float]
    route: bool
    note: str = ""

    def span(self) -> Tuple[float, float]:
        """The clear span along the wall (an unstated width is drawn as one 0.9 m personnel leaf)."""
        w = self.width if self.width is not None else 0.9
        c = self.x if self.along == "x" else self.z
        return (c - w / 2.0, c + w / 2.0)


class Level:
    """One building level: a footprint tiled by rooms; one room may be the remainder (`fill`)."""

    def __init__(self, key: str, foot: Rect, rooms: List[Room], fill: Optional[Room] = None) -> None:
        self.key = key
        self.foot = foot
        self.rooms = rooms
        self.fill = fill
        self.cells: Dict[Cell, str] = {}
        self.overlaps: Set[str] = set()
        self.outside: Set[str] = set()
        for rm in rooms:
            for c in rect_cells(rm.rect):
                if not inside((c[0] + 0.5, c[1] + 0.5), foot):
                    self.outside.add(rm.rid)
                    continue
                if c in self.cells:
                    self.overlaps.add("%s&%s" % (self.cells[c], rm.rid))
                self.cells[c] = rm.rid
        self.fill_area = 0.0
        if fill is not None:
            for c in rect_cells(foot):
                if c not in self.cells:
                    self.cells[c] = fill.rid
                    self.fill_area += 1.0

    def room_at(self, c: Cell) -> str:
        return self.cells.get(c, OUT)

    def sides(self, op: Opening) -> Tuple[Set[str], Set[str]]:
        """Rooms on the two sides (west/north, east/south) of an opening span."""
        lo, hi = op.span()
        a: Set[str] = set()
        b: Set[str] = set()
        for k in range(int(math.floor(lo)), int(math.ceil(hi))):
            if op.along == "x":      # wall at z = op.z: cells above (z-1) and below (z)
                a.add(self.room_at((k, int(op.z) - 1)))
                b.add(self.room_at((k, int(op.z))))
            else:                    # wall at x = op.x
                a.add(self.room_at((int(op.x) - 1, k)))
                b.add(self.room_at((int(op.x), k)))
        return a, b


def reach(edges: Dict[str, Set[str]], start: str) -> Set[str]:
    seen = {start}
    todo = [start]
    while todo:
        for m in edges.get(todo.pop(), set()):
            if m not in seen:
                seen.add(m)
                todo.append(m)
    return seen


def link(edges: Dict[str, Set[str]], a: str, b: str) -> None:
    edges.setdefault(a, set()).add(b)
    edges.setdefault(b, set()).add(a)


def stair_ok(height: float, flights: int, risers: int, riser: float, tread: float) -> Tuple[bool, str]:
    """level_standards §2.7 (lc_check_scale.gd STAIR_*): riser 0.15-0.19, tread 0.25-0.32, <= 16 risers per flight."""
    tot = flights * risers * riser
    good = abs(tot - height) < 1e-6 and risers <= 16 and 0.15 <= riser <= 0.19 and 0.25 <= tread <= 0.32
    run = (risers - 1) * tread
    return good, "%d x %d risers x %.3f = %.2f (storey %.2f), run %.2f" % (flights, risers, riser, tot, height, run)


def slope_deg(rise: float, run: float) -> float:
    return math.degrees(math.atan2(abs(rise), run))
