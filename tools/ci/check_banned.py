#!/usr/bin/env python3
"""Grep gameplay code for banned patterns. Owner: LEAD. See docs/architecture.md §3, §7."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2] / "game"
SCAN = ["systems", "content", "world"]
RULES = [
    (re.compile(r"(?<![\w.])(randi|randf|randf_range|randi_range|randomize)\s*\("), "use GameRng.stream(&\"name\") instead of global RNG"),
    (re.compile(r"get_first_node_in_group\(\s*[\"&]*player"), "single-player assumption: iterate crew instead"),
    (re.compile(r"\bInput\.(is_action|get_vector|get_axis|is_key)"), "raw Input outside an input component (allowed only in files named *input*.gd or ui/)"),
    (re.compile(r"res://(systems|content|world)/"), None),  # cross-env path check handled below
]
OWN_ROOT = {"systems": "systems", "content": "content", "world": "world"}


def main() -> int:
    errors = []
    for top in SCAN:
        base = ROOT / top
        if not base.exists():
            continue
        for f in base.rglob("*.gd"):
            rel = f.relative_to(ROOT).as_posix()
            text = f.read_text(encoding="utf-8", errors="replace")
            for n, line in enumerate(text.splitlines(), 1):
                code = line.split("#", 1)[0]
                for rx, msg in RULES[:3]:
                    if rx.search(code):
                        if "Input" in rx.pattern and ("input" in f.name or "/ui/" in rel or rel.startswith("content/ui")):
                            continue
                        errors.append(f"{rel}:{n}: {msg}")
                # Cross-env hard paths: code may reference contracts/core/assets freely, and
                # its own top folder; referencing another env's internals is a contract smell.
                for m in re.finditer(r"res://(systems|content|world)/", code):
                    if m.group(1) != top:
                        errors.append(f"{rel}:{n}: hard path into another env's folder ({m.group(0)}); go through a contract")
    for e in errors:
        print(e)
    print(f"banned-patterns: {len(errors)} issue(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
