#!/usr/bin/env python3
"""Fail if an environment branch changes files it does not own. Owner: LEAD.

usage: check_ownership.py <a|b|c|d|p> [--base <ref>]
Compares HEAD against merge-base(HEAD, base) (default: origin/<trunk>).
"""
import argparse
import fnmatch
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]


def match(path: str, pattern: str) -> bool:
    if pattern.endswith("/**"):
        return path.startswith(pattern[:-3] + "/") or path == pattern[:-3]
    return fnmatch.fnmatch(path, pattern)


def owned(path: str, env: dict, always: list[str]) -> bool:
    if any(match(path, p) for p in always):
        # .import/.uid sidecars are allowed only next to files the env owns
        stem = path[: -len(".import")] if path.endswith(".import") else path[: -len(".uid")] if path.endswith(".uid") else path
        if stem != path:
            return owned(stem, env, [])
    if any(match(path, p) for p in env.get("excludes", [])):
        return False
    return any(match(path, p) for p in env["owns"])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("env", choices=["a", "b", "c", "d", "p"])
    ap.add_argument("--base", default=None)
    args = ap.parse_args()
    cfg = json.loads((ROOT / "tools/ci/owners.json").read_text())
    env = cfg["envs"][args.env]
    base = args.base or f"origin/{cfg['trunk']}"
    mb = subprocess.run(["git", "merge-base", "HEAD", base], cwd=ROOT, capture_output=True, text=True)
    if mb.returncode != 0:
        print(f"ownership: cannot find merge-base with {base}: {mb.stderr.strip()}")
        return 2
    diff = subprocess.run(["git", "diff", "--name-only", mb.stdout.strip(), "HEAD"], cwd=ROOT,
                          capture_output=True, text=True, check=True)
    # Merges of trunk bring lead changes in; only count files whose content differs from base.
    bad = [p for p in diff.stdout.split() if p and not owned(p, env, cfg.get("always_allowed", []))]
    if bad:
        print(f"ownership: ENV {args.env.upper()} modified files it does not own:")
        for p in bad:
            print(f"  {p}")
        print("Ask the lead via docs/status/env_%s.md instead." % args.env)
        return 1
    print(f"ownership: ENV {args.env.upper()} OK ({len(diff.stdout.split())} files changed)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
