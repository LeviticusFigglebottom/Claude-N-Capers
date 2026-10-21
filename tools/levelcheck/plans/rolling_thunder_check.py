# All Rolling Thunder plan checks in one run (RT-C1 paper stage, D-149.10). Owner: ENV C.
# Run: python3 tools/levelcheck/plans/rolling_thunder_check.py [--check]    (prints every report, exit 1 on any FAIL)
# Read-only: no layout .gd is emitted and nothing under game/ is touched; the emitter comes after the OF done check.
import os
import sys
from typing import Callable, List

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rolling_thunder_convoy as CV  # noqa: E402
import rolling_thunder_floors_ascii as FL  # noqa: E402
import rolling_thunder_site_ascii as ST  # noqa: E402
import rolling_thunder_slots as SL  # noqa: E402
from rolling_thunder_checklib import Report  # noqa: E402

CHECKS: List[Callable[[], Report]] = [FL.check, ST.check, CV.check, SL.check]


def main() -> int:
    reports = [c() for c in CHECKS]
    for r in reports:
        print(r.render())
        print()
    fails = sum(len(r.fails) for r in reports)
    warns = sum(len(r.warns) for r in reports)
    print("ROLLING THUNDER PLAN: %s (%d fail, %d warn across %d scripts)"
          % ("PASS" if fails == 0 else "FAIL", fails, warns, len(reports)))
    for r in reports:
        for f in r.fails:
            print("  FAIL [%s] %s" % (r.title.split(" ")[0], f))
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
